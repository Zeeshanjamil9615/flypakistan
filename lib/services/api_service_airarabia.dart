import 'dart:convert';
import 'api_client.dart';
import 'api_service_airblue.dart';

class ApiServiceAirArabia {
  // ApiClient instance
  final ApiClient _apiClient = ApiClient();

  // Get Air Arabia margin
  Future<Map<String, dynamic>> getAirArabiaMargin(
      String? email, {
        bool printRequest = false,
        bool printResponse = false,
      }) async {
    try {
      final data = {
        if (email != null && email.isNotEmpty) "email": email,
      };

      final response = await _apiClient.request(
        url: 'https://readyflights.pk/api/flight-margin-arabia',
        method: HttpMethod.POST,
        serviceName: 'AIR ARABIA MARGIN',
        body: jsonEncode(data),
        contentType: ContentType.JSON,
        printRequestBody: printRequest,
        printResponseBody: printResponse,
      );

      if (response.isSuccess && response.responseJson != null) {
        return response.responseJson!;
      } else {
        // Return default margin on error
        return {
          'margin_val': '0.00',
          'margin_per': 0,
        };
      }
    } catch (e) {
      return {
        'margin_val': '0.00',
        'margin_per': 0,
      };
    }
  }

  // Helper method to calculate price with margin
  double calculatePriceWithMargin(double basePrice, Map<String, dynamic> marginData) {
    try {
      // Parse margin value and percentage
      final marginVal = double.tryParse(marginData['margin_val']?.toString() ?? '0') ?? 0.0;
      final marginPer = double.tryParse(marginData['margin_per']?.toString() ?? '0') ?? 0.0;

      if (marginVal == 0 && marginPer == 0) {
        return basePrice.ceil().toDouble();
      }

      double finalPrice = basePrice;
      if (marginPer > 0) {
        finalPrice = basePrice * (1 + (marginPer / 100));
      }

      if (marginVal > 0) {
        finalPrice += marginVal;
      }

      return finalPrice.ceil().toDouble();
    } catch (e) {
      return basePrice.ceil().toDouble();
    }
  }

