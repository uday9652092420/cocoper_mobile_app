/// A single line of a Purchase Order.
///
/// Field names follow the verified backend contract:
/// quantity, discount, piecesPercentage, pieces, baseCost, actualQuantity,
/// purchaseCost, purchaseAmount, amount and rate.
class PurchaseOrderLine {
  final String? id;
  final String itemId;
  final String itemName;
  final double quantity;
  final double discount;
  final double piecesPercentage;
  final double pieces;
  final double baseCost;
  final double actualQuantity;
  final double purchaseCost;
  final double purchaseAmount;
  final double amount;
  final double? rate;

  const PurchaseOrderLine({
    this.id,
    required this.itemId,
    this.itemName = '',
    this.quantity = 0,
    this.discount = 0,
    this.piecesPercentage = 0,
    this.pieces = 0,
    this.baseCost = 0,
    this.actualQuantity = 0,
    this.purchaseCost = 0,
    this.purchaseAmount = 0,
    this.amount = 0,
    this.rate,
  });

  factory PurchaseOrderLine.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderLine(
      id: _string(json['id']),
      itemId: _string(json['itemId'] ?? json['item_id']),
      itemName: _string(json['itemName'] ?? json['item_name'] ?? json['name']),
      quantity: _double(json['quantity']),
      discount: _double(json['discount']),
      piecesPercentage: _double(
        json['piecesPercentage'] ?? json['pieces_percentage'],
      ),
      pieces: _double(json['pieces']),
      baseCost: _double(json['baseCost']),
      actualQuantity: _double(
        json['actualQuantity'] ?? json['actual_quantity'],
      ),
      purchaseCost: _double(json['purchaseCost'] ?? json['purchase_cost']),
      purchaseAmount: _double(
        json['purchaseAmount'] ?? json['purchase_amount'],
      ),
      amount: _double(json['amount']),
      rate: json['rate'] is num ? (json['rate'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id != null && id!.isNotEmpty) 'id': id,
      'itemId': itemId,
      'quantity': quantity,
      'discount': discount,
      'piecesPercentage': piecesPercentage,
      'pieces': pieces,
      'baseCost': baseCost,
      'actualQuantity': actualQuantity,
      'purchaseCost': purchaseCost,
      'purchaseAmount': purchaseAmount,
      'amount': amount,
      'rate': rate,
    };
  }

  static String _string(dynamic value) => value?.toString().trim() ?? '';

  static double _double(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
