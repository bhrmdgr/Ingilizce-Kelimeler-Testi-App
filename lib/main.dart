import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart'; // ✅ EKLENDİ
import 'package:ingilizce_kelime_testi/features/auth/signIn/sign_in_view_model.dart';
import 'package:ingilizce_kelime_testi/features/auth/signUp/sign_up_view_model.dart';
import 'package:ingilizce_kelime_testi/features/help_support/help_view_model.dart';
import 'package:ingilizce_kelime_testi/features/home/home_view_model.dart';
import 'package:ingilizce_kelime_testi/features/premium/premium_view_model.dart';
import 'package:ingilizce_kelime_testi/features/profile/profile_view_model.dart';
import 'package:ingilizce_kelime_testi/features/quiz/quiz_view_model.dart';
import 'package:ingilizce_kelime_testi/features/settings/settings_view_model.dart';
import 'package:ingilizce_kelime_testi/helpers/routers/routers.dart';
import 'package:ingilizce_kelime_testi/helpers/theme/theme.dart';
import 'package:ingilizce_kelime_testi/features/home/home_view.dart';
import 'package:ingilizce_kelime_testi/features/auth/signIn/sign_in_view.dart';
import 'package:ingilizce_kelime_testi/service/admob/admob_service.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'dart:io'; // ✅ İzinler için eklendi
import 'package:app_tracking_transparency/app_tracking_transparency.dart'; // ✅ İzinler için eklendi

// ✅ YENİ: Background mesaj handler — herhangi bir class DIŞINDA, en üstte olmalı
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Arka planda mesaj alındı: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ APP CHECK: Debug token'ı zorla loglara yazdırmak için
  if (Platform.isIOS || Platform.isAndroid) {
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
  }

  // ✅ APP CHECK AKTİVASYONU - TEST MODU
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  // ✅ ADMOB SDK BAŞLATILIYOR
  await AdMobService.initialize();

  // ✅ YENİ: Background handler kayıt ediliyor
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SignInViewModel()),
        ChangeNotifierProvider(create: (_) => SignUpViewModel()),
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(create: (_) => SettingsViewModel()),
        ChangeNotifierProvider(create: (_) => QuizViewModel()),
        ChangeNotifierProvider(create: (_) => ProfileViewModel()),
        ChangeNotifierProvider(create: (_) => HelpViewModel()),
        ChangeNotifierProvider(create: (_) => PremiumViewModel()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'English Quiz',
      theme: AppTheme.lightTheme,
      onGenerateRoute: AppRouters.generateRoute,
      home: const AuthCheck(),
    );
  }
}

class AuthCheck extends StatefulWidget { // ✅ İzinleri başlatmak için StatefulWidget yapıldı
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {

  @override
  void initState() {
    super.initState();
    // ✅ Uygulama açıldığında izinleri iste
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _requestPermissions();
    });
  }

  // ✅ iOS İzin Yönetimi (Bildirim + AdMob Tracking)
  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      // 1. AdMob ATT İzni
      await Future.delayed(const Duration(seconds: 1)); // Pencerenin sağlıklı açılması için bekleme
      await AppTrackingTransparency.requestTrackingAuthorization();

      // 2. Bildirim İzni
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;

        if (user != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            builder: (context, userDoc) {
              if (userDoc.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              if (!userDoc.hasData || !userDoc.data!.exists) {
                FirebaseAuth.instance.signOut();
                return const SigninView();
              }

              return const HomeView();
            },
          );
        }

        return const SigninView();
      },
    );
  }
}