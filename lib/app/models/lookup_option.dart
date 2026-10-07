/// A lightweight id/label pair used for read-only lookup selectors
/// (suppliers, items, branches).
class LookupOption {
  final String id;
  final String label;

  const LookupOption({
    required this.id,
    required this.label,
  });

  factory LookupOption.fromDynamic(dynamic value) {
    if (value is! Map) {
      return const LookupOption(id: '', label: '');
    }

    final map = Map<String, dynamic>.from(value);
    final id = _firstNonEmpty([
      map['id'],
      map['ID'],
      map['_id'],
      map['itemId'],
      map['item_id'],
      map['itemCode'],
      map['item_code'],
      map['code'],
    ]);

    final label = _firstNonEmpty([
      map['name'],
      map['itemName'],
      map['item_name'],
      map['supplier_name'],
      map['branch_name'],
      map['organization_name'],
      map['company_name'],
      map['label'],
      map['title'],
      map['description'],
    ]);

    return LookupOption(
      id: id,
      label: label.isEmpty ? id : label,
    );
  }

  static String _string(dynamic value) => value?.toString().trim() ?? '';

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = _string(value);
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }
}
