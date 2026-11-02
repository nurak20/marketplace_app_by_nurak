enum ApiFailureType { cancelled, timeout, connection, server, unknown }

bool? _parseBoolean(Object? value) {
  if (value is bool) return value;
  if (value is num) return value == 1;
  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
        return true;
      case 'false':
      case '0':
      case 'no':
        return false;
    }
  }
  return null;
}

int? _parseInteger(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value is String ? value : '');

String? _parseString(Object? value) => value == null ? null : '$value';

class ResponseRes<T, D> {
  ResponseRes({this.success, this.data});

  String? logId;
  bool? success;
  String? code;
  String? message;
  T? data;
  int? pages;
  int? page;
  int? size;
  int? total;
  ApiFailureType? failureType;

  bool get isCancelled => failureType == ApiFailureType.cancelled;

  ResponseRes.fromJson(
    Map<String, dynamic> json, {
    D Function(dynamic value)? deserialize,
    String? languageCode,
  }) {
    try {
      logId = _parseString(json['log_id'] ?? json['logId']);
      code = _parseString(json['code']);
      pages = _parseInteger(json['pages']);
      page = _parseInteger(json['page']);
      size = _parseInteger(json['size']);
      total = _parseInteger(json['total']);

      if (json['pages'] != null) {
        success = true;
        _readData(json['items'], deserialize);
        return;
      }

      success = _parseBoolean(json['success']);
      message = _message(
        json['message'] ?? json['error'],
        languageCode: languageCode,
      );
      failureType = success == false ? ApiFailureType.server : null;
      _readData(json['data'], deserialize);
    } catch (_) {
      success = false;
      failureType = ApiFailureType.unknown;
      message ??= 'Unable to read the server response.';
      // Preserve the API response shape while keeping malformed payloads from
      // crashing the app's request flow.
      data = null;
    }
  }

  ResponseRes.successDataResponse() {
    success = true;
  }

  ResponseRes.noDataResponse({this.failureType, this.message}) {
    success = false;
  }

  void _readData(Object? value, D Function(dynamic value)? deserialize) {
    if (value == null) return;
    if (value is List) {
      final items = value
          .map((item) => deserialize == null ? item : deserialize(item))
          .toList();
      data = items.cast<D>() as T;
      return;
    }
    data = (deserialize == null ? value : deserialize(value)) as T;
  }

  Map<String, dynamic> toJson([Object? Function(T? value)? serialize]) => {
    'log_id': logId,
    'success': success,
    'code': code,
    'message': message,
    'data': serialize == null ? data : serialize(data),
    'pages': pages,
    'page': page,
    'size': size,
    'total': total,
  };

  static String? messageFrom(Object? value, {String? languageCode}) =>
      _message(value, languageCode: languageCode);

  static ApiFailureType failureTypeForSuccess(bool? success) =>
      success == false ? ApiFailureType.server : ApiFailureType.unknown;

  static String? _message(Object? value, {String? languageCode}) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is Map) {
      final translations = Map<String, dynamic>.from(value);
      final preferred = languageCode == null
          ? null
          : translations[languageCode];
      if (preferred is String && preferred.trim().isNotEmpty) {
        return preferred.trim();
      }
      final english = translations['en'];
      if (english is String && english.trim().isNotEmpty) return english.trim();
      for (final candidate in translations.values) {
        if (candidate is String && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
      }
    }
    return null;
  }
}

class Status {
  Status({this.success, this.code, this.message});

  bool? success;
  String? code;
  String? message;

  Status.fromJson(Map<String, dynamic> json)
    : success = _parseBoolean(json['success']),
      code = _parseString(json['code']),
      message = ResponseRes.messageFrom(json['message']);

  Map<String, dynamic> toJson() => {
    'success': success,
    'code': code,
    'message': message,
  };
}

class ApiResponseException implements Exception {
  const ApiResponseException(this.response, {this.cause});

  final ResponseRes<Object?, Object?> response;
  final Object? cause;

  @override
  String toString() =>
      response.message ?? response.code ?? 'The request was unsuccessful.';
}
