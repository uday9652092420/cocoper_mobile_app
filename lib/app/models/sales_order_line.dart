/// A single line of a Sales Order.
///
/// Field names follow the verified backend contract: itemId, quantity,
/// discount, piecesPercentage, pieces, baseCost, actualQuantity, and the
/// legacy backend `saleCost` field (mapped to [salePrice]),
/// saleAmount and amount. Sales Order lines do NOT contain `rate`.
class SalesOrderLine {
  final String id;
  final String itemId;
  final String itemName;
  final double quantity;
  final double discount;
  final double piecesPercentage;
  final double pieces;
  final double baseCost;
  final double actualQuantity;
  final double salePrice;
  final double saleAmount;
  final double amount;
  final bool hasSaleAmount;

  const SalesOrderLine({
    this.id = '',
    this.itemId = '',
    this.itemName = '',
    this.quantity = 0,
    this.discount = 0,
    this.piecesPercentage = 0,
    this.pieces = 0,
    this.baseCost = 0,
    this.actualQuantity = 0,
    double? salePrice,
    double? saleCost,
    this.saleAmount = 0,
    this.amount = 0,
    bool? hasSaleAmount,
  })  : salePrice = salePrice ?? saleCost ?? 0,
        hasSaleAmount = hasSaleAmount ?? saleAmount != 0;

  double get saleCost => salePrice;

  factory SalesOrderLine.fromJson(Map<String, dynamic> json) {
    final rawItem = json['item'];
    final item = rawItem is Map
        ? Map<String, dynamic>.from(rawItem)
        : const <String, dynamic>{};
    final rawSaleAmount = json['saleAmount'] ?? json['sale_amount'];
    return SalesOrderLine(
      id: _string(json['id'] ?? json['_id']),
      itemId: _string(
        json['itemId'] ?? json['item_id'] ?? item['id'] ?? item['_id'],
      ),
      itemName: _string(
        json['itemName'] ??
            json['item_name'] ??
            json['name'] ??
            item['name'] ??
            item['itemName'] ??
            item['item_name'],
      ),
      quantity: _double(json['quantity']),
      discount: _double(json['discount']),
      piecesPercentage: _double(
        json['piecesPercentage'] ?? json['pieces_percentage'],
      ),
      pieces: _double(json['pieces']),
      baseCost: _double(json['baseCost'] ?? json['base_cost']),
      actualQuantity: _double(
        json['actualQuantity'] ?? json['actual_quantity'],
      ),
      salePrice: _double(json['saleCost'] ?? json['sale_cost']),
      saleAmount: _double(rawSaleAmount ?? json['amount']),
      amount: _double(json['amount']),
      hasSaleAmount: rawSaleAmount != null,
    );
  }

  double get effectiveSaleAmount => hasSaleAmount ? saleAmount : amount;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id.isNotEmpty) 'id': id,
      'itemId': itemId,
      'quantity': quantity,
      'discount': discount,
      'piecesPercentage': piecesPercentage,
      'pieces': pieces,
      'baseCost': baseCost,
      'actualQuantity': actualQuantity,
      'saleCost': salePrice,
      'saleAmount': effectiveSaleAmount,
      'amount': amount,
    };
  }

  static String _string(dynamic value) => value?.toString().trim() ?? '';

  static double _double(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
