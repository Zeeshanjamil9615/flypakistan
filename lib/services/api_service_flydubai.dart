import 'package:dio/dio.dart';
import 'dart:convert';

import '../views/flight/booking_flight/booking_flight_controller.dart';
import '../views/flight/search_flights/sabre/sabre_flight_models.dart';
import '../views/flight/search_flights/search_flight_utils/helper_functions.dart';
import 'api_client.dart';
import 'logger_service.dart';

class ApiServiceFlyDubai {
  // FlyDubai API credentials and constants
  static const String clientId = 'TravelocityPK_FZ_P';
  static const String clientSecret = '57F2F0BE34296098FB0E147194462A60';
  static const String username = 'apitravelocityp';
  static const String password = 'Ag3n@tPk!FLyDuB@1';
  static const String baseUrl = 'https://api.flydubai.com/res/v3';

  // Access token for API calls - make it static to persist across instances
  static String? _accessToken;
  static DateTime? _tokenExpiry;

  // Airline map for airline name lookup
  static Map<String, AirlineInfo>? _airlineMap;
  static final Dio _dioForAirline = Dio();
  
  // ApiClient instance
  final ApiClient _apiClient = ApiClient();

  // Authenticate with FlyDubai API
  Future<bool> authenticate({
    bool printRequest = false,
    bool printResponse = false,
  }) async {
    try {
      final String bodyString = 'client_id=$clientId&client_secret=$clientSecret&grant_type=password&password=${Uri.encodeComponent(password)}&scope=res&username=$username';

      final response = await _apiClient.request(
        url: '$baseUrl/authenticate',
        method: HttpMethod.POST,
        serviceName: 'FLYDUBAI AUTH',
        body: bodyString,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Cookie': 'visid_incap_3059742=mt0fc3JTQDStXbDmAKotlet1zGUAAAAAQUIPAAAAAAA/4nh9vwd+842orxzMj3FS',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
        contentType: ContentType.JSON,
        printRequestBody: printRequest,
        printResponseBody: printResponse,
      );

      if (response.isSuccess) {
        final Map<String, dynamic> tokenData = json.decode(response.responseBody);
        if (tokenData.containsKey('access_token')) {
          _accessToken = tokenData['access_token'];
          _tokenExpiry = DateTime.now().add(Duration(hours: 1));
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Check if token is expired
  bool _isTokenExpired() {
    return _tokenExpiry == null || _tokenExpiry!.isBefore(DateTime.now());
  }








  // Get valid access token (only authenticate if needed)
  Future<String?> getValidToken() async {
    if (_accessToken == null || _isTokenExpired()) {
      final authSuccess = await authenticate();
      return authSuccess ? _accessToken : null;
    }
    return _accessToken;
  }

  // Search FlyDubai flights - this is the only method that can initiate authentication
  Future<Map<String, dynamic>> searchFlights({
    required int type,
    required String origin,
    required String destination,
    required String depDate,
    required int adult,
    required int child,
    required int infant,
    required String cabin,
    List<Map<String, String>>? multiCitySegments,
    bool printRequest = false,
    bool printResponse = false,
  }) async {
    try {
      // Only authenticate here if no valid token exists
      if (_accessToken == null || _isTokenExpired()) {
        final authSuccess = await authenticate();
        if (!authSuccess) {
          return {
            'error': 'FlyDubai authentication failed',
            'flights': [],
            'success': false
          };
        }
      }



      Map<String, dynamic>? searchParams;

      if (type == 2 && multiCitySegments != null && multiCitySegments.isNotEmpty) {
        // Multi-city search
        searchParams = _buildMultiCityRequest(
          segments: multiCitySegments,
          passengers: adult + child + infant,
          cabin: cabin,
        );
      } else if (type == 1) {
        // Round-trip search
        List<String> datesList = [];

        if (depDate.contains(',')) {
          datesList = depDate.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
        } else {
          datesList = [depDate.trim()];
        }

        if (datesList.length < 2) {
          return {
            'error': 'Round-trip requires both departure and return dates. Parsed: $datesList from "$depDate"',
            'flights': [],
            'success': false
          };
        }

        try {
          final outboundDate = DateTime.parse(datesList[0]);
          final returnDate = DateTime.parse(datesList[1]);

          String cleanOrigin = origin.trim().replaceAll(',', '');
          String cleanDestination = destination.trim().replaceAll(',', '');

          if (cleanOrigin.length == 6 && cleanDestination.length == 6) {
            cleanOrigin = cleanOrigin.substring(0, 3);
            cleanDestination = cleanDestination.substring(0, 3);
          }

          searchParams = _buildRoundTripRequest(
            origin: cleanOrigin,
            destination: cleanDestination,
            outboundDate: outboundDate,
            returnDate: returnDate,
            passengers: adult + child + infant,
            cabin: cabin,
          );
        } catch (e) {
          return {
            'error': 'Invalid date format in round-trip request: $e. Dates: $datesList',
            'flights': [],
            'success': false
          };
        }
      } else {
        // One-way search
        final cleanDepDate = depDate.trim();

        try {
          final outboundDate = DateTime.parse(cleanDepDate);

          searchParams = _buildOneWayRequest(
            origin: origin.trim(),
            destination: destination.trim(),
            outboundDate: outboundDate,
            passengers: adult + child + infant,
            cabin: cabin,
          );
        } catch (e) {
          return {
            'error': 'Invalid date format for one-way: $e. Date: "$cleanDepDate"',
            'flights': [],
            'success': false
          };
        }
      }

      if (searchParams == null) {
        return {
          'error': 'Could not build search parameters for FlyDubai',
          'flights': [],
          'success': false
        };
      }

      final endpoint = '$baseUrl/pricing/flightswithfares';
      final requestHeaders = {
        'Authorization': 'Bearer $_accessToken',
        'Cookie': 'visid_incap_3059742=mt0fc3JTQDStXbDmAKotlet1zGUAAAAAQUIPAAAAAAA/4nh9vwd+842orxzMj3FS',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      };
      
      // Log request to file (only in debug mode)
      final logger = LoggerService();
      await logger.logFlightsRequest(
        endpoint: endpoint,
        headers: requestHeaders,
        body: searchParams,
      );
      
      // Make API request using ApiClient
      final response = await _apiClient.request(
        url: endpoint,
        method: HttpMethod.POST,
        serviceName: 'FLYDUBAI SEARCH',
        body: json.encode(searchParams),
        headers: requestHeaders,
        contentType: ContentType.JSON,
        printRequestBody: printRequest,
        printResponseBody: printResponse,
      );
      
      // Log response to file (only in debug mode)
      try {
        final responseBody = json.decode(response.responseBody);
        await logger.logFlightsResponse(
          endpoint: endpoint,
          statusCode: response.statusCode,
          body: responseBody,
        );
      } catch (e) {
        await logger.logFlightsResponse(
          endpoint: endpoint,
          statusCode: response.statusCode,
          body: response.responseBody,
        );
      }

      if (response.isSuccess) {
        final Map<String, dynamic> responseData = json.decode(response.responseBody);
        return {
          'success': true,
          'flights': responseData,
          'airline': 'FlyDubai',
          'source': 'flydubai_api',
          'tripType': _getTripTypeName(type),
        };
      } else if (response.statusCode == 401) {
        // Token expired
        _accessToken = null;
        _tokenExpiry = null;
        final authSuccess = await authenticate();
        if (authSuccess) {
          return await searchFlights(
            type: type,
            origin: origin,
            destination: destination,
            depDate: depDate,
            adult: adult,
            child: child,
            infant: infant,
            cabin: cabin,
            multiCitySegments: multiCitySegments,
            printRequest: printRequest,
            printResponse: printResponse,
          );
        }
      }

      String errorMessage = 'FlyDubai API returned status: ${response.statusCode}';
      try {
        final errorData = json.decode(response.responseBody);
        errorMessage = errorData['message'] ?? 
                      errorData['error'] ?? 
                      errorData['errorMessage'] ?? 
                      errorData['Exception']?.toString() ?? 
                      errorData['Exceptions']?.toString() ??
                      errorMessage;
      } catch (e) {
      }

      return {
        'error': errorMessage,
        'flights': [],
        'success': false
      };

    } catch (e, stackTrace) {
      final logger = LoggerService();
      await logger.logError(
        error: e,
        stackTrace: stackTrace,
        context: {
          'method': 'searchFlights',
          'type': type,
          'origin': origin,
          'destination': destination,
          'depDate': depDate,
          'adult': adult,
          'child': child,
          'infant': infant,
          'cabin': cabin,
        },
      );
      
      return {
        'error': 'FlyDubai search failed: $e',
        'flights': [],
        'success': false
      };
    }
  }

  // Add to cart function - uses existing token, doesn't authenticate
  Future<Map<String, dynamic>> addToCart({
    required List<String> bookingIds,
    required Map<String, dynamic> flightData,
    bool printRequestBody = false,
    bool printResponseBody = false,
  }) async {
    try {
      if (_accessToken == null) {
        return {
          'success': false,
          'error': 'No valid token available. Please search flights first.',
          'details': 'Authentication required before adding to cart'
        };
      }

      final requestBody = _buildAddToCartRequest(bookingIds, flightData);

      final response = await _apiClient.request(
        url: '$baseUrl/order/cart',
        method: HttpMethod.POST,
        serviceName: 'FLYDUBAI ADD TO CART',
        body: json.encode(requestBody),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Cookie': 'visid_incap_3059742=mt0fc3JTQDStXbDmAKotlet1zGUAAAAAQUIPAAAAAAA/4nh9vwd+842orxzMj3FS',
          'Accept-Encoding': 'gzip, deflate',
        },
        contentType: ContentType.JSON,
        printRequestBody: printRequestBody,
        printResponseBody: printResponseBody,
      );

      if (response.isSuccess) {
        final Map<String, dynamic> responseData = json.decode(response.responseBody);
        final securityGuid = _extractSecurityGuid(responseData);

        return {
          'success': true,
          'data': responseData,
          'securityGuid': securityGuid,
        };
      } else if (response.statusCode == 401) {
        _accessToken = null;
        _tokenExpiry = null;
        return {
          'success': false,
          'error': 'Token expired. Please search flights again to get a new token.',
          'response': response.responseBody,
        };
      }

      return {
        'success': false,
        'error': 'Add to Cart failed with status: ${response.statusCode}',
        'response': response.responseBody,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Add to Cart failed: $e',
      };
    }
  }

  String? _extractSecurityGuid(Map<String, dynamic> cartData) {
    try {
      String? securityGuid = cartData['SecurityGUID'] ??
          cartData['SecurityGuid'] ??
          cartData['securityGUID'] ??
          cartData['securityGuid'];

      if (securityGuid != null && securityGuid.isNotEmpty) {
        return securityGuid;
      }

      final flightGroups = cartData['flightGroups'] as List?;
      if (flightGroups != null && flightGroups.isNotEmpty) {
        for (final group in flightGroups) {
          if (group is Map) {
            securityGuid = group['SecurityGuid'] ?? group['securityGuid'];
            if (securityGuid != null && securityGuid.isNotEmpty) {
              return securityGuid;
            }
          }
        }
      }

      final originDestinations = cartData['originDestinations'] as List?;
      if (originDestinations != null && originDestinations.isNotEmpty) {
        for (final od in originDestinations) {
          if (od is Map) {
            securityGuid = od['SecurityGuid'] ?? od['securityGuid'];
            if (securityGuid != null && securityGuid.isNotEmpty) {
              return securityGuid;
            }
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }
  // Create PNR - uses existing token, doesn't authenticate
  Future<Map<String, dynamic>> createPNR({
    required List<TravelerInfo> adults,
    required List<TravelerInfo> children,
    required List<TravelerInfo> infants,
    required String clientEmail,
    required String clientPhone,
    required String countryCode,
    required String simCode,
    required String city,
    required String flightType,
    required List<Map<String, dynamic>> segmentArray,
    required Map<String, dynamic> cartData,
    bool printRequest = false,
    bool printResponse = false,
  }) async {
    try {
      if (_accessToken == null) {
        return {
          'success': false,
          'error': 'No valid token available. Please search flights first.',
          'details': 'Authentication required before creating PNR'
        };
      }

      if (cartData.isEmpty) {
        return {
          'success': false,
          'error': 'Invalid cart data. Please add flights to cart first.',
          'details': 'Cart data is required for PNR creation'
        };
      }

      String securityGuid = '';

      final requestBody = await _buildPNRRequest(
        adults: adults,
        children: children,
        infants: infants,
        clientEmail: clientEmail,
        clientPhone: clientPhone,
        countryCode: countryCode,
        simCode: simCode,
        city: city,
        flightType: flightType,
        segmentArray: segmentArray,
        cartData: cartData,
        securityGuid: securityGuid,
      );

      final response = await _apiClient.request(
        url: '$baseUrl/cp/summaryPNR?accural=true',
        method: HttpMethod.POST,
        serviceName: 'FLYDUBAI CREATE PNR',
        body: json.encode(requestBody),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Accept-Encoding': 'gzip, deflate',
        },
        contentType: ContentType.JSON,
        printRequestBody: printRequest,
        printResponseBody: printResponse,
      );

      if (response.isSuccess) {
        final Map<String, dynamic> responseData = json.decode(response.responseBody);
        final seriesNumber = responseData['SeriesNumber']?.toString();

        if (seriesNumber == null || seriesNumber.isEmpty) {
          return {
            'success': false,
            'error': 'Missing SeriesNumber in PNR creation response',
            'rawResponse': responseData,
          };
        }

        final commitRequest = {
          "ActionType": "CommitSummary",
          "ReservationInfo": {
            "SeriesNumber": seriesNumber,
            "ConfirmationNumber": null
          },
          "SecurityGUID": "$_accessToken",
          "CarrierCodes": [
            {"AccessibleCarrierCode": "FZ"}
          ],
          "ClientIPAddress": "",
          "HistoricUserName": username
        };

        final commitResponse = await _apiClient.request(
          url: '$baseUrl/cp/commitPNR?accrual=true',
          method: HttpMethod.POST,
          serviceName: 'FLYDUBAI COMMIT PNR',
          body: json.encode(commitRequest),
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Accept-Encoding': 'gzip, deflate',
          },
          contentType: ContentType.JSON,
          printRequestBody: printRequest,
          printResponseBody: printResponse,
        );

        Map<String, dynamic> pnrResult;

        if (commitResponse.isSuccess) {
          final commitData = json.decode(commitResponse.responseBody);
          final confirmationNumber =
              commitData['ReservationInfo']?['ConfirmationNumber'] ??
                  commitData['ConfirmationNumber'] ??
                  commitData['reservationInfo']?['confirmationNumber'] ??
                  commitData['confirmationNumber'];

          pnrResult = {
            'success': true,
            'data': responseData,
            'commitData': commitData,
            'confirmationNumber': confirmationNumber,
            'message': 'PNR created and committed successfully',
          };
        } else {
          pnrResult = {
            'success': false,
            'error': 'Commit PNR failed',
            'response': commitResponse.responseBody,
            'statusCode': commitResponse.statusCode,
          };
        }

        try {
          await saveFlyDubaiBooking(
            adults: adults,
            children: children,
            infants: infants,
            clientEmail: clientEmail,
            clientPhone: clientPhone,
            pnrResponse: pnrResult,
            segmentArray: segmentArray,
            cartData: cartData,
            flightType: flightType,
          );
        } catch (saveError) {
        }

        return pnrResult;
      } else if (response.statusCode == 401) {
        _accessToken = null;
        _tokenExpiry = null;
        final errorResponse = {
          'success': false,
          'error': 'Token expired. Please search flights again to get a new token.',
          'response': response.responseBody,
        };

        try {
          await saveFlyDubaiBooking(
            adults: adults,
            children: children,
            infants: infants,
            clientEmail: clientEmail,
            clientPhone: clientPhone,
            pnrResponse: errorResponse,
            segmentArray: segmentArray,
            cartData: cartData,
            flightType: flightType,
          );
        } catch (saveError) {
        }

        return errorResponse;
      } else {
        final errorResponseData = json.decode(response.responseBody);
        final errorMessage = errorResponseData['errorMessage'] ??
            errorResponseData['Message'] ??
            errorResponseData['error'] ??
            errorResponseData['Exception'] ??
            'PNR creation failed with status: ${response.statusCode}';

        final errorResponse = {
          'success': false,
          'error': errorMessage,
          'response': response.responseBody,
          'statusCode': response.statusCode,
        };

        try {
          await saveFlyDubaiBooking(
            adults: adults,
            children: children,
            infants: infants,
            clientEmail: clientEmail,
            clientPhone: clientPhone,
            pnrResponse: errorResponse,
            segmentArray: segmentArray,
            cartData: cartData,
            flightType: flightType,
          );
        } catch (saveError) {
        }

        return errorResponse;
      }
    } catch (e, stackTrace) {
      final errorResponse = {
        'success': false,
        'error': 'PNR creation failed: $e',
        'stackTrace': stackTrace.toString(),
      };

      try {
        await saveFlyDubaiBooking(
          adults: adults,
          children: children,
          infants: infants,
          clientEmail: clientEmail,
          clientPhone: clientPhone,
          pnrResponse: errorResponse,
          segmentArray: segmentArray,
          cartData: cartData,
          flightType: flightType,
        );
      } catch (saveError) {
      }

      return errorResponse;
    }
  }
  // Revalidate flight pricing - uses existing token, doesn't authenticate
  Future<Map<String, dynamic>> revalidateFlight({
    required String bookingId,
    required Map<String, dynamic> flightData,
    bool printRequest = false,
    bool printResponse = false,
  }) async {
    try {
      if (_accessToken == null) {
        return {
          'success': false,
          'error': 'No valid token available. Please search flights first.',
          'details': 'Authentication required before revalidation'
        };
      }

      final result = await addToCart(
        bookingIds: [bookingId],
        flightData: flightData,
        printRequestBody: printRequest,
        printResponseBody: printResponse,
      );

      if (result['success'] == true) {
        return {
          'success': true,
          'updatedPrice': _extractUpdatedPrice(result['data']),
          'cartData': result['data'],
        };
      }

      return result;
    } catch (e) {
      return {
        'success': false,
        'error': 'Revalidation failed: $e',
      };
    }
  }

  // Helper method to get trip type name
  String _getTripTypeName(int type) {
    switch (type) {
      case 0:
        return 'One-Way';
      case 1:
        return 'Round-Trip';
      case 2:
        return 'Multi-City';
      default:
        return 'Unknown';
    }
  }

  // Rest of your helper methods remain unchanged...
  // _buildOneWayRequest, _buildRoundTripRequest, _buildMultiCityRequest,
  // _buildAddToCartRequest, _extractArray, _extractUpdatedPrice,
  // _buildPNRRequest, _calculateAge, _buildSegmentsFromCartData,
  // _buildSpecialServices, _buildSeats, printJsonPretty



  // Build one-way search request
  Map<String, dynamic> _buildOneWayRequest({
    required String origin,
    required String destination,
    required DateTime outboundDate,
    required int passengers,
    required String cabin,
  }) {
    final fareQuoteDetail = {
      "Origin": origin,
      "Destination": destination,
      "PartyConfig": "",
      "UseAirportsNotMetroGroups": "true",
      "UseAirportsNotMetroGroupsAsRule": "true",
      "UseAirportsNotMetroGroupsForFrom": "true",
      "UseAirportsNotMetroGroupsForTo": "true",
      "DateOfDepartureStart": "${outboundDate.toIso8601String().substring(0, 10)}T00:00:00",
      "DateOfDepartureEnd": "${outboundDate.toIso8601String().substring(0, 10)}T23:59:59",
      "FareQuoteRequestInfos": {
        "FareQuoteRequestInfo": [
          {"PassengerTypeID": 1, "TotalSeatsRequired": passengers.toString()}
        ]
      },
      "FareTypeCategory": "1"
    };

    return {
      "RetrieveFareQuoteDateRange": {
        "RetrieveFareQuoteDateRangeRequest": {
          "SecurityGUID": "",
          "CarrierCodes": {
            "CarrierCode": [
              {"AccessibleCarrierCode": "FZ"}
            ]
          },
          "ChannelID": "OTA",
          "CountryCode": "PK",
          "ClientIPAddress": "",
          "HistoricUserName": username,
          "CurrencyOfFareQuote": "PKR",
          "PromotionalCode": "FAREBRANDS",
          "IataNumberOfRequestor": "2730402T",
          "FullInBoundDate": "${outboundDate.day.toString().padLeft(2, '0')}/${outboundDate.month.toString().padLeft(2, '0')}/${outboundDate.year}",
          "FullOutBoundDate": "${outboundDate.day.toString().padLeft(2, '0')}/${outboundDate.month.toString().padLeft(2, '0')}/${outboundDate.year}",
          "CorporationID": "-2147483648",
          "FareFilterMethod": "NoCombinabilityRoundtripLowestFarePerFareType",
          "FareGroupMethod": "WebFareTypes",
          "InventoryFilterMethod": "Available",
          "FareQuoteDetails": {
            "FareQuoteDetailDateRange": [fareQuoteDetail]
          }
        }
      }
    };
  }

  // Build round-trip search request
  Map<String, dynamic> _buildRoundTripRequest({
    required String origin,
    required String destination,
    required DateTime outboundDate,
    required DateTime returnDate,
    required int passengers,
    required String cabin,
  }) {
    String passengerArray = '';
    if (passengers > 0) {
      passengerArray = '''
    {
      "PassengerTypeID": 1,
      "TotalSeatsRequired": "$passengers"
    }''';
    }

    final fareQuoteDetails = [
      {
        "Origin": origin,
        "Destination": destination,
        "PartyConfig": "",
        "UseAirportsNotMetroGroups": "true",
        "UseAirportsNotMetroGroupsAsRule": "true",
        "UseAirportsNotMetroGroupsForFrom": "true",
        "UseAirportsNotMetroGroupsForTo": "true",
        "DateOfDepartureStart": "${outboundDate.toIso8601String().substring(0, 10)}T00:00:00",
        "DateOfDepartureEnd": "${outboundDate.toIso8601String().substring(0, 10)}T23:59:59",
        "FareQuoteRequestInfos": {
          "FareQuoteRequestInfo": [
            {
              "PassengerTypeID": 1,
              "TotalSeatsRequired": passengers.toString()
            }
          ]
        },
        "FareTypeCategory": "1"
      },
      {
        "Origin": destination,
        "Destination": origin,
        "PartyConfig": "",
        "UseAirportsNotMetroGroups": "true",
        "UseAirportsNotMetroGroupsAsRule": "true",
        "UseAirportsNotMetroGroupsForFrom": "true",
        "UseAirportsNotMetroGroupsForTo": "true",
        "DateOfDepartureStart": "${returnDate.toIso8601String().substring(0, 10)}T00:00:00",
        "DateOfDepartureEnd": "${returnDate.toIso8601String().substring(0, 10)}T23:59:59",
        "FareQuoteRequestInfos": {
          "FareQuoteRequestInfo": [
            {
              "PassengerTypeID": 1,
              "TotalSeatsRequired": passengers.toString()
            }
          ]
        },
        "FareTypeCategory": "1"
      }
    ];

    return {
      "RetrieveFareQuoteDateRange": {
        "RetrieveFareQuoteDateRangeRequest": {
          "SecurityGUID": "",
          "CarrierCodes": {
            "CarrierCode": [
              {"AccessibleCarrierCode": "FZ"}
            ]
          },
          "ChannelID": "OTA",
          "CountryCode": "PK",
          "ClientIPAddress": "",
          "HistoricUserName": username,
          "CurrencyOfFareQuote": "PKR",
          "PromotionalCode": "FAREBRANDS",
          "IataNumberOfRequestor": "2730402T",
          "FullInBoundDate": "${returnDate.day.toString().padLeft(2, '0')}/${returnDate.month.toString().padLeft(2, '0')}/${returnDate.year}",
          "FullOutBoundDate": "${outboundDate.day.toString().padLeft(2, '0')}/${outboundDate.month.toString().padLeft(2, '0')}/${outboundDate.year}",
          "CorporationID": "-2147483648",
          "FareFilterMethod": "NoCombinabilityRoundtripLowestFarePerFareType",
          "FareGroupMethod": "WebFareTypes",
          "InventoryFilterMethod": "Available",
          "FareQuoteDetails": {
            "FareQuoteDetailDateRange": fareQuoteDetails
          }
        }
      }
    };
  }
  // Build multi-city search request
  Map<String, dynamic> _buildMultiCityRequest({
    required List<Map<String, String>> segments,
    required int passengers,
    required String cabin,
  }) {
    final List<Map<String, dynamic>> fareQuoteDetails = [];

    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final departureDate = DateTime.parse(segment['date']!);

      fareQuoteDetails.add({
        "Origin": segment['from'],
        "Destination": segment['to'],
        "PartyConfig": "",
        "UseAirportsNotMetroGroups": "true",
        "UseAirportsNotMetroGroupsAsRule": "true",
        "UseAirportsNotMetroGroupsForFrom": "true",
        "UseAirportsNotMetroGroupsForTo": "true",
        "DateOfDepartureStart": "${departureDate.toIso8601String().substring(0, 10)}T00:00:00",
        "DateOfDepartureEnd": "${departureDate.toIso8601String().substring(0, 10)}T23:59:59",
        "FareQuoteRequestInfos": {
          "FareQuoteRequestInfo": [
            {"PassengerTypeID": 1, "TotalSeatsRequired": passengers.toString()}
          ]
        },
        "FareTypeCategory": "1"
      });
    }

    return {
      "RetrieveFareQuoteDateRange": {
        "RetrieveFareQuoteDateRangeRequest": {
          "SecurityGUID": "",
          "CarrierCodes": {
            "CarrierCode": [
              {"AccessibleCarrierCode": "FZ"}
            ]
          },
          "ChannelID": "OTA",
          "CountryCode": "PK",
          "ClientIPAddress": "",
          "HistoricUserName": username,
          "CurrencyOfFareQuote": "PKR",
          "PromotionalCode": "FAREBRANDS",
          "IataNumberOfRequestor": "2730402T",
          "FullInBoundDate": segments.last['date']!.split('-').reversed.join('/'),
          "FullOutBoundDate": segments.first['date']!.split('-').reversed.join('/'),
          "CorporationID": "-2147483648",
          "FareFilterMethod": "NoCombinabilityRoundtripLowestFarePerFareType",
          "FareGroupMethod": "WebFareTypes",
          "InventoryFilterMethod": "Available",
          "FareQuoteDetails": {
            "FareQuoteDetailDateRange": fareQuoteDetails
          }
        }
      }
    };
  }



  Map<String, dynamic> _buildAddToCartRequest(
      List<String> bookingIds, Map<String, dynamic> flightData) {

    final retrieveResult = flightData['RetrieveFareQuoteDateRangeResponse']?['RetrieveFareQuoteDateRangeResult'];
    if (retrieveResult == null) {
      throw Exception('Invalid flight data structure: Missing RetrieveFareQuoteDateRangeResult');
    }

    final basicArray = _extractArray(retrieveResult['FlightSegments']?['FlightSegment']);
    final legDetails = _extractArray(retrieveResult['LegDetails']?['LegDetail']);
    final segmentDetails = _extractArray(retrieveResult['SegmentDetails']?['SegmentDetail']);
    final taxDetails = _extractArray(retrieveResult['TaxDetails']?['TaxDetail']);

    final List<Map<String, dynamic>> originDestinations = [];

    for (int i = 0; i < bookingIds.length; i++) {
      final bk = bookingIds[i];
      final bkIdArray = bk.split('_');

      if (bkIdArray.length < 2) {
        continue;
      }

      final requestedLfid = int.tryParse(bkIdArray[0]) ?? 0;
      final requestedFareId = int.tryParse(bkIdArray[1]) ?? 0;

      dynamic arrayStart;
      if (basicArray is List && basicArray.isNotEmpty) {
        for (var segment in basicArray) {
          if (segment is Map && segment['LFID'] == requestedLfid) {
            arrayStart = segment;
            break;
          }
        }
        if (arrayStart == null) {
          arrayStart = basicArray[0];
        }
      } else if (basicArray is Map) {
        arrayStart = basicArray;
      }

      if (arrayStart == null) {
        continue;
      }

      final lfid1 = arrayStart['LFID'];
      final flightLegDetail = _extractArray(arrayStart['FlightLegDetails']?['FlightLegDetail']);

      // Find segment details
      Map<String, dynamic> segmentInfo = {};
      if (segmentDetails is List && segmentDetails.isNotEmpty) {
        for (final item in segmentDetails) {
          if (item is Map && item['LFID'] == lfid1) {
            segmentInfo = {
              'odID': lfid1,
              'origin': item['Origin'] ?? '',
              'destination': item['Destination'] ?? '',
              'flightNum': item['FlightNum'] ?? '',
              'depDate': item['DepartureDate'] ?? '',
              'isPromoApplied': false,
            };
            break;
          }
        }
      }

      final fareTypes = _extractArray(arrayStart['FareTypes']?['FareType']);

      if (fareTypes == null) {
        continue;
      }

      dynamic fareArray;
      if (fareTypes is List) {
        for (var fareType in fareTypes) {
          if (fareType is Map) {
            final fareInfos = _extractArray(fareType['FareInfos']?['FareInfo']);
            if (fareInfos != null) {
              final fareInfosList = fareInfos is List ? fareInfos : [fareInfos];
              if (fareInfosList.isNotEmpty) {
                final fares = fareInfosList[0];
                final paxList = _extractArray(fares['Pax']);
                if (paxList != null) {
                  final fareData = paxList is List ? paxList[0] : paxList;
                  final fareId = fareData['FareID'];
                  if (fareId == requestedFareId) {
                    fareArray = fareType;
                    break;
                  }
                }
              }
            }
          }
        }
      } else if (fareTypes is Map) {
        fareArray = fareTypes;
      }

      if (fareArray == null) {
        continue;
      }

      final fareTypeId = fareArray['FareTypeID'];
      final fareTypeName = fareArray['FareTypeName'];

      final fareInfos = _extractArray(fareArray['FareInfos']?['FareInfo']);
      final List<Map<String, dynamic>> paxFareInfos = [];
      final List<String> paxIds = [];

      if (fareInfos != null) {
        final fareInfosList = fareInfos is List ? fareInfos : [fareInfos];

        for (int pe = 0; pe < fareInfosList.length; pe++) {
          final fares = fareInfosList[pe];
          final paxList = _extractArray(fares['Pax']);

          if (paxList == null || (paxList is List && paxList.isEmpty)) {
            continue;
          }

          final fareData = paxList is List ? paxList[0] : paxList;
          final id = fareData['ID']?.toString() ?? '1';


          final fareId = fareData['FareID'];
          final fbCode = fareData['FBCode'] ?? '';
          final cabin = fareData['Cabin'] ?? 'ECONOMY';

          // Safely get fare class from booking codes
          String fareClass = 'Y';
          final bookingCodes = _extractArray(fareData['BookingCodes']?['Bookingcode']);
          if (bookingCodes != null) {
            final bookingCodesList = bookingCodes is List ? bookingCodes : [bookingCodes];
            if (pe < bookingCodesList.length && bookingCodesList[pe] is Map) {
              fareClass = bookingCodesList[pe]['RBD']?.toString() ?? 'Y';
            } else if (bookingCodesList.isNotEmpty && bookingCodesList[0] is Map) {
              fareClass = bookingCodesList[0]['RBD']?.toString() ?? 'Y';
            }
          }

          final ptcId = fareData['PTCID'] ?? 1;
          final originalFare = (fareData['DisplayFareAmt'] as num?)?.toDouble() ?? 0.0;
          final baseFareAmtInclTax = (fareData['BaseFareAmtInclTax'] as num?)?.toDouble() ?? 0.0;
          final seatsAvailable = fareData['SeatsAvailable'] ?? 0;
          final infantSeatsAvailable = fareData['InfantSeatsAvailable'] ?? 0;
          final hashCode = fareData['hashcode']?.toString() ?? '';
          final ruleId = fareData['RuleId']?.toString() ?? '';
          final fareCarrier = fareData['FareCarrier']?.toString() ?? 'FZ';

          final applicableTaxDetails = _extractArray(fareData['ApplicableTaxDetails']?['ApplicableTaxDetail']);

          paxIds.add(id);

          final List<Map<String, dynamic>> taxDetailsList = [];
          if (applicableTaxDetails != null) {
            final taxDetailsListRaw = applicableTaxDetails is List ? applicableTaxDetails : [applicableTaxDetails];

            for (int ap = 0; ap < taxDetailsListRaw.length; ap++) {
              final taxDetail = taxDetailsListRaw[ap];
              if (taxDetail is! Map) continue;

              final taxId = taxDetail['TaxID'];
              final amt = (taxDetail['Amt'] as num?)?.toDouble() ?? 0.0;
              final initiatingTaxId = taxDetail['InitiatingTaxID'];

              String taxCode = '';
              if (taxDetails != null) {
                final taxDetailsList = taxDetails is List ? taxDetails : [taxDetails];
                for (final tax in taxDetailsList) {
                  if (tax is Map && tax['TaxID'] == taxId) {
                    taxCode = tax['TaxCode']?.toString() ?? '';
                    break;
                  }
                }
              }

              taxDetailsList.add({
                'amt': amt,
                'taxCode': taxCode,
                'taxID': taxId,
              });
            }

          }

          paxFareInfos.add({
            'applicableTaxDetails': taxDetailsList,
            'fareID': fareId,
            'ID': id,
            'FBC': fbCode,
            'fareClass': fareClass,
            'cabin': cabin,
            'baseFare': originalFare,
            'ruleID': ruleId,
            'originalFare': originalFare,
            'totalFare': baseFareAmtInclTax,
            'PTC': ptcId,
            'seatAvailability': seatsAvailable,
            'infantAvailability': infantSeatsAvailable,
            'secureHash': hashCode,
            'fareCarrier': fareCarrier,
          });
        }
      }

      final List<Map<String, dynamic>> segmentDetailsList = [];
      if (flightLegDetail != null) {
        final flightLegDetailList = flightLegDetail is List ? flightLegDetail : [flightLegDetail];

        for (int j = 0; j < flightLegDetailList.length; j++) {
          final leg = flightLegDetailList[j];
          if (leg is! Map) continue;

          final pfid = leg['PFID'];
          final departureDate2 = leg['DepartureDate']?.toString() ?? '';

          // Get cabin from first fare info if available
          String cabin = 'ECONOMY';
          if (paxFareInfos.isNotEmpty) {
            cabin = paxFareInfos[0]['cabin'] ?? 'ECONOMY';
          }

          if (legDetails != null) {
            final legDetailsList = legDetails is List ? legDetails : [legDetails];

            for (final fld in legDetailsList) {
              if (fld is! Map) continue;

              final fldPfid = fld['PFID'];
              final fldDepartureDate = fld['DepartureDate']?.toString() ?? '';

              if (fldPfid == pfid && fldDepartureDate == departureDate2) {
                // Get fare class from first pax fare info
                String fareClass = 'Y';
                if (paxFareInfos.isNotEmpty) {
                  fareClass = paxFareInfos[0]['fareClass'] ?? 'Y';
                }

                final oaFlight = fld['OperatingCarrier']?.toString() != 'FZ';

                final effectivePaxIds = paxIds.isNotEmpty ? paxIds : ['1'];

                segmentDetailsList.add({
                  'segmentID': pfid,
                  'origin': fld['Origin'] ?? '',
                  'destination': fld['Destination'] ?? '',
                  'depDate': fld['DepartureDate'] ?? '',
                  'arrDate': fld['ArrivalDate'] ?? '',
                  'bookingCodes': [
                    {
                      'fareClass': fareClass,
                      'cabin': cabin,
                      'paxID': effectivePaxIds,
                    }
                  ],
                  'OAFlight': oaFlight,
                  'operCarrier': fld['OperatingCarrier'] ?? 'FZ',
                  'operFlightNum': fld['FlightNum'] ?? '',
                  'mrktCarrier': fld['MarketingCarrier'] ?? 'FZ',
                  'mrktFlightNum': fld['MarketingFlightNum'] ?? '',
                });
                break;
              }
            }
          }
        }
      }

      // Ensure we have at least one segment detail
      if (segmentDetailsList.isEmpty && segmentInfo.isNotEmpty) {
        // Create a basic segment detail from segment info
        segmentDetailsList.add({
          'segmentID': segmentInfo['odID'],
          'origin': segmentInfo['origin'],
          'destination': segmentInfo['destination'],
          'depDate': segmentInfo['depDate'],
          'arrDate': segmentInfo['depDate'], // Fallback to dep date
          'bookingCodes': [
            {
              'fareClass': 'Y',
              'cabin': 'ECONOMY',
              'paxID': paxIds.isNotEmpty ? paxIds : ['1'],
            }
          ],
          'OAFlight': false,
          'operCarrier': 'FZ',
          'operFlightNum': segmentInfo['flightNum'] ?? '',
          'mrktCarrier': 'FZ',
          'mrktFlightNum': segmentInfo['flightNum'] ?? '',
        });
      }

      originDestinations.add({
        ...segmentInfo,
        'fareBrand': [
          {
            'fareBrandID': fareTypeId,
            'fareBrandName': fareTypeName,
            'fareInfos': [
              {
                'paxFareInfos': paxFareInfos.isNotEmpty ? paxFareInfos : [
                  {
                    'applicableTaxDetails': [],
                    'fareID': 1,
                    'ID': '1',
                    'FBC': '',
                    'fareClass': 'Y',
                    'cabin': 'ECONOMY',
                    'baseFare': 0.0,
                    'ruleID': '',
                    'originalFare': 0.0,
                    'totalFare': 0.0,
                    'PTC': 1,
                    'seatAvailability': 0,
                    'infantAvailability': 0,
                    'secureHash': '',
                    'fareCarrier': 'FZ',
                  }
                ],
              }
            ],
          }
        ],
        'segmentDetails': segmentDetailsList,
      });
    }

    return {
      'currency': 'PKR',
      'IATA': '2730402T',
      'inventoryFilterMethod': 0,
      'securityGUID': '',
      'originDestinations': originDestinations.isNotEmpty ? originDestinations : [
        {
          'odID': 0,
          'origin': '',
          'destination': '',
          'flightNum': '',
          'depDate': '',
          'isPromoApplied': false,
          'fareBrand': [
            {
              'fareBrandID': 0,
              'fareBrandName': '',
              'fareInfos': [
                {
                  'paxFareInfos': [
                    {
                      'applicableTaxDetails': [],
                      'fareID': 0,
                      'ID': '1',
                      'FBC': '',
                      'fareClass': 'Y',
                      'cabin': 'ECONOMY',
                      'baseFare': 0.0,
                      'ruleID': '',
                      'originalFare': 0.0,
                      'totalFare': 0.0,
                      'PTC': 1,
                      'seatAvailability': 0,
                      'infantAvailability': 0,
                      'secureHash': '',
                      'fareCarrier': 'FZ',
                    }
                  ],
                }
              ],
            }
          ],
          'segmentDetails': [
            {
              'segmentID': 0,
              'origin': '',
              'destination': '',
              'depDate': '',
              'arrDate': '',
              'bookingCodes': [
                {
                  'fareClass': 'Y',
                  'cabin': 'ECONOMY',
                  'paxID': ['"1"'],
                }
              ],
              'OAFlight': false,
              'operCarrier': 'FZ',
              'operFlightNum': '',
              'mrktCarrier': 'FZ',
              'mrktFlightNum': '',
            }
          ],
        }
      ],
    };
  }

// Helper method to safely extract arrays from potentially different structures
  dynamic _extractArray(dynamic data) {
    if (data == null) return null;

    if (data is List) {
      return data;
    } else if (data is Map) {
      // If it's a map with numeric keys, convert to list
      if (data.keys.every((key) => key is String && int.tryParse(key) != null)) {
        final sortedKeys = data.keys.map((k) => int.parse(k)).toList()..sort();
        return sortedKeys.map((key) => data[key.toString()]).toList();
      }
      return data;
    }

    return [data];
  }


  double _extractUpdatedPrice(Map<String, dynamic> cartData) {
    try {
      final flightGroups = cartData['flightGroups'];
      if (flightGroups is List && flightGroups.isNotEmpty) {
        final fareBrands = flightGroups[0]['fareBrands'];
        if (fareBrands is List && fareBrands.isNotEmpty) {
          final fareInfos = fareBrands[0]['fareInfos'];
          if (fareInfos is List && fareInfos.isNotEmpty) {
            final paxFareInfos = fareInfos[0]['paxFareInfos'];
            if (paxFareInfos is List && paxFareInfos.isNotEmpty) {
              return paxFareInfos[0]['totalFare']?.toDouble() ?? 0.0;
            }
          }
        }
      }

      final originDestinations = cartData['originDestinations'];
      if (originDestinations is List && originDestinations.isNotEmpty) {
        final fareBrands = originDestinations[0]['fareBrands'];
        if (fareBrands is List && fareBrands.isNotEmpty) {
          final fareInfos = fareBrands[0]['fareInfos'];
          if (fareInfos is List && fareInfos.isNotEmpty) {
            final paxFareInfos = fareInfos[0]['paxFareInfos'];
            if (paxFareInfos is List && paxFareInfos.isNotEmpty) {
              return paxFareInfos[0]['totalFare']?.toDouble() ?? 0.0;
            }
          }
        }
      }

      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }



  Map<String, dynamic> _buildPNRRequest({
    required List<TravelerInfo> adults,
    required List<TravelerInfo> children,
    required List<TravelerInfo> infants,
    required String clientEmail,
    required String clientPhone,
    required String countryCode,
    required String simCode,
    required String city,
    required String flightType,
    required List<Map<String, dynamic>> segmentArray,
    required Map<String, dynamic> cartData,
    required String securityGuid,
  }) {
    try {
      final List<Map<String, dynamic>> passengers = [];
      int personId = 0;

      // Process adults
      for (int i = 0; i < adults.length; i++) {
        personId++;
        final adult = adults[i];
        final isPrimary = i == 0;

        // Calculate age
        final age = _calculateAge(adult.dateOfBirthController.text);

        // Normalize gender to API-expected string values
        String genderInput = adult.genderController.text.trim();
        final gender = (genderInput.isEmpty)
            ? "Male"
            : (genderInput.toLowerCase().startsWith('m') ? "Male" : (genderInput.toLowerCase().startsWith('f') ? "Female" : genderInput));

        // Get nationality code
        final nationality = adult.nationalityCountry.value?.countryCode ?? "PK";

        final passenger = {
          "PersonOrgID": -personId,
          "FirstName": _cleanName(adult.firstNameController.text),
          "LastName": _cleanName(adult.lastNameController.text),
          "MiddleName": "",
          "Age": age,
          "DOB": "${adult.dateOfBirthController.text}T00:00:00",
          "Gender": gender,
          "Title": adult.titleController.text,
          "NationalityLaguageID": 1,
          "RelationType": "Self",
          "WBCID": 1,
          "PTCID": 1, // Adult passenger type
          "TravelsWithPersonOrgID": -personId,
          "MarketingOptIn": true,
          "UseInventory": false,
          "Nationality": nationality,
          "ProfileId": -2147483648,
          "IsPrimaryPassenger": isPrimary,
          "DocumentInfos": [
            {
              "DocType": "1",
              "DocNumber": adult.passportCnicController.text,
              "IssuingCountry": nationality,
              "ExpiryDate": adult.passportExpiryController.text.isNotEmpty
                  ? adult.passportExpiryController.text  // No T00:00:00 suffix
                  : "2030-12-31"
            }
          ]
        };

        if (isPrimary) {
          passenger["Address"] = {
            "Address1": city.isNotEmpty ? city : "Home, Sweet Home",
            "Address2": city.isNotEmpty ? city : "Home, Sweet Home",
            "City": city.isNotEmpty ? city : "Islamabad",
            "State": "",
            "Postal": 12123233,  // Number, not string
            "Country": "PK",
            "CountryCode": countryCode,
            "AreaCode": "",
            "PhoneNumber": "",
            "Display": ""
          };

          passenger["ContactInfos"] = [
            {
              "Key": null,
              "ContactID": 0,
              "PersonOrgID": -1,
              "ContactField": "91123789000",
              "ContactType": 2,
              "Extension": "",
              "CountryCode": countryCode,
              "PhoneNumber": "$clientPhone",
              "Display": "",
              "PreferredContactMethod": false,
              "ValidatedContact": false
            },
            {
              "Key": null,
              "ContactID": 0,
              "PersonOrgID": -1,
              "ContactField": "911237890",
              "ContactType": 0,
              "Extension": "",
              "CountryCode": countryCode,
              "PhoneNumber": "$clientPhone",
              "Display": "",
              "PreferredContactMethod": false,
              "ValidatedContact": false
            },
            {
              "Key": null,
              "ContactID": 0,
              "PersonOrgID": -1,
              "ContactField": clientEmail,
              "ContactType": 4,
              "Extension": "",
              "CountryCode": countryCode,
              "PhoneNumber": "$clientPhone",
              "Display": "",
              "PreferredContactMethod": true,
              "ValidatedContact": false
            }
          ];
        } else {
          passenger["Address"] = {
            "Address1": "",
            "Address2": "",
            "City": "",
            "State": "",
            "Postal": 12123233,  // Number, not string
            "Country": "PK",
            "CountryCode": countryCode,
            "AreaCode": "",
            "PhoneNumber": "",
            "Display": ""
          };
          passenger["ContactInfos"] = [];
        }

        passengers.add(passenger);
      }

      // Process children
      for (int i = 0; i < children.length; i++) {
        personId++;
        final child = children[i];

        // Calculate age
        final age = _calculateAge(child.dateOfBirthController.text);

        // Normalize gender to API-expected string values
        String genderInput = child.genderController.text.trim();
        final gender = (genderInput.isEmpty)
            ? "Male"
            : (genderInput.toLowerCase().startsWith('m') ? "Male" : (genderInput.toLowerCase().startsWith('f') ? "Female" : genderInput));

        // Get nationality code
        final nationality = child.nationalityCountry.value?.countryCode ?? "PK";

        passengers.add({
          "PersonOrgID": -personId,
          "FirstName": _cleanName(child.firstNameController.text),
          "LastName": _cleanName(child.lastNameController.text),
          "MiddleName": "",
          "Age": age,
          "DOB": "${child.dateOfBirthController.text}T00:00:00",
          "Gender": gender,
          "Title": child.titleController.text,
          "NationalityLaguageID": 1,
          "RelationType": "Self",
          "WBCID": 1,
          "PTCID": 6, // Child passenger type
          "TravelsWithPersonOrgID": -1,
          "MarketingOptIn": true,
          "UseInventory": false,
          "Address": {
            "Address1": "",
            "Address2": "",
            "City": "",
            "State": "",
            "Postal": 12123233,  // Number, not string
            "Country": "PK",
            "CountryCode": countryCode,
            "AreaCode": "",
            "PhoneNumber": "",
            "Display": ""
          },
          "Nationality": nationality,
          "ProfileId": -2147483648,
          "IsPrimaryPassenger": false,
          "ContactInfos": [],
          "DocumentInfos": [
            {
              "DocType": "1",
              "DocNumber": child.passportCnicController.text,
              "IssuingCountry": nationality,
              "ExpiryDate": child.passportExpiryController.text.isNotEmpty
                  ? child.passportExpiryController.text  // No T00:00:00 suffix
                  : "2030-12-31"
            }
          ]
        });
      }

      // Process infants
      for (int i = 0; i < infants.length; i++) {
        personId++;
        final infant = infants[i];

        // Calculate age
        final age = _calculateAge(infant.dateOfBirthController.text);

        // Normalize gender to API-expected string values
        String genderInput = infant.genderController.text.trim();
        final gender = (genderInput.isEmpty)
            ? "Male"
            : (genderInput.toLowerCase().startsWith('m') ? "Male" : (genderInput.toLowerCase().startsWith('f') ? "Female" : genderInput));

        // Get nationality code
        final nationality = infant.nationalityCountry.value?.countryCode ?? "PK";

        // Infant travels with the first adult (index 0)
        final travelsWithId = -(1); // First adult has PersonOrgID -1

        passengers.add({
          "PersonOrgID": -personId,
          "FirstName": _cleanName(infant.firstNameController.text),
          "LastName": _cleanName(infant.lastNameController.text),
          "MiddleName": "",
          "Age": age,
          "DOB": "${infant.dateOfBirthController.text}T00:00:00",
          "Gender": gender,
          "Title": infant.titleController.text,
          "NationalityLaguageID": 1,
          "RelationType": "Self",
          "WBCID": 1,
          "PTCID": 5, // Infant passenger type
          "TravelsWithPersonOrgID": travelsWithId,
          "MarketingOptIn": true,
          "UseInventory": false,
          "Address": {
            "Address1": "",
            "Address2": "",
            "City": "",
            "State": "",
            "Postal": 12123233,  // Number, not string
            "Country": "PK",
            "CountryCode": countryCode,
            "AreaCode": "",
            "PhoneNumber": "",
            "Display": ""
          },
          "Nationality": nationality,
          "ProfileId": -2147483648,
          "IsPrimaryPassenger": false,
          "ContactInfos": [],
          "DocumentInfos": [
            {
              "DocType": "1",
              "DocNumber": infant.passportCnicController.text,
              "IssuingCountry": nationality,
              "ExpiryDate": infant.passportExpiryController.text.isNotEmpty
                  ? infant.passportExpiryController.text  // No T00:00:00 suffix
                  : "2030-12-31"
            }
          ]
        });
      }

      final List<Map<String, dynamic>> segments = _buildSegmentsFromArray(segmentArray);

      final formattedPhone = _cleanPhoneNumber(clientPhone);
      final formattedSimCode = _cleanPhoneNumber(simCode);

      String securityGuid = cartData['SecurityGuid'] ?? '';

      return {
        "ActionType": "GetSummary",
        "ReservationInfo": {
          "SeriesNumber": "299",
          "ConfirmationNumber": ""
        },
        "CarrierCodes": [
          {
            "AccessibleCarrierCode": "FZ"
          }
        ],
        "ClientIPAddress": "",
        "SecurityToken": "",  // Empty like web request
        "SecurityGUID": "",  // Empty like web request
        "HistoricUserName": username,
        "CarrierCurrency": "PKR",
        "DisplayCurrency": "PKR",
        "IATANum": "2730402T",
        "User": username,
        "ReceiptLanguageID": "1",
        "Address": {
          "Address1": city.isNotEmpty ? city : "Home, Sweet Home",
          "Address2": city.isNotEmpty ? city : "Home, Sweet Home",
          "City": city.isNotEmpty ? city : "Berlin",
          "Postal": "10967",
          "PhoneNumber": formattedPhone.isNotEmpty ? formattedPhone : "11172699999",
          "Country": "PK",
          "CountryCode": countryCode.isNotEmpty ? countryCode : "92",
          "State": "",
          "Display": ""
        },
        "ContactInfos": null,
        "Passengers": passengers,
        "Segments": segments,
        "Payments": []
      };
    } catch (e, stackTrace) {
      rethrow;
    }
  }

  // Enhanced segment builder for round trips
  List<Map<String, dynamic>> _buildSegmentsFromArray(List<Map<String, dynamic>> segmentArray) {
    final List<Map<String, dynamic>> segments = [];

    try {
      for (int i = 0; i < segmentArray.length; i++) {
        final segment = segmentArray[i];
        final paxId = segment['pax'] ?? 1;
        final fareId = segment['fareID'] ?? 1;
        final lfid = segment['lfid'];
        final extra = segment['extra'] as Map<String, dynamic>? ?? {};

        final fareInformationId = fareId is int ? fareId : int.tryParse(fareId.toString()) ?? 1;

        final specialServices = _buildSpecialServices(extra, paxId);
        final seats = _buildSeats(extra, paxId);

        final segmentData = {
          "PersonOrgID": -paxId,
          "FareInformationID": fareInformationId,
          "SpecialServices": specialServices,
          "Seats": seats
        };

        if (lfid != null) {
          segmentData["LogicalFlightID"] = lfid is int ? lfid : int.tryParse(lfid.toString()) ?? 0;
        }

        segments.add(segmentData);
      }
    } catch (e) {
    }

    if (segments.isEmpty) {
      for (int i = 0; i < segmentArray.length; i++) {
        segments.add({
          "PersonOrgID": -(i + 1),
          "FareInformationID": i + 1,
          "SpecialServices": [],
          "Seats": []
        });
      }
    }

    return segments;
  }

  // Helper method to clean phone number
  String _cleanPhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9]'), '');
  }

  List<Map<String, dynamic>> _buildSpecialServices(Map<String, dynamic> extra, int paxId) {
    final List<Map<String, dynamic>> services = [];

    try {
      if (extra['baggage'] != null && extra['baggage'].toString().isNotEmpty) {
        final baggageItems = extra['baggage'].toString().split('!!');
        if (baggageItems.length >= 7) {
          final depDate = baggageItems[2].contains('T')
              ? baggageItems[2]
              : "${baggageItems[2]}T00:00:00";

          services.add({
            "ServiceID": 1,
            "CodeType": baggageItems[0],
            "SSRCategory": 99,
            "LogicalFlightID": int.tryParse(baggageItems[1]) ?? 0,
            "DepartureDate": depDate,
            "Amount": double.tryParse(baggageItems[3]) ?? 0.0,
            "OverrideAmount": false,
            "CurrencyCode": baggageItems[4],
            "Commissionable": false,
            "Refundable": false,
            "ChargeComment": baggageItems[5],
            "PersonOrgID": -paxId,
            "AlreadyAdded": false,
            "PhysicalFlightID": int.tryParse(baggageItems[6]) ?? 0,
            "secureHash": ""
          });
        }
      }

      if (extra['meal'] is List) {
        for (final meal in extra['meal'] as List) {
          if (meal != null && meal.toString().isNotEmpty) {
            final mealItems = meal.toString().split('!!');
            if (mealItems.length >= 7) {
              final codeType = mealItems[0];
              final lfid = int.tryParse(mealItems[1]) ?? 0;
              final pfid = int.tryParse(mealItems[6]) ?? 0;
              String depDate = mealItems[2].contains('T')
                  ? mealItems[2]
                  : "${mealItems[2]}T00:00:00";

              if (depDate.contains('T')) {
                final datePart = depDate.split('T').first;
                depDate = '${datePart}T00:00:00';
              } else {
                depDate = '${depDate}T00:00:00';
              }

              services.add({
                "ServiceID": 1,
                "CodeType": codeType,
                "SSRCategory": 121,
                "LogicalFlightID": lfid,
                "DepartureDate": depDate,
                "Amount": double.tryParse(mealItems[3]) ?? 0.0,
                "OverrideAmount": false,
                "CurrencyCode": mealItems[4],
                "Commissionable": false,
                "Refundable": false,
                "ChargeComment": mealItems[5],
                "PersonOrgID": -paxId,
                "AlreadyAdded": false,
                "PhysicalFlightID": pfid,
                "secureHash": ""
              });
            }
          }
        }
      }
    } catch (e) {
    }

    return services;
  }
  List<Map<String, dynamic>> _buildSeats(Map<String, dynamic> extra, int paxId) {
    final List<Map<String, dynamic>> seats = [];

    try {
      if (extra['seat'] is List) {
        for (final seat in extra['seat'] as List) {
          if (seat != null && seat.toString().isNotEmpty) {
            final seatItems = seat.toString().split('!!');
            if (seatItems.length >= 9) {
              String depDate = seatItems[2];
              final lfid = int.tryParse(seatItems[1]) ?? 0;
              final pfid = int.tryParse(seatItems[6]) ?? 0;
              final seatNumber = seatItems[8];

              if (!depDate.contains('T')) {
                depDate = '${depDate}T00:00:00';
              }

              seats.add({
                "PersonOrgID": -paxId,
                "LogicalFlightID": lfid,
                "PhysicalFlightID": pfid,
                "DepartureDate": depDate,
                "SeatSelected": seatNumber,
                "RowNumber": seatItems[7]
              });
            }
          }
        }
      }
    } catch (e) {
    }

    return seats;
  }
// Helper method to calculate age from date of birth
  int _calculateAge(String dobString) {
    try {
      final dob = DateTime.parse(dobString);
      final now = DateTime.now();
      return now.year - dob.year - (now.month > dob.month || (now.month == dob.month && now.day >= dob.day) ? 0 : 1);
    } catch (e) {
      return 25; // Default age if parsing fails
    }
  }

  List<Map<String, dynamic>> _buildSegmentsFromCartData(
      Map<String, dynamic> cartData,
      int passengerCount,
      List<Map<String, dynamic>> segmentArray
      ) {
    final List<Map<String, dynamic>> segments = [];

    try {
      if (segmentArray.isNotEmpty) {
        for (final segment in segmentArray) {
          segments.add({
            "PersonOrgID": -(segment['pax'] ?? 1),
            "FareInformationID": segment['fareID'] ?? 1,
            "SpecialServices": segment['extra'] != null
                ? _buildSpecialServices(segment['extra'], segment['pax'] ?? 1)
                : [],
            "Seats": segment['extra'] != null
                ? _buildSeats(segment['extra'], segment['pax'] ?? 1)
                : []
          });
        }
      } else {
        final flightGroups = cartData['flightGroups'] as List?;
        if (flightGroups != null && flightGroups.isNotEmpty) {
          for (final flightGroup in flightGroups) {
            final fareBrands = flightGroup['fareBrands'] as List?;
            if (fareBrands != null && fareBrands.isNotEmpty) {
              for (final fareBrand in fareBrands) {
                final fareInfos = fareBrand['fareInfos'] as List?;
                if (fareInfos != null && fareInfos.isNotEmpty) {
                  for (final fareInfo in fareInfos) {
                    final paxFareInfos = fareInfo['paxFareInfos'] as List?;
                    if (paxFareInfos != null && paxFareInfos.isNotEmpty) {
                      for (int i = 0; i < paxFareInfos.length; i++) {
                        final paxFareInfo = paxFareInfos[i];
                        segments.add({
                          "PersonOrgID": -(i + 1),
                          "FareInformationID": paxFareInfo['fareID'] ?? 1,
                          "SpecialServices": [],
                          "Seats": []
                        });
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
    }

    if (segments.isEmpty) {
      for (int i = 0; i < passengerCount; i++) {
        segments.add({
          "PersonOrgID": -(i + 1),
          "FareInformationID": 1,
          "SpecialServices": [],
          "Seats": []
        });
      }
    }

    return segments;
  }



  Future<Map<String, dynamic>> getSeatOptions({
    required List<String> bookingIds,
    required Map<String, dynamic> flightData,
    bool printRequest = false,
    bool printResponse = false,
  }) async {
    try {
      if (_accessToken == null) {
        return {
          'success': false,
          'error': 'No valid token available. Please search flights first.',
        };
      }

      final requestBody = _buildSeatRequest(bookingIds, flightData);

      final response = await _apiClient.request(
        url: '$baseUrl/pricing/seats',
        method: HttpMethod.POST,
        serviceName: 'FLYDUBAI SEATS',
        body: json.encode(requestBody),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Cookie': 'visid_incap_3059742=mt0fc3JTQDStXbDmAKotlet1zGUAAAAAQUIPAAAAAAA/4nh9vwd+842orxzMj3FS',
        },
        contentType: ContentType.JSON,
        printRequestBody: printRequest,
        printResponseBody: printResponse,
      );

      if (response.isSuccess) {
        final Map<String, dynamic> responseData = json.decode(response.responseBody);
        return {
          'success': true,
          'data': responseData,
        };
      } else if (response.statusCode == 401) {
        _accessToken = null;
        _tokenExpiry = null;
        return {
          'success': false,
          'error': 'Token expired. Please search flights again.',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get seat options: ${response.statusCode}',
          'responseBody': response.responseBody,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to get seat options: $e',
      };
    }
  }  Future<Map<String, dynamic>> getBaggageOptions({
    required List<String> bookingIds,
    required Map<String, dynamic> flightData,
    bool printRequest = false,
    bool printResponse = false,
  }) async {
    try {
      if (_accessToken == null) {
        return {
          'success': false,
          'error': 'No valid token available. Please search flights first.',
        };
      }

      final requestBody = _buildBaggageRequest(bookingIds, flightData);

      final response = await _apiClient.request(
        url: '$baseUrl/offers/bags',
        method: HttpMethod.POST,
        serviceName: 'FLYDUBAI BAGGAGE',
        body: json.encode(requestBody),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Cookie': 'visid_incap_3059742=mt0fc3JTQDStXbDmAKotlet1zGUAAAAAQUIPAAAAAAA/4nh9vwd+842orxzMj3FS',
        },
        contentType: ContentType.JSON,
        printRequestBody: printRequest,
        printResponseBody: printResponse,
      );

      if (response.isSuccess) {
        final Map<String, dynamic> responseData = json.decode(response.responseBody);
        return {
          'success': true,
          'data': responseData,
        };
      } else if (response.statusCode == 401) {
        _accessToken = null;
        _tokenExpiry = null;
        return {
          'success': false,
          'error': 'Token expired. Please search flights again.',
        };
      }

      return {
        'success': false,
        'error': 'Failed to get baggage options: ${response.statusCode}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to get baggage options: $e',
      };
    }
  }

  Future<Map<String, dynamic>> getMealOptions({
    required List<String> bookingIds,
    required Map<String, dynamic> flightData,
    bool printRequest = false,
    bool printResponse = false,
  }) async {
    try {
      if (_accessToken == null) {
        return {
          'success': false,
          'error': 'No valid token available. Please search flights first.',
        };
      }

      final requestBody = _buildMealRequest(bookingIds, flightData);

      final response = await _apiClient.request(
        url: '$baseUrl/offers/mealsife',
        method: HttpMethod.POST,
        serviceName: 'FLYDUBAI MEALS',
        body: json.encode(requestBody),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Cookie': 'visid_incap_3059742=mt0fc3JTQDStXbDmAKotlet1zGUAAAAAQUIPAAAAAAA/4nh9vwd+842orxzMj3FS',
        },
        contentType: ContentType.JSON,
        printRequestBody: printRequest,
        printResponseBody: printResponse,
      );

      if (response.isSuccess) {
        final Map<String, dynamic> responseData = json.decode(response.responseBody);
        return {
          'success': true,
          'data': responseData,
        };
      } else if (response.statusCode == 401) {
        _accessToken = null;
        _tokenExpiry = null;
        return {
          'success': false,
          'error': 'Token expired. Please search flights again.',
        };
      }

      return {
        'success': false,
        'error': 'Failed to get meal options: ${response.statusCode}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to get meal options: $e',
      };
    }
  }
  Map<String, dynamic>
  _buildSeatRequest(List<String> bookingIds, Map<String, dynamic> flightData) {
    try {
      final bool isCartData = flightData.containsKey('originDestinations') &&
          !flightData.containsKey('RetrieveFareQuoteDateRangeResponse');

      dynamic segmentDetails;
      dynamic flightSegments;

      if (isCartData) {
        final originDests = flightData['originDestinations'];
        segmentDetails = _extractArray(originDests);
        flightSegments = null;
      } else {
        final retrieveResult = flightData['RetrieveFareQuoteDateRangeResponse']?['RetrieveFareQuoteDateRangeResult'];
        if (retrieveResult == null) {
          throw Exception('Invalid flight data structure');
        }

        segmentDetails = _extractArray(retrieveResult['SegmentDetails']?['SegmentDetail']);
        flightSegments = _extractArray(retrieveResult['FlightSegments']?['FlightSegment']);
      }

      final List<Map<String, dynamic>> flights = [];

      final Set<String> requestedLfids = {};
      for (final bkId in bookingIds) {
        final parts = bkId.split('_');
        if (parts.isNotEmpty) {
          requestedLfids.add(parts[0]);
        }
      }

      if (segmentDetails != null) {
        final segmentsList = segmentDetails is List ? segmentDetails : [segmentDetails];

        for (final segment in segmentsList) {
          if (segment is! Map) continue;

          final lfidNum = isCartData ? segment['odID'] : segment['LFID'];
          if (lfidNum == null) continue;

          final lfidString = lfidNum.toString();

          if (!requestedLfids.contains(lfidString)) continue;

          String depDate = isCartData ?
          (segment['depDate']?.toString() ?? '') :
          (segment['DepartureDate']?.toString() ?? '');
          String formattedDate;

          if (depDate.isEmpty) {
            formattedDate = '${DateTime.now().toIso8601String().substring(0, 10)}T00:00:00';
          } else {
            final datePart = depDate.split('T')[0];
            formattedDate = '${datePart}T00:00:00';
          }

          String sellingCarrier;
          String operatingCarrier;
          String flightNum;
          String origin;
          String dest;

          if (isCartData) {
            final segDetails = segment['segmentDetails'];
            final firstSeg = segDetails is List && segDetails.isNotEmpty ? segDetails[0] : null;

            operatingCarrier = firstSeg?['operCarrier']?.toString() ?? 'FZ';
            sellingCarrier = firstSeg?['mrktCarrier']?.toString() ?? 'FZ';
            flightNum = segment['flightNum']?.toString() ?? '';
            origin = segment['origin']?.toString() ?? '';
            dest = segment['destination']?.toString() ?? '';
          } else {
            sellingCarrier = segment['SellingCarrier']?.toString() ??
                segment['MarketingCarrier']?.toString() ?? 'FZ';
            operatingCarrier = segment['OperatingCarrier']?.toString() ?? 'FZ';
            flightNum = segment['FlightNum']?.toString() ?? '';
            origin = segment['Origin']?.toString() ?? '';
            dest = segment['Destination']?.toString() ?? '';
          }

          flights.add({
            'lfID': lfidString,
            'flightNum': flightNum,
            'depDate': formattedDate,
            'origin': origin,
            'dest': dest,
            'category': null,
            'services': null,
            'currency': 'PKR',
            'UTCOffset': 0,
            'operatingCarrierCode': operatingCarrier,
            'marketingCarrierCode': sellingCarrier,
            'channel': 'TPAPI'
          });
        }
      }

      if (flights.isEmpty && flightSegments != null) {
        final flightSegmentsList = flightSegments is List ? flightSegments : [flightSegments];

        for (final flightSegment in flightSegmentsList) {
          if (flightSegment is! Map) continue;

          final lfid = flightSegment['LFID']?.toString();
          if (lfid == null || lfid.isEmpty) continue;

          String depDate = flightSegment['DepartureDate']?.toString() ?? '';
          String formattedDate;

          if (depDate.isEmpty) {
            formattedDate = '${DateTime.now().toIso8601String().substring(0, 10)}T00:00:00';
          } else {
            final datePart = depDate.split('T')[0];
            formattedDate = '${datePart}T00:00:00';
          }

          final sellingCarrier = flightSegment['SellingCarrier']?.toString() ??
              flightSegment['MarketingCarrier']?.toString() ?? 'FZ';
          final operatingCarrier = flightSegment['OperatingCarrier']?.toString() ?? 'FZ';

          flights.add({
            'lfID': lfid,
            'flightNum': flightSegment['FlightNum']?.toString() ?? '',
            'depDate': formattedDate,
            'origin': flightSegment['Origin']?.toString() ?? '',
            'dest': flightSegment['Destination']?.toString() ?? '',
            'category': null,
            'services': null,
            'currency': 'PKR',
            'UTCOffset': 0,
            'operatingCarrierCode': operatingCarrier,
            'marketingCarrierCode': sellingCarrier,
            'channel': 'TPAPI'
          });
        }
      }

      if (flights.isEmpty) {
        throw Exception('No valid flight segments found in flight data');
      }

      return {
        'token': _accessToken,
        'flights': flights
      };

    } catch (e, stackTrace) {
      return {
        'token': _accessToken,
        'flights': [
          {
            'lfID': '0',
            'flightNum': '0',
            'depDate': '${DateTime.now().toIso8601String().substring(0, 10)}T00:00:00',
            'origin': 'DXB',
            'dest': 'KHI',
            'category': null,
            'services': null,
            'currency': 'PKR',
            'UTCOffset': 0,
            'operatingCarrierCode': 'FZ',
            'marketingCarrierCode': 'FZ',
            'channel': 'TPAPI'
          }
        ]
      };
    }
  }
  Map<String, dynamic> _buildBaggageMealRequest(
      List<String> bookingIds, Map<String, dynamic> flightData) {

    final bool isCartData = flightData.containsKey('originDestinations') &&
        !flightData.containsKey('RetrieveFareQuoteDateRangeResponse');

    dynamic basicArray;
    dynamic legDetails;
    dynamic segmentDetails;

    if (isCartData) {
      final originDests = flightData['originDestinations'];
      segmentDetails = _extractArray(originDests);
      basicArray = segmentDetails;
      legDetails = null;
    } else {
      final retrieveResult = flightData['RetrieveFareQuoteDateRangeResponse']?['RetrieveFareQuoteDateRangeResult'];
      if (retrieveResult == null) {
        throw Exception('Invalid flight data structure');
      }

      basicArray = _extractArray(retrieveResult['FlightSegments']?['FlightSegment']);
      legDetails = _extractArray(retrieveResult['LegDetails']?['LegDetail']);
      segmentDetails = _extractArray(retrieveResult['SegmentDetails']?['SegmentDetail']);
    }

    final List<Map<String, dynamic>> originDestinations = [];
    final Map<int, int> paxTypeCounts = {1: 0, 6: 0, 5: 0};
    bool hasProcessedPaxCounts = false;

    for (int i = 0; i < bookingIds.length; i++) {
      final bk = bookingIds[i];

      final bkIdArray = bk.split('_');
      if (bkIdArray.length < 2) {
        continue;
      }

      final requestedLfid = int.tryParse(bkIdArray[0]) ?? 0;
      final fare = int.tryParse(bkIdArray[1]) ?? 0;

      dynamic arrayStart;
      final String idKey = isCartData ? 'odID' : 'LFID';

      if (basicArray is List && basicArray.isNotEmpty) {
        for (var segment in basicArray) {
          if (segment is Map && segment[idKey] == requestedLfid) {
            arrayStart = segment;
            break;
          }
        }
        if (arrayStart == null) {
          arrayStart = basicArray[0];
        }
      } else if (basicArray is Map) {
        arrayStart = basicArray;
      }

      if (arrayStart == null) {
        continue;
      }

      final lfid1 = arrayStart[idKey];

      dynamic fareInfos;
      String fareTypeName = '';

      if (isCartData) {
        final fareBrands = _extractArray(arrayStart['fareBrand']);
        if (fareBrands != null) {
          final fareBrand = fareBrands is List ? fareBrands[0] : fareBrands;
          fareTypeName = fareBrand['fareBrandName']?.toString() ?? '';
          fareInfos = fareBrand['fareInfos'];
        }
      } else {
        final fareTypes = _extractArray(arrayStart['FareTypes']?['FareType']);

        if (fareTypes == null || (fareTypes is List && fare >= fareTypes.length)) {
          continue;
        }

        final fareArray = fareTypes is List ? fareTypes[fare] : fareTypes;
        fareTypeName = fareArray['FareTypeName']?.toString() ?? '';
        fareInfos = fareArray['FareInfos']?['FareInfo'];
      }

      fareInfos = _extractArray(fareInfos);
      final List<Map<String, dynamic>> paxFareDetails = [];
      final List<Map<String, dynamic>> legDetailList = [];

      Map<String, dynamic> segmentInfo = {};
      if (isCartData) {
        segmentInfo = {
          'origin': arrayStart['origin'] ?? '',
          'destination': arrayStart['destination'] ?? '',
          'departureDate': arrayStart['depDate'] ?? '',
        };
      } else {
        if (segmentDetails is List && segmentDetails.isNotEmpty) {
          for (final item in segmentDetails) {
            if (item is Map && item['LFID'] == lfid1) {
              segmentInfo = {
                'origin': item['Origin'] ?? '',
                'destination': item['Destination'] ?? '',
                'departureDate': item['DepartureDate'] ?? '',
              };
              break;
            }
          }
        }
      }

      // Build leg details based on data format
      dynamic bookingCodes;
      if (isCartData) {
        // Cart data has segmentDetails with bookingCodes
        final segDetails = _extractArray(arrayStart['segmentDetails']?['SegmentDetail'] ?? arrayStart['segmentDetails']);
        bookingCodes = segDetails;  // Will be handled differently below
      } else {
        // Search data has nested FareInfos with booking codes
        // Break down the nested access to avoid syntax issues
        dynamic fareInfoFirst = fareInfos is List && fareInfos.isNotEmpty ? fareInfos[0] : null;
        if (fareInfoFirst != null && fareInfoFirst is Map) {
          final paxArray = fareInfoFirst['Pax'];
          if (paxArray is List && paxArray.isNotEmpty) {
            final firstPax = paxArray[0];
            if (firstPax is Map) {
              final bookingCodesData = firstPax['BookingCodes'];
              if (bookingCodesData is Map) {
                bookingCodes = _extractArray(bookingCodesData['Bookingcode']);
              }
            }
          }
        }
      }
      if (bookingCodes != null) {
        final bookingCodesList = bookingCodes is List ? bookingCodes : [bookingCodes];

        if (isCartData) {
          // Cart data: bookingCodesList is actually segmentDetails
          for (final seg in bookingCodesList) {
            if (seg is! Map) continue;

            final segId = seg['segmentID'];
            final depDate = seg['depDate']?.toString() ?? '';

            legDetailList.add({
              'flightID': segId?.toString() ?? '',
              'board': seg['origin']?.toString() ?? '',
              'off': seg['destination']?.toString() ?? '',
              'depDateTime': depDate,
              'aircraftType': '73V',  // Default for FlyDubai
              'marketingFlt': {
                'carrier': seg['mrktCarrier']?.toString() ?? 'FZ',
                'fltNum': seg['mrktFlightNum']?.toString() ?? '',
              },
              'operatingFlt': {
                'carrier': seg['operCarrier']?.toString() ?? 'FZ',
                'fltNum': seg['operFlightNum']?.toString() ?? '',
              },
            });
          }
        } else {
          // Search data: match booking codes with leg details
          for (final bkcode in bookingCodesList) {
            if (bkcode is! Map) continue;

            if (legDetails != null) {
              final legDetailsList = legDetails is List ? legDetails : [legDetails];

              for (final leg in legDetailsList) {
                if (leg is! Map) continue;

                final pfid = leg['PFID'];
                final departureDate = leg['DepartureDate']?.toString() ?? '';
                final bkcodePfid = bkcode['PFID'];
                final bkcodeDepartureDate = bkcode['DepartureDate']?.toString() ?? '';

                if (pfid == bkcodePfid && departureDate == bkcodeDepartureDate) {
                  legDetailList.add({
                    'flightID': pfid?.toString() ?? '',
                    'board': leg['Origin']?.toString() ?? '',
                    'off': leg['Destination']?.toString() ?? '',
                    'depDateTime': departureDate,
                    'aircraftType': leg['EQP']?.toString() ?? 'B737',
                    'marketingFlt': {
                      'carrier': leg['MarketingCarrier']?.toString() ?? 'FZ',
                      'fltNum': leg['MarketingFlightNum']?.toString() ?? '',
                    },
                    'operatingFlt': {
                      'carrier': leg['OperatingCarrier']?.toString() ?? 'FZ',
                      'fltNum': leg['FlightNum']?.toString() ?? '',
                    },
                  });
                  break;
                }
              }
            }
          }
        }
      }

      // Build pax fare details based on data format
      if (fareInfos != null) {
        final fareInfosList = fareInfos is List ? fareInfos : [fareInfos];

        for (final fareInfo in fareInfosList) {
          if (fareInfo is! Map) continue;

          if (isCartData) {
            // Cart data has paxFareInfos directly
            final paxFareInfosList = _extractArray(fareInfo['paxFareInfos']);
            if (paxFareInfosList != null) {
              final paxFareInfos = paxFareInfosList is List ? paxFareInfosList : [paxFareInfosList];

              for (final paxFare in paxFareInfos) {
                if (paxFare is! Map) continue;

                // Only count passengers ONCE
                if (!hasProcessedPaxCounts) {
                  final int ptcId = (paxFare['PTC'] as num?)?.toInt() ?? 1;
                  paxTypeCounts.update(ptcId, (v) => v + 1, ifAbsent: () => 1);
                }

                paxFareDetails.add({
                  'fareClass': '',
                  'FBC': paxFare['FBC']?.toString() ?? '',
                  'pax': [1],
                  'baseFareAmt': paxFare['baseFare']?.toString() ?? '0',
                  'fareBrand': fareTypeName,
                  'cabin': paxFare['cabin']?.toString() ?? 'ECONOMY',
                });
              }
            }
          } else {
            // Search data has Pax array
            final paxList = _extractArray(fareInfo['Pax']);
            if (paxList == null || (paxList is List && paxList.isEmpty)) {
              continue;
            }

            final fareData = paxList is List ? paxList[0] : paxList;

            // Only count passengers ONCE (on first booking ID), not for each flight segment
            // For round trips, both flights have the same passengers
            if (!hasProcessedPaxCounts) {
              final int ptcId = (fareData['PTCID'] as num?)?.toInt() ?? 1;
              final int paxCount = (fareData['PaxCount'] as num?)?.toInt() ?? 1;
              paxTypeCounts.update(ptcId, (v) => v + paxCount, ifAbsent: () => paxCount);
            }

            paxFareDetails.add({
              'fareClass': '',
              'FBC': fareData['FBCode']?.toString() ?? '',
              'pax': [fareData['PaxCount'] ?? 1],
              'baseFareAmt': fareData['BaseFareAmt']?.toString() ?? '0',
              'fareBrand': fareTypeName,
              'cabin': fareData['Cabin']?.toString() ?? 'ECONOMY',
            });
          }
        }
      }

      // Mark that we've processed passenger counts
      hasProcessedPaxCounts = true;

      originDestinations.add({
        'lfID': lfid1?.toString() ?? '',
        'origin': segmentInfo['origin'] ?? '',
        'dest': segmentInfo['destination'] ?? '',
        'depDateTime': segmentInfo['departureDate'] ?? '',
        'legDetails': {
          'legDetail': legDetailList,
        },
        'paxFareDetails': paxFareDetails,
      });
    }

    // Build paxDetails array based on accumulated counts
    List<Map<String, dynamic>> paxDetailsArray = [];
    int paxIdCounter = 0;
    String _ptcString(int ptcId) {
      switch (ptcId) {
        case 1:
          return 'ADT';
        case 6:
          return 'CHD';
        case 5:
          return 'INF';
        default:
          return 'ADT';
      }
    }
    for (final entry in paxTypeCounts.entries) {
      final ptcId = entry.key;
      final count = entry.value;
      for (int i = 0; i < count; i++) {
        paxIdCounter++;
        paxDetailsArray.add({
          'paxID': paxIdCounter.toString(),
          'PTC': _ptcString(ptcId),
          'dob': '',
          'customerID': 12345,
          'tier': 12345,
        });
      }
    }

    final result = {
      'AncillaryPricingRequest': {
        'GUID': '',
        'saleInfo': {
          'POS': 'KW',
          'currency': 'PKR',
          'channel': 'TPAPI',
          'IATA': '2730402T',
        },
        'paxDetails': paxDetailsArray.isNotEmpty
            ? paxDetailsArray
            : [
          {
            'paxID': '1',
            'PTC': 'ADT',
            'dob': '',
            'customerID': 12345,
            'tier': 12345,
          }
        ],
        'journey': {
          'originDestination': originDestinations,
        },
      },
    };

    return result;
  }


  void _debugFlightDataStructure(Map<String, dynamic> flightData) {
    // Debug method - no-op in production
  }

// Alias for meal request (same structure as baggage)
  Map<String, dynamic> _buildMealRequest(List<String> bookingIds, Map<String, dynamic> flightData) {
    return _buildBaggageMealRequest(bookingIds, flightData);
  }

// Alias for baggage request
  Map<String, dynamic> _buildBaggageRequest(List<String> bookingIds, Map<String, dynamic> flightData) {
    return _buildBaggageMealRequest(bookingIds, flightData);
  }

  Map<String, dynamic>? _findSegmentByIndex(dynamic segmentDetails, int lfid) {
    if (segmentDetails == null) return null;

    if (segmentDetails is List) {
      try {
        for (var seg in segmentDetails) {
          if (seg is Map && seg["LFID"] == lfid) {
            return Map<String, dynamic>.from(seg);
          }
        }
        return null;
      } catch (e) {
        return null;
      }
    } else if (segmentDetails is Map) {
      if (segmentDetails["LFID"] == lfid) {
        return Map<String, dynamic>.from(segmentDetails);
      }
      return null;
    }

    return null;
  }





  // Recursively search for a Security GUID key in a nested response
  String? _findSecurityGuid(dynamic data) {
    try {
      if (data == null) return null;
      if (data is Map) {
        for (final entry in data.entries) {
          final key = entry.key.toString().toLowerCase();
          if (key.contains('securityguid') || key == 'guid') {
            final value = entry.value?.toString();
            if (value != null && value.isNotEmpty) return value;
          }
          final found = _findSecurityGuid(entry.value);
          if (found != null && found.isNotEmpty) return found;
        }
      } else if (data is List) {
        for (final item in data) {
          final found = _findSecurityGuid(item);
          if (found != null && found.isNotEmpty) return found;
        }
      }
    } catch (_) {}
    return null;
  }
  // Add this method to ApiServiceFlyDubai class
  String _cleanName(String name) {
    if (name.isEmpty) return name;

    // Remove special characters, numbers, and extra spaces
    String cleaned = name.replaceAll(RegExp(r'[^a-zA-Z\s]'), '');

    // Remove multiple spaces and trim
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Capitalize first letter of each word
    cleaned = cleaned.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');

    return cleaned;
  }

  // Save FlyDubai booking to company portal
  Future<Map<String, dynamic>> saveFlyDubaiBooking({
    required List<TravelerInfo> adults,
    required List<TravelerInfo> children,
    required List<TravelerInfo> infants,
    required String clientEmail,
    required String clientPhone,
    required Map<String, dynamic> pnrResponse,
    required List<Map<String, dynamic>> segmentArray,
    required Map<String, dynamic> cartData,
    required String flightType,
  }) async {
    try {
      final totalPrice = _extractTotalPriceFromCartData(cartData);
      
      // Prepare booking info
      final bookingInfo = {
        "bfname": adults.isNotEmpty ? adults[0].firstNameController.text : "",
        "blname": adults.isNotEmpty ? adults[0].lastNameController.text : "",
        "bemail": clientEmail,
        "bphno": clientPhone,
        "badd": "b",
        "bcity": "a",
        "final_price": totalPrice.toString(),
        "client_email": clientEmail,
        "client_phone": clientPhone,
      };

      // Prepare adults data
      final adultsData = adults.map((adult) {
        return {
          "title": adult.titleController.text,
          "first_name": adult.firstNameController.text,
          "last_name": adult.lastNameController.text,
          "dob": adult.dateOfBirthController.text,
          "nationality": adult.nationalityCountry.value?.countryCode ?? 'PK',
          "passport": adult.passportCnicController.text,
          "passport_expiry": adult.passportExpiryController.text,
          "cnic": adult.passportCnicController.text,
        };
      }).toList();

      // Prepare children data
      final childrenData = children.map((child) {
        return {
          "title": child.titleController.text,
          "first_name": child.firstNameController.text,
          "last_name": child.lastNameController.text,
          "dob": child.dateOfBirthController.text,
          "nationality": child.nationalityCountry.value?.countryCode ?? 'PK',
          "passport": child.passportCnicController.text,
          "passport_expiry": child.passportExpiryController.text,
          "cnic": child.passportCnicController.text,
        };
      }).toList();

      // Prepare infants data
      final infantsData = infants.map((infant) {
        return {
          "title": infant.titleController.text,
          "first_name": infant.firstNameController.text,
          "last_name": infant.lastNameController.text,
          "dob": infant.dateOfBirthController.text,
          "nationality": infant.nationalityCountry.value?.countryCode ?? 'PK',
          "passport": "a",
          "passport_expiry": "a",
          "cnic": "a",
        };
      }).toList();

      final flights = await _prepareFlyDubaiFlightData(cartData, flightType);

      final pnrStatus = pnrResponse['success'] == true ? 1 : 0;
      final pnr = pnrResponse['confirmationNumber']?.toString() ?? 
                  pnrResponse['pnr']?.toString() ?? '';

      final requestBody = {
        "booking_info": bookingInfo,
        "adults": adultsData,
        "children": childrenData,
        "infants": infantsData,
        "flights": flights,
        "pnr": pnr,
        "buyingPrice": totalPrice.toStringAsFixed(0),
        "sellingPrice": totalPrice.toStringAsFixed(0),
        "pnrStatus": pnrStatus,
        "booking_from": "1",
        "gds": "flydubai"
      };

      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://readyflights.pk/api/',
          headers: {
            'Content-Type': 'application/json',
            // Note: Token should be passed from the calling context if needed
            // 'Authorization': 'Bearer $token',
          },
          responseType: ResponseType.json,
        ),
      );

      final response = await dio.post('flight-booking', data: requestBody);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is Map<String, dynamic>) {
          return response.data;
        } else if (response.data is String) {
          return jsonDecode(response.data) as Map<String, dynamic>;
        }
        return {'status': 'success'};
      } else {
        throw Exception('Failed to save booking: ${response.statusMessage}');
      }
    } catch (e, stackTrace) {
      return {
        'success': false,
        'error': 'Error saving booking: ${e.toString()}',
      };
    }
  }

  // Helper method to extract total price from cart data
  double _extractTotalPriceFromCartData(Map<String, dynamic> cartData) {
    try {
      // Try multiple paths for total price
      final flightGroups = cartData['flightGroups'] as List?;
      if (flightGroups != null && flightGroups.isNotEmpty) {
        double total = 0.0;
        for (var group in flightGroups) {
          if (group is Map) {
            final fareBrands = group['fareBrands'] as List?;
            if (fareBrands != null && fareBrands.isNotEmpty) {
              for (var fareBrand in fareBrands) {
                if (fareBrand is Map) {
                  final fareInfos = fareBrand['fareInfos'] as List?;
                  if (fareInfos != null && fareInfos.isNotEmpty) {
                    for (var fareInfo in fareInfos) {
                      if (fareInfo is Map) {
                        final paxFareInfos = fareInfo['paxFareInfos'] as List?;
                        if (paxFareInfos != null) {
                          for (var paxFare in paxFareInfos) {
                            if (paxFare is Map) {
                              final totalFare = (paxFare['totalFare'] as num?)?.toDouble() ?? 0.0;
                              total += totalFare;
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
        if (total > 0) return total;
      }

      // Alternative path
      final originDestinations = cartData['originDestinations'] as List?;
      if (originDestinations != null && originDestinations.isNotEmpty) {
        double total = 0.0;
        for (var od in originDestinations) {
          if (od is Map) {
            final fareBrands = od['fareBrand'] as List?;
            if (fareBrands != null) {
              for (var fareBrand in fareBrands) {
                if (fareBrand is Map) {
                  final fareInfos = fareBrand['fareInfos'] as List?;
                  if (fareInfos != null && fareInfos.isNotEmpty) {
                    for (var fareInfo in fareInfos) {
                      if (fareInfo is Map) {
                        final paxFareInfos = fareInfo['paxFareInfos'] as List?;
                        if (paxFareInfos != null) {
                          for (var paxFare in paxFareInfos) {
                            if (paxFare is Map) {
                              final totalFare = (paxFare['totalFare'] as num?)?.toDouble() ?? 0.0;
                              total += totalFare;
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
        if (total > 0) return total;
      }
    } catch (e) {
    }
    return 0.0;
  }

  // Fetch airline data from API (similar to Sabre)
  Future<Map<String, AirlineInfo>> _fetchAirlineData() async {
    if (_airlineMap != null) {
      return _airlineMap!;
    }

    Map<String, AirlineInfo> tempAirlineMap = {};

    try {
      var response = await _dioForAirline.request(
        'https://agent1.pk/api.php?type=airlines',
        options: Options(
          method: 'GET',
        ),
      );

      if (response.statusCode == 200) {
        var data = response.data['data'];
        for (var item in data) {
          String logoUrl = item['logo'];
          logoUrl = logoUrl.replaceAll(RegExp(r'^\t+'), '');
          
          tempAirlineMap[item['code']] = AirlineInfo(
            item['name'],
            logoUrl,
          );
        }
        _airlineMap = tempAirlineMap;
      }
    } catch (e) {
    }

    return tempAirlineMap;
  }

  // Helper method to get airline name from carrier code using API
  Future<String> _getAirlineNameFromCode(String carrierCode) async {
    final airlineMap = await _fetchAirlineData();
    final airlineInfo = getAirlineInfo(carrierCode.toUpperCase(), airlineMap);
    return airlineInfo.name;
  }

  // Helper method to prepare FlyDubai flight data
  Future<List<Map<String, dynamic>>> _prepareFlyDubaiFlightData(Map<String, dynamic> cartData, String flightType) async {
    final flights = <Map<String, dynamic>>[];

    try {
      final originDestinations = cartData['originDestinations'] as List?;
      if (originDestinations == null || originDestinations.isEmpty) {
        return flights;
      }

      for (int i = 0; i < originDestinations.length; i++) {
        final od = originDestinations[i];
        if (od is! Map) continue;

        final segmentDetails = od['segmentDetails'] as List?;
        if (segmentDetails == null || segmentDetails.isEmpty) continue;

        for (var segment in segmentDetails) {
          if (segment is! Map) continue;

          final origin = segment['origin']?.toString() ?? '';
          final destination = segment['destination']?.toString() ?? '';
          final depDate = segment['depDate']?.toString() ?? '';
          final arrDate = segment['arrDate']?.toString() ?? '';
          final mrktCarrier = segment['mrktCarrier']?.toString() ?? 'FZ';
          final mrktFlightNum = segment['mrktFlightNum']?.toString() ?? '';
          final operCarrier = segment['operCarrier']?.toString() ?? 'FZ';
          final operFlightNum = segment['operFlightNum']?.toString() ?? '';

          // Get airline names from carrier codes using API
          final marketingAirlineName = await _getAirlineNameFromCode(mrktCarrier);
          final operatingAirlineName = await _getAirlineNameFromCode(operCarrier);

          // Parse dates
          DateTime? depDateTime;
          DateTime? arrDateTime;
          try {
            depDateTime = DateTime.parse(depDate);
          } catch (e) {
            try {
              depDateTime = DateTime.parse(depDate.split('T')[0]);
            } catch (_) {}
          }
          try {
            arrDateTime = DateTime.parse(arrDate);
          } catch (e) {
            try {
              arrDateTime = DateTime.parse(arrDate.split('T')[0]);
            } catch (_) {}
          }

          if (depDateTime == null || arrDateTime == null) continue;

          final duration = arrDateTime.difference(depDateTime);

          // Get cabin class from booking codes
          String cabinClass = 'Economy';
          String cabinCode = 'Y';
          final bookingCodes = segment['bookingCodes'] as List?;
          if (bookingCodes != null && bookingCodes.isNotEmpty) {
            final firstBookingCode = bookingCodes[0];
            if (firstBookingCode is Map) {
              cabinCode = firstBookingCode['cabin']?.toString() ?? 'ECONOMY';
              cabinClass = _getCabinClassName(cabinCode);
            }
          }

          flights.add({
            "departure": {
              "airport": origin,
              "city": origin,
              "date": depDateTime.toIso8601String().split('T')[0],
              "time": "${depDateTime.hour.toString().padLeft(2, '0')}:${depDateTime.minute.toString().padLeft(2, '0')}",
              "terminal": "Main",
            },
            "arrival": {
              "airport": destination,
              "city": destination,
              "date": arrDateTime.toIso8601String().split('T')[0],
              "time": "${arrDateTime.hour.toString().padLeft(2, '0')}:${arrDateTime.minute.toString().padLeft(2, '0')}",
              "terminal": "Main",
            },
            "flight_number": mrktFlightNum,
            "airline_code": mrktCarrier,
            "airline_name": marketingAirlineName,
            "operating_flight_number": operFlightNum,
            "operating_airline_code": operCarrier,
            "operating_airline_name": operatingAirlineName,
            "cabin_class": cabinClass,
            "sub_class": cabinCode,
            "booking_class": cabinCode,
            "hand_baggage": "7kg",
            "check_baggage": "20kg", // Default for FlyDubai
            "meal": "Meal",
            "layover": flights.isNotEmpty ? "Yes" : "None",
            "duration": "${duration.inHours}h ${duration.inMinutes.remainder(60)}m",
            "duration_minutes": duration.inMinutes,
            "type": i == 0 ? (flightType == 'roundtrip' ? "One-Way" : "One-Way") : "Return",
            "fare_basis": "",
            "seats_available": "",
            "is_refundable": true,
            "aircraft_type": "B737",
          });
        }
      }
    } catch (e, stackTrace) {
    }

    return flights;
  }

  String _getCabinClassName(String cabinCode) {
    switch (cabinCode.toUpperCase()) {
      case 'F':
        return 'First Class';
      case 'C':
      case 'J':
        return 'Business Class';
      case 'W':
      case 'S':
        return 'Premium Economy';
      case 'Y':
      case 'ECONOMY':
      default:
        return 'Economy';
    }
  }
}
