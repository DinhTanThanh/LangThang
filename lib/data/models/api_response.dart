class PaginationMeta {
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  const PaginationMeta({
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    final size = (json['size'] as num?)?.toInt() ?? 12;
    final totalElements = (json['totalElements'] as num?)?.toInt() ?? 0;
    final totalPages = (json['totalPages'] as num?)?.toInt() ??
        (size > 0 ? (totalElements / size).ceil() : 1);

    return PaginationMeta(
      page: (json['page'] as num?)?.toInt() ?? 1,
      size: size,
      totalElements: totalElements,
      totalPages: totalPages > 0 ? totalPages : 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'size': size,
      'totalElements': totalElements,
      'totalPages': totalPages,
    };
  }
}

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final PaginationMeta? meta;
  final String? code;
  final List<String>? errors;

  const ApiResponse({
    required this.success,
    this.message = '',
    this.data,
    this.meta,
    this.code,
    this.errors,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    List<String>? parsedErrors;
    if (json['errors'] != null) {
      if (json['errors'] is List) {
        parsedErrors = (json['errors'] as List)
            .map((e) {
              if (e is Map && e.containsKey('errorMessage')) {
                return e['errorMessage'].toString();
              }
              return e.toString();
            })
            .toList();
      } else if (json['errors'] is Map) {
        parsedErrors = [];
        (json['errors'] as Map).forEach((key, value) {
          if (value is List) {
            parsedErrors!.addAll(value.map((v) => v.toString()));
          } else if (value != null) {
            parsedErrors!.add(value.toString());
          }
        });
      }
    }

    PaginationMeta? meta;
    if (json['meta'] != null && json['meta'] is Map<String, dynamic>) {
      meta = PaginationMeta.fromJson(json['meta'] as Map<String, dynamic>);
    }

    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      message: json['message']?.toString() ?? '',
      data: json['data'] != null && fromJsonT != null ? fromJsonT(json['data']) : json['data'] as T?,
      meta: meta,
      code: json['code']?.toString(),
      errors: parsedErrors,
    );
  }
}
