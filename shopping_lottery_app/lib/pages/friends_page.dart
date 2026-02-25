// lib/pages/friends_page.dart
//
// ✅ FriendsPage（可編譯完整版｜修正 GoogleFonts.notoSansTc 不存在）
//
// - 從 users 集合載入會員（排除自己）
// - 搜尋：displayName/name/email/phone/uid
// - 點擊好友 → 開啟 FriendChatPage（你剛剛那份可直接用）
//
// 依賴：cloud_firestore, firebase_auth, flutter/material, google_fonts
//
// Firestore: users/{uid}
//   - displayName 或 name
//   - email, phone (可選)
//   - createdAt (可選)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'friend_chat_page.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _search = TextEditingController();

  // ✅ 跨版本通用：避免 GoogleFonts.notoSansTc 不存在
  TextStyle _noto({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    return GoogleFonts.getFont(
      'Noto Sans TC',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      return const Scaffold(body: Center(child: Text('請先登入')));
    }

    final cs = Theme.of(context).colorScheme;

    // 你若 users 沒 createdAt 或索引不足，這裡可能會噴錯
    // 但至少可編譯；若你確定沒 createdAt，請改成：_db.collection('users').limit(500)
    final query = _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(500);

    return Scaffold(
      appBar: AppBar(
        title: Text('好友', style: _noto(fontWeight: FontWeight.w900)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋 name / email / phone / uid',
                hintStyle: _noto(color: cs.onSurfaceVariant),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              style: _noto(),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '載入失敗：${snap.error}\n\n'
                        '若你 users 沒 createdAt 欄位，請把 query 改成：\n'
                        "_db.collection('users').limit(500)",
                        style: _noto(color: cs.onSurfaceVariant),
                      ),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;

                // 排除自己 + 搜尋
                final q = _search.text.trim().toLowerCase();
                final filtered = docs.where((doc) {
                  if (doc.id == me.uid) return false;

                  if (q.isEmpty) return true;

                  final d = doc.data();
                  final uid = doc.id.toLowerCase();
                  final name = _s(d['displayName'] ?? d['name']).toLowerCase();
                  final email = _s(d['email']).toLowerCase();
                  final phone = _s(d['phone']).toLowerCase();

                  return uid.contains(q) ||
                      name.contains(q) ||
                      email.contains(q) ||
                      phone.contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      '沒有符合條件的好友',
                      style: _noto(color: cs.onSurfaceVariant),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final doc = filtered[i];
                    final d = doc.data();

                    final friendUid = doc.id;
                    final name = _s(d['displayName'] ?? d['name']);
                    final email = _s(d['email']);
                    final phone = _s(d['phone']);

                    final title = name.isNotEmpty ? name : friendUid;

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          title.isNotEmpty ? title.characters.first : '?',
                          style: _noto(fontWeight: FontWeight.w900),
                        ),
                      ),
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _noto(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        [
                          'uid: $friendUid',
                          if (email.isNotEmpty) 'email: $email',
                          if (phone.isNotEmpty) 'phone: $phone',
                        ].join('  •  '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _noto(color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chat_bubble_outline),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FriendChatPage(
                              friendUid: friendUid,
                              friendName: name.isEmpty ? null : name,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
