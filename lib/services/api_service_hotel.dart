// ignore_for_file: empty_catches

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:ready_flights/views/users/login/login_api_service/login_api.dart';

import '../utility/utils.dart';
import '../views/hotel/hotel/guests/guests_controller.dart';
import '../views/hotel/search_hotels/booking_hotel/booking_controller.dart';
import '../views/hotel/search_hotels/search_hotel_controller.dart';

class ApiServiceHotel extends GetxService {
  late final Dio dio;
  static const String _apiKey = 'VSXYTrVlCtVXRAOXGS2==';
  static const String _baseUrl = 'https://apiv2.giinfotech.ae/api/v2';


  // Only margin and ROE needed
  double currentROE = 296.0; // Default ROE
  double currentMargin = 10.0; // Default margin percentage

  ApiServiceHotel() {
    dio = Dio(BaseOptions(baseUrl: _baseUrl));
    if (!Get.isRegistered<SearchHotelController>()) {
      Get.put(SearchHotelController());
    }
  }

  /// Helper: Sets default headers for API requests.
  Options _defaultHeaders() {
    return Options(
      headers: {
        'apikey': _apiKey,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );
  }

  /// Helper: Formats date strings to 'yyyy-MM-dd'.
  String _formatDate(String isoDate) {
    try {
      return DateFormat('yyyy-MM-dd').format(DateTime.parse(isoDate));
    } catch (e) {
      if (kDebugMode) {
        print('Date formatting error: $e');
      }
      return isoDate; // Fallback to the original format if parsing fails.
    }
  }

  // Add this method to fetch margin and ROE
  Future<void> fetchMarginAndROE() async {
    try {
      var headers = {'Content-Type': 'application/json'};
      Map<String, dynamic> requestData = {};

      // Check if AuthController is registered and user is logged in
      if (Get.isRegistered<AuthController>()) {
        final authController = Get.find<AuthController>();
        final isLoggedIn = await authController.isLoggedIn();

        if (isLoggedIn && authController.userData.isNotEmpty) {
          // User is logged in, send login: 1 and email
          String userEmail = authController.userData['cs_email']?.toString() ??
              authController.userData['email']?.toString() ?? "";

          if (userEmail.isNotEmpty) {
            requestData = {
              "login": 1,
              "email": userEmail
            };
            if (kDebugMode) {
              print('Fetching margin for logged-in user: $userEmail');
            }
          }
        } else {
          if (kDebugMode) {
            print('Fetching margin for guest user');
          }
        }
      } else {
        if (kDebugMode) {
          print('AuthController not registered, fetching guest margin');
        }
      }

      var response = await dio.request(
        'https://readyflights.pk/api/margin-hotel',
        options: Options(
          method: 'POST',
          headers: headers,
        ),
        data: json.encode(requestData),
      );

      if (response.statusCode == 200) {
        var data = response.data;

        // Handle string response that needs to be parsed as JSON
        if (data is String) {
          try {
            data = json.decode(data);
          } catch (e) {
            if (kDebugMode) {
              print('Error decoding margin API response: $e');
            }
            return;
          }
        }

        if (data is Map && data['status'] == 'success') {
          // Only update margin and ROE - nothing else
          currentROE = double.tryParse(data['currency_roe_to_pkr'].toString()) ?? 296.0;
          currentMargin = double.tryParse(data['margin_per'].toString()) ?? 10.0;

          if (kDebugMode) {
            print('Updated: ROE=$currentROE, Margin=$currentMargin%');
          }
        }
      } else {
        if (kDebugMode) {
          print('Failed to fetch margin: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching margin and ROE: $e');
      }



      // Keep default values if API fails
    }
  }

  // Simple pricing logic - only ROE and margin
  double applyPricingLogic(double originalPrice) {
    // Apply ROE conversion (multiply)
    double convertedPrice = originalPrice * currentROE;

    // Apply margin percentage
    convertedPrice = convertedPrice * (1 + (currentMargin / 100));

    return convertedPrice;
  }

  Future<List<dynamic>> fetchCities(String cityKeyword) async {
    var headers = {'Cookie': 'PHPSESSID=n2sduu2sfi2p57nhr9h8fc74p0'};

    var dio = Dio();
    try {
      var response = await dio.request(
        'https://readyflights.pk/api/getDestination.php?keyword=$cityKeyword',
        options: Options(method: 'GET', headers: headers),
      );

      if (response.statusCode == 200) {
        // Print raw response data type for debugging

        // Handle string response that needs to be parsed as JSON
        if (response.data is String) {
          try {
            var decodedData = json.decode(response.data);
            if (decodedData is Map &&
                decodedData['status'] == 200 &&
                decodedData['data'] != null) {
              return decodedData['data'] as List;
            } else if (decodedData is List) {
              return decodedData;
            } else {
              return [];
            }
          } catch (e) {
            return [];
          }
        }
        // Handle Map response structure
        else if (response.data is Map) {
          if (response.data['status'] == 200 && response.data['data'] != null) {
            return response.data['data'] as List;
          } else {
            return [];
          }
        }
        // Handle direct List response
        else if (response.data is List) {
          return response.data as List;
        }
        // Fallback for unexpected response types
        else {
          return [];
        }
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Updated fetchHotels method with margin and ROE
  Future<void> fetchHotels({
    required String destinationCode,
    required String countryCode,
    required String nationality,
    required String currency,
    required String checkInDate,
    required String checkOutDate,
    required List<Map<String, dynamic>> rooms,
  }) async {

    print("checking workinbg");

    final searchController = Get.find<SearchHotelController>();

    // Fetch margin and ROE before processing hotels     
    await fetchMarginAndROE();

    final requestBody = {
      "SearchParameter": {
        "DestinationCode": destinationCode,
        "CountryCode": countryCode,
        "Nationality": nationality,
        "Currency": currency,
        "CheckInDate": _formatDate(checkInDate),
        "CheckOutDate": _formatDate(checkOutDate),
        "Rooms": {
          "Room": rooms
              .map(
                (room) => {
              "RoomIdentifier": room["RoomIdentifier"],
              "Adult": room["Adult"],
            },
          )
              .toList(),
        },
        "TassProInfo": {"CustomerCode": "4805", "RegionID": "123"},
      },
    };
    print(requestBody);

    try {
      final response = await dio.post(
        '/hotel/Search',
        data: requestBody,
        options: _defaultHeaders(),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        print(response.data);
        final hotels = data['hotels']?['hotel'] ?? [];
        final sessionId = data['generalInfo']?['sessionId'];
        final destinationCode = data['audit']?['destination']['code'];

        searchController.sessionId.value = sessionId ?? '';
        searchController.destinationCode.value = destinationCode ?? '';
        searchController.hotels.value = hotels.map<Map<String, dynamic>>((hotel) {
          // Get original price and apply only ROE and margin
          double originalPrice = double.tryParse(hotel['minPrice']?.toString() ?? '0') ?? 0;
          double finalPrice = applyPricingLogic(originalPrice);

          return {
            'name': hotel['name'] ?? 'Unknown Hotel',
            'price': finalPrice,
            'address': hotel['hotelInfo']?['add1'] ?? 'Address not available',
            'image': hotel['hotelInfo']?['image'] ?? 'assets/img/cardbg/broken-image.png',
            'rating': double.tryParse(hotel['hotelInfo']?['starRating']?.toString() ?? '0') ?? 3.0,
            'latitude': hotel['hotelInfo']?['lat'] ?? 0.0,
            'longitude': hotel['hotelInfo']?['lon'] ?? 0.0,
            'hotelCode': hotel['code'] ?? '',
            'hotelCity': hotel['hotelInfo']?['city'] ?? '',
          };
        }).toList();

      } else {
        if (kDebugMode) {
          print('Failed to fetch hotels: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching hotels: $e');
      }
    }
  }

  void _printLongText(String text) {
    const int chunkSize = 800;
    for (var i = 0; i < text.length; i += chunkSize) {
      print(text.substring(i, i + chunkSize > text.length ? text.length : i + chunkSize));
    }
  }

  /// Fetch hotel details by hotel ID
  Future<Map<String, dynamic>?> fetchHotelDetails(String hotelId) async {
    var headers = {'Content-Type': 'application/json'};

    var data = json.encode({
      "hotel_id": hotelId
    });

    try {
      var response = await dio.request(
        'https://readyflights.pk/api/hotel-details',
        options: Options(
          method: 'POST',
          headers: headers,
        ),
        data: data,
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('Hotel Details Response: ${response.data}');
        }

        // Handle the case where response.data is a String (JSON string)
        if (response.data is String) {
          try {
            var decodedData = json.decode(response.data);
            return decodedData as Map<String, dynamic>?;
          } catch (e) {
            if (kDebugMode) {
              print('Error decoding JSON string: $e');
            }
            return null;
          }
        }
        // Handle the case where response.data is already a Map
        else if (response.data is Map<String, dynamic>) {
          return response.data as Map<String, dynamic>?;
        }
        // Handle unexpected response type
        else {
          if (kDebugMode) {
            print('Unexpected response type: ${response.data.runtimeType}');
          }
          return null;
        }
      } else {
        if (kDebugMode) {
          print('Failed to fetch hotel details: ${response.statusMessage}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching hotel details: $e');
      }
      return null;
    }
  }

  // Updated fetchRoomDetails method with margin and ROE
  Future<void> fetchRoomDetails(String hotelCode, String sessionId) async {
  final guestsController = Get.find<GuestsController>();
  final searchController = Get.find<SearchHotelController>();

  // Ensure we have the latest margin and ROE
  await fetchMarginAndROE();

  List<Map<String, dynamic>> rooms =
  guestsController.rooms.asMap().entries.map((entry) {
    final index = entry.key;
    final room = entry.value;
    return {
      "RoomIdentifier": index + 1,
      "Adult": room.adults.value,
      if (room.children.value > 0) "child": room.children.value,
    };
  }).toList();

  final requestBody = {
    "SessionId": sessionId,
    "SearchParameter": {
      "HotelCode": hotelCode,
      "Currency": "USD",
      "Rooms": {"Room": rooms},
    },
  };
  print(requestBody);

  try {
    final response = await dio.post(
      '/hotel/RoomDetails',
      data: requestBody,
      options: _defaultHeaders(),
    );

    if (response.statusCode == 200) {
      final data = response.data;
      final prettyJson = const JsonEncoder.withIndent('  ').convert(response.data);
      _printLongText(prettyJson);

      // Extract specific hotel info
      final hotelInfo = data['hotel']?['hotelInfo'];
      final roomData = data['hotel']?['rooms']?['room'];

      // Check if hotel info or room data is null/empty
      if (hotelInfo == null || roomData == null || (roomData is List && roomData.isEmpty)) {
        if (kDebugMode) {
          print("No hotel info or rooms found in response.");
        }
        // Set empty rooms to trigger UI message
        searchController.roomsdata.value = [];
        searchController.hotelName.value = '';
        searchController.image.value = '';
        return;
      }

      searchController.hotelName.value = hotelInfo['name'] ?? '';
      searchController.image.value = hotelInfo['image'] ?? '';

      // Apply pricing logic to room rates
      List<dynamic> updatedRoomData = roomData.map((room) {
        if (room is Map<String, dynamic>) {
          // Create a copy of the room data
          Map<String, dynamic> updatedRoom = Map<String, dynamic>.from(room);

          // Handle direct room price structure
          if (updatedRoom['price'] != null && updatedRoom['price'] is Map) {
            Map<String, dynamic> priceData = Map<String, dynamic>.from(updatedRoom['price']);

            // Apply pricing to gross
            if (priceData['gross'] != null) {
              double originalGross = double.tryParse(priceData['gross'].toString()) ?? 0;
              priceData['gross'] = applyPricingLogic(originalGross);
            }

            // Apply pricing to net
            if (priceData['net'] != null) {
              double originalNet = double.tryParse(priceData['net'].toString()) ?? 0;
              priceData['net'] = applyPricingLogic(originalNet);
            }

            updatedRoom['price'] = priceData;
          }

          // Handle rates structure (if it exists)
          if (updatedRoom['rates'] != null && updatedRoom['rates']['rate'] != null) {
            List<dynamic> rates = updatedRoom['rates']['rate'];
            updatedRoom['rates']['rate'] = rates.map((rate) {
              if (rate is Map<String, dynamic>) {
                Map<String, dynamic> updatedRate = Map<String, dynamic>.from(rate);

                // Apply only ROE and margin to sellingRate
                if (updatedRate['sellingRate'] != null) {
                  double originalPrice = double.tryParse(updatedRate['sellingRate'].toString()) ?? 0;
                  updatedRate['sellingRate'] = applyPricingLogic(originalPrice);
                }

                // Apply only ROE and margin to net rate if it exists
                if (updatedRate['net'] != null) {
                  double originalNet = double.tryParse(updatedRate['net'].toString()) ?? 0;
                  updatedRate['net'] = applyPricingLogic(originalNet);
                }

                return updatedRate;
              }
              return rate;
            }).toList();
          }

          return updatedRoom;
        }
        return room;
      }).toList();

      searchController.roomsdata.value = updatedRoomData;

      print("Hotel Name: ${hotelInfo['name']}");
      print("Rooms Count: ${updatedRoomData.length}");
      print("Applied ROE: $currentROE, Margin: $currentMargin%");
    } else {
      print("❌ Failed: ${response.statusCode}");
      searchController.roomsdata.value = [];
    }
  } catch (e) {
    print("❌ Error: $e");
    searchController.roomsdata.value = [];
  }
}/// Pre-book a room.
  Future<Map<String, dynamic>?> prebook({
    required String sessionId,
    required String hotelCode,
    required int groupCode,
    required String currency,
    required List<String> rateKeys,
  }) async {
    final requestBody = {
      "SessionId": sessionId,
      "SearchParameter": {
        "HotelCode": hotelCode,
        "GroupCode": groupCode,
        "Currency": currency,
        "RateKeys": {"RateKey": rateKeys},
      },
    };

    try {
      final response = await dio.post(
        '/hotel/PreBook',
        data: requestBody,
        options: _defaultHeaders(),
      );

      if (response.statusCode == 200) {
        // Extract and print the condition list
        final data = response.data as Map<String, dynamic>;
        final hotel = data['hotel'] as Map<String, dynamic>?;
        if (hotel != null) {
          final rooms = hotel['rooms'] as Map<String, dynamic>?;
          if (rooms != null) {
            final roomList = rooms['room'] as List<dynamic>?;
            if (roomList != null && roomList.isNotEmpty) {
              for (int i = 0; i < roomList.length; i++) {
                final room = roomList[i] as Map<String, dynamic>;
                final policies = room['policies'] as Map<String, dynamic>?;
                if (policies != null) {
                  final policyList = policies['policy'] as List<dynamic>?;
                  if (policyList != null) {
                    for (int j = 0; j < policyList.length; j++) {
                      final policy = policyList[j] as Map<String, dynamic>;
                      final conditions = policy['condition'] as List<dynamic>?;
                      if (conditions != null) {
                      }
                    }
                  }
                }
              }
            }
          }
        }

        return data;
      } else {
      }
    } catch (e) {
    }
    return null;
  }

  Future<Map<String, dynamic>?> getCancellationPolicy({
    required String sessionId,
    required String hotelCode,
    required int groupCode,
    required String currency,
    required List<String> rateKeys,
  }) async {
    final requestBody = {
      "SessionId": sessionId,
      "SearchParameter": {
        "HotelCode": hotelCode,
        "GroupCode": groupCode,
        "Currency": currency,
        "RateKeys": {"RateKey": rateKeys},
      },
    };

    try {
      final response = await dio.post(
        '/hotel/CancellationPolicy',
        data: requestBody,
        options: _defaultHeaders(),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
      }
    } catch (e) {
    }
    return null;
  }

  Future<Map<String, dynamic>?> getPriceBreakup({
    required String sessionId,
    required String hotelCode,
    required int groupCode,
    required String currency,
    required List<String> rateKeys,
  }) async {
    final requestBody = {
      "SessionId": sessionId,
      "SearchParameter": {
        "HotelCode": hotelCode,
        "GroupCode": groupCode,
        "Currency": currency,
        "RateKeys": {"RateKey": rateKeys},
      },
    };

    try {
      final response = await dio.post(
        '/hotel/PriceBreakup',
        data: requestBody,
        options: _defaultHeaders(),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
      }
    } catch (e) {
    }
    return null;
  }


  Future<bool> bookHotel(Map<String, dynamic> requestBody) async {
    final BookingController bookingcontroller = Get.put(BookingController());

    const String bookingEndpoint = 'https://readyflights.pk/api/create-hotel-booking';

    try {
      final response = await dio.post(
        bookingEndpoint,
        data: requestBody,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status! < 500,
          followRedirects: true,
          maxRedirects: 5,
        ),
      );

      print("Request body: $requestBody");
      print("Raw response: ${response.data}");

      if (response.data != null) {
        // ✅ Agar response string hai to decode karo
        final decoded = response.data is String
            ? jsonDecode(response.data)
            : response.data;

        print("Decoded response: $decoded");

        if (decoded is Map && decoded['BookingNO'] != null) {
          String bookingStr = decoded['BookingNO'].toString();
          bookingStr = bookingStr.replaceAll('SHBK-', '');
          bookingcontroller.booking_num.value = int.tryParse(bookingStr) ?? 0;

          print("Saved booking number: ${bookingcontroller.booking_num.value}");
          return true;
        }
      }

      return false;
    } on DioException catch (e) {
      print("Dio error: ${e.message}");
      return false;
    } catch (e, st) {
      print("General error: $e");
      print(st);
      return false;
    }
  }
}