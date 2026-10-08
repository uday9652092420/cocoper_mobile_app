/// A single line of a Purchase Invoice.
///
/// Field names follow the verified backend contract:
/// quantityTons, discount, piecesPercentage, pieces, baseCost, actualQuantity,
/// purchaseCost and purchaseAmount. Purchase Invoice lines do NOT contain
/// `rate` or `amount`.
class PurchaseInvoiceLine {
  final String? id;
  final String itemId;
  final String itemName;
  final double quantityTons;
  final double discount;
  final double piecesPercentage;
  final double pieces;
  final double baseCost;
  final double actualQuantity;
  final double purchaseCost;
  final double purchaseAmount;

  const PurchaseInvoiceLine({
    this.id,
    this.itemId = '',
    this.itemName = '',
    this.quantityTons = 0,
    this.discount = 0,
    this.piecesPercentage = 0,
    this.pieces = 0,
    this.baseCost = 0,
    this.actualQuantity = 0,
    this.purchaseCost = 0,
    this.purchaseAmount = 0,
  });

  factory PurchaseInvoiceLine.fromJson(Map<String, dynamic> json) {
    final rawItem = json['item'];
    final item = rawItem is Map
        ? Map<String, dynamic>.from(rawItem)
        : const <String, dynamic>{};

    return PurchaseInvoiceLine(
      id: _string(json['id']),
      itemId: _string(json['itemId'] ?? json['item_id'] ?? item['id']),
      itemName: _string(
        json['itemName'] ??
            json['item_name'] ??
            json['name'] ??
            item['name'] ??
            item['itemName'] ??
            item['item_name'],
      ),
      quantityTons: _double(
        json['quantityTons'] ?? json['quantity_tons'],
      ),
      discount: _double(json['discount']),
      piecesPercentage: _double(
        json['piecesPercentage'] ?? json['pieces_percentage'],
      ),
      pieces: _double(json['pieces']),
      baseCost: _double(json['baseCost'] ?? json['base_cost']),
      actualQuantity: _double(
        json['actualQuantity'] ?? json['actual_quantity'],
      ),
      purchaseCost: _double(json['purchaseCost'] ?? json['purchase_cost']),
      purchaseAmount: _double(
        json['purchaseAmount'] ?? json['purchase_amount'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id != null && id!.isNotEmpty) 'id': id,
      'itemId': itemId,
      'quantityTons': quantityTons,
      'discount': discount,
      'piecesPercentage': piecesPercentage,
      'pieces': pieces,
      'baseCost': baseCost,
      'actualQuantity': actualQuantity,
      'purchaseCost': purchaseCost,
      'purchaseAmount': purchaseAmount,
    };
  }

  static String _string(dynamic value) => value?.toString().trim() ?? '';

  static double _double(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
