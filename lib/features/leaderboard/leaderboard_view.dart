import 'package:cloud_firestore/cloud_firestore.dart';
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

class _LeaderboardViewState extends State<LeaderboardView> with SingleTickerProviderStateMixin {
  final String _defaultAvatar = "assets/avatars/boy-avatar-1.png";
  late TabController _tabController;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pageController = PageController();

    Future.microtask(() => context
        .read<LeaderboardViewModel>()
        .fetchLeaderboardData(
        widget.userData.totalXP,
        widget.userData.weeklyScore
    ));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String _getValidAvatar(String? path) {
    if (path == null || path.trim().isEmpty || !path.contains('assets')) {
      return _defaultAvatar;
    }
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LeaderboardViewModel>();
    final rank = RankManager.getRank(widget.userData.totalXP.toInt());

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [rank['color'].withOpacity(0.6), const Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              _buildModernTabSelector(),
              const SizedBox(height: 10),

              if (viewModel.isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.white)))
              else
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) => _tabController.animateTo(index),
                    children: [
                      _buildLeaderboardList(
                          viewModel,
                          isWeekly: true,
                          title: "Haftalık Sıralaman: ${viewModel.myWeeklyRank ?? '...'}"
                      ),
                      _buildLeaderboardList(
                          viewModel,
                          isWeekly: false,
                          title: "Genel Sıralaman: ${viewModel.myRank ?? '...'}"
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTabSelector() {
    final rank = RankManager.getRank(widget.userData.totalXP.toInt());
    final Color userRankColor = rank['color'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (index) => _pageController.animateToPage(index,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutQuart),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              userRankColor,
              userRankColor.withBlue(150).withRed(100)
            ],
          ),
          boxShadow: [
            BoxShadow(
                color: userRankColor.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4)
            )
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: "HAFTALIK"),
          Tab(text: "GENEL"),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(LeaderboardViewModel viewModel, {required bool isWeekly, required String title}) {
    final topPlayers = isWeekly ? viewModel.topWeeklyPlayers : viewModel.topPlayers;
    final aboveMe = isWeekly ? viewModel.aboveMeWeekly : viewModel.aboveMe;
    final belowMe = isWeekly ? viewModel.belowMeWeekly : viewModel.belowMe;
    final myRank = isWeekly ? viewModel.myWeeklyRank : viewModel.myRank;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        _buildPodium(topPlayers, isWeekly: isWeekly),
        const SizedBox(height: 25),
        _buildSectionTitle(title),
        const SizedBox(height: 10),

        ...aboveMe.map((doc) => _buildPlayerCard(doc, isMe: false, isWeekly: isWeekly)),
        _buildPlayerCard(null, isMe: true, currentRank: myRank, isWeekly: isWeekly),
        ...belowMe.map((doc) => _buildPlayerCard(doc, isMe: false, isWeekly: isWeekly)),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              "ARENA LİGİ",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 3),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildPodium(List topPlayers, {required bool isWeekly}) {
    if (topPlayers.isEmpty) return const SizedBox.shrink();

    List<Widget> podiumItems = [];
    if (topPlayers.length >= 2) podiumItems.add(_buildPodiumItem(topPlayers[1], 2, isWeekly: isWeekly));
    podiumItems.add(_buildPodiumItem(topPlayers[0], 1, isWeekly: isWeekly));
    if (topPlayers.length >= 3) podiumItems.add(_buildPodiumItem(topPlayers[2], 3, isWeekly: isWeekly));

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: podiumItems,
      ),
    );
  }

  Widget _buildPodiumItem(dynamic doc, int rank, {required bool isWeekly}) {
    final data = doc.data() as Map<String, dynamic>;
    final bool isMe = (data['username'] == widget.userData.username);

    final String name = isMe ? widget.userData.username : (data['username'] ?? "...");
    final String avatar = isMe ? _getValidAvatar(widget.userData.avatarPath) : _getValidAvatar(data['avatar']);

    // ✅ Podyumda gösterilen puan (Haftalık mı Genel mi)
    final displayScore = (data[isWeekly ? 'weeklyScore' : 'totalScore'] ?? 0).toInt();

    double avatarRadius = rank == 1 ? 45 : 35;
    double iconSize = rank == 1 ? 40 : 30;
    Color rankColor = rank == 1 ? Colors.amber : (rank == 2 ? Colors.grey.shade100 : const Color(0xFFFF9A00));
    IconData podiumIcon = rank == 1 ? Icons.emoji_events_rounded : Icons.workspace_premium_rounded;

    return Transform.translate(
      offset: rank == 1 ? const Offset(0, -20) : Offset.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(podiumIcon, color: rankColor, size: iconSize),
          const SizedBox(height: 5),
          Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: avatarRadius + 3,
                backgroundColor: rankColor,
                child: CircleAvatar(
                  radius: avatarRadius,
                  backgroundImage: AssetImage(avatar),
                ),
              ),
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: rankColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(rank.toString(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(name, style: TextStyle(color: Colors.white, fontSize: rank == 1 ? 14 : 12, fontWeight: rank == 1 ? FontWeight.bold : FontWeight.normal)),
          Text("$displayScore XP", style: TextStyle(color: rankColor.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(dynamic doc, {required bool isMe, int? currentRank, required bool isWeekly}) {
    String name;
    int displayScore;
    int rankCalculationScore; // ✅ Rütbe hesabı için kullanılacak puan
    String avatar;

    if (isMe) {
      name = widget.userData.username;
      displayScore = isWeekly ? widget.userData.weeklyScore.toInt() : widget.userData.totalXP.toInt();
      rankCalculationScore = widget.userData.totalXP.toInt(); // Kendimiz için her zaman totalXP
      avatar = _getValidAvatar(widget.userData.avatarPath);
    } else {
      final data = doc.data() as Map<String, dynamic>;
      name = data['username'] ?? "Öğrenci";
      displayScore = (data[isWeekly ? 'weeklyScore' : 'totalScore'] ?? 0).toInt();
      // ✅ BAŞKASI İÇİN: Rütbe ikonu her zaman totalScore üzerinden hesaplanır
      rankCalculationScore = (data['totalScore'] ?? 0).toInt();
      avatar = _getValidAvatar(data['avatar']);
    }

    // ✅ Rütbe ikonunu ve başlığını her zaman GENEL PUANA göre alıyoruz
    final rankInfo = RankManager.getRank(rankCalculationScore);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF1E293B) : Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMe ? const Color(0xFF6366F1).withOpacity(0.5) : Colors.white.withOpacity(0.05),
          width: isMe ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              currentRank != null ? "#$currentRank" : "",
              style: TextStyle(color: isMe ? Colors.amber : Colors.white38, fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
          CircleAvatar(radius: 22, backgroundImage: AssetImage(avatar)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text("${rankInfo['icon']} ${rankInfo['title']}".toUpperCase(),
                    style: TextStyle(color: rankInfo['color'], fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ],
            ),
          ),
          // ✅ Sadece sağda yazan sayı (XP) listeye göre değişir (Haftalık mı Genel mi)
          Text("$displayScore XP", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 5),
      child: Text(title, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2)),
    );
  }
}