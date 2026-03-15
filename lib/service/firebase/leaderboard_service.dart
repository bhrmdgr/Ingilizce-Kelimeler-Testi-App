// ✅ GÜNCELLENMİŞ LEADERBOARD SERVICE
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LeaderboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ Kullanıcının genel sıralamasını Firebase Count ile maliyetsiz çekme
  Future<int> getUserRank(double xp) async {
    try {
      // Not: totalScore alanına göre 'leaderboard' koleksiyonundan sayıyoruz
      final query = _firestore
          .collection('leaderboard')
          .where('totalScore', isGreaterThan: xp);

      final snapshot = await query.count().get();

      // Üstte kaç kişi varsa +1 ekleyerek kullanıcının sırasını buluyoruz.
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

      transaction.set(leaderboardRef, {
        'uid': user.uid,
        'username': username,
        'avatar': avatar,
        'totalScore': currentTotal,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  // ✅ KOMŞU KULLANICILARI GETİR (Önceki 5 - Sonraki 5)
  Future<Map<String, List<DocumentSnapshot>>> getNeighboringLeaderboard(int currentUserScore) async {
    final String currentUid = _auth.currentUser?.uid ?? "";

    // 🏆 1. SIRADAKİ (Podyum için her zaman çekilir)
    var topQuery = await _firestore
        .collection('leaderboard')
        .orderBy('totalScore', descending: true)
        .limit(1)
        .get();

    // 🔼 ÜSTTEKİ 5 KİŞİ
    var aboveQuery = await _firestore
        .collection('leaderboard')
        .where('totalScore', isGreaterThan: currentUserScore)
        .orderBy('totalScore', descending: false)
        .limit(5) // Limit 3'ten 5'e çıkarıldı
        .get();

    // 🔽 ALTTAKİ 5 KİŞİ
    var belowQuery = await _firestore
        .collection('leaderboard')
        .where('totalScore', isLessThan: currentUserScore)
        .orderBy('totalScore', descending: true)
        .limit(5) // Limit 3'ten 5'e çıkarıldı
        .get();

    List<DocumentSnapshot> aboveDocs = aboveQuery.docs.reversed.toList();

    // Kendimizi listelerden temizle (Her ihtimale karşı)
    aboveDocs.removeWhere((doc) => doc.id == currentUid);
    List<DocumentSnapshot> belowDocs = belowQuery.docs.where((doc) => doc.id != currentUid).toList();

    return {
      'topOne': topQuery.docs,
      'above': aboveDocs,
      'below': belowDocs,
    };
  }
}