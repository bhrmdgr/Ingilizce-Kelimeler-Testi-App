// --- RankManager Sınıfı (Kod tarafında hesaplama yapar) ---
import 'package:flutter/animation.dart';

class RankManager {
  static Map<String, dynamic> getRank(int score) {
    if (score <= 499) {
      return {'title': 'Yolcu', 'icon': '👟', 'color': const Color(0xFF9E9E9E), 'next': 500};
    } else if (score <= 1499) {
      return {'title': 'Çırak', 'icon': '📖', 'color': const Color(0xFF4CAF50), 'next': 1500};
    } else if (score <= 3999) {
      return {'title': 'Kaşif', 'icon': '🧭', 'color': const Color(0xFF2196F3), 'next': 4000};
    } else if (score <= 7999) {
      return {'title': 'Konuşmacı', 'icon': '🗣️', 'color': const Color(0xFF9C27B0), 'next': 8000};
    } else if (score <= 14999) {
      return {'title': 'Bursiyer', 'icon': '🎓', 'color': const Color(0xFFFF9800), 'next': 15000};
    } else if (score <= 24999) {
      return {'title': 'Usta', 'icon': '⚔️', 'color': const Color(0xFFE91E63), 'next': 25000};
    } else if (score <= 39999) {
      return {'title': 'Bilge', 'icon': '🧙', 'color': const Color(0xFF3F51B5), 'next': 40000};
    } else {
      return {'title': 'Efsane', 'icon': '👑', 'color': const Color(0xFFFFD700), 'next': 55000};
    }
  }
}
