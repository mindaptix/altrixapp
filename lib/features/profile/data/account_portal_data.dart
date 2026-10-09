import '../../../core/network/api_response.dart';

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};

/// Optional account details from the existing patient profile response.
/// Missing financial fields stay unknown rather than becoming a zero balance.
class AccountPortalData {
  const AccountPortalData({
    this.primary,
    this.secondary,
    this.documents = const [],
    this.billing = const BillingSummary(),
  });

  final InsurancePlan? primary;
  final InsurancePlan? secondary;
  final List<AccountDocument> documents;
  final BillingSummary billing;

  factory AccountPortalData.fromProfile(Map<String, dynamic> response) {
    final payload = unwrapApiPayload(response);
    final patient = _map(
      payload['client'] ?? payload['patient'] ?? payload['user'],
    );
    final insurance = _map(payload['insurance'] ?? patient['insurance']);
    final primary = _map(insurance['primary']);
    final secondary = _map(insurance['secondary']);
    final flatPrimary = InsurancePlan.fromJson(insurance, prefix: 'primary');
    final flatSecondary = InsurancePlan.fromJson(
      insurance,
      prefix: 'secondary',
    );
    final documents = payload['documents'] ?? patient['documents'];
    return AccountPortalData(
      primary: primary.isNotEmpty
          ? InsurancePlan.fromJson(primary)
          : (flatPrimary.carrier.isNotEmpty ? flatPrimary : null),
      secondary: secondary.isNotEmpty
          ? InsurancePlan.fromJson(secondary)
          : (flatSecondary.carrier.isNotEmpty &&
                    flatSecondary.carrier.toLowerCase() != 'none'
                ? flatSecondary
                : null),
      documents: asJsonMapList(documents)
          .map(AccountDocument.fromJson)
          .toList(),
      billing: BillingSummary.fromJson(
        _map(payload['billing'] ?? patient['billing']),
      ),
    );
  }
}

class InsurancePlan {
  const InsurancePlan({
    required this.carrier,
    this.memberId = '',
    this.groupNumber = '',
    this.copay = '',
    this.deductible = '',
    this.status = '',
    this.lastVerified = '',
  });
  final String carrier,
      memberId,
      groupNumber,
      copay,
      deductible,
      status,
      lastVerified;

  factory InsurancePlan.fromJson(
    Map<String, dynamic> json, {
    String prefix = '',
  }) {
    String field(String name, List<String> aliases) {
      if (prefix.isEmpty) return readString(json, [name, ...aliases]);
      return readString(json, [
        '$prefix${name[0].toUpperCase()}${name.substring(1)}',
      ]);
    }

    return InsurancePlan(
      carrier: field('carrier', ['payer', 'name']),
      memberId: field('memberId', ['member_id']),
      groupNumber: prefix.isEmpty
          ? readString(json, ['groupNumber', 'group', 'group_number'])
          : readString(json, ['${prefix}Group', '${prefix}GroupNumber']),
      copay: field('copay', []),
      deductible: field('deductible', []),
      status: field('status', []),
      lastVerified: readString(json, ['lastVerified', 'last_verified']),
    );
  }
}

class AccountDocument {
  const AccountDocument({
    required this.type,
    required this.name,
    this.status = '',
    this.url = '',
  });
  final String type, name, status, url;
  factory AccountDocument.fromJson(Map<String, dynamic> json) =>
      AccountDocument(
        type: readString(json, ['type', 'documentType']),
        name: readString(json, [
          'name',
          'title',
          'fileName',
        ], fallback: 'Document'),
        status: readString(json, ['status']),
        url: readString(json, ['url', 'fileUrl']),
      );
}

class BillingSummary {
  const BillingSummary({
    this.balanceDue,
    this.nextCopay,
    this.paymentMethod = '',
    this.history = const [],
  });
  final double? balanceDue, nextCopay;
  final String paymentMethod;
  final List<BillingEntry> history;
  factory BillingSummary.fromJson(Map<String, dynamic> json) => BillingSummary(
    balanceDue: readDouble(json, ['balanceDue', 'balance_due']),
    nextCopay: readDouble(json, ['nextCopay', 'next_copay']),
    paymentMethod: readString(json, ['paymentMethod', 'payment_method']),
    history: asJsonMapList(json['history']).map(BillingEntry.fromJson).toList(),
  );
}

class BillingEntry {
  const BillingEntry({
    required this.description,
    this.date = '',
    this.payer = '',
    this.status = '',
    this.amount,
  });
  final String description, date, payer, status;
  final double? amount;
  factory BillingEntry.fromJson(Map<String, dynamic> json) => BillingEntry(
    description: readString(json, ['description', 'desc'], fallback: 'Service'),
    date: readString(json, ['date', 'serviceDate']),
    payer: readString(json, ['payer']),
    status: readString(json, ['status']),
    amount: readDouble(json, ['amount']),
  );
}
