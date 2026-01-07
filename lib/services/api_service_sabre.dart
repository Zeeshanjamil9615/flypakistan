// ignore_for_file: empty_catches

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../views/flight/booking_flight/booking_flight_controller.dart';
import '../views/flight/search_flights/sabre/sabre_flight_models.dart';
import 'api_client.dart';
import 'api_service_airblue.dart';
import 'margin_service_flight.dart';

class ApiServiceSabre extends GetxService {
  late final Dio dio;
  // Initialize directly instead of using late
  final AirBlueFlightApiService flightShoppingService = AirBlueFlightApiService();

  // Add ApiClient instance
  final ApiClient _apiClient = ApiClient();

  static const String _baseUrl = 'https://api.havail.sabre.com';
  static const String _tokenKey = 'flight_api_token';
  static const String _tokenExpiryKey = 'flight_token_expiry';
  final BookingFlightController bookingController = Get.put(
    BookingFlightController(),
  );


  // Add a property to store the airline map
  final Rx<Map<String, AirlineInfo>> airlineMap = Rx<Map<String, AirlineInfo>>({});
  // Add a method to get the airline map
  Map<String, AirlineInfo> getAirlineMap() {
    return airlineMap.value;
  }
  // Initialize airline data when service starts
  @override
  void onInit() {
    super.onInit();
    // Fetch airline data when service initializes
    fetchAirlineData().then((data) {
      airlineMap.value = data;
    });
  }


  // Cabin class mapping
  static const Map<String, String> _cabinClassMapping = {
    'ECONOMY': 'Economy',
    'PREMIUM ECONOMY': 'PremiumEconomy',
    'BUSINESS': 'Business',
    'FIRST': 'First',
  };

  String _mapCabinClass(String cabin) {
    return _cabinClassMapping[cabin.toUpperCase()] ?? 'Economy';
  }

