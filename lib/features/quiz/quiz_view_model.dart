import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ingilizce_kelime_testi/features/quiz/quiz_model.dart';
import 'package:ingilizce_kelime_testi/helpers/score_calculate/score_calculate.dart';
import 'package:ingilizce_kelime_testi/service/admob/admob_service.dart';
import 'package:ingilizce_kelime_testi/service/firebase/leaderboard_service.dart';
import 'package:ingilizce_kelime_testi/service/firebase/stats_service.dart';

// ✅ Yeni eklenen mod yapısı
enum QuizQuestionMode { enToTr, trToEn, random }

class QuizViewModel extends ChangeNotifier {
  final StatsService _statsService = StatsService();
  final LeaderboardService _leaderboardService = LeaderboardService();

  List<WordModel> _allWords = [];
  bool isLoading = false;

  // --- Quiz Ayarları ---
  int selectedQuestionCount = 10;
  String selectedLevel = 'A1';
  String selectedType = 'all';
  QuizQuestionMode selectedQuestionMode = QuizQuestionMode.enToTr; // ✅ Varsayılan mod

  // --- Reklam Sayaçları ---
  // ✅ Soru bazlı takip için yeni sayaç
  int _totalQuestionCounter = 0;

  final List<int> questionCounts = [10, 20, 30, 40];
  final List<String> levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
  final List<String> types = ['all', 'noun', 'verb', 'adjective', 'adverb'];

  // --- Quiz Anlık Durum Verileri ---
  int currentQuestionIndex = 0;
  int correctCount = 0;
  int wrongCount = 0;
  List<WordModel> learnedWords = [];
  List<WordModel> wrongWords = [];
  List<String> currentOptions = [];
  bool isCurrentQuestionEnToTr = true; // ✅ O anki sorunun yönünü tutar

  int currentScore = 0;
  int comboCount = 0;
  int lastEarnedPoints = 0;

  // QuizViewModel.dart içinde

  // ✅ Güncellenen Reklam Mantığı
  bool shouldShowInterstitialAd(int currentQuizLength) {
    _totalQuestionCounter += currentQuizLength;

    // ŞART: Toplam çözülen soru sayısı 30 veya üzerindeyse reklam göster.
    // Bu sayede:
    // - 30 veya 40 soruluk testte (Hemen ilk test sonu)
    // - 20 soruluk testlerde (2. test sonu - toplam 40 olur)
    // - 10 soruluk testlerde (3. test sonu - toplam 30 olur)
    // reklam tetiklenir.
    if (_totalQuestionCounter >= 30) {
      _totalQuestionCounter = 0; // Reklam gösterileceği için sayacı sıfırla
      return true;
    }

    // Şart sağlanmadıysa reklam gösterme
    return false;
  }

