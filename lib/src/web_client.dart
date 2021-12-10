import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;

import 'exceptions.dart';

class WebClient extends Equatable {
  final String baseUrl;
  final String? accessToken;
  final int timeoutSeconds;

  const WebClient(
      {required this.baseUrl, this.accessToken, this.timeoutSeconds = 15});

  WebClient copyWith(
          {String? baseUrl, String? accessToken, int? timeoutSeconds}) =>
      WebClient(
        baseUrl: baseUrl ?? this.baseUrl,
        accessToken: accessToken ?? this.accessToken,
        timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      );

  @override
  List<Object?> get props => [baseUrl, accessToken];

  @override
  String toString() => 'WebClient {baseUrl:$baseUrl}';

  Future<http.Response?> post(
    String endpoint,
    dynamic payload, {
    String? baseUrl,
    bool jsonEncodedPayload = false,
  }) async {
    if (baseUrl == null) baseUrl = this.baseUrl;
    var headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    };
    if (accessToken != null) {
      headers[HttpHeaders.authorizationHeader] = "Bearer $accessToken";
    }
    final jsonPayload = jsonEncodedPayload ? payload : jsonEncode(payload);
    final response = await http
        .post(
          Uri.parse('$baseUrl$endpoint'),
          body: jsonPayload,
          headers: headers,
        )
        .timeout(Duration(seconds: timeoutSeconds));
    _throwIfNotSuccess(response.statusCode, endpoint: endpoint);
    return response;
  }

  Future<http.StreamedResponse?> uploadFile({
    required String endpoint,
    required String filePath,
    required String fileName,
    String? baseUrl,
  }) async {
    var file = File(filePath);
    final stream = http.ByteStream(file.openRead());
    var length = await file.length();
    if (baseUrl == null) baseUrl = this.baseUrl;

    var uri = Uri.parse('$baseUrl$endpoint');

    var request = new http.MultipartRequest("POST", uri);
    if (accessToken != null) {
      request.headers[HttpHeaders.authorizationHeader] = "Bearer $accessToken";
    }
    var multipartFile =
        new http.MultipartFile('file', stream, length, filename: fileName);
    //contentType: new MediaType('image', 'png'));

    request.files.add(multipartFile);
    var response = await request.send();
    _throwIfNotSuccess(response.statusCode, endpoint: endpoint);
    return response;
  }

  Future<http.Response?> get(
    dynamic endpoint, {
    String? baseUrl,
  }) async {
    var headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    };
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    Uri uri;
    if (endpoint is String) {
      uri = Uri.parse('${baseUrl ?? this.baseUrl}$endpoint');
    } else if (endpoint is Uri) {
      uri = endpoint;
    } else {
      throw ArgumentError('Unsupported endpoint');
    }
    final response = await http
        .get(uri, headers: headers)
        .timeout(Duration(seconds: timeoutSeconds));
    _throwIfNotSuccess(response.statusCode, endpoint: endpoint);
    return response;
  }

  void _throwIfNotSuccess(int statusCode, {required String endpoint}) {
    if (statusCode == 403) {
      throw AccessDeniedException(endpoint: endpoint);
    } else if (statusCode == 401) {
      throw UnauthorizedException(endpoint: endpoint);
    } else if (statusCode == 404) {
      throw NotFoundException(endpoint: endpoint);
    } else if (statusCode == 500) {
      throw ServerException(endpoint: endpoint);
    }
  }
}
