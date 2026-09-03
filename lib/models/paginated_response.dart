/// Generic wrapper for DRF paginated responses.
///
/// Shape:
/// ```json
/// {
///   "count": 42,
///   "next": "http://.../api/jobs/?page=2",
///   "previous": null,
///   "results": [...]
/// }
/// ```
class PaginatedResponse<T> {
  final int count;
  final String? next;
  final String? previous;
  final List<T> results;

  const PaginatedResponse({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  bool get hasNext => next != null && next!.isNotEmpty;
  bool get hasPrevious => previous != null && previous!.isNotEmpty;

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final rawResults = json['results'] as List<dynamic>? ?? [];
    return PaginatedResponse<T>(
      count: json['count'] as int? ?? 0,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
      results: rawResults
          .map((item) => fromJsonT(item as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  String toString() => 'PaginatedResponse(count=$count, results=${results.length})';
}
