class WordModel {
  final String en;
  final String tr;
  final String type;
  final String level;

  WordModel({
    required this.en,
    required this.tr,
    required this.type,
    required this.level,
  });

  // JSON'dan (Map) nesneye dönüştüren mevcut constructor'ın muhtemelen şöyledir:
  factory WordModel.fromJson(Map<String, dynamic> json) {
    return WordModel(
      en: json['en'] ?? '',
      tr: json['tr'] ?? '',
      type: json['type'] ?? '',
      level: json['level'] ?? '',
    );
  }

  // --- BURAYI EKLE: Nesneyi JSON'a (Map) dönüştüren metod ---
  Map<String, dynamic> toJson() {
    return {
      'en': en,
      'tr': tr,
      'type': type,
      'level': level,
    };
  }
}
class QuizSettings {
  int questionCount;
  String selectedLevel;
  String selectedType;

  QuizSettings({
    this.questionCount = 10,
    this.selectedLevel = 'A1',
    this.selectedType = 'all',
  });
}