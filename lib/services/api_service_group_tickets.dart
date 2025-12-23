import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiServiceGroupTickets {
  late final Dio dio;
  
  // Al Saboor API credentials
  static const String _agentCode = '2737';
  static const String _email = 'tech@sastayhotels.pk';
  static const String _password = '1766469414';
  
  // Base URL from Al Saboor API documentation
  static const String _baseUrl = 'https://alsaboorportal.com/admins/api';
  
  // SharedPreferences keys
  static const String _tokenKey = 'alsaboor_auth_token';
  static const String _tokenExpiryKey = 'alsaboor_token_expiry';
  
  ApiServiceGroupTickets() {
    dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
        },
      ),
    );
    
    // Add logging interceptor in debug mode
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
  }
  
  /// Authenticate with Al Saboor API
  /// Returns token and expiry timestamp
  /// According to docs: POST /login with formdata (email, password, Agent_code)
  Future<Map<String, dynamic>> authenticate() async {
    try {
      if (kDebugMode) {
        print('🔐 Authenticating with Al Saboor API...');
      }
      
      // Use FormData.fromMap() as per working Postman example
      // Note: Field name is 'agent_code' (lowercase), not 'Agent_code'
      final formData = FormData.fromMap({
        'email': _email,
        'password': _password,
        'agent_code': _agentCode, // lowercase as per working example
      });
      
      if (kDebugMode) {
        print('📤 Form data: email=${_email}, password=***, agent_code=${_agentCode}');
      }
      
      final response = await dio.post(
        '/login',
        data: formData,
        options: Options(
          method: 'POST',
          headers: {
            'Accept': 'application/json',
          },
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        // Handle response - it might be a Map or String (JSON string)
        Map<String, dynamic> data;
        if (response.data is String) {
          // Parse JSON string
          data = jsonDecode(response.data as String);
        } else if (response.data is Map) {
          data = response.data as Map<String, dynamic>;
        } else {
          return {
            'success': false,
            'message': 'Invalid response format',
          };
        }
        
        // Check for error status first
        if (data['status'] == 'error') {
          return {
            'success': false,
            'message': data['message'] ?? 'Authentication failed',
          };
        }
        
        // Extract token and expiry from response
        // Response structure: {status, message, token, expiry}
        final token = data['token'];
        final expiry = data['expiry'];
        
        if (token != null && token.toString().isNotEmpty) {
          // Calculate expiry timestamp
          int expiryTimestamp;
          if (expiry == null || expiry.toString().isEmpty) {
            // Default to 1 hour if not provided
            expiryTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
          } else if (expiry is int) {
            // If expiry is already a timestamp
            expiryTimestamp = expiry;
          } else if (expiry is String) {
            // Try to parse as timestamp or date string
            try {
              // Try parsing as ISO date string
              expiryTimestamp = DateTime.parse(expiry).millisecondsSinceEpoch ~/ 1000;
            } catch (e) {
              // If parsing fails, try as Unix timestamp string
              try {
                expiryTimestamp = int.parse(expiry);
              } catch (e2) {
                // Default to 1 hour if parsing fails
                expiryTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
              }
            }
          } else {
            // Default to 1 hour if not provided
            expiryTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
          }
          
          // Store token and expiry
          await _storeToken(token.toString(), expiryTimestamp);
          
          if (kDebugMode) {
            print('✅ Al Saboor Authentication successful');
            print('🔐 Token: ${token.toString().substring(0, 20)}...');
            print('🔐 Token expires at: ${DateTime.fromMillisecondsSinceEpoch(expiryTimestamp * 1000)}');
          }
          
          return {
            'success': true,
            'token': token.toString(),
            'expiry': expiryTimestamp,
          };
        }
      }
      
      return {
        'success': false,
        'message': 'Authentication failed: Invalid response',
      };
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ Al Saboor Authentication error: ${e.message}');
        if (e.response != null) {
          print('Response: ${e.response?.data}');
        }
      }
      
      // Try to extract error message from response
      String errorMessage = e.message ?? 'Authentication failed';
      if (e.response?.data != null) {
        try {
          Map<String, dynamic> errorData;
          if (e.response!.data is String) {
            errorData = jsonDecode(e.response!.data as String);
          } else if (e.response!.data is Map) {
            errorData = e.response!.data as Map<String, dynamic>;
          } else {
            errorData = {};
          }
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (parseError) {
          // If parsing fails, use default message
        }
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Al Saboor Authentication error: $e');
      }
      
      return {
        'success': false,
        'message': 'An unexpected error occurred: ${e.toString()}',
      };
    }
  }
  
  /// Store token and expiry in SharedPreferences
  Future<void> _storeToken(String token, int expiryTimestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setInt(_tokenExpiryKey, expiryTimestamp);
  }
  
  /// Get valid token from storage or authenticate if expired
  Future<String?> getValidToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final expiryTimestamp = prefs.getInt(_tokenExpiryKey);
    
    if (token == null || expiryTimestamp == null) {
      // No token stored, need to authenticate
      if (kDebugMode) {
        print('🔐 No token found, authenticating...');
      }
      final authResult = await authenticate();
      return authResult['success'] == true ? authResult['token'] as String? : null;
    }
    
    // Check if token is expired
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (now >= expiryTimestamp) {
      // Token expired, authenticate again
      if (kDebugMode) {
        print('🔐 Token expired, re-authenticating...');
      }
      final authResult = await authenticate();
      return authResult['success'] == true ? authResult['token'] as String? : null;
    }
    
    // Token is valid
    return token;
  }
  
  /// Get all groups from Al Saboor API
  /// According to docs: GET /groups?type=UMRAH GROUP&token=YOUR_TOKEN
  /// type can be "UMRAH GROUP" or "ONE WAY GROUP"
  /// Note: API expects "ONEWAY" instead of "ONE WAY GROUP"
  Future<Map<String, dynamic>> getAllGroups({required String groupType}) async {
    try {
      // Get valid token first
      final token = await getValidToken();
      
      if (token == null) {
        return {
          'success': false,
          'message': 'Failed to get authentication token',
        };
      }
      
      // Map group type for API - remove spaces for ONE WAY GROUP
      String apiGroupType = groupType;
      if (groupType == 'ONE WAY GROUP') {
        apiGroupType = 'ONEWAY';
      }
      
      if (kDebugMode) {
        print('📋 Fetching $groupType (API: $apiGroupType) from Al Saboor API...');
      }
      
      // According to docs, token is passed as query parameter, not header
      // Authorization header format: Token YOUR_API_KEY (but token is in query param)
      final response = await dio.get(
        '/groups',
        queryParameters: {
          'type': apiGroupType, // "UMRAH GROUP" or "ONEWAY"
          'token': token,
        },
        options: Options(
          headers: {
            'Authorization': 'Token $token', // Also include in header as per docs
          },
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        if (kDebugMode) {
          print('✅ Groups fetched successfully');
        }
        
        // Handle response - it might be a Map or String (JSON string)
        dynamic responseData = response.data;
        if (responseData is String) {
          // Parse JSON string
          responseData = jsonDecode(responseData);
        }
        
        return {
          'success': true,
          'data': responseData,
        };
      }
      
      return {
        'success': false,
        'message': 'Failed to fetch groups',
      };
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching groups: ${e.message}');
        if (e.response != null) {
          print('Response: ${e.response?.data}');
        }
      }
      
      // If unauthorized, try to re-authenticate and retry once
      if (e.response?.statusCode == 401) {
        if (kDebugMode) {
          print('🔄 Unauthorized, re-authenticating and retrying...');
        }
        
        // Clear stored token
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tokenKey);
        await prefs.remove(_tokenExpiryKey);
        
        // Retry with new token
        return await getAllGroups(groupType: groupType);
      }
      
      return {
        'success': false,
        'message': e.response?.data?['message'] ?? e.message ?? 'Failed to fetch groups',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching groups: $e');
      }
      
      return {
        'success': false,
        'message': 'An unexpected error occurred: ${e.toString()}',
      };
    }
  }

  /// Get specific group details
  /// GET /group-details?group_id=ID&token=TOKEN
  /// Create a group booking
  /// POST /booking with JSON body containing passenger details
  Future<Map<String, dynamic>> createBooking({
    required String groupId,
    required String roe,
    required int noOfSeat,
    required String pnr1,
    String? pnr2,
    required List<String> paxTitle,
    required List<String> humanType,
    required List<String> surName,
    required List<String> givenName,
    required List<String> passNo,
    required List<String> dob,
    required List<String> doi,
    required List<String> doe,
    required List<String> adultPrice,
    required List<String> childPrice,
    required List<String> infantPrice,
  }) async {
    try {
      final token = await getValidToken();
      if (token == null) {
        return {'success': false, 'message': 'Authentication failed. Please try again.'};
      }

      final requestBody = {
        'roe': roe,
        'no_of_seat': noOfSeat.toString(),
        'group_id': groupId,
        'pnr_1': pnr1,
        if (pnr2 != null) 'pnr_2': pnr2,
        'pax_title': paxTitle,
        'human_type': humanType,
        'sur_name': surName,
        'given_name': givenName,
        'pass_no': passNo,
        'dob': dob,
        'doi': doi,
        'doe': doe,
        'adult_price': adultPrice,
        'child_price': childPrice,
        'infant_price': infantPrice,
      };

      final response = await dio.post(
        '/booking',
        queryParameters: {
          'token': token,
        },
        data: requestBody,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Token $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        Map<String, dynamic> data;
        if (response.data is String) {
          data = jsonDecode(response.data as String);
        } else if (response.data is Map) {
          data = response.data as Map<String, dynamic>;
        } else {
          return {'success': false, 'message': 'Invalid response format'};
        }

        if (data.containsKey('status') && data['status'] == 'error') {
          return {'success': false, 'message': data['message'] ?? 'Booking failed'};
        }

        return {
          'success': true,
          'data': data,
          'transaction_id': data['transaction_id'] ?? data['booking_id'],
          'message': data['message'] ?? 'Booking created successfully',
        };
      }

      return {'success': false, 'message': 'Booking failed: Invalid response'};
    } on DioException catch (e) {
      String errorMessage = 'Failed to create booking';
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final responseData = e.response!.data;
        
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'].toString();
        } else if (statusCode == 401) {
          errorMessage = 'Authentication failed. Please try again.';
        } else if (statusCode == 400) {
          errorMessage = 'Invalid booking data. Please check your input.';
        }
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Connection timeout. Please check your internet connection.';
      }

      if (kDebugMode) {
        print('❌ Al Saboor Create Booking error: $errorMessage');
      }

      return {'success': false, 'message': errorMessage};
    } catch (e) {
      if (kDebugMode) {
        print('❌ Unexpected error creating booking: ${e.toString()}');
      }
      return {'success': false, 'message': 'An unexpected error occurred: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> getGroupDetails({required String groupId}) async {
    try {
      final token = await getValidToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Failed to get authentication token',
        };
      }

      if (kDebugMode) {
        print('📋 Fetching group details for $groupId');
      }

      final response = await dio.get(
        '/group-details',
        queryParameters: {
          'group_id': groupId,
          'token': token,
        },
        options: Options(
          headers: {
            'Authorization': 'Token $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        dynamic responseData = response.data;
        if (responseData is String) {
          responseData = jsonDecode(responseData);
        }
        return {
          'success': true,
          'data': responseData,
        };
      }

      return {
        'success': false,
        'message': 'Failed to fetch group details',
      };
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching group details: ${e.message}');
        if (e.response != null) {
          print('Response: ${e.response?.data}');
        }
      }
      if (e.response?.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tokenKey);
        await prefs.remove(_tokenExpiryKey);
        return await getGroupDetails(groupId: groupId);
      }
      return {
        'success': false,
        'message': e.response?.data?['message'] ?? e.message ?? 'Failed to fetch group details',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching group details: $e');
      }
      return {
        'success': false,
        'message': 'An unexpected error occurred: ${e.toString()}',
      };
    }
  }
}

