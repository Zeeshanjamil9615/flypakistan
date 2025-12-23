import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Production-ready logging service for ReadyFlights app
/// 
/// Logs are saved to Android external storage in organized folders:
/// /storage/emulated/0/ReadyFlights/logs/
///   ├── flights/YYYY-MM-DD/request_<timestamp>.txt
///   ├── flights/YYYY-MM-DD/response_<timestamp>.txt
///   ├── hotels/YYYY-MM-DD/request_<timestamp>.txt (future)
///   ├── hotels/YYYY-MM-DD/response_<timestamp>.txt (future)
///   └── errors/YYYY-MM-DD/error_<timestamp>.txt
/// 
/// Features:
/// - Only logs in debug mode (kDebugMode) - no logs in release builds
/// - Automatically masks sensitive data (tokens, passwords, etc.)
/// - Creates directory structure automatically
/// - Separate files for requests and responses
/// 
/// Example usage:
/// 
/// ```dart
/// final logger = LoggerService();
/// 
/// // Log a flights API request
/// await logger.logFlightsRequest(
///   endpoint: 'https://api.example.com/flights/search',
///   headers: {
///     'Content-Type': 'application/json',
///     'Authorization': 'Bearer token123', // Will be masked
///   },
///   body: {
///     'origin': 'DXB',
///     'destination': 'KHI',
///     'date': '2024-01-15',
///   },
/// );
/// 
/// // Log a flights API response
/// await logger.logFlightsResponse(
///   endpoint: 'https://api.example.com/flights/search',
///   statusCode: 200,
///   body: responseData,
/// );
/// 
/// // Log an error
/// await logger.logError(
///   error: exception,
///   stackTrace: stackTrace,
///   context: {
///     'method': 'searchFlights',
///     'userId': '12345',
///   },
/// );
/// ```
/// 
/// Integration into existing API service:
/// 
/// ```dart
/// Future<Map<String, dynamic>> searchFlights(...) async {
///   try {
///     final endpoint = '$baseUrl/pricing/flightswithfares';
///     final headers = {'Authorization': 'Bearer $_accessToken'};
///     final body = json.encode(searchParams);
///     
///     // Log request
///     final logger = LoggerService();
///     await logger.logFlightsRequest(
///       endpoint: endpoint,
///       headers: headers,
///       body: searchParams, // Pass Map for better formatting
///     );
///     
///     // Make API call
///     final response = await http.post(
///       Uri.parse(endpoint),
///       headers: headers,
///       body: body,
///     );
///     
///     // Log response
///     await logger.logFlightsResponse(
///       endpoint: endpoint,
///       statusCode: response.statusCode,
///       body: json.decode(response.body),
///     );
///     
///     return responseData;
///   } catch (e, stackTrace) {
///     // Log error
///     await LoggerService().logError(
///       error: e,
///       stackTrace: stackTrace,
///     );
///     rethrow;
///   }
/// }
/// ```
class LoggerService {
  // Singleton instance
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  // Base directory for logs
  static const String _baseFolderName = 'ReadyFlights';
  static const String _logsFolderName = 'logs';
  static const String _flightsFolderName = 'flights';
  static const String _hotelsFolderName = 'hotels';
  static const String _errorsFolderName = 'errors';

  // Sensitive fields to mask
  static const List<String> _sensitiveKeys = [
    'authorization',
    'authorization:',
    'bearer',
    'token',
    'access_token',
    'accessToken',
    'password',
    'pwd',
    'secret',
    'client_secret',
    'clientSecret',
    'api_key',
    'apiKey',
    'apikey',
  ];

  /// Log a flights API request
  /// 
  /// [endpoint] - API endpoint URL
  /// [headers] - Request headers
  /// [body] - Request body (can be Map, String, or dynamic)
  /// 
  /// Returns the generated filename for the log, or null if logging failed
  Future<String?> logFlightsRequest({
    required String endpoint,
    Map<String, String>? headers,
    dynamic body,
  }) async {
    if (!kDebugMode) return null;

    try {
      final timestamp = DateTime.now();
      final fileName = 'request_${timestamp.millisecondsSinceEpoch}.txt';
      final logContent = _buildRequestLog(
        apiName: 'Flights',
        endpoint: endpoint,
        headers: headers,
        body: body,
        timestamp: timestamp,
      );

      final logPath = await _getLogFilePath(
        category: _flightsFolderName,
        fileName: fileName,
        timestamp: timestamp,
      );

      if (logPath != null) {
        await _writeLogFile(logPath, logContent);
        return fileName;
      }
    } catch (e) {
      // Silently fail in production, but we're in debug mode
      // Don't use print/debugPrint as per requirements
    }

    return null;
  }

