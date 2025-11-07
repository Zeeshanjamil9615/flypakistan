import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthController extends GetxController {
  var dio = Dio();
  static const String _baseUrl = 'https://readyflights.pk/api';

  // Keys for SharedPreferences
  static const String _tokenKey = 'user_auth_token';
  static const String _tokenExpiryKey = 'user_token_expiry';
  static const String _userDataKey = 'user_data';

  // Observable values
  final RxBool isLoading = false.obs;
  final RxBool isLoggedInValue = false.obs;
  final RxMap<String, dynamic> userData = <String, dynamic>{}.obs;

  @override
  void onInit() {
    super.onInit();
    // Initialize Dio
    dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    // Add logging interceptor in debug mode
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }

    // Check login status at startup
    checkLoginStatus();
  }

  // Check login status and load user data if logged in
  Future<void> checkLoginStatus() async {
    final loginStatus = await isLoggedIn();
    isLoggedInValue.value = loginStatus;

    if (loginStatus) {
      final data = await getUserData();
      if (data != null) {
        userData.value = data;
      }
    }
  }

  // Check if token is valid or get a new one if needed
  Future<String?> getValidToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final expiryTimestamp = prefs.getInt(_tokenExpiryKey);

    if (token == null || expiryTimestamp == null) {
      return null; // No token stored
    }

    // Check if token is expired
    final now =
        DateTime.now().millisecondsSinceEpoch ~/
        1000; // Current time in seconds
    if (now >= expiryTimestamp) {
      if (kDebugMode) {
        print('Token expired, needs refresh');
      }
      return null; // Token expired
    }

    return token; // Valid token
  }

  // Store token with expiry and user data
  Future<void> _storeAuthData(
    String token,
    int expiryTimestamp,
    Map<String, dynamic> userData,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setInt(_tokenExpiryKey, expiryTimestamp);
    await prefs.setString(_userDataKey, jsonEncode(userData));

    if (kDebugMode) {
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(
        expiryTimestamp * 1000,
      );
      print('Token stored, expires on: $expiryDate');
      print('User data stored: $userData');
    }

    // Update login status and user data
    isLoggedInValue.value = true;
    this.userData.value = userData;
  }

  // Get stored user data
  Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString(_userDataKey);
    if (userDataString != null) {
      return jsonDecode(userDataString);
    }
    return null;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    isLoading.value = true;

    try {
      final response = await dio.post(
        '$_baseUrl/token',
        data: {'email': email, 'password': password, 'Platform':"app"},
      );

      if (response.statusCode == 200 && response.data != null) {
        // Parse token, expiry and user data
        final token = response.data['token'];
        final expiryTimestamp = response.data['expire'];
        final userData = response.data['UserData'] ?? {};
        print("user login data");
        print(userData);

        if (token != null && expiryTimestamp != null) {
          // Store token with expiry and user data
          await _storeAuthData(token, expiryTimestamp, userData);

          isLoading.value = false;
          return {
            'success': true,
            'token': token,
            'userData': userData,
            'message': 'Login successful',
          };
        }
      }

      // Extract error message from response
      String errorMessage = 'Login failed';
      if (response.data != null && response.data is Map) {
        errorMessage =
            response.data['message'] ??
            response.data['error'] ??
            'Login failed with status code: ${response.statusCode}';
      }
      

      isLoading.value = false;
      return {
        'success': false,
        'message': errorMessage,
        'statusCode': response.statusCode,
      };
    } on DioException catch (e) {
      isLoading.value = false;
      return _handleDioError(e, 'Login');
    } catch (e) {
      isLoading.value = false;
      return {
        'success': false,
        'message': 'An unexpected error occurred: ${e.toString()}',
      };
    }
  }

  Future<void> logout() async {
    isLoading.value = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_tokenExpiryKey);
    await prefs.remove(_userDataKey);

    // Reset login status and user data
    isLoggedInValue.value = false;
    userData.value = {};
    isLoading.value = false;
  }

  // Method to check if user is logged in with valid token
  Future<bool> isLoggedIn() async {
    final token = await getValidToken();
    return token != null;
  }

  // Helper method to handle Dio errors consistently
  Map<String, dynamic> _handleDioError(DioException e, String operation) {
    String errorMessage;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        errorMessage =
            'Connection timeout. Please check your internet connection.';
        break;
      case DioExceptionType.receiveTimeout:
        errorMessage =
            'Server took too long to respond. Please try again later.';
        break;
      case DioExceptionType.sendTimeout:
        errorMessage =
            'Request timeout. Please check your internet connection.';
        break;
      case DioExceptionType.badResponse:
        if (e.response != null) {
          // Try to extract error message from response
          if (e.response!.data is Map) {
            errorMessage =
                e.response!.data['message'] ??
                e.response!.data['error'] ??
                '$operation failed with status: ${e.response!.statusCode}';
          } else {
            errorMessage =
                '$operation failed with status: ${e.response!.statusCode}';
          }
        } else {
          errorMessage = 'Bad server response';
        }
        break;
      case DioExceptionType.cancel:
        errorMessage = 'Request was cancelled';
        break;
      case DioExceptionType.connectionError:
        errorMessage = 'No internet connection. Please check your network.';
        break;
      case DioExceptionType.unknown:
      default:
        if (e.message != null && e.message!.contains('SocketException')) {
          errorMessage = 'No internet connection. Please check your network.';
        } else {
          errorMessage = 'An unexpected error occurred: ${e.message}';
        }
    }

    // Log the error in debug mode
    if (kDebugMode) {
      print('$operation API Error: $errorMessage');
      if (e.response != null) {
        print('Response status: ${e.response!.statusCode}');
        print('Response data: ${e.response!.data}');
      }
    }

    return {'success': false, 'message': errorMessage};
  }

  Future<Map<String, dynamic>> registerRequest({
    required String agencyName,
    required String contactName,
    required String email,
    required String countryCode,
    required String cellNumber,
    required String address,
    required String city,
  }) async {
    isLoading.value = true;

    try {
      final response = await dio.post(
        '$_baseUrl/registerRequest',
        data: {
          "agency_name": agencyName,
          "contact_name": contactName,
          "email": email,
          "country_code": countryCode,
          "csphno": cellNumber,
          "full_addrss": address,
          "city": city,
        },
      );

      // Debug log the raw response
      if (kDebugMode) {
        print('Registration request response: ${response.data}');
      }

      // Parse the response data
      var responseData = response.data;
      if (responseData is String) {
        try {
          responseData = jsonDecode(responseData);
        } catch (e) {
          // If JSON parsing fails, keep it as string
        }
      }

      // Check the status field in the response
      if (responseData is Map && responseData.containsKey('status')) {
        // Check if status is error or 400
        if (responseData['status'] == 'error' ||
            responseData['status'] == 400 ||
            (responseData['status'] is num && responseData['status'] != 200 && responseData['status'] != 1)) {
          isLoading.value = false;
          return {
            'success': false,
            'message': responseData['message'] ?? 'Registration request failed',
            'errors': responseData['errors'] ?? {},
            'data': responseData,
          };
        }
      }

      // If we reach here and HTTP status is 200/201 and status is 1, consider it success
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          responseData is Map &&
          (responseData['status'] == 1 || responseData['status'] == 200)) {
        isLoading.value = false;
        return {
          'success': true,
          'data': responseData,
          'email': responseData['email'] ?? email,
          'message':
              responseData is Map
                  ? (responseData['message'] ?? 'OTP sent successfully')
                  : 'OTP sent successfully',
        };
      } else {
        // Handle other HTTP error codes
        String errorMessage =
            'Registration request failed with status code: ${response.statusCode}';
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'];
        }

        isLoading.value = false;
        return {
          'success': false,
          'message': errorMessage,
          'statusCode': response.statusCode,
        };
      }
    } on DioException catch (e) {
      isLoading.value = false;
      return _handleDioError(e, 'Registration Request');
    } catch (e) {
      if (kDebugMode) {
        print('Registration request exception: ${e.toString()}');
        print('Stack trace: ${StackTrace.current}');
      }
      isLoading.value = false;
      return {
        'success': false,
        'message': 'Registration request failed: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> registerVerify({
    required String email,
    required String otp,
  }) async {
    isLoading.value = true;

    try {
      final response = await dio.post(
        '$_baseUrl/registerVerify',
        data: {
          "email": email,
          "otp": otp,
        },
      );

      // Debug log the raw response
      if (kDebugMode) {
        print('Registration verify response: ${response.data}');
      }

      // Parse the response data
      var responseData = response.data;
      if (responseData is String) {
        try {
          responseData = jsonDecode(responseData);
        } catch (e) {
          // If JSON parsing fails, keep it as string
        }
      }

      // Check the status field in the response
      if (responseData is Map && responseData.containsKey('status')) {
        // Check if status is error, 400 (OTP mismatch), or 410 (OTP expired)
        if (responseData['status'] == 'error' ||
            responseData['status'] == 400 ||
            responseData['status'] == 410 ||
            (responseData['status'] is num && responseData['status'] != 200)) {
          isLoading.value = false;
          return {
            'success': false,
            'message': responseData['message'] ?? 'OTP verification failed',
            'statusCode': responseData['status'],
            'data': responseData,
          };
        }
      }

      // If we reach here and HTTP status is 200/201 and status is 200, consider it success
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          responseData is Map &&
          responseData['status'] == 200) {
        isLoading.value = false;
        return {
          'success': true,
          'data': responseData,
          'message':
              responseData is Map
                  ? (responseData['message'] ?? 'Registration completed successfully')
                  : 'Registration completed successfully',
        };
      } else {
        // Handle other HTTP error codes
        String errorMessage =
            'OTP verification failed with status code: ${response.statusCode}';
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'];
        }

        isLoading.value = false;
        return {
          'success': false,
          'message': errorMessage,
          'statusCode': response.statusCode,
        };
      }
    } on DioException catch (e) {
      isLoading.value = false;
      return _handleDioError(e, 'Registration Verify');
    } catch (e) {
      if (kDebugMode) {
        print('Registration verify exception: ${e.toString()}');
        print('Stack trace: ${StackTrace.current}');
      }
      isLoading.value = false;
      return {
        'success': false,
        'message': 'OTP verification failed: ${e.toString()}',
      };
    }
  }

  // Add this method to your AuthController class

  Future<Map<String, dynamic>> getHotelBookings() async {
    isLoading.value = true;

    try {
      // Get the token from SharedPreferences
      final token = await getValidToken();

      if (token == null) {
        isLoading.value = false;
        return {
          'success': false,
          'message': 'Authentication token not found. Please login again.',
        };
      }

      // Set up headers with the token
      final headers = {'Authorization': 'Bearer $token'};

      // Make the API request
      final response = await dio.get(
        '$_baseUrl/hotel-booking',
        options: Options(headers: headers),
      );

      // Debug log the response
      if (kDebugMode) {
        print('Hotel bookings response: ${response.data}');
      }

      if (response.statusCode == 200) {
        isLoading.value = false;
        return {
          'success': true,
          'data': response.data,
          'message': 'Hotel bookings retrieved successfully',
        };
      } else {
        String errorMessage = 'Failed to fetch hotel bookings';
        if (response.data != null &&
            response.data is Map &&
            response.data.containsKey('message')) {
          errorMessage = response.data['message'];
        }

        isLoading.value = false;
        return {
          'success': false,
          'message': errorMessage,
          'statusCode': response.statusCode,
        };
      }
    } on DioException catch (e) {
      isLoading.value = false;
      return _handleDioError(e, 'Hotel Bookings');
    } catch (e) {
      if (kDebugMode) {
        print('Hotel bookings exception: ${e.toString()}');
        print('Stack trace: ${StackTrace.current}');
      }
      isLoading.value = false;
      return {
        'success': false,
        'message': 'Failed to fetch hotel bookings: ${e.toString()}',
      };
    }
  }

  // Updated getGroupBookings function with proper null safety handling
  Future<Map<String, dynamic>> getGroupBookings({
    required String fromDate,
    required String toDate,
  }) async {
    isLoading.value = true;

    try {
      // Get the token from SharedPreferences
      final token = await getValidToken();

      if (token == null) {
        isLoading.value = false;
        return {
          'success': false,
          'message': 'Authentication token not found. Please login again.',
        };
      }

      // Set up headers with the token
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      // Create request data with date parameters
      final Map<String, dynamic> requestData = {
        'from_date': fromDate,
        'to_date': toDate,
      };

      // Make the API request with POST method and date parameters
      final response = await dio.post(
        '$_baseUrl/group-bookings',
        options: Options(headers: headers),
        data: requestData,
      );

      // Debug log the response
      if (kDebugMode) {
        print('Group bookings response: ${response.data}');
      }

      if (response.statusCode == 200) {
        isLoading.value = false;
        return {
          'success': true,
          'data': response.data,
          'message': 'Group bookings retrieved successfully',
        };
      } else {
        String errorMessage = 'Failed to fetch Group bookings';
        if (response.data != null &&
            response.data is Map &&
            response.data.containsKey('message')) {
          errorMessage = response.data['message'];
        }

        isLoading.value = false;
        return {
          'success': false,
          'message': errorMessage,
          'statusCode': response.statusCode,
        };
      }
    } on DioException catch (e) {
      isLoading.value = false;
      return _handleDioError(e, 'Group Bookings');
    } catch (e) {
      if (kDebugMode) {
        print('Group bookings exception: ${e.toString()}');
        print('Stack trace: ${StackTrace.current}');
      }
      isLoading.value = false;
      return {
        'success': false,
        'message': 'Failed to fetch Group bookings: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> getFlightsBookings({
    required String fromDate,
    required String toDate,
  }) async {
    isLoading.value = true;

    try {
      // Get the token from SharedPreferences
      final token = await getValidToken();

      if (token == null) {
        isLoading.value = false;
        return {
          'success': false,
          'message': 'Authentication token not found. Please login again.',
        };
      }

      // Set up headers with the token
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      // Create request data with date parameters
      final Map<String, dynamic> requestData = {
        'from_date': fromDate,
        'to_date': toDate,
      };

      // Make the API request with POST method and date parameters
      final response = await dio.post(
        '$_baseUrl/all-flights',
        options: Options(headers: headers),
        data: requestData,
      );

      // Debug log the response
      if (kDebugMode) {
        print('Group bookings response: ${response.data}');
      }

      if (response.statusCode == 200) {
        isLoading.value = false;
        return {
          'success': true,
          'data': response.data,
          'message': 'Group bookings retrieved successfully',
        };
      } else {
        String errorMessage = 'Failed to fetch Group bookings';
        if (response.data != null &&
            response.data is Map &&
            response.data.containsKey('message')) {
          errorMessage = response.data['message'];
        }

        isLoading.value = false;
        return {
          'success': false,
          'message': errorMessage,
          'statusCode': response.statusCode,
        };
      }
    } on DioException catch (e) {
      isLoading.value = false;
      return _handleDioError(e, 'Group Bookings');
    } catch (e) {
      if (kDebugMode) {
        print('Group bookings exception: ${e.toString()}');
        print('Stack trace: ${StackTrace.current}');
      }
      isLoading.value = false;
      return {
        'success': false,
        'message': 'Failed to fetch Group bookings: ${e.toString()}',
      };
    }
  }
}
