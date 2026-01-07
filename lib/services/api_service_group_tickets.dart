import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class ApiServiceGroupTickets {
  final ApiClient _apiClient = ApiClient();
  
  // Al Saboor API credentials
  static const String _agentCode = '2737';
  static const String _email = 'tech@sastayhotels.pk';
  static const String _password = '1766469414';
  
  // Base URL from Al Saboor API documentation
  static const String _baseUrl = 'https://alsaboorportal.com/admins/api';
  
  // SharedPreferences keys
  static const String _tokenKey = 'alsaboor_auth_token';
  static const String _tokenExpiryKey = 'alsaboor_token_expiry';
  
  /// Authenticate with Al Saboor API
  /// Returns token and expiry timestamp
  /// According to docs: POST /login with formdata (email, password, Agent_code)
  Future<Map<String, dynamic>> authenticate() async {
    try {
      final formData = FormData.fromMap({
        'email': _email,
        'password': _password,
        'agent_code': _agentCode,
      });
      
      final response = await _apiClient.request(
        serviceName: 'AL_SABOOR_AUTH',
        url: '$_baseUrl/login',
        method: HttpMethod.POST,
        body: formData,
        headers: {
          'Accept': 'application/json',
        },
      );
      
      if (response.isSuccess && response.responseJson != null) {
        // Use the parsed JSON response
        Map<String, dynamic> data = response.responseJson!;
        
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
          
          await _storeToken(token.toString(), expiryTimestamp);
          
          return {
            'success': true,
            'token': token.toString(),
            'expiry': expiryTimestamp,
          };
        }
      }
      
      return {
        'success': false,
        'message': response.message,
      };
    } catch (e) {
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
      final authResult = await authenticate();
      return authResult['success'] == true ? authResult['token'] as String? : null;
    }
    
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (now >= expiryTimestamp) {
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
      
      String apiGroupType = groupType;
      if (groupType == 'ONE WAY GROUP') {
        apiGroupType = 'ONEWAY';
      }
      
      final response = await _apiClient.request(
        serviceName: 'AL_SABOOR_GROUPS',
        url: '$_baseUrl/groups?type=$apiGroupType&token=$token',
        method: HttpMethod.GET,
        headers: {
          'Authorization': 'Token $token',
        },
      );
      
      if (response.isSuccess && response.responseJson != null) {
        dynamic responseData = response.responseJson;
        if (responseData is String) {
          // Parse JSON string
          responseData = jsonDecode(responseData);
        }
        
        return {
          'success': true,
          'data': responseData,
        };
      }
      
      // Check for 401 unauthorized
      if (response.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tokenKey);
        await prefs.remove(_tokenExpiryKey);
        
        // Retry with new token
        return await getAllGroups(groupType: groupType);
      }
      
      return {
        'success': false,
        'message': response.message,
      };
    } catch (e) {
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
  /// Create a group booking
  /// POST /booking with FormData containing passenger details
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
    String? agentId,
    String? agentName,
  }) async {
    try {
      final token = await getValidToken();
      if (token == null) {
        return {'success': false, 'message': 'Authentication failed. Please try again.'};
      }

      // Build FormData map with array fields using the correct format
      Map<String, dynamic> formDataMap = {
        'token': token,
        'roe': roe,
        'no_of_seat': noOfSeat.toString(),
        'group_id': groupId,
        'pnr_1': pnr1,
        'pnr_2': pnr2 ?? '',
        'agent_id': agentId ?? '10',
        'agent_name': agentName ?? 'API USER',
      };

      // Add array fields - each element separately with [] suffix
      for (int i = 0; i < paxTitle.length; i++) {
        formDataMap['pax_title[$i]'] = paxTitle[i];
      }
      for (int i = 0; i < humanType.length; i++) {
        formDataMap['human_type[$i]'] = humanType[i];
      }
      for (int i = 0; i < surName.length; i++) {
        formDataMap['sur_name[$i]'] = surName[i];
      }
      for (int i = 0; i < givenName.length; i++) {
        formDataMap['given_name[$i]'] = givenName[i];
      }
      for (int i = 0; i < passNo.length; i++) {
        formDataMap['pass_no[$i]'] = passNo[i];
      }
      for (int i = 0; i < dob.length; i++) {
        formDataMap['dob[$i]'] = dob[i];
      }
      for (int i = 0; i < doi.length; i++) {
        formDataMap['doi[$i]'] = doi[i];
      }
      for (int i = 0; i < doe.length; i++) {
        formDataMap['doe[$i]'] = doe[i];
      }

      // Add price arrays if they have values
      if (adultPrice.isNotEmpty) {
        for (int i = 0; i < adultPrice.length; i++) {
          formDataMap['adult_price[$i]'] = adultPrice[i];
        }
      }
      if (childPrice.isNotEmpty) {
        for (int i = 0; i < childPrice.length; i++) {
          formDataMap['child_price[$i]'] = childPrice[i];
        }
      }
      if (infantPrice.isNotEmpty) {
        for (int i = 0; i < infantPrice.length; i++) {
          formDataMap['infant_price[$i]'] = infantPrice[i];
        }
      }

      final formData = FormData.fromMap(formDataMap);

      final response = await _apiClient.request(
          serviceName: 'AL_SABOOR_BOOKING',
          url: '$_baseUrl/booking',
          method: HttpMethod.POST,
          body: formData,
          headers: {
            'Accept': 'application/json',
          },
          printRequestBody: true,
          printResponseBody: true
      );

      if (response.isSuccess && response.responseJson != null) {
        Map<String, dynamic> data = response.responseJson!;

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

      // Handle 401 unauthorized - clear token and retry
      if (response.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tokenKey);
        await prefs.remove(_tokenExpiryKey);
        return {'success': false, 'message': 'Authentication expired. Please try again.'};
      }

      String errorMessage = 'Failed to create booking';
      if (response.statusCode == 400) {
        errorMessage = 'Invalid booking data. Please check your input.';
      } else {
        errorMessage = response.message;
      }

      return {'success': false, 'message': errorMessage};
    } catch (e) {
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

      final response = await _apiClient.request(
        serviceName: 'AL_SABOOR_GROUP_DETAILS',
        url: '$_baseUrl/group-details?group_id=$groupId&token=$token',
        method: HttpMethod.GET,
        headers: {
          'Authorization': 'Token $token',
        },
      );

      if (response.isSuccess && response.responseJson != null) {
        dynamic responseData = response.responseJson;
        if (responseData is String) {
          responseData = jsonDecode(responseData);
        }
        return {
          'success': true,
          'data': responseData,
        };
      }

      // Check for 401 unauthorized
      if (response.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tokenKey);
        await prefs.remove(_tokenExpiryKey);
        return await getGroupDetails(groupId: groupId);
      }

      return {
        'success': false,
        'message': response.message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred: ${e.toString()}',
      };
    }
  }
}

