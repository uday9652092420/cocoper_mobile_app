/// A Direct Sale returned by the verified GET /direct-sales contract.
class DirectSale {
  final String id;
  final String directSaleNo;
  final String salesOrderNo;
  final String customerId;
  final String branchId;
  final String invoiceDate;
  final String mode;
  final double invoiceTotal;
  final String customerName;
  final String branchName;
  final String status;
  final bool? approved;
  final List<DirectSaleLine> lines;
  final List<DirectSaleGunnyBag> gunnyBags;

  const DirectSale({
    this.id = '',
    this.directSaleNo = '',
    this.salesOrderNo = '',
    this.customerId = '',
    this.branchId = '',
    this.invoiceDate = '',
    this.mode = '',
    this.invoiceTotal = 0,
    this.customerName = '',
    this.branchName = '',
    this.status = '',
    this.approved,
    this.lines = const [],
    this.gunnyBags = const [],
  });

  factory DirectSale.fromJson(Map<String, dynamic> json) {
    final customer = _map(json['customer']);
    final branch = _map(json['branch']);
    final rawLines = json['lines'];
    final rawBags = json['gunnyBags'] ?? json['gunny_bags'];

    return DirectSale(
      id: _string(json['id'] ?? json['_id']),
      directSaleNo: _string(json['directSaleNo']),
      salesOrderNo: _string(json['salesOrderNo']),
      customerId: _string(json['customerId'] ?? customer['id']),
      branchId: _string(json['branchId'] ?? branch['id']),
      invoiceDate: _string(json['invoiceDate'] ?? json['invoice_date']),
      mode: _string(json['mode']),
      invoiceTotal: _double(json['invoiceTotal'] ?? json['invoice_total']),
      customerName: _string(
        json['customerName'] ?? json['customer_name'] ?? customer['name'],
      ),
      branchName: _string(
        json['branchName'] ?? json['branch_name'] ?? branch['name'],
      ),
      status: _string(json['status']),
      approved: _nullableBool(json['approved']),
      lines: rawLines is List
          ? rawLines
              .whereType<Map<dynamic, dynamic>>()
              .map((row) => DirectSaleLine.fromJson(
                    Map<String, dynamic>.from(row),
                  ))
              .toList()
          : const [],
      gunnyBags: rawBags is List
          ? rawBags
              .whereType<Map<dynamic, dynamic>>()
              .map((row) => DirectSaleGunnyBag.fromJson(
                    Map<String, dynamic>.from(row),
                  ))
              .toList()
          : const [],
    );
  }

  static Map<String, dynamic> _map(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  static String _string(dynamic value) => value?.toString().trim() ?? '';

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool? _nullableBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value == null) return null;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return null;
  }
}

class DirectSaleLine {
  final String itemId;
  final String itemName;
  final double quantity;
  final double discount;
  final double piecesPercentage;
  final double pieces;
  final double baseCost;
  final double actualQuantity;
  final double salesPrice;
  final double salesAmount;

  const DirectSaleLine({
    this.itemId = '',
    this.itemName = '',
    this.quantity = 0,
    this.discount = 0,
    this.piecesPercentage = 0,
    this.pieces = 0,
    this.baseCost = 0,
    this.actualQuantity = 0,
    this.salesPrice = 0,
    this.salesAmount = 0,
  });

  factory DirectSaleLine.fromJson(Map<String, dynamic> json) {
    final item = DirectSale._map(json['item']);
    return DirectSaleLine(
      itemId:
          DirectSale._string(json['itemId'] ?? json['item_id'] ?? item['id']),
      itemName: DirectSale._string(
        json['itemName'] ?? json['item_name'] ?? item['name'],
      ),
      quantity: DirectSale._double(json['quantity']),
      discount: DirectSale._double(json['discount']),
      piecesPercentage: DirectSale._double(
        json['piecesPercentage'] ?? json['pieces_percentage'],
      ),
      pieces: DirectSale._double(json['pieces']),
      baseCost: DirectSale._double(json['baseCost'] ?? json['base_cost']),
      actualQuantity: DirectSale._double(
        json['actualQuantity'] ?? json['actual_quantity'],
      ),
      salesPrice: DirectSale._double(
        json['salesPrice'] ?? json['sales_price'],
      ),
      salesAmount: DirectSale._double(
        json['salesAmount'] ?? json['sales_amount'],
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'itemId': itemId,
        'quantity': quantity,
        'discount': discount,
        'piecesPercentage': piecesPercentage,
        'pieces': pieces,
        'baseCost': baseCost,
        'actualQuantity': actualQuantity,
        'salesPrice': salesPrice,
        'salesAmount': salesAmount,
      };
}

class DirectSaleGunnyBag {
  final String bagTypeId;
  final String bharthiTypeId;
  final double bagBharthi;
  final double quantity;
  final double rate;
  final double amount;

  const DirectSaleGunnyBag({
    this.bagTypeId = '',
    this.bharthiTypeId = '',
    this.bagBharthi = 0,
    this.quantity = 0,
    this.rate = 0,
    this.amount = 0,
  });

  factory DirectSaleGunnyBag.fromJson(Map<String, dynamic> json) {
    return DirectSaleGunnyBag(
      bagTypeId: DirectSale._string(json['bagTypeId'] ?? json['bag_type_id']),
      bharthiTypeId: DirectSale._string(
        json['bharthiTypeId'] ?? json['bharthi_type_id'],
      ),
      bagBharthi: DirectSale._double(
        json['bagBharthi'] ?? json['bag_bharthi'],
      ),
      quantity: DirectSale._double(json['quantity']),
      rate: DirectSale._double(json['rate']),
      amount: DirectSale._double(json['amount']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'bagTypeId': bagTypeId,
        'bharthiTypeId': bharthiTypeId,
        'bagBharthi': bagBharthi,
        'quantity': quantity,
        'rate': rate,
        'amount': amount,
      };
}

class DirectSaleBagType {
  final String id;
  final String label;
  final String bharthiTypeId;
  final double bagBharthi;

  const DirectSaleBagType({
    required this.id,
    required this.label,
    this.bharthiTypeId = '',
    this.bagBharthi = 0,
  });

  factory DirectSaleBagType.fromJson(Map<String, dynamic> json) {
    final bharthiType = DirectSale._map(json['bharthiType']);
    final id = DirectSale._string(
      json['id'] ?? json['_id'] ?? json['bagTypeId'] ?? json['bag_type_id'],
    );
    final name = DirectSale._string(
      json['name'] ?? json['bagName'] ?? json['bag_name'] ?? json['label'],
    );
    return DirectSaleBagType(
      id: id,
      label: name.isEmpty ? id : name,
      bharthiTypeId: DirectSale._string(
        json['bharthiTypeId'] ?? json['bharthi_type_id'] ?? bharthiType['id'],
      ),
      bagBharthi: DirectSale._double(
        json['bagBharthi'] ?? json['bag_bharthi'],
      ),
    );
  }
}
