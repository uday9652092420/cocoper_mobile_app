/// A single line of a Sales Order.
///
/// Field names follow the verified backend contract: itemId, quantity,
/// discount, piecesPercentage, pieces, baseCost, actualQuantity, saleCost,
/// saleAmount and amount. Sales Order lines do NOT contain `rate`.
class SalesOrderLine {
  final String itemId;
  final String itemName;
  final double quantity;
  final double discount;
  final double piecesPercentage;
  final double pieces;
  final double baseCost;
  final double actualQuantity;
  final double saleCost;
  final double saleAmount;
  final double amount;

  const SalesOrderLine({
    this.itemId = '',
    this.itemName = '',
    this.quantity = 0,
    this.discount = 0,
    this.piecesPercentage = 0,
    this.pieces = 0,
    this.baseCost = 0,
    this.actualQuantity = 0,
    this.saleCost = 0,
    this.saleAmount = 0,
    this.amount = 0,
  });

  factory SalesOrderLine.fromJson(Map<String, dynamic> json) {
    return SalesOrderLine(
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
      saleCost: _double(json['saleCost'] ?? json['sale_cost']),
      saleAmount: _double(json['saleAmount'] ?? json['sale_amount']),
      amount: _double(json['amount']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'itemId': itemId,
      'quantity': quantity,
      'discount': discount,
      'piecesPercentage': piecesPercentage,
      'pieces': pieces,
      'baseCost': baseCost,
      'actualQuantity': actualQuantity,
      'saleCost': saleCost,
      'saleAmount': saleAmount,
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
