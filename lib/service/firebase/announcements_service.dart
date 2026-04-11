import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnnouncementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> checkNewAnnouncement() async {
    try {
      // 1. Güncel duyuruyu çek
      final doc = await _firestore.collection('announcements').doc('current').get();

      if (!doc.exists || doc.data()?['isActive'] == false) return null;

      final data = doc.data()!;
      final String announcementId = data['id'];

      // 2. Yerel hafızadaki son okunan ID'yi al
      final prefs = await SharedPreferences.getInstance();
      final String? lastReadId = prefs.getString('last_read_announcement_id');

      // 3. Karşılaştır: ID'ler farklıysa duyuru yenidir
      if (lastReadId != announcementId) {
        return data;
      }
    } catch (e) {
      print("Duyuru kontrol hatası: $e");
    }
    return null;
  }

  Future<void> markAsRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_read_announcement_id', id);
  }
}