import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ingilizce_kelime_testi/features/home/home_model.dart';
import 'package:ingilizce_kelime_testi/features/home/home_view_model.dart';
import 'package:ingilizce_kelime_testi/helpers/rank_manager/rank_manager.dart';
import 'package:ingilizce_kelime_testi/helpers/routers/routers.dart';

class ScoreCardWidget extends StatelessWidget {
  final HomeModel userData;
  final VoidCallback onShowLeaderboard;

  const ScoreCardWidget({
    super.key,
    required this.userData,
    required this.onShowLeaderboard,
  });

  @override
  Widget build(BuildContext context) {
    // Rütbe bilgilerini alıyoruz
    final rank = RankManager.getRank(userData.totalXP.toInt());
    final Color rankColor = rank['color']; // Rütbenin ana rengi (Örn: Altın, Bronz, Safir vb.)
    final int currentXP = userData.totalXP.toInt();
    final int nextGoal = rank['next'];
    final double progress = (currentXP / nextGoal).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // ARKA PLAN ARTIK DİNAMİK: Rütbe rengine göre gradyan oluşturur
        gradient: LinearGradient(
          colors: [
            rankColor.withOpacity(0.85),
            rankColor.withBlue(rankColor.blue + 30).withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: rankColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: Stack(
          children: [
            // Dekoratif arka plan dairesi
            Positioned(
              right: -30,
              top: -30,
              child: CircleAvatar(
                radius: 70,
                backgroundColor: Colors.white.withOpacity(0.07),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                children: [
                  // --- ÜST KISIM: Rütbe ve İlerleme ---
                  Row(
                    children: [
                      _buildRankBadge(rank),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rank['title'].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: 1.5,
                                shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: Colors.black.withOpacity(0.1),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "$currentXP / $nextGoal XP",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // --- ORTA KISIM: Renkli İkonlu Skorlar ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildScoreItem("HAFTALIK", "${userData.weeklyScore.toInt()}",
                          Icons.calendar_month_rounded, Colors.lightBlueAccent),
                      _buildDivider(),
                      _buildScoreItem("TOPLAM", "${userData.totalXP.toInt()}",
                          Icons.emoji_events_rounded, Colors.amber), // Kupa Altın Rengi
                      _buildDivider(),
                      _buildScoreItem("SERİ", "${userData.dailyStreak}",
                          Icons.local_fire_department_rounded, Colors.orangeAccent), // Ateş Turuncu
                    ],
                  ),

                  const SizedBox(height: 25),

                  // --- ALT KISIM: Arena Butonu ---
                  _buildArenaAccessButton(context, rankColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(Map<String, dynamic> rank) {
    return Container(
      height: 65,
      width: 65,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
      ),
      child: Center(
        child: Text(rank['icon'], style: const TextStyle(fontSize: 32)),
      ),
    );
  }

  Widget _buildScoreItem(String label, String value, IconData icon, Color iconColor) {
    return Column(
      children: [
        // İkon artık kendi rengine sahip
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.white.withOpacity(0.2),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber.withOpacity(0.8), size: 18),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  // ✅ PREMIUM ALERT METODU EKLENDİ
  void _showPremiumAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Text(
              "Arena'ya Katıl",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Dünya sıralamasındaki yerini merak mı ediyorsun?",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 15),
            _buildFeatureRow(Icons.leaderboard_rounded, "Gerçek zamanlı sıralama"),
            _buildFeatureRow(Icons.military_tech_rounded, "Ligindeki rakiplerini gör"),
            _buildFeatureRow(Icons.ads_click_rounded, "Reklamsız deneyim"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Daha Sonra", style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRouters.premium);
            },
            child: const Text("PREMIUM'A GEÇ", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildArenaAccessButton(BuildContext context, Color rankColor) {
    final userRank = context.watch<HomeViewModel>().userRank;

    return InkWell(
      onTap: () {
        if (userData.isPremium) {
          Navigator.pushNamed(context, AppRouters.leaderboard, arguments: userData);
        } else {
          _showPremiumAlert(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08), // Daha premium şeffaf görünüm
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: userData.isPremium ? Colors.amber.withOpacity(0.5) : Colors.white10,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Sol İkon
            Icon(
              userData.isPremium ? Icons.stars_rounded : Icons.workspace_premium_rounded,
              color: Colors.amber,
              size: 22,
            ),
            const SizedBox(width: 12),

            // Metin Alanı - Expanded kullanarak taşmayı önlüyoruz
            Expanded(
              child: Text(
                "Genel Sıralamadaki Yerini Gör",
                // textAlign: TextAlign.center, // Row içinde Expanded varken center garip durabilir, sola yaslamak daha profesyoneldir
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w800,
                  fontSize: 13, // 12 çok küçüktü, 13 ideal
                  letterSpacing: 0.3,
                ),
                softWrap: true,
                maxLines: 2, // En fazla 2 satır, kelimeyi bölmez alta atar
              ),
            ),

            const SizedBox(width: 8),

            // Sağ Taraf: Sıralama ve Ok
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (userData.isPremium && userRank != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "#$userRank",
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.3),
                  size: 14,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}