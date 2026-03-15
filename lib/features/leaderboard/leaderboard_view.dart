import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ingilizce_kelime_testi/features/home/home_model.dart';
import 'package:ingilizce_kelime_testi/helpers/rank_manager/rank_manager.dart';
import 'leaderboard_view_model.dart';

class LeaderboardView extends StatefulWidget {
  final HomeModel userData;
  const LeaderboardView({super.key, required this.userData});

  @override
  State<LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends State<LeaderboardView> {
  // Varsayılan avatar yolu (Assets klasöründe olduğundan emin ol)
  final String _defaultAvatar = "assets/avatars/boy-avatar-1.png";

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context
        .read<LeaderboardViewModel>()
        .fetchLeaderboardData(widget.userData.totalXP));
  }

  // Güvenli Resim Yükleme Fonksiyonu
  String _getValidAvatar(String? path) {
    if (path == null || path.trim().isEmpty) return _defaultAvatar;
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LeaderboardViewModel>();
    final rank = RankManager.getRank(widget.userData.totalXP.toInt());

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [rank['color'].withOpacity(0.8), const Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              if (viewModel.isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.white)))
              else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _buildPodium(viewModel.topPlayers),
                      const SizedBox(height: 30),
                      _buildSectionTitle("Genel Sıralaman: ${viewModel.myRank ?? '...'}"),

                      // Üstteki 5 kişi (Service 3 getiriyordu, ViewModel/Service limitine göre dinamik)
                      ...viewModel.aboveMe.map((doc) => _buildPlayerCard(doc, isMe: false)),

                      // KENDİMİZ (Count ile gelen gerçek sıra burada gösteriliyor)
                      _buildPlayerCard(null, isMe: true, currentRank: viewModel.myRank),

                      // Alttaki 5 kişi
                      ...viewModel.belowMe.map((doc) => _buildPlayerCard(doc, isMe: false)),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            "ARENA LİGİ",
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildPodium(List topPlayers) {
    if (topPlayers.isEmpty) return const SizedBox.shrink();
    final data = topPlayers[0].data() as Map<String, dynamic>;

    return Column(
      children: [
        const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 50),
        const SizedBox(height: 10),
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.amber,
          child: CircleAvatar(
            radius: 47,
            backgroundImage: AssetImage(_getValidAvatar(data['avatar'])),
          ),
        ),
        const SizedBox(height: 10),
        Text(data['username'] ?? "Lider", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const Text("LİDER", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, letterSpacing: 3)),
      ],
    );
  }

  Widget _buildPlayerCard(dynamic doc, {required bool isMe, int? currentRank}) {
    String name;
    int score;
    String avatar;

    if (isMe) {
      name = widget.userData.username;
      score = widget.userData.totalXP.toInt();
      avatar = _getValidAvatar(widget.userData.avatarPath);
    } else {
      final data = doc.data() as Map<String, dynamic>;
      name = data['username'] ?? "Öğrenci";
      score = (data['totalScore'] ?? 0).toInt();
      avatar = _getValidAvatar(data['avatar']);
    }

    final rankInfo = RankManager.getRank(score);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isMe ? Colors.amber.withOpacity(0.5) : Colors.white10,
          width: isMe ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          if (!isMe) const Icon(Icons.unfold_more_rounded, color: Colors.white24, size: 16),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundImage: AssetImage(avatar),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text("${rankInfo['icon']} ${rankInfo['title']}",
                    style: TextStyle(color: rankInfo['color'], fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("$score XP", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              // BURASI KRİTİK: Count ile gelen sıra burada gösteriliyor
              if (isMe && currentRank != null)
                Text("#$currentRank", style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, left: 5),
      child: Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }
}