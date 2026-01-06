// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xml2json/xml2json.dart';

/// Content type for API requests
enum ContentType {
  JSON,
  XML,
}

/// HTTP methods supported by ApiClient
enum HttpMethod {
  GET,
  POST,
  PUT,
  PATCH,
  DELETE,
}

/// Response model for API calls
class ResponseModel {
  final bool isSuccess;
  final String message;
  final int statusCode;
  final String responseBody;
  final Map<String, dynamic>? responseJson;

  ResponseModel({
    required this.isSuccess,
    required this.message,
    required this.statusCode,
    required this.responseBody,
    this.responseJson,
  });

  @override
  String toString() => 'ResponseModel(isSuccess: $isSuccess, message: $message, statusCode: $statusCode)';
}

/// Professional API client with support for JSON and XML requests/responses
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // SSL certificate paths (loaded from assets)
  String? _certPath;
  String? _keyPath;
  bool _sslInitialized = false;

  /// Initialize SSL certificates from assets
  Future<void> initSSLCertificates() async {
    if (_sslInitialized) return;

    try {
      final ByteData certData = await rootBundle.load('assets/certs/cert.pem');
      final ByteData keyData = await rootBundle.load('assets/certs/key.pem');

      final Directory tempDir = await getTemporaryDirectory();
      final File certFile = File('${tempDir.path}/api_client_cert.pem');
      final File keyFile = File('${tempDir.path}/api_client_key.pem');

      await certFile.writeAsBytes(certData.buffer.asUint8List());
      await keyFile.writeAsBytes(keyData.buffer.asUint8List());

      _certPath = certFile.path;
      _keyPath = keyFile.path;
      _sslInitialized = true;
    } catch (e) {
      _printLog('❌ Failed to initialize SSL certificates: $e');
    }
  }

  /// Main request method
  /// 
  /// [serviceName] - Required label to identify the API source (e.g., 'AIRBLUE', 'FLYDUBAI', 'HOTELS')
  /// [printRequestBody] - Optional flag to print the request body (default: false)
  /// [printResponseBody] - Optional flag to print the response body (default: false)
  /// [sendCall] - Optional flag to actually send the API call (default: true)
  ///               When false, only prints the request but does not send it
  Future<ResponseModel> request({
    required String url,
    required HttpMethod method,
    required String serviceName,
    dynamic body,
    Map<String, String>? headers,
    ContentType contentType = ContentType.JSON,
    bool useSSL = false,
    bool printRequestBody = false,
    bool printResponseBody = false,
    bool convertXmlToJson = false,
    bool sendCall = true,
  }) async {
    final startTime = DateTime.now();
    
    // Always print request header
    _printRequestHeader(serviceName, url, method, contentType);
    
    // Optionally print request body
    if (printRequestBody && body != null) {
      _printBody('📦 REQUEST BODY ${serviceName.toUpperCase()}', body.toString(), contentType);
    }
    
    // If sendCall is false, skip the actual API call and return a placeholder response
    if (!sendCall) {
      _printLog('');
      _printLog('⚠️ [$serviceName] API call skipped (sendCall = false)');
      _printDivider();
      return ResponseModel(
        isSuccess: false,
        message: 'API call skipped (sendCall = false)',
        statusCode: 0,
        responseBody: '',
      );
    }
    
    try {
      // Build headers
      final Map<String, String> requestHeaders = {
        'Accept': contentType == ContentType.XML 
            ? 'application/xml' 
            : 'application/json',
        'Content-Type': contentType == ContentType.XML 
            ? 'text/xml; charset=utf-8' 
            : 'application/json',
      };
      if (headers != null) {
        requestHeaders.addAll(headers);
      }

      // Create Dio instance
      final dio = Dio(
        BaseOptions(
          headers: requestHeaders,
          responseType: ResponseType.plain,
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      // Configure SSL if needed
      if (useSSL) {
        await _configureSSL(dio);
      }

      // Make request
      Response response;
      switch (method) {
        case HttpMethod.GET:
          response = await dio.get(url);
          break;
        case HttpMethod.POST:
          response = await dio.post(url, data: body);
          break;
        case HttpMethod.PUT:
          response = await dio.put(url, data: body);
          break;
        case HttpMethod.PATCH:
          response = await dio.patch(url, data: body);
          break;
        case HttpMethod.DELETE:
          response = await dio.delete(url, data: body);
          break;
      }

      final duration = DateTime.now().difference(startTime);
      
      // Always print response header
      _printResponseHeader(serviceName, url, response.statusCode ?? 0, duration);
      
      // Optionally print response body
      if (printResponseBody) {
        _printBody('📄 RESPONSE BODY  ${serviceName.toUpperCase()}', response.data.toString(), contentType);
      }
      
      _printDivider();

      // Handle response
      return _handleResponse(
        response.statusCode ?? 0,
        response.data.toString(),
        contentType,
        convertXmlToJson,
      );
    } on DioException catch (e) {
      final duration = DateTime.now().difference(startTime);
      _printResponseHeader(serviceName, url, e.response?.statusCode ?? 0, duration, isError: true);
      if (printResponseBody && e.response?.data != null) {
        _printBody('❌ ERROR BODY', e.response!.data.toString(), contentType);
      }
      _printDivider();
      return _handleDioError(e, printResponseBody);
    } on SocketException {
      _printLog('');
      _printLog('❌ [$serviceName] No Internet Connection');
      _printDivider();
      return ResponseModel(
        isSuccess: false,
        message: 'No Internet Connection',
        statusCode: 503,
        responseBody: '',
      );
    } catch (e) {
      _printLog('');
      _printLog('❌ [$serviceName] Error: $e');
      _printDivider();
      return ResponseModel(
        isSuccess: false,
        message: 'Something went wrong: $e',
        statusCode: 499,
        responseBody: '',
      );
    }
  }

  /// Configure SSL for Dio client
  Future<void> _configureSSL(Dio dio) async {
    await initSSLCertificates();

    if (_certPath == null || _keyPath == null) {
      throw Exception('SSL certificates not initialized');
    }

    final SecurityContext securityContext = SecurityContext();
    securityContext.useCertificateChain(_certPath!);
    securityContext.usePrivateKey(_keyPath!);

    final HttpClient httpClient = HttpClient(context: securityContext);
    httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) {
      return true; // Note: Implement proper validation in production
    };

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => httpClient,
    );
  }

  /// Handle successful response
  ResponseModel _handleResponse(
    int statusCode,
    String responseBody,
    ContentType contentType,
    bool convertXmlToJson,
  ) {
    Map<String, dynamic>? jsonResponse;

    // Convert XML to JSON if needed
    if (contentType == ContentType.XML && convertXmlToJson) {
      jsonResponse = _convertXmlToJson(responseBody);
    } else if (contentType == ContentType.JSON) {
      try {
        jsonResponse = jsonDecode(responseBody) as Map<String, dynamic>;
      } catch (_) {}
    }

    if (statusCode == 200 || statusCode == 201) {
      return ResponseModel(
        isSuccess: true,
        message: 'Success',
        statusCode: statusCode,
        responseBody: responseBody,
        responseJson: jsonResponse,
      );
    } else if (statusCode == 401) {
      return ResponseModel(
        isSuccess: false,
        message: 'Unauthorized',
        statusCode: 401,
        responseBody: responseBody,
        responseJson: jsonResponse,
      );
    } else if (statusCode == 500) {
      return ResponseModel(
        isSuccess: false,
        message: 'Server Error',
        statusCode: 500,
        responseBody: responseBody,
        responseJson: jsonResponse,
      );
    } else {
      return ResponseModel(
        isSuccess: false,
        message: 'Request failed with status: $statusCode',
        statusCode: statusCode,
        responseBody: responseBody,
        responseJson: jsonResponse,
      );
    }
  }

  /// Handle Dio errors
  ResponseModel _handleDioError(DioException e, bool printResponseBody) {
    final statusCode = e.response?.statusCode ?? 499;
    final responseBody = e.response?.data?.toString() ?? '';

    String message;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        message = 'Connection timeout';
        break;
      case DioExceptionType.sendTimeout:
        message = 'Send timeout';
        break;
      case DioExceptionType.receiveTimeout:
        message = 'Receive timeout';
        break;
      case DioExceptionType.badResponse:
        message = 'Bad response: $statusCode';
        break;
      case DioExceptionType.cancel:
        message = 'Request cancelled';
        break;
      case DioExceptionType.connectionError:
        message = 'Connection error';
        break;
      default:
        message = 'Network error: ${e.message}';
    }

    return ResponseModel(
      isSuccess: false,
      message: message,
      statusCode: statusCode,
      responseBody: responseBody,
    );
  }

  /// Convert XML string to JSON map
  Map<String, dynamic> _convertXmlToJson(String xmlString) {
    try {
      final transformer = Xml2Json();
      transformer.parse(xmlString);
      final jsonString = transformer.toGData();
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return {'error': 'Failed to parse XML response', 'raw': xmlString};
    }
  }

  /// Print request header (always printed)
  void _printRequestHeader(String serviceName, String url, HttpMethod method, ContentType contentType) {
    _printLog('');
    _printLog('╔══════════════════════════════════════════════════════════════════╗');
    _printLog('║  📤 REQUEST  ║  🚀 ${serviceName.toUpperCase()}  ║');

    _printLog('  🔹 Method      : ${method.name}');
    _printLog('  🔹 URL         : $url');
    _printLog('  🔹 Content-Type: ${contentType.name}');
    _printLog('╚══════════════════════════════════════════════════════════════════╝');

  }

  /// Print response header (always printed)
  void _printResponseHeader(String serviceName, String url, int statusCode, Duration duration, {bool isError = false}) {
    final statusEmoji = statusCode >= 200 && statusCode < 300 ? '✅' : '❌';
    final statusText = statusCode >= 200 && statusCode < 300 ? 'SUCCESS' : 'FAILED';
    _printLog('');
    _printLog('  ┌──────────────────────────────────────────────────────────────┐');
    _printLog('  │  📥 RESPONSE ║  🚀 ${serviceName.toUpperCase()}  ║           │');

    _printLog('  $statusEmoji Status      : $statusCode ($statusText)');
    _printLog('  ⏱️  Duration    : ${duration.inMilliseconds}ms');
    _printLog('  └──────────────────────────────────────────────────────────────┘');
  }

  /// Print body content (optional)
  void _printBody(String title, String body, ContentType contentType) {
    _printLog('');
    _printLog('  ┌──────────────────────────────────────────────────────────────┐');
    _printLog('  │  $title${' ' * (60 - title.length)}│');
    _printLog('  └──────────────────────────────────────────────────────────────┘');
    if (contentType == ContentType.XML) {
      _printPrettyXml(body);
    } else {
      _printPrettyJson(body);
    }
  }

  /// Print divider
  void _printDivider() {
    _printLog('');
    _printLog('══════════════════════════════════════════════════════════════════');
    _printLog('');
  }

  /// Print log message
  void _printLog(String message) {
    // ignore: avoid_print
    print(message);
  }

  /// Print pretty formatted JSON
  void _printPrettyJson(String body, {int chunkSize = 800}) {
    try {
      final jsonObject = json.decode(body);
      final prettyString = const JsonEncoder.withIndent('  ').convert(jsonObject);
      _printChunked(prettyString, chunkSize);
    } catch (e) {
      _printChunked(body, chunkSize);
    }
  }

  /// Print pretty formatted XML
  void _printPrettyXml(String xml, {int chunkSize = 800}) {
    try {
      // Simple XML formatting
      String formatted = xml;
      formatted = formatted.replaceAll('><', '>\n<');
      _printChunked(formatted, chunkSize);
    } catch (e) {
      _printChunked(xml, chunkSize);
    }
  }

  /// Print large text in chunks
  void _printChunked(String text, int chunkSize) {
    for (var i = 0; i < text.length; i += chunkSize) {
      final endIndex = (i + chunkSize < text.length) ? i + chunkSize : text.length;
      _printLog(text.substring(i, endIndex));
    }
  }
}


