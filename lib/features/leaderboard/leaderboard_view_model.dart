import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ingilizce_kelime_testi/service/firebase/leaderboard_service.dart';

class LeaderboardViewModel extends ChangeNotifier {
  final LeaderboardService _service = LeaderboardService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<DocumentSnapshot> _topPlayers = [];
  List<DocumentSnapshot> get topPlayers => _topPlayers;

  List<DocumentSnapshot> _aboveMe = [];
  List<DocumentSnapshot> get aboveMe => _aboveMe;

  List<DocumentSnapshot> _belowMe = [];
  List<DocumentSnapshot> get belowMe => _belowMe;

  int? _myRank;
  int? get myRank => _myRank;

  Future<void> fetchLeaderboardData(double currentXP) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Tam sıralamayı al
      _myRank = await _service.getUserRank(currentXP);

      // Komşuları ve lideri al
      final data = await _service.getNeighboringLeaderboard(currentXP.toInt());

      _topPlayers = data['topOne'] ?? [];
      _aboveMe = data['above'] ?? [];
      _belowMe = data['below'] ?? [];
    } catch (e) {
      debugPrint("Leaderboard hatası: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}