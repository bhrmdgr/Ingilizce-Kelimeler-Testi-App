import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:ingilizce_kelime_testi/service/firebase/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _dailyGoal = 10;
  int get dailyGoal => _dailyGoal;

  // ✅ YENİ: Değişiklik bayrağı
  bool _hasChanges = false;
  bool get hasChanges => _hasChanges;

  // ✅ GÜNCELLEME: Firebase sorgusu yerine local veriden/bayraktan kontrol
  bool _isGuestUser = true;
  bool get isGuest => _isGuestUser;

  // ✅ YENİ: Bayrağı sıfırla (HomeView okuduktan sonra çağırır)
  void clearChanges() {
    _hasChanges = false;
  }

  SettingsViewModel() {
    _loadCurrentGoal();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> _loadCurrentGoal() async {
    final prefs = await SharedPreferences.getInstance();
    _dailyGoal = prefs.getInt('daily_goal') ?? 10;

    // ✅ Home sayfasında kaydedilen user_type kontrolü
    final userType = prefs.getString('user_type');
    _isGuestUser = (userType == 'guest' || _auth.currentUser?.isAnonymous == true);

    notifyListeners();
  }

  Future<void> updateDailyGoal(int newGoal) async {
    _dailyGoal = newGoal;
    _hasChanges = true; // ✅ Değişiklik işaretlendi
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_goal', newGoal);

    final user = _auth.currentUser;
    if (user != null && !user.isAnonymous) {
      await _firestore.collection('users').doc(user.uid).update({
        'daily_goal': newGoal,
      });
    }
  }

  // ✅ YENİ: Bildirim ayarı değişince de bayrak set edilsin
  void markChanged() {
    _hasChanges = true;
    notifyListeners();
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_type');
      await prefs.setBool('is_guest', false);
    } catch (e) {
      debugPrint("Hata: $e");
    } finally {
      _setLoading(false);
    }
  }
}