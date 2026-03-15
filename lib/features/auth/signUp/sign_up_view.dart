import 'package:flutter/gestures.dart'; // TapGesture için eklendi
import 'package:flutter/material.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:ingilizce_kelime_testi/features/auth/signUp/sign_up_view_model.dart';
import 'package:ingilizce_kelime_testi/helpers/policy/privacy_policy.dart'; // Eklendi
import 'package:ingilizce_kelime_testi/helpers/policy/terms_of_use.dart';   // Eklendi
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../../../../helpers/theme/theme.dart';
import '../../../../helpers/routers/routers.dart';

class SignupView extends StatefulWidget {
  const SignupView({super.key});

  @override
  State<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends State<SignupView> {
  final _fullNameController = TextEditingController(); // Eklendi
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _fullPhoneNumber = "";

  // Şifre görünürlük durumları
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Politika onay durumu
  bool _isAccepted = false;

  @override
  void dispose() {
    _fullNameController.dispose(); // Eklendi
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Politika içeriğini gösteren yardımcı alert
  void _showPolicyDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Kapat"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = Provider.of<SignUpViewModel>(context);

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            children: [
              Text("Yeni Hesap Oluştur", style: theme.textTheme.displayLarge),
              const SizedBox(height: 10),
              Text("Hemen aramıza katıl ve öğrenmeye başla.", style: theme.textTheme.bodyMedium),
              const SizedBox(height: 40),

              _buildField(_fullNameController, "Ad Soyad", Icons.badge_outlined, theme), // Eklendi
              const SizedBox(height: 15),

              _buildField(_usernameController, "Kullanıcı Adı", Icons.person_outline, theme),
              const SizedBox(height: 15),

              _buildPhoneField(theme),

              const SizedBox(height: 15),
              _buildField(_emailController, "E-posta", Icons.mail_outline, theme, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 15),

              // Şifre Alanı
              _buildField(
                  _passwordController,
                  "Şifre",
                  Icons.lock_outline,
                  theme,
                  isPassword: true,
                  isVisible: _isPasswordVisible,
                  onVisibilityToggle: () {
                    setState(() => _isPasswordVisible = !_isPasswordVisible);
                  }
              ),
              const SizedBox(height: 15),

              // Şifre Tekrar Alanı
              _buildField(
                  _confirmPasswordController,
                  "Şifre Tekrar",
                  Icons.lock_reset_outlined,
                  theme,
                  isPassword: true,
                  isVisible: _isConfirmPasswordVisible,
                  onVisibilityToggle: () {
                    setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
                  }
              ),

              const SizedBox(height: 20),

              // --- KULLANIM KOŞULLARI VE GİZLİLİK CHECKBOX ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _isAccepted,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (val) {
                        setState(() => _isAccepted = val ?? false);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontFamily: 'Poppins'),
                        children: [
                          TextSpan(
                            text: "Kullanım Koşulları",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                              color: Colors.blue,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _showPolicyDialog("Kullanım Koşulları", TermsOfUse.content),
                          ),
                          const TextSpan(text: " ve "),
                          TextSpan(
                            text: "Gizlilik Politikası",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                              color: Colors.blue,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _showPolicyDialog("Gizlilik Politikası", PrivacyPolicy.content),
                          ),
                          const TextSpan(text: " metinlerini okudum ve kabul ediyorum."),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: (viewModel.isLoading || !_isAccepted) ? null : () async {
                  if (_fullPhoneNumber.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen geçerli bir telefon numarası girin.")));
                    return;
                  }

                  bool codeSent = await viewModel.sendVerificationCode(
                    email: _emailController.text,
                    phone: _fullPhoneNumber,
                  );

                  if (codeSent && mounted) {
                    _showOtpDialog(context, theme);
                  }
                },
                child: viewModel.isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Kayıt Ol"),
              ),

              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Zaten hesabın var mı? Giriş Yap",
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: IntlPhoneField(
        controller: _phoneController,
        initialCountryCode: 'TR',
        disableLengthCheck: true,
        textAlignVertical: TextAlignVertical.center,
        dropdownIconPosition: IconPosition.trailing,
        showCountryFlag: true,
        dropdownTextStyle: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        pickerDialogStyle: PickerDialogStyle(
          backgroundColor: AppTheme.surfaceColor,
          searchFieldInputDecoration: InputDecoration(
            hintText: 'Ülke Ara',
            suffixIcon: const Icon(Icons.search),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        decoration: InputDecoration(
          hintText: 'Telefon Numarası',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          prefixIcon: Icon(
            Icons.phone_android_outlined,
            color: theme.colorScheme.primary.withOpacity(0.7),
          ),
        ),
        languageCode: "tr",
        onChanged: (phone) {
          _fullPhoneNumber = phone.completeNumber;
        },
      ),
    );
  }

  void _showOtpDialog(BuildContext context, ThemeData theme) {
    final TextEditingController otpController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // ViewModel'i dinle
            final viewModel = Provider.of<SignUpViewModel>(context);

            // Pinput Teması
            final defaultPinTheme = PinTheme(
              width: 50,
              height: 60,
              textStyle: theme.textTheme.displayLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.w600),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.transparent),
              ),
            );

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              contentPadding: const EdgeInsets.fromLTRB(24, 30, 24, 10),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.phonelink_lock_rounded, color: theme.colorScheme.primary, size: 32),
                  ),
                  const SizedBox(height: 20),
                  Text("Kodu Doğrula", style: theme.textTheme.displayLarge?.copyWith(fontSize: 22)),
                  const SizedBox(height: 10),
                  Text(
                    "Güvenliğin için telefonuna gelen 6 haneli kodu buraya girmelisin.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 30),
                  Pinput(
                    length: 6,
                    controller: otpController,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: defaultPinTheme.copyWith(
                      decoration: defaultPinTheme.decoration!.copyWith(
                        border: Border.all(color: theme.colorScheme.primary),
                        color: Colors.white,
                      ),
                    ),
                    separatorBuilder: (index) => const SizedBox(width: 8),
                    onChanged: (value) {
                      // Butonun aktifliğini güncellemek için dialog state'ini tetikle
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 35),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: viewModel.isLoading ? null : () => Navigator.pop(context),
                          child: Text("İptal", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: (viewModel.isLoading || otpController.text.length < 6)
                              ? null
                              : () async {
                            bool success = await viewModel.completeSignUp(
                              fullName: _fullNameController.text,
                              username: _usernameController.text,
                              email: _emailController.text,
                              phone: _fullPhoneNumber,
                              password: _passwordController.text,
                              confirmPassword: _confirmPasswordController.text,
                              smsCode: otpController.text,
                            );

                            if (success && context.mounted) {
                              Navigator.pop(context);
                              Navigator.pushReplacementNamed(context, AppRouters.home);
                            }
                          },
                          child: (viewModel.isLoading && otpController.text.length == 6)
                              ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                              : const Text("Onayla"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildField(
      TextEditingController controller,
      String hint,
      IconData icon,
      ThemeData theme,
      {bool isPassword = false,
        bool isVisible = false,
        VoidCallback? onVisibilityToggle,
        TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? !isVisible : false,
        keyboardType: keyboardType,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: theme.colorScheme.primary.withOpacity(0.7)),
          suffixIcon: isPassword ? IconButton(
            icon: Icon(
              isVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey.shade600,
            ),
            onPressed: onVisibilityToggle,
          ) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        ),
      ),
    );
  }
}