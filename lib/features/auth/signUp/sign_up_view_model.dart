import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:ingilizce_kelime_testi/service/firebase/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignUpViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Telefon doğrulama süreci için gerekli ID
  String? _verificationId;
  bool get isCodeSent => _verificationId != null;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // 1. ADIM: Doğrulama Kodu Gönder
  Future<bool> sendVerificationCode({
    required String email,
    required String phone,
  }) async {
    // Email Validasyonu
    if (!EmailValidator.validate(email)) {
      debugPrint("Geçersiz e-posta formatı");
      return false;
    }

    if (phone.isEmpty) {
      debugPrint("Telefon numarası boş olamaz");
      return false;
    }

    _setLoading(true);
    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: phone,
        codeSent: (id) {
          _verificationId = id;
          _setLoading(false);
        },
        verificationFailed: (e) {
          _setLoading(false);
          debugPrint("Telefon doğrulama hatası: ${e.message}");
        },
      );
      return true;
    } catch (e) {
      _setLoading(false);
      debugPrint("verifyPhoneNumber beklenmedik hata: $e");
      return false;
    }
  }

  // 2. ADIM: Kaydı Tamamla (Telefon Kodu + Email/Şifre + Database Kaydı)
  Future<bool> completeSignUp({
    required String fullName, // İsim Soyisim eklendi
    required String username,
    required String email,
    required String phone, // Database kaydı için gerekli
    required String password,
    required String confirmPassword,
    required String smsCode,
  }) async {
    // Basit Doğrulamalar
    if (password != confirmPassword) {
      debugPrint("Şifreler eşleşmiyor");
      return false;
    }

    if (_verificationId == null) {
      debugPrint("Önce doğrulama kodu gönderilmelidir");
      return false;
    }

    _setLoading(true);

    try {
      // Firebase Kayıt ve Telefon Bağlama İşlemi
      final result = await _authService.signUpWithPhoneAndEmail(
        email: email,
        password: password,
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      // ✅ Eğer kayıt başarılıysa ve kullanıcı oluşturulmuşsa devam et
      if (result != null && result.user != null) {
        // --- DATABASE GÜNCELLEMESİ ---
        await _authService.saveUserToDatabase(
          uid: result.user!.uid,
          fullName: fullName, // AuthService'e iletiliyor
          username: username,
          email: email,
          phoneNumber: phone,
        );

        // Yerel hafızaya kullanıcı tipini kaydet
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_type', 'free');
        await prefs.setString('full_name', fullName); // İsim yerelde de saklanabilir

        _setLoading(false);
        return true;
      }
    } catch (e) {
      // ✅ BURASI KRİTİK: Hata fırlatılırsa loading'i burada kapatıyoruz
      debugPrint("completeSignUp hatası yakalandı: $e");
    }

    // Eğer buraya ulaştıysa bir şeyler ters gitmiştir
    _setLoading(false);
    return false;
  }
}