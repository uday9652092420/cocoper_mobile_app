class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.name,
  });

  final String code;
  final String name;

  factory AppLanguage.fromJson(dynamic value) {
    if (value is! Map) {
      throw const FormatException('Language entry must be an object.');
    }

    final map = Map<String, dynamic>.from(value);
    final code = map['code']?.toString().trim() ?? '';
    final name = map['name']?.toString().trim() ?? '';
    if (code.isEmpty || name.isEmpty) {
      throw const FormatException('Language entry requires code and name.');
    }

    return AppLanguage(code: code, name: name);
  }
}