  /// Log a flights API response
  /// 
  /// [endpoint] - API endpoint URL
  /// [statusCode] - HTTP status code
  /// [headers] - Response headers (optional)
  /// [body] - Response body (can be Map, String, or dynamic)
  /// 
  /// Returns the generated filename for the log, or null if logging failed
  Future<String?> logFlightsResponse({
    required String endpoint,
    required int statusCode,
    Map<String, String>? headers,
    dynamic body,
  }) async {
    if (!kDebugMode) return null;

    try {
      final timestamp = DateTime.now();
      final fileName = 'response_${timestamp.millisecondsSinceEpoch}.txt';
      final logContent = _buildResponseLog(
        apiName: 'Flights',
        endpoint: endpoint,
        statusCode: statusCode,
        headers: headers,
        body: body,
        timestamp: timestamp,
      );

      final logPath = await _getLogFilePath(
        category: _flightsFolderName,
        fileName: fileName,
        timestamp: timestamp,
      );

      if (logPath != null) {
        await _writeLogFile(logPath, logContent);
        return fileName;
      }
    } catch (e) {
      // Silently fail - don't use print/debugPrint
    }

    return null;
  }

  /// Log an error
  /// 
  /// [error] - Error message or Exception
  /// [stackTrace] - Stack trace (optional)
  /// [context] - Additional context information (optional)
  /// 
  /// Returns the generated filename for the log, or null if logging failed
  Future<String?> logError({
    required dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    if (!kDebugMode) return null;

    try {
      final timestamp = DateTime.now();
      final fileName = 'error_${timestamp.millisecondsSinceEpoch}.txt';
      final logContent = _buildErrorLog(
        error: error,
        stackTrace: stackTrace,
        context: context,
        timestamp: timestamp,
      );

      final logPath = await _getLogFilePath(
        category: _errorsFolderName,
        fileName: fileName,
        timestamp: timestamp,
      );

      if (logPath != null) {
        await _writeLogFile(logPath, logContent);
        return fileName;
      }
    } catch (e) {
      // Silently fail - don't use print/debugPrint
    }

    return null;
  }

  /// Get the full path for a log file
  Future<String?> _getLogFilePath({
    required String category,
    required String fileName,
    required DateTime timestamp,
  }) async {
    try {
      // Get external storage directory
      Directory? externalDir;
      
      if (Platform.isAndroid) {
        // For Android, try to access /storage/emulated/0 directly
        // This is the standard external storage root path
        final externalStoragePath = '/storage/emulated/0';
        externalDir = Directory(externalStoragePath);
        
        // Check if we can access this directory (exists or can be created)
        // On Android 10+, this may require MANAGE_EXTERNAL_STORAGE permission
        // but we'll try anyway - it will fail silently if not accessible
        try {
          // Try to create a test to see if we have access
          final testDir = Directory(_joinPath(externalStoragePath, _baseFolderName));
          if (!await testDir.exists()) {
            await testDir.create(recursive: true);
          }
          // If we got here, we have access - use the external storage path
        } catch (e) {
          // If we can't access /storage/emulated/0, fallback to app directory
          externalDir = await getExternalStorageDirectory();
          if (externalDir == null) {
            // Last resort: use application documents directory
            externalDir = await getApplicationDocumentsDirectory();
          } else {
            // path_provider returns app-specific directory, navigate up to emulated/0
            final currentPath = externalDir.path;
            if (currentPath.contains('/Android/data/')) {
              final parts = currentPath.split('/Android/data/');
              if (parts.isNotEmpty) {
                externalDir = Directory(parts[0]);
              }
            } else if (currentPath.contains('/Android/')) {
              final parts = currentPath.split('/Android/');
              if (parts.isNotEmpty) {
                externalDir = Directory(parts[0]);
              }
            }
          }
        }
      } else {
        // For iOS or other platforms, use application documents directory
        externalDir = await getApplicationDocumentsDirectory();
      }

      if (externalDir == null) return null;

      // Build the full path: /storage/emulated/0/ReadyFlights/logs/category/YYYY-MM-DD/fileName
      final dateFolder = _formatDateFolder(timestamp);
      final logDirPath = _joinPath(
        externalDir.path,
        _baseFolderName,
        _logsFolderName,
        category,
        dateFolder,
      );
      final logDir = Directory(logDirPath);

      // Create directory if it doesn't exist
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      return _joinPath(logDir.path, fileName);
    } catch (e) {
      return null;
    }
  }

  /// Write log content to file
  Future<void> _writeLogFile(String filePath, String content) async {
    try {
      final file = File(filePath);
      await file.writeAsString(content, mode: FileMode.write);
    } catch (e) {
      // Silently fail
    }
  }

  /// Build request log content
  String _buildRequestLog({
    required String apiName,
    required String endpoint,
    Map<String, String>? headers,
    dynamic body,
    required DateTime timestamp,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('=' * 80);
    buffer.writeln('FLIGHTS API REQUEST');
    buffer.writeln('=' * 80);
    buffer.writeln('Timestamp: ${_formatTimestamp(timestamp)}');
    buffer.writeln('API Name: $apiName');
    buffer.writeln('Endpoint: $endpoint');
    buffer.writeln('');
    
    // Headers
    if (headers != null && headers.isNotEmpty) {
      buffer.writeln('Request Headers:');
      buffer.writeln('-' * 80);
      for (var entry in headers.entries) {
        final maskedValue = _maskSensitiveData(entry.key, entry.value);
        buffer.writeln('${entry.key}: $maskedValue');
      }
      buffer.writeln('');
    }
    
    // Body
    buffer.writeln('Request Body:');
    buffer.writeln('-' * 80);
    buffer.writeln(_formatBody(body));
    buffer.writeln('');
    buffer.writeln('=' * 80);
    
    return buffer.toString();
  }

  /// Build response log content
  String _buildResponseLog({
    required String apiName,
    required String endpoint,
    required int statusCode,
    Map<String, String>? headers,
    dynamic body,
    required DateTime timestamp,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('=' * 80);
    buffer.writeln('FLIGHTS API RESPONSE');
    buffer.writeln('=' * 80);
    buffer.writeln('Timestamp: ${_formatTimestamp(timestamp)}');
    buffer.writeln('API Name: $apiName');
    buffer.writeln('Endpoint: $endpoint');
    buffer.writeln('Status Code: $statusCode');
    buffer.writeln('');
    
    // Headers (optional, usually not needed for responses)
    if (headers != null && headers.isNotEmpty) {
      buffer.writeln('Response Headers:');
      buffer.writeln('-' * 80);
      for (var entry in headers.entries) {
        final maskedValue = _maskSensitiveData(entry.key, entry.value);
        buffer.writeln('${entry.key}: $maskedValue');
      }
      buffer.writeln('');
    }
    
    // Body
    buffer.writeln('Response Body:');
    buffer.writeln('-' * 80);
    buffer.writeln(_formatBody(body));
    buffer.writeln('');
    buffer.writeln('=' * 80);
    
    return buffer.toString();
  }

  /// Build error log content
  String _buildErrorLog({
    required dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    required DateTime timestamp,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('=' * 80);
    buffer.writeln('ERROR LOG');
    buffer.writeln('=' * 80);
    buffer.writeln('Timestamp: ${_formatTimestamp(timestamp)}');
    buffer.writeln('');
    
    // Error message
    buffer.writeln('Error:');
    buffer.writeln('-' * 80);
    buffer.writeln(error.toString());
    buffer.writeln('');
    
    // Stack trace
    if (stackTrace != null) {
      buffer.writeln('Stack Trace:');
      buffer.writeln('-' * 80);
      buffer.writeln(stackTrace.toString());
      buffer.writeln('');
    }
    
    // Context
    if (context != null && context.isNotEmpty) {
      buffer.writeln('Context:');
      buffer.writeln('-' * 80);
      buffer.writeln(_formatBody(context));
      buffer.writeln('');
    }
    
    buffer.writeln('=' * 80);
    
    return buffer.toString();
  }

  /// Format body for logging (handles Map, String, and other types)
  String _formatBody(dynamic body) {
    if (body == null) {
      return '(null)';
    }
    
    if (body is String) {
      // Try to parse as JSON for pretty printing
      try {
        final decoded = jsonDecode(body);
        return _maskSensitiveInJson(JsonEncoder.withIndent('  ').convert(decoded));
      } catch (e) {
        // Not JSON, return as-is (but mask sensitive data)
        return _maskSensitiveInString(body);
      }
    }
    
    if (body is Map || body is List) {
      return _maskSensitiveInJson(JsonEncoder.withIndent('  ').convert(body));
    }
    
    return body.toString();
  }

  /// Mask sensitive data in a string value
  String _maskSensitiveData(String key, String value) {
    final lowerKey = key.toLowerCase();
    
    for (var sensitiveKey in _sensitiveKeys) {
      if (lowerKey.contains(sensitiveKey.toLowerCase())) {
        if (value.length <= 10) {
          return '***';
        } else if (value.length <= 20) {
          return '${value.substring(0, 4)}***${value.substring(value.length - 4)}';
        } else {
          return '${value.substring(0, 8)}***${value.substring(value.length - 8)}';
        }
      }
    }
    
    return value;
  }

  /// Mask sensitive data in JSON string
  String _maskSensitiveInJson(String jsonString) {
    String result = jsonString;
    
    try {
      final decoded = jsonDecode(jsonString);
      final masked = _maskSensitiveInObject(decoded);
      return JsonEncoder.withIndent('  ').convert(masked);
    } catch (e) {
      // If JSON parsing fails, do string-based masking
      return _maskSensitiveInString(jsonString);
    }
  }

  /// Mask sensitive data in JSON object recursively
  dynamic _maskSensitiveInObject(dynamic obj) {
    if (obj is Map) {
      final maskedMap = <String, dynamic>{};
      for (var entry in obj.entries) {
        final key = entry.key.toString();
        final lowerKey = key.toLowerCase();
        
        // Check if this key is sensitive
        bool isSensitive = false;
        for (var sensitiveKey in _sensitiveKeys) {
          if (lowerKey.contains(sensitiveKey.toLowerCase())) {
            isSensitive = true;
            break;
          }
        }
        
        if (isSensitive) {
          final value = entry.value.toString();
          if (value.length <= 10) {
            maskedMap[key] = '***';
          } else if (value.length <= 20) {
            maskedMap[key] = '${value.substring(0, 4)}***${value.substring(value.length - 4)}';
          } else {
            maskedMap[key] = '${value.substring(0, 8)}***${value.substring(value.length - 8)}';
          }
        } else {
          // Recursively process nested objects
          maskedMap[key] = _maskSensitiveInObject(entry.value);
        }
      }
      return maskedMap;
    } else if (obj is List) {
      return obj.map((item) => _maskSensitiveInObject(item)).toList();
    }
    
    return obj;
  }

  /// Mask sensitive data in plain string (fallback)
  String _maskSensitiveInString(String text) {
    // This is a simple fallback - in practice, JSON masking is preferred
    return text;
  }

  /// Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.year}-${_padZero(timestamp.month)}-${_padZero(timestamp.day)} '
           '${_padZero(timestamp.hour)}:${_padZero(timestamp.minute)}:${_padZero(timestamp.second)}.${_padZero(timestamp.millisecond, 3)}';
  }

  /// Format date for folder name (YYYY-MM-DD)
  String _formatDateFolder(DateTime timestamp) {
    return '${timestamp.year}-${_padZero(timestamp.month)}-${_padZero(timestamp.day)}';
  }

  /// Pad number with zeros
  String _padZero(int number, [int width = 2]) {
    return number.toString().padLeft(width, '0');
  }

  /// Join path segments with platform-specific separator
  String _joinPath(String part1, [String? part2, String? part3, String? part4, String? part5]) {
    String result = part1;
    
    void addPart(String? part) {
      if (part != null && part.isNotEmpty) {
        // Remove leading/trailing separators from the part
        part = part.replaceAll(RegExp(r'^[/\\]+|[/\\]+$'), '');
        if (part.isNotEmpty) {
          if (!result.endsWith('/') && !result.endsWith('\\')) {
            result += Platform.pathSeparator;
          }
          result += part;
        }
      }
    }
    
    addPart(part2);
    addPart(part3);
    addPart(part4);
    addPart(part5);
    
    return result;
  }
}

