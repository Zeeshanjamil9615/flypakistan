import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../views/flight/booking_flight/booking_flight_controller.dart';

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

  // Authenticate with FlyDubai API
  Future<bool> authenticate() async {
    try {
      print('Authenticating with FlyDubai API...');
      final String bodyString = 'client_id=$clientId&client_secret=$clientSecret&grant_type=password&password=${Uri.encodeComponent(password)}&scope=res&username=$username';

      final response = await http.post(
        Uri.parse('$baseUrl/authenticate'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Cookie': 'visid_incap_3059742=mt0fc3JTQDStXbDmAKotlet1zGUAAAAAQUIPAAAAAAA/4nh9vwd+842orxzMj3FS',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
        body: bodyString,
      );

      print('FlyDubai Auth Response Status: ${response.statusCode}');
      print('FlyDubai Auth Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> tokenData = json.decode(response.body);
        if (tokenData.containsKey('access_token')) {
          _accessToken = tokenData['access_token'];

          // Set token expiry (assuming 1 hour expiration, adjust if API provides expires_in)
          _tokenExpiry = DateTime.now().add(Duration(hours: 1));

          print('✅ FlyDubai Authentication successful');
          print('🔐 NEW Token: $_accessToken');
          print('🔐 NEW Token hash: ${_accessToken?.hashCode}');
          print('⏰ Token expires at: $_tokenExpiry');
          return true;
        }
      }

      print('FlyDubai Authentication failed');
      return false;
    } catch (e) {
      print('FlyDubai Authentication error: $e');
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
    print("Acces Token fly dubai");
    print(_accessToken);
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
  }) async {
    try {
      // print('=== FLYDUBAI API SEARCH STARTED ===');
      // print('Trip Type: $type (${_getTripTypeName(type)})');
      // print('Raw depDate: "$depDate"');

      // Only authenticate here if no valid token exists
      if (_accessToken == null || _isTokenExpired()) {
        print('🔄 Token is null or expired, authenticating...');
        final authSuccess = await authenticate();
        if (!authSuccess) {
          return {
            'error': 'FlyDubai authentication failed',
            'flights': [],
            'success': false
          };
        }
      } else {
        print('✅ Using existing valid token (hash: ${_accessToken?.hashCode})');
      }



      // Rest of the searchFlights method remains the same...
      Map<String, dynamic>? searchParams;

      if (type == 2 && multiCitySegments != null && multiCitySegments.isNotEmpty) {
        // Multi-city search
        print('Processing multi-city search with ${multiCitySegments.length} segments');
        searchParams = _buildMultiCityRequest(
          segments: multiCitySegments,
          passengers: adult + child + infant,
          cabin: cabin,
        );
      } else if (type == 1) {
        // Round-trip search
        print('Processing round-trip search');

        // Parse dates - handle different possible formats
        List<String> datesList = [];

        if (depDate.contains(',')) {
          datesList = depDate.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
        } else {
          // If no comma, might be a single date - this shouldn't happen for round-trip
          datesList = [depDate.trim()];
        }

        print("Date parsing - split result: $datesList");

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

          print("Successfully parsed dates - Outbound: $outboundDate, Return: $returnDate");

          searchParams = _buildRoundTripRequest(
            origin: origin.trim(),
            destination: destination.trim(),
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
        print('Processing one-way search');
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

      print("Using access token in search flight: $_accessToken");
      printJsonPretty(json.encode(searchParams));
      // Make API request
      final response = await http.post(
        Uri.parse('$baseUrl/pricing/flightswithfares'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
          'Cookie': 'visid_incap_3059742=mt0fc3JTQDStXbDmAKotlet1zGUAAAAAQUIPAAAAAAA/4nh9vwd+842orxzMj3FS',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
        body: json.encode(searchParams),
      );

      print('FlyDubai Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        print("++++++++++++++++++Fly Dubai Response ++++++++++++++++++");
        printJsonPretty(responseData);
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
          );
        }
      }

      return {
        'error': 'FlyDubai API returned status: ${response.statusCode}',
        'flights': [],
        'success': false
      };

    } catch (e) {
      print('FlyDubai API search error: $e');
      return {
        'error': 'FlyDubai search failed: $e',
        'flights': [],
        'success': false
      };
    }
  }

  // Add to cart function - uses existing token, doesn't authenticate
// Update the addToCart method in ApiServiceFlyDubai
  Future<Map<String, dynamic>> addToCart({
    required List<String> bookingIds,
    required Map<String, dynamic> flightData,
  }) async {
    try {
      // Use existing token, don't authenticate here
      if (_accessToken == null) {
        return {
          'success': false,
          'error': 'No valid token available. Please search flights first.',
          'details': 'Authentication required before adding to cart'
        };
      }

      final tokenToUse = _accessToken;
      // print("🔐 Using access token in ADD TO CART: $tokenToUse");
      // print("🔐 Token hash: ${tokenToUse?.hashCode}");
      //
      // print('=== FLYDUBAI ADD TO CART STARTED ===');
      // print('Booking IDs: $bookingIds');

      // Parse the flight data and build the request
      final requestBody = _buildAddToCartRequest(bookingIds, flightData);

      // print("+++++++++++++++++++Add to cart Request+++++++++++++++++++++++");
      // printJsonPretty(requestBody);

      final response = await http.post(
        Uri.parse('$baseUrl/order/cart'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
          'Cookie': 'visid_incap_3059742=mt0fc3JTQDStXbDmAKotlet1zGUAAAAAQUIPAAAAAAA/4nh9vwd+842orxzMj3FS',
          'Accept-Encoding': 'gzip, deflate',
        },
        body: json.encode(requestBody),
      );

      // print("+++++++++++++++++++Add to cart Response+++++++++++++++++++++++");
      // print('Add to Cart Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        print('Add to Cart successful');

        // Extract Security GUID for round trips
        final securityGuid = _extractSecurityGuid(responseData);
        print('Extracted Security GUID: $securityGuid');

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
          'response': response.body,
        };
      }

      return {
        'success': false,
        'error': 'Add to Cart failed with status: ${response.statusCode}',
        'response': response.body,
      };
    } catch (e) {
      print('Add to Cart error: $e');
      return {
        'success': false,
        'error': 'Add to Cart failed: $e',
      };
    }
  }

