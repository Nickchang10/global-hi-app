import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/campaign_model.dart';

class CampaignService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// 讀取活動清單（可選 vendorId 篩選）
  Future<List<Campaign>> fetchCampaigns({String? vendorId}) async {
    // ✅ 關鍵：使用帶泛型的 Query<Map<String, dynamic>>
    Query<Map<String, dynamic>> query = _db
        .collection('campaigns')
        .orderBy('createdAt', descending: true);

    if (vendorId != null && vendorId.trim().isNotEmpty) {
      query = query.where('vendorId', isEqualTo: vendorId.trim());
    }

    final QuerySnapshot<Map<String, dynamic>> snap = await query.get();

    return snap.docs
        .map((d) => Campaign.fromMap(d.id, d.data()))
        .toList();
  }

  /// 新增活動
  Future<void> addCampaign(Campaign campaign) async {
    final data = <String, dynamic>{
      ...campaign.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _db.collection('campaigns').add(data);
  }

  /// 更新活動
  Future<void> updateCampaign(String id, Map<String, dynamic> data) async {
    await _db.collection('campaigns').doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 刪除活動
  Future<void> deleteCampaign(String id) async {
    await _db.collection('campaigns').doc(id).delete();
  }
}
