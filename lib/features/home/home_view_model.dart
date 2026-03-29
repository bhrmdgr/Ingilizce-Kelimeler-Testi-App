// features/home/home_view_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ingilizce_kelime_testi/features/home/home_model.dart';
import 'package:ingilizce_kelime_testi/service/admob/admob_service.dart';
import 'package:ingilizce_kelime_testi/service/firebase/user_service.dart';
import 'package:ingilizce_kelime_testi/service/firebase/stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeViewModel extends ChangeNotifier {
  final UserService _userService = UserService();
  final StatsService _statsService = StatsService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  HomeModel? _userData;
  HomeModel? get userData => _userData;

  int? _userRank;
  int? get userRank => _userRank;

  Future<void> fetchUserData() async {
    if (_userData == null) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      await _statsService.checkAndResetStreak();

      final user = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      String? userType = prefs.getString('user_type');

      if (userType == null && user != null && user.isAnonymous) {
        userType = 'guest';
      }

      if (userType == 'guest') {
        _userData = await _userService.getLocalGuest();
      } else if (user != null) {
        _userData = await _userService.getFirestoreUser(user.uid);

        if (_userData == null) {
          debugPrint("Kullanıcı dökümanı bulunamadı, oturum kapatılıyor...");
          await FirebaseAuth.instance.signOut();
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      if (_userData != null) {
        AdMobService.isPremiumUser = _userData!.isPremium;

        if (_userData!.isPremium) {
          await fetchUserRank(_userData!.totalXP);
        }
      }

    } catch (e) {
      debugPrint("Veri çekme hatası: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUserRank(double xp) async {
    try {
      final query = FirebaseFirestore.instance
          .collection('users')
          .where('total_xp', isGreaterThan: xp);

      final snapshot = await query.count().get();
      _userRank = (snapshot.count ?? 0) + 1;
      notifyListeners();
    } catch (e) {
      debugPrint("Sıralama çekme hatası: $e");
    }
  }

  Future<void> updateAvatar(String uid, String avatarPath, bool isGuest) async {
    try {
      await _userService.updateAvatar(uid, avatarPath, isGuest);
      await fetchUserData();
    } catch (e) {
      debugPrint("Avatar güncelleme hatası: $e");
    }
  }

  Future<void> setDailyGoal(int goal) async {
    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();

    // ✅ GÜNCELLEME: Daha güvenli kullanıcı tipi belirleme
    String? userType = prefs.getString('user_type');

    // Eğer pref boşsa ama Firebase user yoksa veya anonimse de guest say
    bool isGuest = userType == 'guest' || user == null || user.isAnonymous;
    String uid = user?.uid ?? 'guest_user';

    try {
      // Artık UserService hem lokal hem cloud güncellemeyi yönetiyor
      await _userService.updateDailyGoal(uid, goal, isGuest);
      // UI'ın güncellenmesi için veriyi tekrar çekiyoruz
      await fetchUserData();
    } catch (e) {
      debugPrint("Hedef güncelleme hatası: $e");
    }
  }
}