// Enhanced Security GUID extraction
  String? _extractSecurityGuid(Map<String, dynamic> cartData) {
    try {
      // Try multiple possible paths for Security GUID (check uppercase first as it appears in response)
      String? securityGuid = cartData['SecurityGUID'] ??  // All uppercase - appears in cart response!
          cartData['SecurityGuid'] ??
          cartData['securityGUID'] ??
          cartData['securityGuid'];

      if (securityGuid != null && securityGuid.isNotEmpty) {
        return securityGuid;
      }

      // Deep search in nested structures
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

      // Search in originDestinations
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
      print('Error extracting Security GUID: $e');
      return null;
    }
  }
// Create PNR - uses existing token, doesn't authenticate
  // Update the createPNR method in ApiServiceFlyDubai
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
  }) async {
    try {
      if (_accessToken == null) {
        return {
          'success': false,
          'error': 'No valid token available. Please search flights first.',
          'details': 'Authentication required before creating PNR'
        };
      }

      // print('=== CREATING PNR FOR FLYDUBAI ===');
      // print('Flight Type: $flightType');
      // print('Using access token: $_accessToken');

      if (cartData.isEmpty) {
        return {
          'success': false,
          'error': 'Invalid cart data. Please add flights to cart first.',
          'details': 'Cart data is required for PNR creation'
        };
      }

      // For round trips, ensure we have a valid Security GUID
      String securityGuid = '';
      // if (flightType == 'roundtrip') {
      //   securityGuid = _extractSecurityGuid(cartData) ?? '';
      //   if (securityGuid.isEmpty) {
      //     return {
      //       'success': false,
      //       'error': 'Security GUID is required for round trip bookings but was not found in cart data.',
      //       'details': 'Please try adding flights to cart again'
      //     };
      //   }
      //   print('✅ Using Security GUID for round trip: $securityGuid');
      // }

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
        securityGuid: securityGuid, // Pass the security GUID
      );
      // print("the token is $_accessToken");
      // print('PNR Request Body:');
      // printJsonPretty(requestBody);
      // print("the token is $_accessToken");


      final response = await http.post(
        Uri.parse('$baseUrl/cp/summaryPNR?accural=true'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
          'Accept-Encoding': 'gzip, deflate',
        },
        body: json.encode(requestBody),

      );

      // print('PNR Creation Response Status: ${response.statusCode}');
      // print('PNR Creation Response Body:');
      // printJsonPretty(response.body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final seriesNumber = responseData['SeriesNumber']?.toString();

        if (seriesNumber == null || seriesNumber.isEmpty) {
          return {
            'success': false,
            'error': 'Missing SeriesNumber in PNR creation response',
            'rawResponse': responseData,
          };
        }

        print('✅ PNR created (Summary). SeriesNumber: $seriesNumber');
        print('--- COMMITTING PNR NOW ---');

        // Build commit request body
        final commitRequest = {
          "ActionType": "CommitSummary",
          "ReservationInfo": {
            "SeriesNumber": seriesNumber,
            "ConfirmationNumber": null
          },
          "SecurityGUID":  "$_accessToken",
          "CarrierCodes": [
            {"AccessibleCarrierCode": "FZ"}
          ],
          "ClientIPAddress": "",
          "HistoricUserName": username
        };

        final commitResponse = await http.post(
          Uri.parse('$baseUrl/cp/commitPNR?accrual=true'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_accessToken',
            'Accept-Encoding': 'gzip, deflate',
          },
          body: json.encode(commitRequest),
        );

        print('CommitPNR Response Status: ${commitResponse.statusCode}');
        // print('CommitPNR Response Body:');
        // printJsonPretty(commitResponse.body);

        if (commitResponse.statusCode == 200) {
          final commitData = json.decode(commitResponse.body);
          final confirmationNumber =
              commitData['ReservationInfo']?['ConfirmationNumber'] ??
                  commitData['ConfirmationNumber'] ??
                  commitData['reservationInfo']?['confirmationNumber'] ??
                  commitData['confirmationNumber'];

          print('✅ Final PNR Confirmation Number: $confirmationNumber');

          return {
            'success': true,
            'data': responseData,
            'commitData': commitData,
            'confirmationNumber': confirmationNumber,
            'message': 'PNR created and committed successfully',
          };
        } else {
          return {
            'success': false,
            'error': 'Commit PNR failed',
            'response': commitResponse.body,
            'statusCode': commitResponse.statusCode,
          };
        }
      } else if (response.statusCode == 401) {
        _accessToken = null;
        _tokenExpiry = null;
        return {
          'success': false,
          'error': 'Token expired. Please search flights again to get a new token.',
          'response': response.body,
        };
      } else {
        final errorResponse = json.decode(response.body);
        final errorMessage = errorResponse['errorMessage'] ??
            errorResponse['Message'] ??
            errorResponse['error'] ??
            errorResponse['Exception'] ??
            'PNR creation failed with status: ${response.statusCode}';



        return {
          'success': false,
          'error': errorMessage,
          'response': response.body,
          'statusCode': response.statusCode,
        };
      }
    } catch (e, stackTrace) {
      print('❌ PNR creation error: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'error': 'PNR creation failed: $e',
        'stackTrace': stackTrace.toString(),
      };
    }
  }
  // Revalidate flight pricing - uses existing token, doesn't authenticate
  Future<Map<String, dynamic>> revalidateFlight({
    required String bookingId,
    required Map<String, dynamic> flightData,
  }) async {
    try {
      // Use existing token, don't authenticate here
      if (_accessToken == null) {
        return {
          'success': false,
          'error': 'No valid token available. Please search flights first.',
          'details': 'Authentication required before revalidation'
        };
      }

      // For FlyDubai, revalidation is typically done through addToCart
      final result = await addToCart(
        bookingIds: [bookingId],
        flightData: flightData,
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
      print('Revalidation error: $e');
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
    print('Building one-way request: $origin -> $destination on ${outboundDate.toIso8601String()}');

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
    print('Building round-trip request: $origin -> $destination on ${outboundDate.toIso8601String()}, return on ${returnDate.toIso8601String()}');

    // PASSENGER ARRAY BUILDING - Similar to PHP version
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
    print('Building multi-city request with ${segments.length} segments');

    final List<Map<String, dynamic>> fareQuoteDetails = [];

    for (var segment in segments) {
      final departureDate = DateTime.parse(segment['date']!);
      print('Adding segment: ${segment['from']} -> ${segment['to']} on ${segment['date']}');

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



// Build add to cart request
  Map<String, dynamic> _buildAddToCartRequest(
      List<String> bookingIds, Map<String, dynamic> flightData) {

    // Safely extract nested data with proper null checks
    final retrieveResult = flightData['RetrieveFareQuoteDateRangeResponse']?['RetrieveFareQuoteDateRangeResult'];
    if (retrieveResult == null) {
      throw Exception('Invalid flight data structure: Missing RetrieveFareQuoteDateRangeResult');
    }

    // Handle different possible structures for these arrays
    final basicArray = _extractArray(retrieveResult['FlightSegments']?['FlightSegment']);
    final legDetails = _extractArray(retrieveResult['LegDetails']?['LegDetail']);
    final segmentDetails = _extractArray(retrieveResult['SegmentDetails']?['SegmentDetail']);
    final taxDetails = _extractArray(retrieveResult['TaxDetails']?['TaxDetail']);

    final List<Map<String, dynamic>> originDestinations = [];

    for (int i = 0; i < bookingIds.length; i++) {
      final bk = bookingIds[i];
      final bkIdArray = bk.split('_');

      if (bkIdArray.length < 2) {
        print('Invalid booking ID format: $bk');
        continue;
      }

      final requestedLfid = int.tryParse(bkIdArray[0]) ?? 0;  // This is LFID, not array index
      final requestedFareId = int.tryParse(bkIdArray[1]) ?? 0;  // This is FareID, not array index

      print('🔍 Looking for LFID: $requestedLfid with FareID: $requestedFareId in flight segments');

      // Find the flight segment with matching LFID (not using LFID as array index!)
      dynamic arrayStart;
      if (basicArray is List && basicArray.isNotEmpty) {
        // Search for the segment with matching LFID
        for (var segment in basicArray) {
          if (segment is Map && segment['LFID'] == requestedLfid) {
            arrayStart = segment;
            print('✅ Found segment with LFID: $requestedLfid');
            break;
          }
        }
        if (arrayStart == null) {
          print('⚠️ No segment found with LFID: $requestedLfid, using first segment as fallback');
          arrayStart = basicArray[0];
        }
      } else if (basicArray is Map) {
        arrayStart = basicArray;
      }

      if (arrayStart == null) {
        print('❌ No flight segment found for booking ID: $bk');
        continue;
      }

      final lfid1 = arrayStart['LFID'];
      print('📌 Using segment with LFID: $lfid1 for booking ID: $bk');
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

      // Safely access fare types and search by FareID
      final fareTypes = _extractArray(arrayStart['FareTypes']?['FareType']);
      print('   Available fare types count: ${fareTypes is List ? fareTypes.length : 1}');

      if (fareTypes == null) {
        print('❌ No fare types found for booking ID: $bk');
        continue;
      }

      // Search for the fare type with matching FareID
      dynamic fareArray;
      if (fareTypes is List) {
        for (var fareType in fareTypes) {
          if (fareType is Map) {
            // Get the FareID from the first Pax in the first FareInfo
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
        print('❌ No fare type found with FareID: $requestedFareId for booking ID: $bk');
        continue;
      }

      final fareTypeId = fareArray['FareTypeID'];
      final fareTypeName = fareArray['FareTypeName'];

      print('   ✅ Using fare type: $fareTypeName (ID: $fareTypeId, FareID: $requestedFareId)');

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

                // Ensure paxIds is not empty
                final effectivePaxIds = paxIds.isNotEmpty ? paxIds : ['1'];
                print(effectivePaxIds);
                print("Pax Id's");

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


// Extract updated price from addToCart response
  double _extractUpdatedPrice(Map<String, dynamic> cartData) {
    try {
      // Navigate through the response structure to find the total fare
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

      // Alternative path
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
      print('Error extracting updated price: $e');
      return 0.0;
    }
  }



// Update the _buildPNRRequest method in api_service_flydubai.dart
// Update the _buildPNRRequest method in ApiServiceFlyDubai
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
      print('Building PNR request for flight type: $flightType');
      print('Adults: ${adults.length}, Children: ${children.length}, Infants: ${infants.length}');
      print('Segment array: ${segmentArray.length} items');

      // Build passengers array
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

      // Build segments from segment array with proper extras
      final List<Map<String, dynamic>> segments = _buildSegmentsFromArray(segmentArray);

      // Format phone numbers for the request
      final formattedPhone = _cleanPhoneNumber(clientPhone);
      final formattedSimCode = _cleanPhoneNumber(simCode);

      // Try to obtain SecurityGUID from cartData if present
      String securityGuid = cartData['SecurityGuid'] ?? '';

      print('Security GUID from cart: $securityGuid');

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
      print('Error building PNR request: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }// Enhanced segment builder with proper extras handling
  // Enhanced segment builder for round trips
  List<Map<String, dynamic>> _buildSegmentsFromArray(List<Map<String, dynamic>> segmentArray) {
    final List<Map<String, dynamic>> segments = [];

    try {
      print('Building segments from array...');
      print('Segment array length: ${segmentArray.length}');

      for (int i = 0; i < segmentArray.length; i++) {
        final segment = segmentArray[i];
        final paxId = segment['pax'] ?? 1;
        final fareId = segment['fareID'] ?? 1;
        final extra = segment['extra'] as Map<String, dynamic>? ?? {};

        // FareInformationID should be sequential (1, 2, 3...) for PNR, not the actual fareID
        final fareInformationId = i + 1;

        print('📍 Processing segment $i:');
        print('   - Passenger ID (pax): $paxId');
        print('   - Original fareID from segment: $fareId');
        print('   - Using FareInformationID for PNR: $fareInformationId (sequential)');
        print('   - Extra data: $extra');

        // Build special services (baggage and meals)
        final specialServices = _buildSpecialServices(extra, paxId);

        // Build seats
        final seats = _buildSeats(extra, paxId);

        segments.add({
          "PersonOrgID": -paxId,
          "FareInformationID": fareInformationId,  // Use sequential ID (1, 2, 3...)
          "SpecialServices": specialServices,
          "Seats": seats
        });

        print('Added segment $i with FareInformationID: $fareInformationId, ${specialServices.length} special services and ${seats.length} seats');
      }
    } catch (e) {
      print('Error building segments from array: $e');
    }

    // For round trips, ensure we have segments for both outbound and return
    if (segments.isEmpty) {
      print('Creating fallback segments...');
      for (int i = 0; i < segmentArray.length; i++) {
        segments.add({
          "PersonOrgID": -(i + 1),
          "FareInformationID": i + 1,  // Sequential: 1, 2, 3...
          "SpecialServices": [],
          "Seats": []
        });
      }
    }

    print('Built ${segments.length} segments from array');
    return segments;
  }// Helper method to clean phone number
  String _cleanPhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9]'), '');
  }

// Enhanced special services builder
// Enhanced special services builder to match PHP format
  List<Map<String, dynamic>> _buildSpecialServices(Map<String, dynamic> extra, int paxId) {
    final List<Map<String, dynamic>> services = [];

    try {
      // Handle baggage
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

      // Handle meals
      if (extra['meal'] is List) {
        for (final meal in extra['meal'] as List) {
          if (meal != null && meal.toString().isNotEmpty) {
            final mealItems = meal.toString().split('!!');
            if (mealItems.length >= 7) {
              final depDate = mealItems[2].contains('T')
                  ? mealItems[2]
                  : "${mealItems[2]}T00:00:00";

              services.add({
                "ServiceID": 1,
                "CodeType": mealItems[0],
                "SSRCategory": 121,
                "LogicalFlightID": int.tryParse(mealItems[1]) ?? 0,
                "DepartureDate": depDate,
                "Amount": double.tryParse(mealItems[3]) ?? 0.0,
                "OverrideAmount": false,
                "CurrencyCode": mealItems[4],
                "Commissionable": false,
                "Refundable": false,
                "ChargeComment": mealItems[5],
                "PersonOrgID": -paxId,
                "AlreadyAdded": false,
                "PhysicalFlightID": int.tryParse(mealItems[6]) ?? 0,
                "secureHash": ""
              });
            }
          }
        }
      }

      // Handle seats as chargeable SSR (SPST)
      if (extra['seat'] is List) {
        for (final seat in extra['seat'] as List) {
          if (seat != null && seat.toString().isNotEmpty) {
            final seatItems = seat.toString().split('!!');
            if (seatItems.length >= 9) {
              final depDate = seatItems[2].contains('T')
                  ? seatItems[2]
                  : "${seatItems[2]}T00:00:00";

              services.add({
                "ServiceID": 1,
                "CodeType": seatItems[0],
                "SSRCategory": 0,
                "LogicalFlightID": int.tryParse(seatItems[1]) ?? 0,
                "DepartureDate": depDate,
                "Amount": double.tryParse(seatItems[3]) ?? 0.0,
                "OverrideAmount": false,
                "CurrencyCode": seatItems[4],
                "Commissionable": false,
                "Refundable": false,
                "ChargeComment": seatItems[5],
                "PersonOrgID": -paxId,
                "AlreadyAdded": false,
                "PhysicalFlightID": int.tryParse(seatItems[6]) ?? 0,
                "secureHash": ""
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error building special services: $e');
    }

    return services;
  }
// Enhanced seats builder
  List<Map<String, dynamic>> _buildSeats(Map<String, dynamic> extra, int paxId) {
    final List<Map<String, dynamic>> seats = [];

    try {
      // Handle seats
      if (extra['seat'] is List) {
        for (final seat in extra['seat'] as List) {
          if (seat != null && seat.toString().isNotEmpty) {
            final seatItems = seat.toString().split('!!');
            if (seatItems.length >= 9) {
              seats.add({
                "PersonOrgID": -paxId,
                "LogicalFlightID": int.tryParse(seatItems[1]) ?? 0,
                "PhysicalFlightID": int.tryParse(seatItems[6]) ?? 0,
                "DepartureDate": seatItems[2],
                "SeatSelected": seatItems[8],
                "RowNumber": seatItems[7]
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error building seats: $e');
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

// Update the _buildSegmentsFromCartData method
  List<Map<String, dynamic>> _buildSegmentsFromCartData(
      Map<String, dynamic> cartData,
      int passengerCount,
      List<Map<String, dynamic>> segmentArray
      ) {
    final List<Map<String, dynamic>> segments = [];

    try {
      print('Building segments from cart data and segment array...');
      print('Segment array: ${segmentArray.length} items');

      // If we have segment array from the controller, use it
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
        // Fallback: create basic segments from cart data
        print('No segment array provided, creating basic segments...');

        // Extract flight groups from cart data
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
      print('Error building segments from cart data: $e');
    }

    // Fallback: create basic segments if extraction fails
    if (segments.isEmpty) {
      print('Creating fallback segments...');
      for (int i = 0; i < passengerCount; i++) {
        segments.add({
          "PersonOrgID": -(i + 1),
          "FareInformationID": 1,
          "SpecialServices": [],
          "Seats": []
        });
      }
    }

    print('Built ${segments.length} segments');
    return segments;
  }



  // Add these methods to ApiServiceFlyDubai class

  Future<Map<String, dynamic>> getSeatOptions({
    required List<String> bookingIds,
    required Map<String, dynamic> flightData,
  }) async {
    try {
      if (_accessToken == null) {
        return {
          'success': false,
          'error': 'No valid token available. Please search flights first.',
        };
      }

      final tokenToUse = _accessToken;

      print('=== FLYDUBAI GET SEAT OPTIONS STARTED ===');
      print('Booking IDs: $bookingIds');
      print('🔐 Using access token in GET SEATS: $tokenToUse');
      print('🔐 Token hash: ${tokenToUse?.hashCode}');
      print('🔐 Token Length: ${tokenToUse?.length ?? 0}');

      final requestBody = _buildSeatRequest(bookingIds, flightData);

      print('Seat Request Body:');
      printJsonPretty(requestBody);

      final response = await http.post(
        Uri.parse('$baseUrl/pricing/seats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',  // Include Authorization header
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Cookie': 'visid_incap_3059742=mt0fc3JTQDStXbDmAKotlet1zGUAAAAAQUIPAAAAAAA/4nh9vwd+842orxzMj3FS',
        },
        body: json.encode(requestBody),
      );

      print('Seat Options Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        print('✅ Seat options retrieved successfully');
        print('Seat Options Response Body (first 500 chars): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
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
        print('❌ Seat options failed: ${response.statusCode}');
        print('❌ Response Body: ${response.body}');
        print('❌ Request Headers:');
        print('   - Content-Type: application/json');
        print('   - Authorization: Bearer ${_accessToken?.substring(0, 20)}...');
        print('❌ Full Request Body:');
        printJsonPretty(requestBody);

        // Try to parse error response for more details
        try {
          final errorData = json.decode(response.body);
          print('❌ Parsed Error Response:');
          printJsonPretty(errorData);
        } catch (e) {
          print('❌ Could not parse error response as JSON');
        }

        return {
          'success': false,
          'error': 'Failed to get seat options: ${response.statusCode}',
          'responseBody': response.body,
        };
      }
    } catch (e) {
      print('Get seat options error: $e');
      return {
        'success': false,
        'error': 'Failed to get seat options: $e',
      };
    }
  }// Get baggage options
  Future<Map<String, dynamic>> getBaggageOptions({
    required List<String> bookingIds,
    required Map<String, dynamic> flightData,
  }) async {
    try {
      if (_accessToken == null) {
        return {
          'success': false,
          'error': 'No valid token available. Please search flights first.',
        };
      }

      final tokenToUse = _accessToken;

      print('=== FLYDUBAI GET BAGGAGE OPTIONS STARTED ===');
      print('Booking IDs: $bookingIds');
      print('🔐 Token hash in BAGGAGE: ${tokenToUse?.hashCode}');

      final requestBody = _buildBaggageRequest(bookingIds, flightData);

      print('Baggage Request Body:');
      printJsonPretty(requestBody);

      final response = await http.post(
        Uri.parse('$baseUrl/offers/bags'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
          'Cookie': 'visid_incap_3059742=mt0fc3JTQDStXbDmAKotlet1zGUAAAAAQUIPAAAAAAA/4nh9vwd+842orxzMj3FS',
        },
        body: json.encode(requestBody),
      );

      print('Baggage Options Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
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
      print('Get baggage options error: $e');
      return {
        'success': false,
        'error': 'Failed to get baggage options: $e',
      };
    }
  }

// Get meal options
  Future<Map<String, dynamic>> getMealOptions({
    required List<String> bookingIds,
    required Map<String, dynamic> flightData,
  }) async {
    try {
      if (_accessToken == null) {
        return {
          'success': false,
          'error': 'No valid token available. Please search flights first.',
        };
      }

      final tokenToUse = _accessToken;

      print("Acces Token fly dubai");
      print(tokenToUse);
      print('🔐 Token hash in MEALS: ${tokenToUse?.hashCode}');

      print('=== FLYDUBAI GET MEAL OPTIONS STARTED ===');
      print('Booking IDs: $bookingIds');

      final requestBody = _buildMealRequest(bookingIds, flightData);

      print('Meal Request Body:');
      printJsonPretty(requestBody);

      final response = await http.post(
        Uri.parse('$baseUrl/offers/mealsife'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
          'Cookie': 'visid_incap_3059742=mt0fc3JTQDStXbDmAKotlet1zGUAAAAAQUIPAAAAAAA/4nh9vwd+842orxzMj3FS',
        },
        body: json.encode(requestBody),
      );

      print('Meal Options Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
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
      print('Get meal options error: $e');
      return {
        'success': false,
        'error': 'Failed to get meal options: $e',
      };
    }
  }
  Map<String, dynamic>
  _buildSeatRequest(List<String> bookingIds, Map<String, dynamic> flightData) {
    try {
      print('🔄 Building seat request for ${bookingIds.length} booking IDs...');
      print('Booking IDs: $bookingIds');
      print('📋 Flight Data Keys: ${flightData.keys.toList()}');

      // Check if this is cart data or search data
      final bool isCartData = flightData.containsKey('originDestinations') &&
          !flightData.containsKey('RetrieveFareQuoteDateRangeResponse');

      print('📦 Data Type: ${isCartData ? "CART DATA" : "SEARCH DATA"}');

      dynamic segmentDetails;
      dynamic flightSegments;

      if (isCartData) {
        // Cart data has originDestinations directly
        final originDests = flightData['originDestinations'];
        print('   Raw originDestinations type: ${originDests.runtimeType}');
        print('   Raw originDestinations is List: ${originDests is List}');
        if (originDests is List) {
          print('   Raw originDestinations length: ${originDests.length}');
          for (int i = 0; i < originDests.length; i++) {
            print('   originDest[$i]: ${originDests[i] is Map ? (originDests[i] as Map).keys.toList() : originDests[i].runtimeType}');
          }
        }
        segmentDetails = _extractArray(originDests);
        flightSegments = null; // Not available in cart data
        print('✅ Using originDestinations from cart data');
        print('   After extract - type: ${segmentDetails.runtimeType}, is List: ${segmentDetails is List}');
        print('   Extracted ${segmentDetails is List ? segmentDetails.length : (segmentDetails != null ? 1 : 0)} origin destinations');
      } else {
        // Search data has nested structure
        final retrieveResult = flightData['RetrieveFareQuoteDateRangeResponse']?['RetrieveFareQuoteDateRangeResult'];
        if (retrieveResult == null) {
          print('❌ RetrieveFareQuoteDateRangeResult is null');
          print('Available keys in flightData: ${flightData.keys}');
          throw Exception('Invalid flight data structure');
        }

        segmentDetails = _extractArray(retrieveResult['SegmentDetails']?['SegmentDetail']);
        flightSegments = _extractArray(retrieveResult['FlightSegments']?['FlightSegment']);
        print('✅ Using SegmentDetails from search data');
      }

      print('📊 Available segments: ${segmentDetails is List ? segmentDetails.length : 1}');
      if (!isCartData) {
        print('📊 Available flight segments: ${flightSegments is List ? flightSegments.length : 1}');
      }

      // Debug: print all segment LFIDs and detailed info
      if (segmentDetails is List) {
        print('📋 Segment LFIDs available:');
        for (var seg in segmentDetails) {
          if (seg is Map) {
            if (isCartData) {
              // Cart data format
              print('   - odID: ${seg['odID']}, ${seg['origin']}->${seg['destination']}');
            } else {
              // Search data format
              print('   - LFID: ${seg['LFID']}, ${seg['Origin']}->${seg['Destination']}');
              print('     SellingCarrier: ${seg['SellingCarrier']}, OperatingCarrier: ${seg['OperatingCarrier']}, MarketingCarrier: ${seg['MarketingCarrier']}');
            }
          }
        }
      }

      final List<Map<String, dynamic>> flights = [];

      // Extract LFIDs from booking IDs to match against segments
      final Set<String> requestedLfids = {};
      for (final bkId in bookingIds) {
        final parts = bkId.split('_');
        if (parts.isNotEmpty) {
          requestedLfids.add(parts[0]); // LFID/odID is the first part before '_'
        }
      }
      print('🎯 Requested LFIDs/odIDs from booking IDs: $requestedLfids');

      // For round trips, ONLY include segments that match the booking IDs
      // This matches the web implementation which loops through booking IDs
      if (segmentDetails != null) {
        final segmentsList = segmentDetails is List ? segmentDetails : [segmentDetails];

        print('🔍 Processing ${segmentsList.length} segments from flight data...');

        for (final segment in segmentsList) {
          if (segment is! Map) continue;

          // Get LFID/odID (different keys for cart vs search data)
          final lfidNum = isCartData ? segment['odID'] : segment['LFID'];
          if (lfidNum == null) {
            print('⚠️ Segment has no ${isCartData ? "odID" : "LFID"}, skipping');
            continue;
          }

          final lfidString = lfidNum.toString();

          // IMPORTANT: Only include segments that match our booking IDs
          if (!requestedLfids.contains(lfidString)) {
            print('⏭️ Skipping segment with ${isCartData ? "odID" : "LFID"} $lfidString (not in booking IDs)');
            continue;
          }

          print('✓ Including segment with ${isCartData ? "odID" : "LFID"} $lfidString (matches booking ID)');

          // Parse departure date - Use midnight time (matching web implementation)
          String depDate = isCartData ?
          (segment['depDate']?.toString() ?? '') :
          (segment['DepartureDate']?.toString() ?? '');
          String formattedDate;

          if (depDate.isEmpty) {
            print('⚠️ No departure date for $lfidString');
            formattedDate = '${DateTime.now().toIso8601String().substring(0, 10)}T00:00:00';
          } else {
            // Extract date part only (before 'T') and add T00:00:00, matching web implementation
            final datePart = depDate.split('T')[0]; // Get YYYY-MM-DD part
            formattedDate = '${datePart}T00:00:00';
          }

          print('   Using depDate: $formattedDate (original: $depDate)');

          // Extract fields based on data format
          String sellingCarrier;
          String operatingCarrier;
          String flightNum;
          String origin;
          String dest;

          if (isCartData) {
            // Cart data has simplified structure
            final segDetails = segment['segmentDetails'];
            final firstSeg = segDetails is List && segDetails.isNotEmpty ? segDetails[0] : null;

            operatingCarrier = firstSeg?['operCarrier']?.toString() ?? 'FZ';
            sellingCarrier = firstSeg?['mrktCarrier']?.toString() ?? 'FZ';
            flightNum = segment['flightNum']?.toString() ?? '';
            origin = segment['origin']?.toString() ?? '';
            dest = segment['destination']?.toString() ?? '';
          } else {
            // Search data format
            sellingCarrier = segment['SellingCarrier']?.toString() ??
                segment['MarketingCarrier']?.toString() ?? 'FZ';
            operatingCarrier = segment['OperatingCarrier']?.toString() ?? 'FZ';
            flightNum = segment['FlightNum']?.toString() ?? '';
            origin = segment['Origin']?.toString() ?? '';
            dest = segment['Destination']?.toString() ?? '';
          }

          final flight = {
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
          };

          flights.add(flight);
          print('✅ Added flight: ${flight['origin']} -> ${flight['dest']} on ${flight['depDate']} (LFID: $lfidString)');
          print('   Marketing: $sellingCarrier, Operating: $operatingCarrier');
        }
      }

      // If we still don't have flights, try to extract from flight segments
      if (flights.isEmpty && flightSegments != null) {
        print('⚠️ No flights from segment details, trying flight segments...');
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
            // Extract date part only and add T00:00:00, matching web implementation
            final datePart = depDate.split('T')[0];
            formattedDate = '${datePart}T00:00:00';
          }

          // Use SellingCarrier if available, fallback to MarketingCarrier or FZ
          final sellingCarrier = flightSegment['SellingCarrier']?.toString() ??
              flightSegment['MarketingCarrier']?.toString() ?? 'FZ';
          final operatingCarrier = flightSegment['OperatingCarrier']?.toString() ?? 'FZ';

          final flight = {
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
          };

          flights.add(flight);
          print('✅ Added flight from segment: ${flight['origin']} -> ${flight['dest']}');
          print('   Marketing: $sellingCarrier, Operating: $operatingCarrier');
        }
      }

      // Ensure we have at least one flight
      if (flights.isEmpty) {
        print('❌ No flights could be extracted from flight data');
        throw Exception('No valid flight segments found in flight data');
      }

      // IMPORTANT: Include the token in the request body (not just in headers)
      // This matches the web implementation
      final request = {
        'token': _accessToken,
        'flights': flights
      };

      print('🎯 Seat request built with ${flights.length} flight(s)');
      print('📋 Flights included:');
      for (final flight in flights) {
        print('   ${flight['origin']} → ${flight['dest']} on ${flight['depDate']} (LFID: ${flight['lfID']})');
      }
      print('🔐 Token included in request body: ${_accessToken?.substring(0, 20)}...');

      return request;

    } catch (e, stackTrace) {
      print('❌ Error building seat request: $e');
      print('Stack trace: $stackTrace');
      // Return minimal fallback request (with token)
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
    debugPrint("🔍 Starting _buildBaggageMealRequest...");
    debugPrint("➡️ bookingIds: $bookingIds");
    debugPrint("📋 Flight Data Keys: ${flightData.keys.toList()}");

    // Check if this is cart data or search data
    final bool isCartData = flightData.containsKey('originDestinations') &&
        !flightData.containsKey('RetrieveFareQuoteDateRangeResponse');

    debugPrint("📦 Data Type: ${isCartData ? "CART DATA" : "SEARCH DATA"}");

    dynamic basicArray;
    dynamic legDetails;
    dynamic segmentDetails;

    if (isCartData) {
      // For cart data, use originDestinations directly
      final originDests = flightData['originDestinations'];
      debugPrint("   Raw originDestinations type: ${originDests.runtimeType}");
      debugPrint("   Raw originDestinations length: ${originDests is List ? originDests.length : 'not a list'}");
      segmentDetails = _extractArray(originDests);
      basicArray = segmentDetails; // Reuse for simplicity
      legDetails = null; // Not needed for cart data
      debugPrint("✅ Using originDestinations from cart data");
      debugPrint("   After _extractArray - segmentDetails type: ${segmentDetails.runtimeType}");
      debugPrint("   After _extractArray - segmentDetails length: ${segmentDetails is List ? segmentDetails.length : (segmentDetails != null ? 1 : 'null')}");
    } else {
      // Search data has nested structure
      final retrieveResult = flightData['RetrieveFareQuoteDateRangeResponse']?['RetrieveFareQuoteDateRangeResult'];
      if (retrieveResult == null) {
        debugPrint("❌ retrieveResult is null! Invalid flightData structure");
        throw Exception('Invalid flight data structure');
      }

      basicArray = _extractArray(retrieveResult['FlightSegments']?['FlightSegment']);
      legDetails = _extractArray(retrieveResult['LegDetails']?['LegDetail']);
      segmentDetails = _extractArray(retrieveResult['SegmentDetails']?['SegmentDetail']);
      debugPrint("✅ Using FlightSegments/LegDetails/SegmentDetails from search data");
    }

    debugPrint("✅ Extracted Arrays:");
    debugPrint("   basicArray: ${basicArray.runtimeType}");
    debugPrint("   legDetails: ${legDetails.runtimeType}");
    debugPrint("   segmentDetails: ${segmentDetails.runtimeType}");

    final List<Map<String, dynamic>> originDestinations = [];
    // Track pax counts by PTCID - but only count once (not per booking ID)
    // For round trips, multiple booking IDs represent different flights for the SAME passengers
    final Map<int, int> paxTypeCounts = {1: 0, 6: 0, 5: 0}; // 1=ADT,6=CHD,5=INF
    bool hasProcessedPaxCounts = false; // Flag to ensure we only count passengers once

    for (int i = 0; i < bookingIds.length; i++) {
      final bk = bookingIds[i];
      debugPrint("➡️ Processing bookingId[$i]: $bk");

      final bkIdArray = bk.split('_');
      if (bkIdArray.length < 2) {
        debugPrint("⚠️ bookingId[$i] skipped (invalid format)");
        continue;
      }

      final requestedLfid = int.tryParse(bkIdArray[0]) ?? 0;  // This is LFID, not array index
      final fare = int.tryParse(bkIdArray[1]) ?? 0;
      debugPrint("   Requested LFID: $requestedLfid, fare index: $fare");

      // Find the segment data with matching LFID/odID
      dynamic arrayStart;
      final String idKey = isCartData ? 'odID' : 'LFID';

      if (basicArray is List && basicArray.isNotEmpty) {
        // Search for the segment with matching LFID/odID
        for (var segment in basicArray) {
          if (segment is Map && segment[idKey] == requestedLfid) {
            arrayStart = segment;
            debugPrint("   ✅ Found segment with $idKey: $requestedLfid");
            break;
          }
        }
        if (arrayStart == null) {
          debugPrint("   ⚠️ No segment found with $idKey: $requestedLfid, using first segment");
          arrayStart = basicArray[0];
        }
      } else if (basicArray is Map) {
        arrayStart = basicArray;
      }

      if (arrayStart == null) {
        debugPrint("❌ arrayStart is null for bookingId[$i]");
        continue;
      }

      final lfid1 = arrayStart[idKey];
      debugPrint("   📌 Using segment with $idKey: $lfid1");

      // Extract fare info based on data format
      dynamic fareInfos;
      String fareTypeName = '';

      if (isCartData) {
        // Cart data has fareBrand array
        final fareBrands = _extractArray(arrayStart['fareBrand']);
        if (fareBrands != null) {
          // For cart data, just use the first fareBrand (it's already the selected one)
          final fareBrand = fareBrands is List ? fareBrands[0] : fareBrands;
          fareTypeName = fareBrand['fareBrandName']?.toString() ?? '';
          fareInfos = fareBrand['fareInfos'];
        }
        debugPrint("   fareTypeName from cart: $fareTypeName");
      } else {
        // Search data has FareTypes
        final fareTypes = _extractArray(arrayStart['FareTypes']?['FareType']);
        debugPrint("   fareTypes type: ${fareTypes.runtimeType}");

        if (fareTypes == null || (fareTypes is List && fare >= fareTypes.length)) {
          debugPrint("⚠️ Skipping bookingId[$i]: Invalid fareTypes or index out of range");
          continue;
        }

        final fareArray = fareTypes is List ? fareTypes[fare] : fareTypes;
        fareTypeName = fareArray['FareTypeName']?.toString() ?? '';
        fareInfos = fareArray['FareInfos']?['FareInfo'];
        debugPrint("   fareTypeName: $fareTypeName");
      }

      fareInfos = _extractArray(fareInfos);
      final List<Map<String, dynamic>> paxFareDetails = [];
      final List<Map<String, dynamic>> legDetailList = [];

      // Find segment info based on data format
      Map<String, dynamic> segmentInfo = {};
      if (isCartData) {
        // Cart data already has segment info at top level
        segmentInfo = {
          'origin': arrayStart['origin'] ?? '',
          'destination': arrayStart['destination'] ?? '',
          'departureDate': arrayStart['depDate'] ?? '',
        };
        debugPrint("   segmentInfo from cart: $segmentInfo");
      } else {
        // Search data needs to find it from segmentDetails
        if (segmentDetails is List && segmentDetails.isNotEmpty) {
          for (final item in segmentDetails) {
            if (item is Map && item['LFID'] == lfid1) {
              segmentInfo = {
                'origin': item['Origin'] ?? '',
                'destination': item['Destination'] ?? '',
                'departureDate': item['DepartureDate'] ?? '',
              };
              debugPrint("   segmentInfo found: $segmentInfo");
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
        debugPrint("   bookingCodes found: ${bookingCodesList.length}");

        if (isCartData) {
          // Cart data: bookingCodesList is actually segmentDetails
          for (final seg in bookingCodesList) {
            if (seg is! Map) continue;

            final segId = seg['segmentID'];
            final depDate = seg['depDate']?.toString() ?? '';

            debugPrint("   Processing cart segment: segmentID=$segId");
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
                  debugPrint("   Matching leg found: PFID=$pfid, Departure=$departureDate");
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
        debugPrint("   paxFareDetails added: ${paxFareDetails.length}");
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
      debugPrint("✅ Added originDestination for bookingId[$i]");
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

    debugPrint("🧮 Final passenger count: ${paxDetailsArray.length} (should match actual passengers, not booking IDs)");
    for (var pax in paxDetailsArray) {
      debugPrint("   - Passenger ${pax['paxID']}: ${pax['PTC']}");
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

    debugPrint("🎯 Final AncillaryPricingRequest built successfully!");
    debugPrint(result.toString());

    return result;
  }


  void _debugFlightDataStructure(Map<String, dynamic> flightData) {
    try {
      print('=== DEBUG FLIGHT DATA STRUCTURE ===');
      final retrieveResult = flightData['RetrieveFareQuoteDateRangeResponse']?['RetrieveFareQuoteDateRangeResult'];

      if (retrieveResult == null) {
        print('❌ No RetrieveFareQuoteDateRangeResult found');
        return;
      }

      final basicArray = _extractArray(retrieveResult['FlightSegments']?['FlightSegment']);
      final segmentDetails = _extractArray(retrieveResult['SegmentDetails']?['SegmentDetail']);

      print('FlightSegments count: ${basicArray is List ? basicArray.length : 'N/A'}');
      print('SegmentDetails count: ${segmentDetails is List ? segmentDetails.length : 'N/A'}');

      if (segmentDetails is List) {
        for (int i = 0; i < segmentDetails.length; i++) {
          final segment = segmentDetails[i];
          if (segment is Map) {
            print('Segment $i: LFID=${segment['LFID']}, ${segment['Origin']}->${segment['Destination']}, Date=${segment['DepartureDate']}');
          }
        }
      }

      if (basicArray is List) {
        for (int i = 0; i < basicArray.length; i++) {
          final flightSegment = basicArray[i];
          if (flightSegment is Map) {
            print('FlightSegment $i: LFID=${flightSegment['LFID']}');
          }
        }
      }
      print('=== END DEBUG ===');
    } catch (e) {
      print('Debug error: $e');
    }
  }

// Alias for meal request (same structure as baggage)
  Map<String, dynamic> _buildMealRequest(List<String> bookingIds, Map<String, dynamic> flightData) {
    return _buildBaggageMealRequest(bookingIds, flightData);
  }

// Alias for baggage request
  Map<String, dynamic> _buildBaggageRequest(List<String> bookingIds, Map<String, dynamic> flightData) {
    return _buildBaggageMealRequest(bookingIds, flightData);
  }

// Helper to find segment by index
// Helper to find segment by index
// Helper to find segment by LFID
  Map<String, dynamic>? _findSegmentByIndex(dynamic segmentDetails, int lfid) {
    debugPrint("🔍 _findSegmentByIndex called with LFID=$lfid, type=${segmentDetails.runtimeType}");

    if (segmentDetails == null) {
      debugPrint("❌ segmentDetails is null");
      return null;
    }

    if (segmentDetails is List) {
      debugPrint("➡️ segmentDetails is a List with length= ${segmentDetails.length}");
      try {
        for (var seg in segmentDetails) {
          if (seg is Map && seg["LFID"] == lfid) {
            debugPrint("✅ Found matching segment with LFID=$lfid");
            return Map<String, dynamic>.from(seg);
          }
        }
        debugPrint("⚠️ No segment found with LFID=$lfid in the list");
        return null;
      } catch (e) {
        debugPrint("🔥 Error while searching segment list: $e");
        return null;
      }
    } else if (segmentDetails is Map) {
      debugPrint("➡️ segmentDetails is a single Map");
      if (segmentDetails["LFID"] == lfid) {
        debugPrint("✅ Single segment matches LFID=$lfid");
        return Map<String, dynamic>.from(segmentDetails);
      } else {
        debugPrint("⚠️ Single segment does not match LFID=$lfid (found ${segmentDetails["LFID"]})");
        return null;
      }
    }

    debugPrint("⚠️ segmentDetails is neither List nor Map (type=${segmentDetails.runtimeType})");
    return null;
  }




  /// Prints JSON nicely with chunking
  void printJsonPretty(dynamic jsonData) {
    const int chunkSize = 1000;
    final jsonString = const JsonEncoder.withIndent(' ').convert(jsonData);

    // for (int i = 0; i < jsonString.length; i += chunkSize) {
    //   final chunk = jsonString.substring(
    //     i,
    //     i + chunkSize < jsonString.length ? i + chunkSize : jsonString.length,
    //   );
    //   print(chunk);
    // }
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
}