  Future<void> fetchWords() async {
    isLoading = true;
    notifyListeners();

    try {
      String fileName = _getFileNameByLevel(selectedLevel);
      final String response = await rootBundle.loadString('assets/data/$fileName');
      final List<dynamic> data = json.decode(response);

      _allWords = data
          .where((item) => item.containsKey('en'))
          .map((json) => WordModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint("Kelime yükleme hatası ($selectedLevel): $e");
      _allWords = [];
    }

    isLoading = false;
    notifyListeners();
  }

  String _getFileNameByLevel(String level) {
    switch (level) {
      case 'A1': return 'a_one_words.json';
      case 'A2': return 'a_two_words.json';
      case 'B1': return 'b_one_words.json';
      case 'B2': return 'b_two_words.json';
      case 'C1': return 'c_one_words.json';
      case 'C2': return 'c_two_words.json';
      default: return 'a_one_words.json';
    }
  }

  void setQuestionCount(int count) {
    selectedQuestionCount = count;
    notifyListeners();
  }

  void setLevel(String level) {
    if (selectedLevel != level) {
      selectedLevel = level;
      fetchWords();
      notifyListeners();
    }
  }

  void setType(String type) {
    selectedType = type;
    notifyListeners();
  }

  // ✅ Yeni eklenen mod değiştirici
  void setQuestionMode(QuizQuestionMode mode) {
    selectedQuestionMode = mode;
    notifyListeners();
  }

  List<WordModel> generateQuizList() {
    List<WordModel> filtered = _allWords.where((w) {
      bool levelMatch = w.level == selectedLevel;
      bool typeMatch = selectedType == 'all' || w.type == selectedType;
      return levelMatch && typeMatch;
    }).toList();

    filtered.shuffle();
    return filtered.take(selectedQuestionCount).toList();
  }

  Future<void> generateOptions(WordModel correctWord) async {
    if (_allWords.isEmpty) {
      selectedLevel = correctWord.level;
      await fetchWords();
    }

    // ✅ Sorunun yönünü belirle
    if (selectedQuestionMode == QuizQuestionMode.enToTr) {
      isCurrentQuestionEnToTr = true;
    } else if (selectedQuestionMode == QuizQuestionMode.trToEn) {
      isCurrentQuestionEnToTr = false;
    } else {
      isCurrentQuestionEnToTr = Random().nextBool();
    }

    // ✅ Doğru cevabı yönüne göre seç
    String correctAnswer = isCurrentQuestionEnToTr ? correctWord.tr : correctWord.en;

    List<String> options = [correctAnswer];
    List<WordModel> potentialDistractors = List.from(_allWords);
    potentialDistractors.shuffle();

    for (var word in potentialDistractors) {
      // ✅ Çeldiricileri yönüne göre seç
      String distractor = isCurrentQuestionEnToTr ? word.tr : word.en;

      if (options.length < 4 &&
          distractor != correctAnswer &&
          !options.contains(distractor)) {

        if (selectedType != 'all') {
          if (word.type == correctWord.type) {
            options.add(distractor);
          }
        } else {
          options.add(distractor);
        }
      }
    }

    if (options.length < 4) {
      for (var word in potentialDistractors) {
        String distractor = isCurrentQuestionEnToTr ? word.tr : word.en;
        if (options.length < 4 && distractor != correctAnswer && !options.contains(distractor)) {
          options.add(distractor);
        }
      }
    }

    options.shuffle();
    currentOptions = options;
    notifyListeners();
  }

  void answerQuestion(WordModel word, String selectedAnswer,
      {bool isReviewMode = false, bool isLearnedReview = false}) {

    // ✅ Kontrolü soru yönüne göre yap
    String correctAnswer = isCurrentQuestionEnToTr ? word.tr : word.en;
    bool isCorrect = correctAnswer == selectedAnswer;

    if (isCorrect) {
      correctCount++;
      comboCount++; // ✅ Önce combo artırılır
      if (!isLearnedReview) learnedWords.add(word);
    } else {
      wrongCount++;
      comboCount = 0; // ✅ Hata yapılırsa seri sıfırlanır
      wrongWords.add(word);
    }

    int basePoint;
    int penaltyPoint;

    if (isLearnedReview) {
      basePoint = 4;
      penaltyPoint = 2;
    } else if (isReviewMode) {
      basePoint = 6;
      penaltyPoint = 3;
    } else {
      basePoint = 10;
      penaltyPoint = 6;
    }

    double multiplier = 1.0;
    String lvl = word.level.toUpperCase();
    if (lvl.startsWith('B')) multiplier = 1.5;
    if (lvl.startsWith('C')) multiplier = 2.5;

    if (isCorrect) {
      // ✅ Temel Puan Hesaplama
      lastEarnedPoints = (basePoint * multiplier).toInt();

      // ✅ SERİ BONUSU: Normal modda 5. doğrudan itibaren her soruya +3 prim eklenir
      if (!isReviewMode && !isLearnedReview && comboCount >= 5) {
        lastEarnedPoints += 3;
      }
    } else {
      lastEarnedPoints = -(penaltyPoint * multiplier).toInt();
    }

    currentScore += lastEarnedPoints;
    if (currentScore < 0) currentScore = 0;

    notifyListeners();
  }

  Future<void> nextQuestion(List<WordModel> quizList) async {
    if (currentQuestionIndex < quizList.length - 1) {
      currentQuestionIndex++;
      await generateOptions(quizList[currentQuestionIndex]);
      notifyListeners();
    }
  }

  Future<void> refreshQuizList() async {
    resetQuiz();
    List<WordModel> newList = generateQuizList();
    if (newList.isNotEmpty) {
      await generateOptions(newList[0]);
    }
    notifyListeners();
  }

  Future<void> uploadResults(int totalQuestionCount, {bool isReview = false}) async {
    isLoading = true;
    notifyListeners();

    try {
      // ✅ StatsService artık tüm tabloları (User, Daily, Genel Leaderboard, Haftalık Leaderboard)
      // tek bir Batch işlemi ile güncellediği için burası yeterli.
      await _statsService.saveQuizResults(
        learnedWords: learnedWords,
        wrongWords: wrongWords,
        earnedPoints: currentScore,
        isReviewMode: isReview,
      );

      // ❌ LeaderboardService.updateScores(currentScore) satırı silindi.
      // Çünkü StatsService içindeki batch.set(leaderboardRef...) ve
      // batch.set(weeklyLeaderboardRef...) işlemleri bu görevi zaten üstlendi.

    } catch (e) {
      debugPrint("Yükleme hatası: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void resetQuiz() {
    currentQuestionIndex = 0;
    correctCount = 0;
    wrongCount = 0;
    learnedWords = [];
    wrongWords = [];
    currentOptions = [];
    currentScore = 0;
    comboCount = 0;
    lastEarnedPoints = 0;
    notifyListeners();
  }
}