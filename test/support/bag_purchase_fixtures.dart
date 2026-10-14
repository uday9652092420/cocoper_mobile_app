import 'package:cocoper_mobile/app/models/bag_purchase.dart';

/// Saved bag purchases captured from the UAT backend list endpoint
/// (`GET /api/bag-purchases?organizationId=711212e2-0af4-48a0-9dcc-c27908e0bc57`).
///
/// The payload is stored verbatim, including the trailing space in the BP-003
/// supplier name, so the parser keeps handling the real response.
const bagPurchaseRecordsPayload = <Map<String, dynamic>>[
  <String, dynamic>{
    'id': '9a0ec645-d776-409f-9305-1627ab017b21',
    'purchase_no': 'BP-003',
    'purchase_date': '2026-10-13T22:00:00.000Z',
    'supplier_id': 'SUP-1788498304343',
    'supplier_code': 'RS-02',
    'supplier_name': 'Kerala Cocos Suppliers Pvt Ltd ',
    'remarks': 'Good Services',
    'total_amount': 750,
    'created_at': '2026-10-13T22:00:00.000Z',
    'organization_id': '711212e2-0af4-48a0-9dcc-c27908e0bc57',
    'branch_id': '4039b460-48dd-47d4-bcd1-c2b1b27473b1',
    'lines': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': '94bff089-a3c5-4ad3-bf51-82afef3ef3fc',
        'purchase_id': '9a0ec645-d776-409f-9305-1627ab017b21',
        'gunny_bag_id': 'GB-1790760444200',
        'gunny_bag_code': 'WG-04',
        'gunny_bag_name': 'Polyster Bag',
        'bharthi': null,
        'quantity': 50,
        'rate': 15,
        'amount': 750,
        'bag_code': 'WG-04',
        'bag_name': 'Polyster Bag',
      },
    ],
  },
  <String, dynamic>{
    'id': 'b8c7a370-5867-495f-a1d2-529eda5050a0',
    'purchase_no': 'BP-002',
    'purchase_date': '2026-09-03T22:00:00.000Z',
    'supplier_id': 'SUP-1788498304343',
    'supplier_code': 'RS-02',
    'supplier_name': 'Kerala Cocos Suppliers Pvt Ltd ',
    'remarks': 'Good Services',
    'total_amount': 120000,
    'created_at': '2026-09-03T22:00:00.000Z',
    'organization_id': '711212e2-0af4-48a0-9dcc-c27908e0bc57',
    'branch_id': '85208b82-f731-476b-be46-6de9fd47f757',
    'lines': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': '6f910e90-982b-47b7-a046-849b79ce2b2e',
        'purchase_id': 'b8c7a370-5867-495f-a1d2-529eda5050a0',
        'gunny_bag_id': 'GB-1788248172607',
        'gunny_bag_code': 'WG-03',
        'gunny_bag_name': 'Jute Bag',
        'bharthi': null,
        'quantity': 6000,
        'rate': 20,
        'amount': 120000,
        'bag_code': 'WG-03',
        'bag_name': 'Jute Bag',
      },
    ],
  },
  <String, dynamic>{
    'id': '39321dc9-dc82-4928-b53b-910d01fe8f9b',
    'purchase_no': 'BP-001',
    'purchase_date': '2026-08-31T22:00:00.000Z',
    'supplier_id': 'SUP-1788256048434',
    'supplier_code': 'RS-01',
    'supplier_name': 'Godavari Cocos Suppliers Pvt Ltd',
    'remarks': 'Good Services',
    'total_amount': 72000,
    'created_at': '2026-08-31T22:00:00.000Z',
    'organization_id': '711212e2-0af4-48a0-9dcc-c27908e0bc57',
    'branch_id': '85208b82-f731-476b-be46-6de9fd47f757',
    'lines': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'e407ffc7-78ec-4201-bd32-247945c60692',
        'purchase_id': '39321dc9-dc82-4928-b53b-910d01fe8f9b',
        'gunny_bag_id': 'GB-1788248172607',
        'gunny_bag_code': 'WG-03',
        'gunny_bag_name': 'Jute Bag',
        'bharthi': null,
        'quantity': 6000,
        'rate': 12,
        'amount': 72000,
        'bag_code': 'WG-03',
        'bag_name': 'Jute Bag',
      },
    ],
  },
];

/// The verified envelope returned by the backend list endpoint.
const bagPurchaseListResponse = <String, dynamic>{
  'success': true,
  'data': bagPurchaseRecordsPayload,
};

/// The captured records decoded through the production parser.
List<BagPurchase> decodedBagPurchases() => bagPurchaseRecordsPayload
    .map((record) => BagPurchase.fromJson(Map<String, dynamic>.from(record)))
    .toList(growable: false);