  Future<Map<String, dynamic>> searchFlights({
    required int type,
    required String origin,
    required String destination,
    required String depDate,
    required int adult,
    required int child,
    required int infant,
    required String cabin,
    bool printRequest = false,
    bool printResponse = false,
  }) async {
    try {
      final data = {
        "type": type.toString(),
        "origin": origin,
        "destination": destination,
        "depDate": depDate,
        "adult": adult.toString(),
        "child": child.toString(),
        "infant": infant.toString(),
        "stop": "0", // Air Arabia doesn't support stop filter
        "cabin": cabin,
        "username": "user123456",
        "password": "pass123456"
      };

      final response = await _apiClient.request(
        url: 'https://readyflights.pk/api/new-air-arabia-flights',
        method: HttpMethod.POST,
        serviceName: 'AIR ARABIA SEARCH',
        body: jsonEncode(data),
        contentType: ContentType.JSON,
        printRequestBody: printRequest,
        printResponseBody: printResponse,
      );

      if (response.isSuccess && response.responseJson != null) {
        return response.responseJson!;
      } else {
        throw ApiException(
          message: response.message,
          statusCode: response.statusCode,
          errors: {},
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to search Air Arabia flights: $e',
        statusCode: null,
        errors: {},
      );
    }
  }

  Future<Map<String, dynamic>> getFlightPackages({
    required int type,
    required int adult,
    required int child,
    required int infant,
    required List<Map<String, dynamic>> sector,
    bool printRequest = false,
    bool printResponse = false,
  }) async {
    try {
      final data = {
        "type": type,
        "adult": adult,
        "child": child,
        "infant": infant,
        "sector": sector,
      };

      final response = await _apiClient.request(
        url: 'https://readyflights.pk/api/get-air-arabia-package',
        method: HttpMethod.POST,
        serviceName: 'AIR ARABIA PACKAGES',
        body: jsonEncode(data),
        headers: {
          'Cookie': 'PHPSESSID=f6e1vveq1sr0h15f4t4k31u4f6'
        },
        contentType: ContentType.JSON,
        printRequestBody: printRequest,
        printResponseBody: printResponse,
      );

      if (response.isSuccess && response.responseJson != null) {
        return response.responseJson!;
      } else {
        throw ApiException(
          message: response.message,
          statusCode: response.statusCode,
          errors: {},
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to load Air Arabia packages: $e',
        statusCode: null,
        errors: {},
      );
    }
  }

  Future<Map<String, dynamic>> revalidateAirArabiaPackage({
    required int type,
    required int adult,
    required int child,
    required int infant,
    required List<Map<String, dynamic>> sector,
    required Map<String, dynamic> fare,
    required int csId,
    bool printRequest = false,
    bool printResponse = false,
  }) async {
    try {
      final data = {
        "type": type,
        "adult": adult,
        "child": child,
        "infant": infant,
        "sector": sector,
        "fare": fare,
      };

      final response = await _apiClient.request(
        url: 'https://readyflights.pk/api/air-arabia-package-revalidate',
        method: HttpMethod.POST,
        serviceName: 'AIR ARABIA REVALIDATE',
        body: jsonEncode(data),
        headers: {
          'Cookie': 'PHPSESSID=u1gagb79trmq6famf6dbsnt7a6'
        },
        contentType: ContentType.JSON,
        printRequestBody: printRequest,
        printResponseBody: printResponse,
      );

      if (response.isSuccess && response.responseJson != null) {
        return response.responseJson!;
      } else {
        throw ApiException(
          message: response.message,
          statusCode: response.statusCode,
          errors: {},
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to revalidate Air Arabia package: $e',
        statusCode: null,
        errors: {},
      );
    }
  }

  Future<Map<String, dynamic>> createAirArabiaBooking({
    required String email,
    required String finalKey,
    required String echoToken,
    required String transactionIdentifier,
    required String jsession,
    required int adults,
    required int child,
    required int infant,
    required List<int> stopsSector,
    required String bkIdArray,
    required String bkIdArray3,
    required List<List<String>> adultBaggage,
    required List<List<List<String>>> adultMeal,
    required List<List<List<String>>> adultSeat,
    required List<dynamic> childBaggage,
    required List<dynamic> childMeal,
    required List<dynamic> childSeat,
    required String bookerName,
    required String countryCode,
    required String simCode,
    required String city,
    required String address,
    required String phone,
    required String remarks,
    required double marginPer,
    required double marginVal,
    required double finalPrice,
    required double totalPrice,
    required String flightType,
    required int csId,
    required String csName,
    required List<Map<String, dynamic>> adultPassengers,
    required List<Map<String, dynamic>> childPassengers,
    required List<Map<String, dynamic>> infantPassengers,
    required List<Map<String, dynamic>> flightDetails,
    bool printRequest = false,
    bool printResponse = false,
  }) async {
    try {
      final data = {
        "email": email,
        "final_key": finalKey,
        "EchoToken": echoToken,
        "TransactionIdentifier": transactionIdentifier,
        "jsession": jsession,
        "adults": adults,
        "child": child,
        "infant": infant,
        "stops_sector": stopsSector,
        "bk_id_array": bkIdArray,
        "bk_id_array3": bkIdArray3,
        "adult_baggage": adultBaggage,
        "adult_meal": adultMeal,
        "adult_seat": adultSeat,
        "child_baggage": childBaggage,
        "child_meal": childMeal,
        "child_seat": childSeat,
        "booker_name": bookerName,
        "country_code": countryCode,
        "sim_code": simCode,
        "city": city,
        "address": address,
        "phone": phone,
        "remarks": remarks,
        "margin_per": marginPer,
        "margin_val": marginVal,
        "final_price": finalPrice,
        "total_price": totalPrice,
        "flight_type": flightType,
        "cs_id": csId,
        "cs_name": csName,
        "adult_passengers": adultPassengers,
        "child_passengers": childPassengers,
        "infant_passengers": infantPassengers,
        "flight_details": flightDetails,
      };

      final response = await _apiClient.request(
        url: 'https://readyflights.pk/api/air-arabia-create-booking',
        method: HttpMethod.POST,
        serviceName: 'AIR ARABIA BOOKING',
        body: jsonEncode(data),
        headers: {
          'Cookie': 'PHPSESSID=trfun4hl59lq621fvrhus9oti5'
        },
        contentType: ContentType.JSON,
        printRequestBody: true,
        printResponseBody: printResponse,
      );

      if (response.isSuccess && response.responseJson != null) {
        return response.responseJson!;
      } else {
        throw ApiException(
          message: response.message,
          statusCode: response.statusCode,
          errors: {},
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to create Air Arabia booking: $e',
        statusCode: null,
        errors: {},
      );
    }
  }
}

