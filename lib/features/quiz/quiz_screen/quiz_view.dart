import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:ingilizce_kelime_testi/features/admob_widget/smart_banner_widget.dart';
import 'package:ingilizce_kelime_testi/features/quiz/quiz_model.dart';
import 'package:ingilizce_kelime_testi/features/quiz/quiz_view_model.dart';
import 'package:ingilizce_kelime_testi/service/admob/admob_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

class QuizView extends StatefulWidget {
  final List<WordModel> quizList;
  final bool isReviewMode;
  final bool isLearnedReview;

  const QuizView({
    super.key,
    required this.quizList,
    this.isReviewMode = false,
    this.isLearnedReview = false,
  });
  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  String? selectedOption;
  bool isChecking = false;
  bool showScorePop = false;

  final AudioPlayer audioPlayer = AudioPlayer();
  final AudioPlayer effectPlayer = AudioPlayer();
  bool _isSoundEnabled = true;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
    AdMobService.loadInterstitialAd();
  }

  Future<void> _initializeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isSoundEnabled = prefs.getBool('sound_enabled') ?? true;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = context.read<QuizViewModel>();
      vm.resetQuiz();
      if (widget.quizList.isNotEmpty) {
        await vm.generateOptions(widget.quizList[0]);
        if (vm.isCurrentQuestionEnToTr) {
          _speak(widget.quizList[0].en);
        }
      }
    });
  }

  Future<void> _speak(String text) async {
    if (_isSoundEnabled && text.isNotEmpty) {
      try {
        String url = "https://translate.google.com/translate_tts?ie=UTF-8&q=${Uri.encodeComponent(text)}&tl=en&client=tw-ob";
        await audioPlayer.play(UrlSource(url));
      } catch (e) {
        debugPrint("Ses çalma hatası: $e");
      }
    }
  }

  Future<void> _playResultSound(bool isCorrect) async {
    if (_isSoundEnabled) {
      try {
        await effectPlayer.stop();
        String path = isCorrect ? "sounds/correct.mp3" : "sounds/wrong.mp3";
        await effectPlayer.play(AssetSource(path), volume: 0.8);
      } catch (e) {
        debugPrint("Efekt sesi hatası: $e");
      }
    }
  }

  Future<bool> _showBackDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text("Testi Bırak?", style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1A1F36))),
        content: const Text(
          "Test bitmeden çıkarsanız sonuçlarınız kaydedilmeyecektir. Yine de çıkmak istiyor musunuz?",
          style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black54, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("GERİ DÖN", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w900)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("YİNE DE ÇIK", style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    effectPlayer.dispose();
    super.dispose();
  }

  Color _getBorderColor(String option, WordModel word, bool isEnToTr) {
    String correctVal = isEnToTr ? word.tr : word.en;
    if (selectedOption == null) return Colors.black.withOpacity(0.05);
    if (option == correctVal) return Colors.greenAccent.shade700;
    if (option == selectedOption && option != correctVal) return Colors.redAccent.shade400;
    return Colors.black.withOpacity(0.05);
  }

  Color _getFillColor(String option, WordModel word, bool isEnToTr) {
    String correctVal = isEnToTr ? word.tr : word.en;
    if (selectedOption == null) return Colors.white;
    if (option == correctVal) return Colors.green.shade50;
    if (option == selectedOption && option != correctVal) return Colors.red.shade50;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<QuizViewModel>();
    if (vm.currentQuestionIndex >= widget.quizList.length) return const Scaffold();

    final currentWord = widget.quizList[vm.currentQuestionIndex];
    final double progress = (vm.currentQuestionIndex + 1) / widget.quizList.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final bool shouldPop = await _showBackDialog();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Column(
            children: [
              Text(
                "SORU ${vm.currentQuestionIndex + 1}",
                style: TextStyle(color: Colors.indigo.shade900, fontWeight: FontWeight.w900, fontSize: 18),
              ),
              Text(
                "${widget.quizList.length} SORU İÇİNDEN",
                style: TextStyle(color: Colors.indigo.withOpacity(0.5), fontWeight: FontWeight.bold, fontSize: 10),
              ),
            ],
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: Icon(Icons.close_rounded, color: Colors.indigo.shade900, size: 22),
                onPressed: () async {
                  final bool shouldPop = await _showBackDialog();
                  if (shouldPop && context.mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: Icon(
                    _isSoundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    color: _isSoundEnabled ? const Color(0xFF6366F1) : Colors.grey,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _isSoundEnabled = !_isSoundEnabled),
                ),
              ),
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF0F3FF), Color(0xFFFFFFFF)],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      _buildProgressBar(progress),
                      const SizedBox(height: 24),
                      _buildScoreBoard(vm),
                      const SizedBox(height: 32),
                      _buildWordCard(currentWord, vm.isCurrentQuestionEnToTr),
                      const SizedBox(height: 40),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          physics: const BouncingScrollPhysics(),
                          itemCount: vm.currentOptions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            return _buildAnimatedOption(vm, vm.currentOptions[index], currentWord);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (vm.isLoading)
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      color: Colors.white.withOpacity(0.2),
                      child: const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
                    ),
                  ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SmartBannerWidget(
          adUnitId: AdMobService.bannerAdUnitIdQuiz,
        ),
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return Container(
      height: 12,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutBack,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _buildWordCard(WordModel word, bool isEnToTr) {
    String questionText = isEnToTr ? word.en : word.tr;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.indigo.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 15)),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _speak(word.en),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.volume_up_rounded, color: Color(0xFF6366F1), size: 32),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            questionText.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.indigo.shade900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedOption(QuizViewModel vm, String option, WordModel correctWord) {
    Color borderColor = _getBorderColor(option, correctWord, vm.isCurrentQuestionEnToTr);
    Color fillColor = _getFillColor(option, correctWord, vm.isCurrentQuestionEnToTr);

    String correctVal = vm.isCurrentQuestionEnToTr ? correctWord.tr : correctWord.en;
    bool isSelected = selectedOption == option;
    bool isCorrect = option == correctVal;

    return GestureDetector(
      onTap: isChecking ? null : () => _handleAnswer(vm, option, correctWord),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 2.5),
          boxShadow: [
            if (!isChecking)
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isSelected || (isChecking && isCorrect) ? Colors.indigo.shade900 : Colors.indigo.shade700,
                ),
              ),
            ),
            if (isChecking && isCorrect)
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 26),
            if (isSelected && !isCorrect)
              const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 26),
          ],
        ),
      ),
    );
  }

  void _handleAnswer(QuizViewModel vm, String option, WordModel word) async {
    if (isChecking) return;
    setState(() {
      selectedOption = option;
      isChecking = true;
      showScorePop = true;
    });

    String correctVal = vm.isCurrentQuestionEnToTr ? word.tr : word.en;
    bool isCorrect = (option == correctVal);
    _playResultSound(isCorrect);

    if (!vm.isCurrentQuestionEnToTr) {
      _speak(word.en);
    }

    vm.answerQuestion(
      word,
      option,
      isReviewMode: widget.isReviewMode,
      isLearnedReview: widget.isLearnedReview,
    );

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => showScorePop = false);
    });

    await Future.delayed(const Duration(milliseconds: 1000));

    if (mounted) {
      if (vm.currentQuestionIndex < widget.quizList.length - 1) {
        await vm.nextQuestion(widget.quizList);
        setState(() {
          selectedOption = null;
          isChecking = false;
        });
        if (vm.isCurrentQuestionEnToTr) {
          _speak(widget.quizList[vm.currentQuestionIndex].en);
        }
      } else {
        await vm.uploadResults(widget.quizList.length);
        if (mounted) {
          if (vm.shouldShowInterstitialAd(widget.quizList.length)) {
            AdMobService.showInterstitialAd();
          }
          _showResultDialog(vm);
        }
      }
    }
  }

  Widget _buildScoreBoard(QuizViewModel vm) {
    return Row(
      children: [
        _scoreTileCompact(vm.correctCount, Colors.green, Icons.check_circle_outline_rounded),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Column(
                  children: [
                    Text("${vm.currentScore} XP", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                    if (vm.comboCount >= 3)
                      Text("🔥 SERİ: ${vm.comboCount}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                  ],
                ),
                if (showScorePop)
                  Positioned(
                    top: -35,
                    child: TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: -20),
                      duration: const Duration(milliseconds: 500),
                      builder: (context, double value, child) {
                        return Transform.translate(
                          offset: Offset(0, value),
                          child: Text(
                            vm.lastEarnedPoints > 0 ? "+${vm.lastEarnedPoints}" : "${vm.lastEarnedPoints}",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: vm.lastEarnedPoints > 0 ? Colors.green.shade600 : Colors.redAccent,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        _scoreTileCompact(vm.wrongCount, Colors.redAccent, Icons.highlight_off_rounded),
      ],
    );
  }

  Widget _scoreTileCompact(int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text("$count", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.indigo.shade900)),
        ],
      ),
    );
  }

  void _showResultDialog(QuizViewModel vm) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: Column(
          children: [
            const Icon(Icons.stars_rounded, color: Colors.amber, size: 80),
            const SizedBox(height: 16),
            Text("TEBRİKLER!", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.indigo.shade900, fontSize: 24)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Kazanılan Puan", style: TextStyle(color: Colors.indigo.withOpacity(0.5), fontWeight: FontWeight.bold)),
            Text("${vm.currentScore} XP", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Color(0xFF6366F1))),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _resSummary(vm.correctCount, "Doğru", Colors.green),
                const SizedBox(width: 24),
                _resSummary(vm.wrongCount, "Yanlış", Colors.redAccent),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                if (!widget.isReviewMode && !widget.isLearnedReview)
                  _dialogButton("YENİ TEST", const Color(0xFF2ECC71), () {
                    Navigator.pop(context);
                    _startNewQuiz();
                  }),
                if (vm.wrongWords.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      List<WordModel> retryList = List.from(vm.wrongWords);
                      Navigator.pop(context);
                      _startRetryQuiz(retryList);
                    },
                    child: const Text("YANLIŞLARI TEKRAR ET", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent)),
                  ),
                _dialogButton("ANA SAYFA", const Color(0xFF6366F1), () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resSummary(int val, String label, Color color) {
    return Column(
      children: [
        Text("$val", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black38)),
      ],
    );
  }

  Widget _dialogButton(String label, Color color, VoidCallback onTap) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
      ),
    );
  }

  void _startNewQuiz() {
    final vm = context.read<QuizViewModel>();
    List<WordModel> newList = vm.generateQuizList();
    setState(() {
      selectedOption = null;
      isChecking = false;
      showScorePop = false;
    });
    vm.resetQuiz();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => QuizView(quizList: newList)));
  }

  void _startRetryQuiz(List<WordModel> retryList) {
    final vm = context.read<QuizViewModel>();
    setState(() {
      selectedOption = null;
      isChecking = false;
      showScorePop = false;
    });
    vm.resetQuiz();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => QuizView(quizList: retryList, isReviewMode: true)));
  }
}