  ApiServiceSabre() {
    dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      validateStatus: (status) => true,
    ));
  }

  Future<void> _storeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final expiryTime = DateTime.now().add(const Duration(minutes: 55));
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_tokenExpiryKey, expiryTime.toIso8601String());
  }

  Future<String?> getValidToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final expiryTimeStr = prefs.getString(_tokenExpiryKey);

    if (token != null && expiryTimeStr != null) {
      final expiryTime = DateTime.parse(expiryTimeStr);
      if (DateTime.now().isBefore(expiryTime)) {
        return token;
      }
    }
    return null;
  }

  Future<String> generateToken() async {
    try {
      final pcc = '6MD8';
      final username = '409318';
      final password = 'SSWRES99';

      final key = 'V1:$username:$pcc:AA';
      final keyBase64 = base64Encode(utf8.encode(key));
      final passwordBase64 = base64Encode(utf8.encode(password));
      final finalKey = '$keyBase64:$passwordBase64';
      final finalKeyBase64 = base64Encode(utf8.encode(finalKey));

      // Use ApiClient for token generation
      final response = await _apiClient.request(
        url: '$_baseUrl/v2/auth/token',
        method: HttpMethod.POST,
        serviceName: 'SABRE TOKEN',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic $finalKeyBase64',
          'grant_type': 'client_credentials',
        },
        contentType: ContentType.JSON,
      );

      if (response.isSuccess && response.responseJson != null && response.responseJson!['access_token'] != null) {
        final token = response.responseJson!['access_token'] as String;
        await _storeToken(token);
        return token;
      } else {
        throw Exception('Failed to generate token');
      }
    } catch (e) {
      throw Exception('Error generating token: $e');
    }
  }
  // Sabre 0
  // AirBlue 1

  Future<Map<String, dynamic>> searchFlights({
    required int type,
    required String origin,
    required String destination,
    required String depDate,
    required int adult,
    required int child,
    required int infant,
    required int stop,
    required String cabin,
    required int flight,

  }) async {
    try {
      if(flight==0){
        final token = await getValidToken() ?? await generateToken();
        // Original Sabre API call
        final sabreResponse = await _searchFlightsWithSabre(
          type: type,
          origin: origin,
          destination: destination,
          depDate: depDate,
          adult: adult,
          child: child,
          infant: infant,
          stop: stop,
          cabin: cabin,
          token: token,
        );

        return sabreResponse;
      }else if(flight==1){
        // New Air Blue API call with same parameters
        try {
          final airBlueResponse = await _searchFlightsWithAirBlue(
            type: type,
            origin: origin,
            destination: destination,
            depDate: depDate,
            adult: adult,
            child: child,
            infant: infant,
            stop: stop.toString(), // Convert int to string as Air Blue expects string
            cabin: cabin,
          );

          return airBlueResponse;
        } catch (airBlueError) {
          // If Air Blue API fails, just log the error but continue with Sabre results
        }
      }
      return {};
    } catch (e) {
      throw Exception('Error searching flights: $e');
    }
  }

  Future<Map<String, dynamic>> _searchFlightsWithSabre({
    required int type,
    required String origin,
    required String destination,
    required String depDate,
    required int adult,
    required int child,
    required int infant,
    required int stop,
    required String cabin,
    required String token,
  }) async {
    try {
      final originArray = origin.split(',');
      final destinationArray = destination.split(',');
      final depDateArray = depDate.split(',');

      final mappedCabin = _mapCabinClass(cabin);

      List<Map<String, dynamic>> passengers = [];
      List<Map<String, dynamic>> originDestinations = [];

      if (type == 0) {
        // One-way trip
        originDestinations.add({
          "RPH": "1",
          "DepartureDateTime": "${depDateArray[1]}T00:00:01",
          "OriginLocation": {"LocationCode": originArray[1].toUpperCase()},
          "DestinationLocation": {
            "LocationCode": destinationArray[1].toUpperCase()
          }
        });
      } else if (type == 1) {
        // Return trip
        originDestinations.addAll([
          {
            "RPH": "1",
            "DepartureDateTime": "${depDateArray[1]}T00:00:01",
            "OriginLocation": {"LocationCode": originArray[1].toUpperCase()},
            "DestinationLocation": {
              "LocationCode": destinationArray[1].toUpperCase()
            }
          },
          {
            "RPH": "2",
            "DepartureDateTime": "${depDateArray[2]}T00:00:01",
            "OriginLocation": {
              "LocationCode": destinationArray[1].toUpperCase()
            },
            "DestinationLocation": {
              "LocationCode": originArray[1].toUpperCase()
            }
          }
        ]);
      } else if (type == 2) {
        // Multi-city trip
        for (int i = 1; i < depDateArray.length; i++) {
          if (i < originArray.length && i < destinationArray.length) {
            originDestinations.add({
              "RPH": "$i",
              "DepartureDateTime": "${depDateArray[i]}T00:00:01",
              "OriginLocation": {"LocationCode": originArray[i].toUpperCase()},
              "DestinationLocation": {
                "LocationCode": destinationArray[i].toUpperCase()
              }
            });
          }
        }
      }

      if (adult > 0) passengers.add({"Code": "ADT", "Quantity": adult});
      if (child > 0) passengers.add({"Code": "CHD", "Quantity": child});
      if (infant > 0) passengers.add({"Code": "INF", "Quantity": infant});

      final requestBody = {
        "OTA_AirLowFareSearchRQ": {
          "ResponseType": "OTA",
          "ResponseVersion": "4.3.0",
          "Version": "4.3.0",
          "OriginDestinationInformation": originDestinations,
          "POS": {
            "Source": [
              {
                "PseudoCityCode": "6MD8",
                "RequestorID": {
                  "CompanyName": {"Code": "TN"},
                  "ID": "1",
                  "Type": "1"
                }
              }
            ]
          },
          "TPA_Extensions": {
            "IntelliSellTransaction": {
              "RequestType": {"Name": "50ITINS"}
            }
          },
          "TravelPreferences": {
            "ValidInterlineTicket": true,
            "CabinPref": [
              {"Cabin": mappedCabin, "PreferLevel": "Preferred"}
            ],
            "VendorPref": [{}],
            "TPA_Extensions": {
              "DataSources": {
                "ATPCO": "Enable",
                "LCC": "Enable",
                "NDC": "Enable"
              },
              "NumTrips": {"Number": 50},
              "NDCIndicators": {
                "MultipleBrandedFares": {"Value": true},
                "MaxNumberOfUpsells": {"Value": 6}
              },
              "TripType": {
                "Value": type == 1 ? "Return" : (type == 2 ? "Other" : "OneWay")
              }
            },
            "MaxStopsQuantity": stop
          },
          "TravelerInfoSummary": {
            "SeatsRequested": [adult + child],
            "AirTravelerAvail": [
              {"PassengerTypeQuantity": passengers}
            ],
            "PriceRequestInformation": {
              "TPA_Extensions": {
                "BrandedFareIndicators": {
                  "MultipleBrandedFares": true,
                  "ReturnBrandAncillaries": true,
                  "UpsellLimit": 4,
                  "ParityMode": "Leg",
                  "ParityModeForLowest": "Leg",
                  "ItinParityFallbackMode": "LegParity",
                  "ItinParityBrandlessLeg": true
                }
              }
            }
          }
        }
      };

      // Use ApiClient for flight search
      final response = await _apiClient.request(
        url: '$_baseUrl/v3/offers/shop',
        method: HttpMethod.POST,
        serviceName: 'SABRE FLIGHT SEARCH',
        body: jsonEncode(requestBody),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        contentType: ContentType.JSON,
      );

      if (response.isSuccess && response.responseJson != null) {
        return response.responseJson!;
      } else {
        throw Exception('Failed to search flights: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching flights with Sabre: $e');
    }
  }

  // Helper method to search flights with Air Blue
  Future<Map<String, dynamic>> _searchFlightsWithAirBlue({
    required int type,
    required String origin,
    required String destination,
    required String depDate,
    required int adult,
    required int child,
    required int infant,
    required String stop,
    required String cabin,
  }) async {
    try {
      // Format parameters for Air Blue API
      // Air Blue expects comma-prefixed strings for origin, destination, and depDate
      String formattedOrigin = origin;
      String formattedDestination = destination;
      String formattedDepDate = depDate;

      // Ensure they start with comma
      if (!formattedOrigin.startsWith(',')) formattedOrigin = ',$formattedOrigin';
      if (!formattedDestination.startsWith(',')) formattedDestination = ',$formattedDestination';
      if (!formattedDepDate.startsWith(',')) formattedDepDate = ',$formattedDepDate';

      return await flightShoppingService.airBlueFlightSearch(
        type: type,
        origin: formattedOrigin,
        destination: formattedDestination,
        depDate: formattedDepDate,
        adult: adult,
        child: child,
        infant: infant,
        stop: stop,
        cabin: cabin,
      );
    } catch (e) {
      throw Exception('Error searching flights with Air Blue: $e');
    }
  }

  // Add to ApiServiceFlight class in api_service_sabre.dart
  Future<Map<String, dynamic>> checkFlightAvailability({
    required int type,
    required List<Map<String, dynamic>> flightSegments,
    required Map<String, dynamic> requestBody,
    required int adult,
    required int child,
    required int infant,
    bool isNDC = false, // Add this parameter
  }) async {
    try {
      final token = await getValidToken() ?? await generateToken();

      final String endpoint;
      final Map<String, dynamic> requestData;

      if (isNDC) {
        // Handle NDC validation
        endpoint = '/v1/offers/price';
        requestData = {
          "query": [
            {
              "offerItemId": requestBody['offerItemId'] ?? [],
            }
          ],
          "params": {
            "formOfPayment": requestBody['formOfPayment'] ?? [],
          },
        };
      } else {
        // Handle standard validation
        endpoint = '/v4/shop/flights/revalidate';
        requestData = requestBody;
      }

      // Use ApiClient for flight availability check
      final response = await _apiClient.request(
        url: '$_baseUrl$endpoint',
        method: HttpMethod.POST,
        serviceName: 'SABRE FLIGHT AVAILABILITY',
        body: jsonEncode(requestData),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        contentType: ContentType.JSON,
      );

      if (response.isSuccess && response.responseJson != null) {
        return response.responseJson!;
      } else {
        throw Exception('Failed to check flight availability: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error checking flight availability: $e');
    }
  }

  Future<Map<String, AirlineInfo>> fetchAirlineData() async {
    Map<String, AirlineInfo> tempAirlineMap = {};

    try {
      // Use ApiClient for airline data fetch
      final response = await _apiClient.request(
        url: 'https://agent1.pk/api.php?type=airlines',
        method: HttpMethod.GET,
        serviceName: 'AIRLINE DATA',
        contentType: ContentType.JSON,
      );

      if (response.isSuccess && response.responseJson != null && response.responseJson!['data'] != null) {
        var data = response.responseJson!['data'] as List;
        for (var item in data) {
          // Clean and format the logo URL
          String logoUrl = item['logo'];

          // Remove any escaped characters like \t, \n, etc.
          logoUrl = logoUrl.replaceAll(RegExp(r'^\t+'), '');

          tempAirlineMap[item['code']] = AirlineInfo(
            item['name'],
            logoUrl,
          );
        }
        // Update the stored airlineMap
        airlineMap.value = tempAirlineMap;
      } else {
        // Handle error
      }
    } catch (e) {
      // Handle error
    }

    return tempAirlineMap;
  }

  Future<dynamic> createPNRRequest({
    required SabreFlight flight,
    required List<TravelerInfo> adults,
    required List<TravelerInfo> children,
    required List<TravelerInfo> infants,
    required String bookerEmail,
    required String bookerPhone,
    required Map<String, dynamic>? revalidatePricing,
  }) async {
    Map<String, dynamic>? pnrResponse;

    try {
      if (flight.isNDC) {
        pnrResponse = await _createNDCPNRRequest(
            flight: flight,
            adults: adults,
            children: children,
            infants: infants,
            bookerEmail: bookerEmail,
            bookerPhone: bookerPhone,
            revalidatePricing: revalidatePricing
        );
      } else {
        pnrResponse = await _createStandardPNRRequest(
          flight: flight,
          adults: adults,
          children: children,
          infants: infants,
          bookerEmail: bookerEmail,
          bookerPhone: bookerPhone,
        );
      }

      // Save booking regardless of PNR success
      await saveSabreBooking(
        flight: flight,
        pnrResponse: pnrResponse,
        token: (await getValidToken()).toString(),
        adults: adults,
        children: children,
        infants: infants,
        bookerEmail: bookerEmail,
        bookerPhone: bookerPhone,
      );

      return pnrResponse;
    } catch (e) {
      // Even if PNR fails, try to save the booking
      try {
        await saveSabreBooking(
          flight: flight,
          pnrResponse: null,
          token: (await getValidToken()).toString(),
          adults: adults,
          children: children,
          infants: infants,
          bookerEmail: bookerEmail,
          bookerPhone: bookerPhone,
        );
      } catch (saveError) {
        // Ignore save error
      }

      throw Exception('Error creating PNR: $e');
    }
  }

  Future<dynamic> _createStandardPNRRequest({
    required SabreFlight flight,
    required List<TravelerInfo> adults,
    required List<TravelerInfo> children,
    required List<TravelerInfo> infants,
    required String bookerEmail,
    required String bookerPhone,
  }) async {
    // Extract necessary information from the flight and travelers
    final List<Map<String, dynamic>> passengers = [];
    final List<Map<String, dynamic>> flightSegments = [];

    // Add adults
    for (var i = 0; i < adults.length; i++) {
      final adult = adults[i];
      passengers.add({
        "NameNumber": "${i + 1}.1",
        "NameReference": "", // Empty string for adults
        "PassengerType": "ADT",
        "GivenName": "${adult.firstNameController.text.trim()} ${adult.titleController.text}",
        "Surname": adult.lastNameController.text.trim(),
        "DateOfBirth": adult.dateOfBirthController.text,
        "PassportNumber": adult.passportCnicController.text.trim(),
        "PassportExpiry": adult.passportExpiryController.text,
      });
    }

    // Add children
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      passengers.add({
        "NameNumber": "${adults.length + i + 1}.1",
        "NameReference": "C${(i + 4).toString().padLeft(2, '0')}",
        "PassengerType": "CNN",
        "GivenName": "${child.firstNameController.text.trim()} ${child.titleController.text}",
        "Surname": child.lastNameController.text.trim(),
        "DateOfBirth": child.dateOfBirthController.text,
        "PassportNumber": child.passportCnicController.text.trim(),
        "PassportExpiry": child.passportExpiryController.text,
      });
    }

    // Add infants
    for (var i = 0; i < infants.length; i++) {
      final infant = infants[i];
      passengers.add({
        "NameNumber": "${i + 1}.1",
        "NameReference": "I${(i + 12).toString().padLeft(2, '0')}",
        "PassengerType": "INF",
        "Infant": true,
        "GivenName": "${infant.firstNameController.text.trim()} ${infant.titleController.text}",
        "Surname": infant.lastNameController.text.trim(),
        "DateOfBirth": infant.dateOfBirthController.text,
        "PassportNumber": infant.passportCnicController.text.trim(),
        "PassportExpiry": infant.passportExpiryController.text,
      });
    }

    // Add flight segments
    var segmentIndex = 0;
    for (var leg in flight.legSchedules) {
      for (var schedule in leg['schedules']) {
        flightSegments.add({
          "DepartureDateTime": schedule['departure']['dateTime'],
          "FlightNumber": schedule['carrier']['marketingFlightNumber'].toString(),
          "NumberInParty": passengers.length.toString(),
          "ResBookDesigCode": flight.segmentInfo[segmentIndex].bookingCode,
          "Status": "NN",
          "DestinationLocation": {
            "LocationCode": schedule['arrival']['airport'],
          },
          "MarketingAirline": {
            "Code": schedule['carrier']['marketing'],
            "FlightNumber": schedule['carrier']['marketingFlightNumber'].toString(),
          },
          "OriginLocation": {
            "LocationCode": schedule['departure']['airport'],
          },
        });
        segmentIndex++;
      }
    }

    // Extract FareBasis codes from flight data
    final List<Map<String, dynamic>> fareBasisCodes = [];
    for (var leg in flight.legSchedules) {
      if (leg['fareBasisCode'] != null) {
        fareBasisCodes.add({
          "FareBasis": {
            "Code": leg['fareBasisCode'],
          },
          "RPH": "${fareBasisCodes.length + 1}",
        });
      }
    }

    // Get the first adult's phone and email
    final firstAdultPhone = adults.isNotEmpty ? adults[0].phoneController.text : bookerPhone;
    final firstAdultCountry = adults.isNotEmpty ? adults[0].phoneCountry.toString() : "92";
    final firstAdultEmail = adults.isNotEmpty ? adults[0].emailController.text : bookerEmail;

    // Format phone with 00 + countryCode + number (without leading 0)
    String formatPhone(String phone, String countryCode) {
      phone = phone.replaceAll(RegExp(r'\D'), '');
      if (phone.startsWith('0')) {
        phone = phone.substring(1);
      }
      return '0092$phone';
    }

    final formattedPhone = formatPhone(firstAdultPhone, firstAdultCountry);

    List<Map<String, String>> passengerType = [];

    if (adults.isNotEmpty) {
      passengerType.add({
        "Code": "ADT",
        "Quantity": adults.length.toString(),
      });
    }

    if (children.isNotEmpty) {
      passengerType.add({
        "Code": "CNN",
        "Quantity": children.length.toString(),
      });
    }

    if (infants.isNotEmpty) {
      passengerType.add({
        "Code": "INF",
        "Quantity": infants.length.toString(),
      });
    }

    // Create the request body for standard PNR
    final requestBody = {
      "CreatePassengerNameRecordRQ": {
        "haltOnAirPriceError": true,
        "haltOnInvalidMCT": true,
        "targetCity": "6MD8",
        "version": "2.5.0",
        "TravelItineraryAddInfo": {
          "AgencyInfo": {
            "Ticketing": {
              "TicketType": "7T-A",
            },
          },
          "CustomerInfo": {
            "ContactNumbers": {
              "ContactNumber": passengers
                  .where((passenger) => passenger["PassengerType"] != "INF")
                  .map((passenger) => {
                "NameNumber": passenger["NameNumber"],
                "Phone": formattedPhone,
                "PhoneUseType": "M"
              })
                  .toList(),
            },
            "Email": passengers
                .where((passenger) => passenger["PassengerType"] != "INF")
                .map((passenger) => {
              "Address": firstAdultEmail,
              "NameNumber": passenger["NameNumber"]
            })
                .toList(),
            "PersonName": passengers.asMap().entries.map((entry) {
              int index = entry.key + 1;
              var passenger = entry.value;
              return {
                "NameNumber": "$index.1",
                "NameReference": passenger["NameReference"],
                "PassengerType": passenger["PassengerType"],
                if (passenger["PassengerType"] == "INF") "Infant": true,
                "GivenName": passenger["GivenName"],
                "Surname": passenger["Surname"],
              };
            }).toList(),
          },
        },
        "AirBook": {
          "OriginDestinationInformation": {
            "FlightSegment": flightSegments,
          },
          "RetryRebook": {
            "Option": true,
          },
          "HaltOnStatus": [
            {"Code": "HL"}, {"Code": "HN"}, {"Code": "HX"}, {"Code": "LL"},
            {"Code": "NN"}, {"Code": "NO"}, {"Code": "PN"}, {"Code": "UC"},
            {"Code": "UN"}, {"Code": "US"}, {"Code": "UU"},
          ],
          "RedisplayReservation": {
            "NumAttempts": 10,
            "WaitInterval": 500,
          },
        },
        "AirPrice": [
          {
            "PriceRequestInformation": {
              "Retain": true,
              "OptionalQualifiers": {
                "PricingQualifiers": {
                  "CommandPricing": fareBasisCodes,
                  "ItineraryOptions": {
                    "SegmentSelect": fareBasisCodes.map((code) => {
                      "Number": code["RPH"],
                      "RPH": code["RPH"],
                    }).toList(),
                  },
                  "PassengerType": passengerType,
                },
              },
            },
          },
        ],
        "SpecialReqDetails": {
          "SpecialService": {
            "SpecialServiceInfo": {
              "AdvancePassenger": passengers.map((passenger) {
                return {
                  "Document": {
                    "IssueCountry": "PK",
                    "NationalityCountry": "PK",
                    "ExpirationDate": passenger["PassportExpiry"],
                    "Number": passenger["PassportNumber"],
                    "Type": "P",
                  },
                  "PersonName": {
                    "GivenName": passenger["GivenName"],
                    "MiddleName": "",
                    "Surname": passenger["Surname"],
                    "DateOfBirth": passenger["DateOfBirth"],
                    "DocumentHolder": true,
                    "Gender": passenger["PassengerType"] == "INF" ? "M" : "F",
                    "LapChild": passenger["PassengerType"] == "INF",
                    "NameNumber": passenger["NameNumber"],
                  },
                };
              }).toList(),
              "Service": [
                ...passengers
                    .where((passenger) => passenger["PassengerType"] != "INF")
                    .map((passenger) => [
                  {
                    "SSR_Code": "CTCM",
                    "PersonName": {
                      "NameNumber": passenger["NameNumber"],
                    },
                    "Text": formattedPhone,
                  },
                  {
                    "SSR_Code": "CTCE",
                    "PersonName": {
                      "NameNumber": passenger["NameNumber"],
                    },
                    "Text": firstAdultEmail.replaceAll('@', '//'),
                  },
                ])
                    .expand((x) => x)
                    ,
                ...passengers
                    .where((passenger) => passenger["PassengerType"] == "INF")
                    .map((passenger) => {
                  "SSR_Code": "INFT",
                  "PersonName": {
                    "NameNumber": passenger["NameNumber"],
                  },
                  "Text":
                  "${passenger["Surname"]}/${passenger["GivenName"].split(' ')[0]}${passenger["GivenName"].split(' ').length > 1 ? passenger["GivenName"].split(' ')[1] : ''}/${passenger["DateOfBirth"]}"
                })
                    ,
              ],
            },
          },
        },
        "PostProcessing": {
          "ARUNK": {
            "keepSegments": true,
            "priorPricing": true,
          },
          "EndTransaction": {
            "Email": {
              "Ind": true,
            },
            "Source": {
              "ReceivedFrom": "ReadyFlight",
            },
          },
          "PostBookingHKValidation": {
            "waitInterval": 200,
            "numAttempts": 4,
          },
          "WaitForAirlineRecLoc": {
            "waitInterval": 200,
            "numAttempts": 4,
          },
          "RedisplayReservation": {
            "waitInterval": 1000,
          },
        },
      },
    };

    final token = await getValidToken() ?? await generateToken();

    // Use ApiClient for standard PNR creation
    final response = await _apiClient.request(
      url: '$_baseUrl/v2.5.0/passenger/records?mode=create',
      method: HttpMethod.POST,
      serviceName: 'SABRE STANDARD PNR',
      body: jsonEncode(requestBody),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'Conversation-ID': '2021.01.DevStudio',
      },
      contentType: ContentType.JSON,
    );

    if (response.isSuccess && response.responseJson != null) {
      handlePnrResponse(response.responseJson!);
      return response.responseJson!;
    } else {
      throw Exception('Failed to create standard PNR: ${response.statusCode}');
    }
  }

  Future<dynamic> _createNDCPNRRequest({
    required SabreFlight flight,
    required List<TravelerInfo> adults,
    required List<TravelerInfo> children,
    required List<TravelerInfo> infants,
    required String bookerEmail,
    required String bookerPhone,
    required Map<String, dynamic>? revalidatePricing,
  }) async {
    try {
      // Extract offer information
      final offerId = revalidatePricing!.isNotEmpty
          ? revalidatePricing['offerId']
          : 'default-offer-id';

      final offerItemId = revalidatePricing.isNotEmpty
          ? revalidatePricing['offerItemId']
          : 'default-offer-item-id';


      // Helper function to format phone number in full format (0092...)
      String formatPhoneNumberFull(String phone, String countryCode) {
        // Remove any non-digit characters and spaces
        phone = phone.replaceAll(RegExp(r'\D'), '');

        // If already in 0092 format, return as is
        if (phone.startsWith('00$countryCode')) {
          return phone;
        }

        // Remove leading zero if present (single zero)
        if (phone.startsWith('0') && !phone.startsWith('00')) {
          phone = phone.substring(1);
        }

        // Remove country code if present at the start (without 00)
        if (phone.startsWith(countryCode)) {
          phone = phone.substring(countryCode.length);
        }

        // Return in format: 00 + countryCode + phone
        return '00$countryCode$phone';
      }

      // Helper function to format email for SSR
      String formatEmailForSSR(String email) {
        // Just replace @ with //, don't modify other characters
        return email.replaceAll('@', '//');
      }

      // Helper function to format date for INFT SSR
      String formatDateForINFT(String dateString) {
        final date = DateTime.parse(dateString);
        return '${date.year.toString().substring(2)}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
      }

      // Build request components
      List<Map<String, dynamic>> contactInfos = [];
      List<Map<String, dynamic>> passengers = [];
      List<Map<String, dynamic>> secureFlightList = [];
      List<Map<String, dynamic>> serviceList = [];

      int passengerIndex = 1;
      int infantCounter = 1;

      // Process Adults
      for (int i = 0; i < adults.length; i++) {
        final adult = adults[i];
        final firstName = adult.firstNameController.text.trim();
        final lastName = adult.lastNameController.text.trim();
        final title = adult.titleController.text.trim().isEmpty ? 'Mr' : adult.titleController.text.trim();
        final dob = adult.dateOfBirthController.text.isEmpty ? '1990-01-01' : adult.dateOfBirthController.text;
        final passportNumber = adult.passportCnicController.text.trim();
        final passportExpiry = adult.passportExpiryController.text.isEmpty ? '2030-12-31' : adult.passportExpiryController.text;
        final nationality = adult.nationalityCountry.value?.countryCode ?? 'PK';
        final gender = adult.genderController.text.startsWith('M') ? 'M' : 'F';
        final email = adult.emailController.text.trim().isEmpty ? bookerEmail : adult.emailController.text.trim();

        // Format phone number properly
        final phoneCountryCode = adult.phoneCountry.value?.phoneCode ?? '92';
        final adultPhone = adult.phoneController.text.trim().isEmpty ? bookerPhone : adult.phoneController.text.trim();
        // Format phone as 0092... format
        final formattedPhone = formatPhoneNumberFull(adultPhone, phoneCountryCode);
        final formattedEmailForSSR = formatEmailForSSR(email);

        // Contact info
        contactInfos.add({
          "id": "CI-$passengerIndex",
          "emailAddresses": [
            {
              "address": email
            }
          ],
          "phones": [
            {
              "number": formattedPhone
            }
          ]
        });

        // Passenger info
        passengers.add({
          "contactInfoRefId": "CI-$passengerIndex",
          "birthdate": dob,
          "givenName": "$firstName $title",
          "id": "Passenger$passengerIndex",
          "surname": lastName,
          "typeCode": "ADT",
          "identityDocuments": [
            {
              "id": "ID-1",
              "documentNumber": passportNumber,
              "documentTypeCode": "PT",
              "issuingCountryCode": nationality,
              "placeOfIssue": nationality,
              "citizenshipCountryCode": nationality,
              "residenceCountryCode": nationality,
              "titleName": title,
              "givenName": lastName, // REVERSED: lastName in givenName
              "middleName": "",
              "surname": firstName, // REVERSED: firstName in surname
              "suffixName": "",
              "birthdate": dob,
              "genderCode": gender,
              "issueDate": DateTime.now().subtract(Duration(days: 365)).toIso8601String().substring(0, 10),
              "expiryDate": passportExpiry,
              "hostCountryCode": nationality
            }
          ]
        });

        // Secure flight info
        secureFlightList.add({
          "SegmentNumber": "A",
          "PersonName": {
            "DateOfBirth": dob,
            "Gender": gender,
            "NameNumber": "$passengerIndex.1",
            "GivenName": "$firstName $title",
            "Surname": lastName
          }
        });

        // Service requests
        serviceList.addAll([
          {
            "SSR_Code": "CTCM",
            "PersonName": {
              "NameNumber": "$passengerIndex.1"
            },
            "Text": formattedPhone
          },
          {
            "SSR_Code": "CTCE",
            "PersonName": {
              "NameNumber": "$passengerIndex.1"
            },
            "Text": formattedEmailForSSR
          }
        ]);

        passengerIndex++;
      }

      // Process Children
      for (int i = 0; i < children.length; i++) {
        final child = children[i];
        final firstName = child.firstNameController.text.trim();
        final lastName = child.lastNameController.text.trim();
        final title = child.titleController.text.trim().isEmpty ? 'Ms' : child.titleController.text.trim();
        final dob = child.dateOfBirthController.text.isEmpty ? '2015-01-01' : child.dateOfBirthController.text;
        final passportNumber = child.passportCnicController.text.trim();
        final passportExpiry = child.passportExpiryController.text.isEmpty ? '2030-12-31' : child.passportExpiryController.text;
        final nationality = child.nationalityCountry.value?.countryCode ?? 'PK';
        final gender = child.genderController.text.startsWith('M') ? 'M' : 'F';

        // Use booker's contact info for children
        final bookerPhoneCountryCode = bookingController.bookerPhoneCountry.value?.phoneCode ?? '92';
        final formattedPhone = formatPhoneNumberFull(bookerPhone, bookerPhoneCountryCode);
        final formattedEmailForSSR = formatEmailForSSR(bookerEmail);

        // Contact info
        contactInfos.add({
          "id": "CI-$passengerIndex",
          "emailAddresses": [
            {
              "address": bookerEmail
            }
          ],
          "phones": [
            {
              "number": formattedPhone
            }
          ]
        });

        // Passenger info
        passengers.add({
          "contactInfoRefId": "CI-$passengerIndex",
          "birthdate": dob,
          "givenName": "$firstName $title",
          "id": "Passenger$passengerIndex",
          "surname": lastName,
          "typeCode": "CHD",
          "identityDocuments": [
            {
              "id": "ID-1",
              "documentNumber": passportNumber,
              "documentTypeCode": "PT", // Children use "PT"
              "issuingCountryCode": nationality,
              "placeOfIssue": nationality,
              "citizenshipCountryCode": nationality,
              "residenceCountryCode": nationality,
              "titleName": title,
              "givenName": lastName, // REVERSED: lastName in givenName (no title)
              "middleName": "",
              "surname": firstName, // REVERSED: firstName in surname
              "suffixName": "",
              "birthdate": dob,
              "genderCode": gender,
              "issueDate": DateTime.now().subtract(Duration(days: 365)).toIso8601String().substring(0, 10),
              "expiryDate": passportExpiry,
              "hostCountryCode": nationality
            }
          ]
        });

        secureFlightList.add({
          "SegmentNumber": "A",
          "PersonName": {
            "DateOfBirth": dob,
            "Gender": gender,
            "NameNumber": "$passengerIndex.1",
            "GivenName": "$firstName $title",
            "Surname": lastName
          }
        });

        serviceList.addAll([
          {
            "SSR_Code": "CTCM",
            "PersonName": {
              "NameNumber": "$passengerIndex.1"
            },
            "Text": formattedPhone
          },
          {
            "SSR_Code": "CTCE",
            "PersonName": {
              "NameNumber": "$passengerIndex.1"
            },
            "Text": formattedEmailForSSR
          }
        ]);

        passengerIndex++;
      }

      // Process Infants
      for (int i = 0; i < infants.length; i++) {
        final infant = infants[i];
        final firstName = infant.firstNameController.text.trim();
        final lastName = infant.lastNameController.text.trim();
        final title = infant.titleController.text.trim().isEmpty ? 'Ms' : infant.titleController.text.trim();
        final dob = infant.dateOfBirthController.text.isEmpty ? '2023-01-01' : infant.dateOfBirthController.text;
        final passportNumber = infant.passportCnicController.text.trim();
        final passportExpiry = infant.passportExpiryController.text.isEmpty ? '2030-12-31' : infant.passportExpiryController.text;
        final nationality = infant.nationalityCountry.value?.countryCode ?? 'PK';
        final gender = infant.genderController.text.startsWith('M') ? 'M' : 'F';

        // Use booker's contact info for infants
        final bookerPhoneCountryCode = bookingController.bookerPhoneCountry.value?.phoneCode ?? '92';
        final formattedPhone = formatPhoneNumberFull(bookerPhone, bookerPhoneCountryCode);
        final formattedEmailForSSR = formatEmailForSSR(bookerEmail);

        // Contact info for infant
        contactInfos.add({
          "id": "CI-$passengerIndex",
          "emailAddresses": [
            {
              "address": bookerEmail
            }
          ],
          "phones": [
            {
              "number": formattedPhone
            }
          ]
        });

        // Passenger info
        passengers.add({
          "contactInfoRefId": "CI-$passengerIndex",
          "birthdate": dob,
          "givenName": firstName, // No title for infants in givenName
          "id": "Passenger$passengerIndex",
          "surname": lastName,
          "typeCode": "INF",
          "passengerRefId": "CI-1", // References first contact (adult)
          "identityDocuments": [
            {
              "id": "ID-1",
              "documentNumber": passportNumber,
              "documentTypeCode": "PT", // Infants use "PT"
              "issuingCountryCode": nationality,
              "placeOfIssue": nationality,
              "citizenshipCountryCode": nationality,
              "residenceCountryCode": nationality,
              "titleName": title,
              "givenName": lastName, // REVERSED: lastName in givenName (no title)
              "middleName": "",
              "surname": firstName, // REVERSED: firstName in surname
              "suffixName": "",
              "birthdate": dob,
              "genderCode": gender,
              "issueDate": DateTime.now().subtract(Duration(days: 365)).toIso8601String().substring(0, 10),
              "expiryDate": passportExpiry,
              "hostCountryCode": nationality
            }
          ]
        });

        // Secure flight for infant
        secureFlightList.add({
          "SegmentNumber": "A",
          "PersonName": {
            "DateOfBirth": dob,
            "Gender": gender, // Just M or F, not MI
            "NameNumber": "$infantCounter.1",
            "GivenName": "$firstName $title",
            "Surname": lastName
          }
        });

        // INFT SSR for infant
        final dobFormatted = formatDateForINFT(dob);
        serviceList.add({
          "SSR_Code": "INFT",
          "PersonName": {
            "NameNumber": "$infantCounter.1"
          },
          "Text": "$lastName/$firstName$title/$dobFormatted"
        });

        passengerIndex++;
        infantCounter++;
      }

      // Create the complete request body
      final requestBody = {
        "transactionOptions": {
          "requestType": "STATELESS",
          "commitTransaction": true,
          "movePassengerDetails": true,
          "intialIgnore": true  // Note: typo in web API, using "intialIgnore" not "initialIgnore"
        },
        "contactInfos": contactInfos,
        "createOrders": [
          {
            "offerId": offerId,
            "selectedOfferItems": [
              {
                "id": offerItemId
              }
            ]
          }
        ],
        "passengers": passengers,
        "SpecialReqDetails": {
          "SpecialService": {
            "SpecialServiceInfo": {
              "SecureFlight": secureFlightList,
              "Service": serviceList
            }
          }
        },
        "PostProcessing": {
          "RedisplayReservation": {
            "waitInterval": 100
          },
          "EndTransaction": {
            "Email": {
              "Ind": true
            },
            "Source": {
              "ReceivedFrom": "AGENT1B2B"
            }
          }
        }
      };

      final token = await getValidToken() ?? await generateToken();

      // Use ApiClient for NDC PNR creation
      final response = await _apiClient.request(
        url: '$_baseUrl/v1/orders/create',
        method: HttpMethod.POST,
        serviceName: 'SABRE NDC PNR',
        body: jsonEncode(requestBody),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        contentType: ContentType.JSON,
      );

      if (response.isSuccess && response.responseJson != null) {
        final responseData = response.responseJson!;
        if (responseData['order'] != null && responseData['order']['id'] != null) {
          return responseData;
        }
      } else {
        throw Exception('Failed to create NDC PNR: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating NDC PNR: $e');
    }
  }

  void handlePnrResponse(Map<String, dynamic> pnrResponse) async {
    final pnrData = pnrResponse['CreatePassengerNameRecordRS'];
    if (pnrData['ApplicationResults']['status'] == 'Complete') {
      final itineraryRefId = pnrData['ItineraryRef']['ID'];
      try {
        await getBooking(itineraryRefId);
      } catch (e) {
        // Ignore error
      }
    }
  }

  Future<Map<String, dynamic>> getBooking(String pnrId) async {
    try {
      // Get the valid token or generate a new one if necessary
      final token = await getValidToken() ?? await generateToken();

      // Prepare the request body
      final requestBody = {
        "confirmationId": pnrId,
      };

      // Use ApiClient for getting booking details
      final response = await _apiClient.request(
        url: '$_baseUrl/v1/trip/orders/getBooking',
        method: HttpMethod.POST,
        serviceName: 'SABRE GET BOOKING',
        body: jsonEncode(requestBody),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        contentType: ContentType.JSON,
      );

      if (response.isSuccess && response.responseJson != null) {
        return response.responseJson!;
      } else {
        throw Exception('Failed to get booking details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting booking details: $e');
    }
  }

  // Helper method to extract PNR from response
  String _extractPnrFromResponse(Map<String, dynamic> pnrResponse) {
    try {
      if (pnrResponse['CreatePassengerNameRecordRS'] != null) {
        // Standard PNR response
        final applicationResults = pnrResponse['CreatePassengerNameRecordRS']['ApplicationResults'];
        if (applicationResults['status'] == 'Complete') {
          return pnrResponse['CreatePassengerNameRecordRS']['ItineraryRef']['ID'] ?? "";
        }
      } else if (pnrResponse['order'] != null) {
        // NDC PNR response
        return pnrResponse['order']['pnrLocator'] ?? "";
      }
    } catch (e) {
      // Ignore error
    }
    return "";
  }

  // Helper method to check if PNR was successful
  bool _isPnrSuccessful(Map<String, dynamic> pnrResponse) {
    try {
      if (pnrResponse['CreatePassengerNameRecordRS'] != null) {
        return pnrResponse['CreatePassengerNameRecordRS']['ApplicationResults']['status'] == 'Complete';
      } else if (pnrResponse['order'] != null) {
        return pnrResponse['order']['pnrLocator'] != null;
      }
    } catch (e) {
      // Ignore error
    }
    return false;
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
      default:
        return 'Economy';
    }
  }

  Future<Map<String, dynamic>> saveSabreBooking({
    required SabreFlight flight,
    required Map<String, dynamic>? pnrResponse,
    required String token,
    required List<TravelerInfo> adults,
    required List<TravelerInfo> children,
    required List<TravelerInfo> infants,
    required String bookerEmail,
    required String bookerPhone,
  }) async {
    try {
      // Prepare booking info
      final bookingInfo = {
        "bfname": bookingController.firstNameController.text,
        "blname": bookingController.lastNameController.text,
        "bemail": bookingController.emailController.text,
        "bphno": bookingController.phoneController.text,
        "badd": "b",
        "bcity": "a",
        "final_price": flight.price.toString(),
        "client_email": bookingController.emailController.text,
        "client_phone": bookingController.phoneController.text,
      };

      // Prepare adults data
      final adultsData = bookingController.adults.map((adult) {
        return {
          "title": adult.titleController.text,
          "first_name": adult.firstNameController.text,
          "last_name": adult.lastNameController.text,
          "dob": adult.dateOfBirthController.text,
          "nationality": adult.nationalityController.text,
          "passport": adult.passportCnicController.text,
          "passport_expiry": adult.passportExpiryController.text,
          "cnic": adult.passportCnicController.text,
        };
      }).toList();

      // Prepare children data
      final childrenData = bookingController.children.map((child) {
        return {
          "title": child.titleController.text,
          "first_name": child.firstNameController.text,
          "last_name": child.lastNameController.text,
          "dob": child.dateOfBirthController.text,
          "nationality": child.nationalityController.text,
          "passport": child.passportCnicController.text,
          "passport_expiry": child.passportExpiryController.text,
          "cnic": child.passportCnicController.text,
        };
      }).toList();

      // Prepare infants data
      final infantsData = bookingController.infants.map((infant) {
        return {
          "title": infant.titleController.text,
          "first_name": infant.firstNameController.text,
          "last_name": infant.lastNameController.text,
          "dob": infant.dateOfBirthController.text,
          "nationality": infant.nationalityController.text,
          "passport": "a",
          "passport_expiry": "a",
          "cnic": "a",
        };
      }).toList();

      // Prepare flights data
      final flights = _prepareSabreFlightData(flight);

      // Determine PNR status (1 for success, 0 for failure)
      final pnrStatus = pnrResponse != null && _isPnrSuccessful(pnrResponse) ? 1 : 0;
      final pnr = pnrResponse != null ? _extractPnrFromResponse(pnrResponse) : "";


      final ApiServiceMargin apiServiceMargin = Get.put(ApiServiceMargin());
      // Get airline code from flight
      final airlineCode = flight.airlineCode;
      // Prefer cached margin data if available (set during search in controller)
      Map<String, dynamic> marginData =  {};
      if (marginData.isEmpty) {
        try {
          marginData = await apiServiceMargin.getMargin(airlineCode, 'sabre', "Sabre");
        } catch (e) {
          // Margin fetch failed, using defaults
        }
      }
      final calculatedSellingPrice = apiServiceMargin.calculatePriceWithMargin(flight.buyingPrice, marginData);



      // Prepare final request body
      final requestBody = {
        "booking_info": bookingInfo,
        "adults": adultsData,
        "children": childrenData,
        "infants": infantsData,
        "flights": flights,
        "pnr": pnr,
        "buyingPrice": flight.buyingPrice.toStringAsFixed(0),
        "sellingPrice": calculatedSellingPrice.toStringAsFixed(0),
        "pnrStatus": pnrStatus,
        "booking_from": "1", // Sabre booking source
        "gds": "sabre"
      };

      // Use ApiClient for saving booking
      final response = await _apiClient.request(
        url: 'https://readyflights.pk/api/flight-booking',
        method: HttpMethod.POST,
        serviceName: 'SABRE SAVE BOOKING',
        body: jsonEncode(requestBody),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        contentType: ContentType.JSON,
      );

      if (response.isSuccess) {
        if (response.responseJson != null) {
          return response.responseJson!;
        }
        return {'status': 'success'};
      } else {
        throw Exception('Failed to save booking: ${response.message}');
      }
    } catch (e) {
      throw Exception('Error saving booking: $e');
    }
  }

  // Helper method to prepare flight data for Sabre
  List<Map<String, dynamic>> _prepareSabreFlightData(SabreFlight flight) {
    final flights = <Map<String, dynamic>>[];

    for (var leg in flight.legSchedules) {
      for (var schedule in leg['schedules']) {
        final departureDateTime = DateTime.parse(schedule['departure']['dateTime']);
        final arrivalDateTime = DateTime.parse(schedule['arrival']['dateTime']);
        final duration = arrivalDateTime.difference(departureDateTime);

        // Get the corresponding segment info
        final segmentIndex = flights.length;
        final segment = segmentIndex < flight.segmentInfo.length
            ? flight.segmentInfo[segmentIndex]
            : FlightSegmentInfo(
          bookingCode: 'Y',
          cabinCode: 'Y',
          mealCode: 'M',
          seatsAvailable: '',
          fareBasisCode: '',
        );

        flights.add({
          "departure": {
            "airport": schedule['departure']['airport'],
            "city": schedule['departure']['city'] ?? schedule['departure']['airport'],
            "date": departureDateTime.toIso8601String().split('T')[0],
            "time": "${departureDateTime.hour.toString().padLeft(2, '0')}:${departureDateTime.minute.toString().padLeft(2, '0')}",
            "terminal": schedule['departure']['terminal'] ?? 'Main',
          },
          "arrival": {
            "airport": schedule['arrival']['airport'],
            "city": schedule['arrival']['city'] ?? schedule['arrival']['airport'],
            "date": arrivalDateTime.toIso8601String().split('T')[0],
            "time": "${arrivalDateTime.hour.toString().padLeft(2, '0')}:${arrivalDateTime.minute.toString().padLeft(2, '0')}",
            "terminal": schedule['arrival']['terminal'] ?? 'Main',
          },
          "flight_number": schedule['carrier']['marketingFlightNumber'].toString(),
          "airline_code": schedule['carrier']['marketing'],
          "airline_name": flight.airline,
          "operating_flight_number": schedule['carrier']['operatingFlightNumber']?.toString() ?? schedule['carrier']['marketingFlightNumber'].toString(),
          "operating_airline_code": schedule['carrier']['operating'] ?? schedule['carrier']['marketing'],
          "operating_airline_name": flight.airline,
          "cabin_class": _getCabinClassName(segment.cabinCode),
          "sub_class": segment.cabinCode,
          "booking_class": segment.bookingCode,
          "hand_baggage": "7kg", // Default value
          "check_baggage": "${flight.baggageAllowance.weight} ${flight.baggageAllowance.unit}",
          "meal": segment.mealCode == 'M' ? 'Meal' : (segment.mealCode.isNotEmpty ? segment.mealCode : 'None'),
          "layover": flight.legSchedules.length > 1 ? "Yes" : "None",
          "duration": "${duration.inHours}h ${duration.inMinutes.remainder(60)}m",
          "duration_minutes": duration.inMinutes,
          "type": flight.legSchedules.length == 1 ? "One-Way" : "Return",
          "fare_basis": segment.fareBasisCode,
          "seats_available": segment.seatsAvailable,
          "is_refundable": flight.isRefundable,
          "aircraft_type": schedule['equipment']?['aircraftType'] ?? 'Unknown',
        });
      }
    }

    return flights;
  }
}