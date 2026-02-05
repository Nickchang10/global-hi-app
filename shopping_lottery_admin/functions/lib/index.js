"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.paymentSuccess = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const crypto = __importStar(require("crypto"));
admin.initializeApp();
const db = admin.firestore();
/* ============================================================
 * Webhook 驗證
 * ============================================================ */
function verifyLinePay(req) {
    const secret = functions.config().linepay.secret;
    const signature = req.headers["x-line-authorization"];
    const nonce = req.headers["x-line-authorization-nonce"];
    if (!secret || !signature || !nonce)
        return false;
    const body = JSON.stringify(req.body);
    const raw = secret + nonce + body;
    const hash = crypto
        .createHmac("sha256", secret)
        .update(raw)
        .digest("base64");
    return hash === signature;
}
function verifyECPay(payload) {
    const key = functions.config().ecpay.hash_key;
    const iv = functions.config().ecpay.hash_iv;
    if (!key || !iv || !(payload === null || payload === void 0 ? void 0 : payload.CheckMacValue))
        return false;
    const sorted = Object.keys(payload)
        .filter((k) => k !== "CheckMacValue")
        .sort()
        .map((k) => `${k}=${payload[k]}`)
        .join("&");
    const raw = `HashKey=${key}&${sorted}&HashIV=${iv}`;
    const encoded = encodeURIComponent(raw).toLowerCase();
    const hash = crypto
        .createHash("sha256")
        .update(encoded)
        .digest("hex")
        .toUpperCase();
    return hash === payload.CheckMacValue;
}
function verifyTapPay(req) {
    const key = functions.config().tappay.partner_key;
    const signature = req.headers["x-tappay-signature"];
    if (!key || !signature)
        return false;
    const body = JSON.stringify(req.body);
    const hash = crypto
        .createHmac("sha256", key)
        .update(body)
        .digest("hex");
    return hash === signature;
}
/* ============================================================
 * paymentSuccess（最終版）
 * ============================================================ */
exports.paymentSuccess = functions.https.onRequest(async (req, res) => {
    try {
        // --------------------------------------------------
        // 1️⃣ 判斷金流來源（⚠️ 這裡是正確寫法）
        // --------------------------------------------------
        const provider = String(req.headers["x-payment-provider"] || "");
        if ((provider === "linepay" && !verifyLinePay(req)) ||
            (provider === "ecpay" && !verifyECPay(req.body)) ||
            (provider === "tappay" && !verifyTapPay(req))) {
            res.status(403).send("invalid webhook signature");
            return;
        }
        // --------------------------------------------------
        // 2️⃣ Payload 驗證
        // --------------------------------------------------
        const { status, transactionId, userId, userEmail, items, finalAmount, paymentMethod, } = req.body;
        if (status !== "SUCCESS" ||
            !transactionId ||
            !userId ||
            !Array.isArray(items)) {
            res.status(400).send("invalid payload");
            return;
        }
        // --------------------------------------------------
        // 3️⃣ 防重複（Idempotency）
        // --------------------------------------------------
        const lockRef = db.collection("payment_locks").doc(transactionId);
        const result = await db.runTransaction(async (tx) => {
            var _a;
            const lockSnap = await tx.get(lockRef);
            if (lockSnap.exists) {
                return {
                    duplicated: true,
                    orderId: lockSnap.data().orderId,
                };
            }
            // 訂單編號
            const orderNo = await generateOrderNo(tx);
            const orderRef = db.collection("orders").doc();
            // 建立訂單
            tx.set(orderRef, {
                orderNo,
                userId,
                userEmail,
                status: "paid",
                items,
                finalAmount,
                currency: "TWD",
                payment: {
                    method: paymentMethod,
                    transactionId,
                    paidAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            // 扣庫存
            for (const item of items) {
                const pRef = db.collection("products").doc(item.productId);
                const pSnap = await tx.get(pRef);
                if (!pSnap.exists)
                    throw new Error("product not found");
                const stock = (_a = pSnap.data().stock) !== null && _a !== void 0 ? _a : 0;
                if (stock < item.qty)
                    throw new Error("out of stock");
                tx.update(pRef, {
                    stock: admin.firestore.FieldValue.increment(-item.qty),
                    sold: admin.firestore.FieldValue.increment(item.qty),
                });
            }
            // 銷售報表（日）
            const day = new Date().toISOString().slice(0, 10);
            const reportRef = db.collection("reports_sales").doc(day);
            tx.set(reportRef, {
                date: day,
                totalRevenue: admin.firestore.FieldValue.increment(finalAmount),
                orderCount: admin.firestore.FieldValue.increment(1),
            }, { merge: true });
            // 鎖定 webhook
            tx.set(lockRef, {
                orderId: orderRef.id,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            return { duplicated: false, orderId: orderRef.id };
        });
        // --------------------------------------------------
        // 4️⃣ 通知（Transaction 外）
        // --------------------------------------------------
        await Promise.all([
            db.collection("notifications").add({
                userId,
                title: "付款成功",
                body: "您的訂單已付款成功",
                orderId: result.orderId,
                read: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            }),
            db.collection("notifications").add({
                role: "admin",
                title: "新訂單成立",
                body: `訂單 ${result.orderId} 已付款`,
                orderId: result.orderId,
                read: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            }),
        ]);
        res.json(Object.assign({ ok: true }, result));
    }
    catch (err) {
        console.error("paymentSuccess error:", err);
        res.status(500).send(err.message);
    }
});
/* ============================================================
 * 訂單編號產生（Transaction-safe）
 * ============================================================ */
async function generateOrderNo(tx) {
    var _a;
    const ymd = new Date().toISOString().slice(0, 10).replace(/-/g, "");
    const ref = db.doc(`counters/orders_${ymd}`);
    const snap = await tx.get(ref);
    const next = snap.exists ? ((_a = snap.data().seq) !== null && _a !== void 0 ? _a : 0) + 1 : 1;
    tx.set(ref, { seq: next }, { merge: true });
    return `OS${ymd}${String(next).padStart(4, "0")}`;
}
//# sourceMappingURL=index.js.map