import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:ingilizce_kelime_testi/service/firebase/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignUpViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Yeni Kayıt Metodu: Telefon ve SMS gerektirmez
  Future<bool> signUp({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    // Validasyonlar
    if (!EmailValidator.validate(email)) {
      debugPrint("Geçersiz e-posta formatı");
      return false;
    }

    if (password != confirmPassword) {
      debugPrint("Şifreler eşleşmiyor");
      return false;
    }

    if (username.isEmpty || fullName.isEmpty) {
      debugPrint("Lütfen tüm alanları doldurun");
      return false;
    }

    _setLoading(true);

    try {
      // AuthService içindeki positional parameter yapısına uygun çağrı
      final result = await _authService.signUpWithEmail(email, password);

      if (result != null && result.user != null) {
        // DATABASE GÜNCELLEMESİ
        await _authService.saveUserToDatabase(
          uid: result.user!.uid,
          fullName: fullName,
          username: username,
          email: email,
          phoneNumber: "", // Telefon artık boş
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_type', 'free');
        await prefs.setString('full_name', fullName);

        _setLoading(false);
        return true;
      }
    } catch (e) {
      debugPrint("signUp hatası: $e");
    }

    _setLoading(false);
    return false;
  }

  @Deprecated("Telefon doğrulaması kaldırıldı, signUp metodunu kullanın.")
  Future<bool> sendVerificationCode({required String email, required String phone}) async => true;

  @Deprecated("Telefon doğrulaması kaldırıldı, signUp metodunu kullanın.")
  Future<bool> completeSignUp({
    required String fullName,
    required String username,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
    required String smsCode,
  }) async => await signUp(
    fullName: fullName,
    username: username,
    email: email,
    password: password,
    confirmPassword: confirmPassword,
  );
}