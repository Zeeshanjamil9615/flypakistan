
import 'dart:convert';

import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_disposable.dart';

import '../views/users/login/login_api_service/login_api.dart';
import 'api_client.dart';

class ApiServiceMargin extends GetxService {
  // Cache for margin data so we can reuse it between search and booking


  static const String _marginApiBaseUrl = 'https://readyflights.pk/api';


  final AuthController authController = Get.put(
    AuthController(),
  );
  // Add ApiClient instance
  final ApiClient _apiClient = ApiClient();



  Future<Map<String, dynamic>> getMargin(String airlineCode, String gds, String Api) async {
    try {
      // Check if user is logged in by getting valid token
      final token = await authController.getValidToken();
      final isLoggedIn = token != null;

      // Get user data if logged in
      Map<String, dynamic>? userData;
      String email = "";

      if (isLoggedIn) {
        userData = await authController.getUserData();
        // Get cs_email from userData, fallback to empty string if not found
        email = userData?['cs_email'] ?? "";
      }

      // Use ApiClient for margin data
      final response = await _apiClient.request(
          url: '$_marginApiBaseUrl/get-margin',
          method: HttpMethod.POST,
          serviceName: 'GET MARGIN: $Api $airlineCode',
          body: jsonEncode({
            "airline_code": airlineCode,
            "gds": gds,
            "login": isLoggedIn ? 1 : 0, // Send 1 if logged in, 0 if not
            "email": email, // Send cs_email if logged in, empty string if not
          }),
          headers: {
            'Content-Type': 'application/json',
          },
          contentType: ContentType.JSON,
          printResponseBody: true
      );

      if (response.isSuccess) {
        Map<String, dynamic> marginMap = {};

        // Handle different response types
        if (response.responseJson != null) {
          // Already parsed JSON
          marginMap = Map<String, dynamic>.from(response.responseJson!);
        } else if (response.responseBody.isNotEmpty) {
          // Parse JSON string
          try {
            marginMap = jsonDecode(response.responseBody) as Map<String, dynamic>;
          } catch (e) {
            return {};
          }
        } else {
          return {};
        }

        return marginMap;
      } else {
        throw Exception('Failed to get margin: ${response.message}');
      }
    } catch (e) {
      throw Exception('Error getting margin: $e');
    }
  }

// Calculate price with margin based on margin type
// marginType: "per" for percentage, "val" for fixed value
  double calculatePriceWithMargin(double basePrice, Map<String, dynamic> marginData) {
    try {
      if (marginData.isEmpty) {
        // Round up to next integer if there's a decimal (matching Laravel PHP behavior)
        return basePrice.ceil().toDouble();
      }

      final marginType = marginData['flight_margin_type']?.toString().toLowerCase().trim() ?? '';
      final marginValRaw = marginData['margin_val'];
      final marginPerRaw = marginData['margin_per'];

      // Handle numeric types (int, double) and string representations
      double marginVal = 0.0;
      if (marginValRaw != null) {
        if (marginValRaw is num) {
          marginVal = marginValRaw.toDouble();
        } else {
          marginVal = double.tryParse(marginValRaw.toString()) ?? 0.0;
        }
      }

      double marginPer = 0.0;
      if (marginPerRaw != null) {
        if (marginPerRaw is num) {
          marginPer = marginPerRaw.toDouble();
        } else {
          marginPer = double.tryParse(marginPerRaw.toString()) ?? 0.0;
        }
      }

      // Use margin type to determine which calculation to use
      double finalPrice = basePrice;
      if (marginType == 'per' && marginPer > 0) {
        // Percentage margin: API returns as decimal (0.03 = 3%), so multiply directly
        // basePrice * (1 + marginPer) where marginPer is already a decimal
        finalPrice = basePrice * (1 + marginPer);
      } else if (marginType == 'val' && marginVal > 0) {
        // Fixed value margin: basePrice + marginValue
        finalPrice = basePrice + marginVal;
      }

      // Round up to next integer if there's a decimal (matching Laravel PHP behavior)
      return finalPrice.ceil().toDouble();
    } catch (e) {
      // Round up to next integer if there's a decimal (matching Laravel PHP behavior)
      return basePrice.ceil().toDouble();
    }
  }

}