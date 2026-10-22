import 'api_contract.dart';

class ApplicationSummary {
  final int total;
  final Map<String, int> byStatus, byProcessingStatus;
  ApplicationSummary.fromJson(Map<String, dynamic> json)
    : total = ApiValue.integer(json['total']),
      byStatus = _counts(json['by_status']),
      byProcessingStatus = _counts(json['by_processing_status']);
  static Map<String, int> _counts(Object? value) => Map.unmodifiable(
    (value as Map).map(
      (key, count) => MapEntry(key.toString(), ApiValue.integer(count)),
    ),
  );
}
