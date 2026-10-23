import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class ApiService {
  final String? token;
  final Future<void> Function()? onUnauthorized;
  ApiService({this.token, this.onUnauthorized});

  static const _requestTimeout = Duration(seconds: 20);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse('${AppConstants.baseUrl}$path').replace(
        queryParameters: query?.map((k, v) => MapEntry(k, v.toString())));
  }

  Future<dynamic> _handle(http.Response res) async {
    dynamic body;
    if (res.body.isNotEmpty) {
      try {
        body = jsonDecode(res.body);
      } on FormatException {
        body = null;
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    final errorMessage = (body is Map && body['error'] != null)
        ? body['error'].toString()
        : null;
    if (res.statusCode == 401 &&
        token != null &&
        errorMessage != 'Current password is incorrect') {
      await onUnauthorized?.call();
      throw ApiException(
          'Your session has expired. Please sign in again.', 401);
    }
    throw ApiException(errorMessage ?? 'Request failed', res.statusCode);
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(_requestTimeout);
      return await _handle(response);
    } on TimeoutException {
      throw ApiException(
          'The server took too long to respond. Please try again.');
    } on StateError catch (error) {
      throw ApiException(error.message.toString());
    } on ApiException {
      rethrow;
    } on Exception {
      throw ApiException(
          'Could not connect to the server. Check your connection and try again.');
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    return _send(() => http.get(_uri(path, query), headers: _headers));
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    return _send(() =>
        http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    return _send(() =>
        http.put(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));
  }

  Future<dynamic> delete(String path) async {
    return _send(() => http.delete(_uri(path), headers: _headers));
  }
}
