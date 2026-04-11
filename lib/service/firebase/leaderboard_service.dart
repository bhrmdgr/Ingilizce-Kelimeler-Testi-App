// ✅ GÜNCELLENMİŞ LEADERBOARD SERVICE
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LeaderboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ Kullanıcının sıralamasını çekme (Haftalık veya Genel seçilebilir)
  Future<int> getUserRank(double score, {bool isWeekly = false}) async {
    try {
      final String collectionPath = isWeekly ? 'weekly_leaderboard' : 'leaderboard';
      final String fieldPath = isWeekly ? 'weeklyScore' : 'totalScore';

      final query = _firestore
          .collection(collectionPath)
          .where(fieldPath, isGreaterThan: score);

      final snapshot = await query.count().get();

      return (snapshot.count ?? 0) + 1;
    } catch (e) {
      debugPrint("Sıralama çekilemedi (LeaderboardService): $e");
      return 0;
    }
  }

  Future<void> updateScores(int earnedPoints) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;

    final userRef = _firestore.collection('users').doc(user.uid);
    final leaderboardRef = _firestore.collection('leaderboard').doc(user.uid);
    final weeklyLeaderboardRef = _firestore.collection('weekly_leaderboard').doc(user.uid); // ✅ HAFTALIK REF EKLENDİ

    return _firestore.runTransaction((transaction) async {
      DocumentSnapshot userSnap = await transaction.get(userRef);
      if (!userSnap.exists) return;

      int currentTotal = (userSnap.get('totalScore') ?? 0) + earnedPoints;
      int currentWeekly = (userSnap.get('weeklyScore') ?? 0) + earnedPoints;
      String username = userSnap.get('username') ?? "Öğrenci";
      String avatar = userSnap.get('avatarPath') ?? "assets/avatars/boy-avatar-1.png";

      transaction.update(userRef, {
        'totalScore': currentTotal,
        'weeklyScore': currentWeekly,
        'lastActive': FieldValue.serverTimestamp(),
      });

      // ✅ GENEL TABLO GÜNCELLEME
      transaction.set(leaderboardRef, {
        'uid': user.uid,
        'username': username,
        'avatar': avatar,
        'totalScore': currentTotal,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ✅ HAFTALIK TABLO GÜNCELLEME
      transaction.set(weeklyLeaderboardRef, {
        'uid': user.uid,
        'username': username,
        'avatar': avatar,
        'weeklyScore': currentWeekly,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  // ✅ KOMŞU KULLANICILARI GETİR (Haftalık veya Genel seçilebilir)
  Future<Map<String, List<DocumentSnapshot>>> getNeighboringLeaderboard(
      int currentUserScore, {bool isWeekly = false}) async {

    final String currentUid = _auth.currentUser?.uid ?? "";
    final String collectionPath = isWeekly ? 'weekly_leaderboard' : 'leaderboard';
    final String fieldPath = isWeekly ? 'weeklyScore' : 'totalScore';

    // 🏆 İLK 3 KİŞİ (Podyum için)
    var topQuery = await _firestore
        .collection(collectionPath)
        .orderBy(fieldPath, descending: true)
        .limit(3)
        .get();

    // 🔼 ÜSTTEKİ 5 KİŞİ
    var aboveQuery = await _firestore
        .collection(collectionPath)
        .where(fieldPath, isGreaterThan: currentUserScore)
        .orderBy(fieldPath, descending: false)
        .limit(3)
        .get();

    // 🔽 ALTTAKİ 5 KİŞİ
    var belowQuery = await _firestore
        .collection(collectionPath)
        .where(fieldPath, isLessThan: currentUserScore)
        .orderBy(fieldPath, descending: true)
        .limit(3)
        .get();

    List<DocumentSnapshot> aboveDocs = aboveQuery.docs.reversed.toList();

    // Kendimizi listelerden temizle
    aboveDocs.removeWhere((doc) => doc.id == currentUid);
    List<DocumentSnapshot> belowDocs = belowQuery.docs.where((doc) => doc.id != currentUid).toList();

    return {
      'topOne': topQuery.docs,
      'above': aboveDocs,
      'below': belowDocs,
    };
  }
}