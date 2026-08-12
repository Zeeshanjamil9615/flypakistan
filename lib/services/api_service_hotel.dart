// ignore_for_file: empty_catches

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData;
import 'package:intl/intl.dart';
import 'package:ready_flights/views/users/login/login_api_service/login_api.dart';

import '../views/hotel/hotel/guests/guests_controller.dart';
import '../views/hotel/hotel/hotel_date_controller.dart';
import '../views/hotel/search_hotels/booking_hotel/booking_controller.dart';
import '../views/hotel/search_hotels/search_hotel_controller.dart';
import '../views/hotel/search_hotels/select_room/controller/select_room_controller.dart';
import 'hotel_merge_util.dart';

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
      return isoDate;
    }
  }

  /// Helper: Number of nights between two dates, minimum 1.
  int _nightsBetween(String checkInDate, String checkOutDate) {
    try {
      final int nights = DateTime.parse(
        checkOutDate,
      ).difference(DateTime.parse(checkInDate)).inDays;
      return nights > 0 ? nights : 1;
    } catch (e) {
      return 1;
    }
  }

  /// Helper: 'Lahore, Punjab, Pakistan' -> 'Lahore' for the own-DB city param.
  String _cityNameOnly(String rawCity) {
    return rawCity.split(',').first.trim();
  }

  /// Helper: own-DB text fields arrive HTML-escaped (e.g. 'Hotel &amp; Suites').
  String _unescapeHtml(String value) {
    return value
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
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
          }
        }
      }

      var response = await dio.request(
        'https://flypakistan.pk/api/margin-hotel',
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
            return;
          }
        }

        if (data is Map && data['status'] == 'success') {
          currentROE = double.tryParse(data['currency_roe_to_pkr'].toString()) ?? 296.0;
          currentMargin = double.tryParse(data['margin_per'].toString()) ?? 10.0;
        }
      }
    } catch (e) {
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
        'https://flypakistan.pk/api/getDestination.php?keyword=$cityKeyword',
        options: Options(method: 'GET', headers: headers),
      );
      if (response.statusCode == 200) {
        print("fecthcites....... 113${response.data}");
        List<dynamic> _sortCities(List<dynamic> items) {
          const List<String> preferredCityOrder = [
            'karachi',
            'lahore',
            'islamabad',
            'faisalabad',
            'peshawar',
            'multan',
            'sialkot',
            'gujranwala',
            'murree',
            'nathia gali',
            'hunza',
            'skardu',
            'swat',
            'hyderabad',
            'gilgit',
            'rawalpindi',
          ];
          final Map<String, int> preferredCityIndex = {
            for (int i = 0; i < preferredCityOrder.length; i++)
              preferredCityOrder[i]: i,
          };

          String keyOf(dynamic item) {
            if (item is String) return item;
            if (item is Map) {
              const keys = [
                'name',
                'city',
                'label',
                'text',
                'destination',
                'destinationName',
                'CityName',
                'city_name',
              ];
              for (final k in keys) {
                final v = item[k];
                if (v != null) return v.toString();
              }
              // If the shape is unknown, at least make it deterministic.
              return item.values.isNotEmpty ? item.values.first.toString() : '';
            }
            return item?.toString() ?? '';
          }

          String normalizedCityName(dynamic item) {
            final raw = keyOf(item).trim().toLowerCase();
            final cleaned = raw
                .replaceAll(RegExp(r',\s*pakistan$'), '')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
            if (cleaned == 'nathiagali') return 'nathia gali';
            return cleaned;
          }

          items.sort((a, b) {
            final ka = normalizedCityName(a);
            final kb = normalizedCityName(b);
            final ia = preferredCityIndex[ka];
            final ib = preferredCityIndex[kb];

            if (ia != null && ib != null) return ia.compareTo(ib);
            if (ia != null) return -1;
            if (ib != null) return 1;
            return ka.compareTo(kb);
          });
          return items;
        }

        // Print raw response data type for debugging
        // Handle string response that needs to be parsed as JSON
        if (response.data is String) {
          try {
            var decodedData = json.decode(response.data);
            if (decodedData is Map &&
                decodedData['status'] == 200 &&
                decodedData['data'] != null) {
              return _sortCities(List<dynamic>.from(decodedData['data'] as List));
            } else if (decodedData is List) {
              return _sortCities(List<dynamic>.from(decodedData));
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
            return _sortCities(
              List<dynamic>.from(response.data['data'] as List),
            );
          } else {
            return [];
          }
        }
        // Handle direct List response
        else if (response.data is List) {
          return _sortCities(List<dynamic>.from(response.data as List));
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

  /// Fetches a single hotel's image from flypakistan getHotelsDetails API.
  /// POST with hotel_id; response: {"status":200,"hotel_image":"https://..."}
  /// Returns the hotel_image URL or null.
  Future<String?> fetchHotelDetailImage(String hotelId) async {
    if (hotelId.isEmpty) return null;
    const String url = 'https://flypakistan.pk/api/getHotelsDetails.php';
    try {
      var requestData = FormData.fromMap({'hotel_id': hotelId});
      // Log request
      print('━━━ fetchHotelDetailImage REQUEST ━━━');
      print('URL: $url');
      print('Method: POST');
      print('Body: { hotel_id: $hotelId }');

      var dio = Dio();
      var response = await dio.request(
        url,
        options: Options(
          method: 'POST',
          headers: {'Cookie': 'PHPSESSID=tn7u2id1c3q1im57f4dcente83'},
        ),
        data: requestData,
      );
      // Log response
      print('━━━ fetchHotelDetailImage RESPONSE ━━━');
      print('Status: ${response.statusCode}');
      print('Data: ${response.data}');

      if (response.statusCode != 200) return null;
      var data = response.data;
      if (data is String) {
        try {
          data = json.decode(data); 
        } catch (e) {
          return null;
        }
      }
      if (data is! Map || data['status'] != 200) return null;
      var hotelImage = data['hotel_image']?.toString();
      if (hotelImage != null && hotelImage.isNotEmpty) {
        print('hotel_image: $hotelImage');
      }
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return (hotelImage != null && hotelImage.isNotEmpty) ? hotelImage : null;
    } catch (e) {
      print('━━━ fetchHotelDetailImage ERROR ━━━');
      print('$e');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return null;
    }
  }

  /// Fetches hotels from OUR OWN database for the same search the Arabian
  /// Hotels API is given: city, check-in, check-out and adults.
  ///
  /// Returns cards normalized into the same shape [fetchHotels] builds, so both
  /// sources can be merged into one list (see `hotel_merge_util.dart`).
  /// Never throws: on any failure it returns an empty list so the third-party
  /// results still render.
  Future<List<Map<String, dynamic>>> fetchOwnDbHotels({
    required String cityName,
    required String checkInDate,
    required String checkOutDate,
    required List<Map<String, dynamic>> rooms,
  }) async {
    final String city = _cityNameOnly(cityName);
    if (city.isEmpty) return [];

    // Same search window the third-party request uses; own-DB prices are
    // per night, so we need the nights count to build a stay total.
    final int nights = _nightsBetween(checkInDate, checkOutDate);
    final int adults = rooms.fold<int>(
      0,
      (sum, room) => sum + (int.tryParse(room['Adult']?.toString() ?? '') ?? 0),
    );

    final Map<String, dynamic> queryParameters = {
      'city': city,
      'chkin': _formatDate(checkInDate),
      'chkout': _formatDate(checkOutDate),
      'adults': (adults > 0 ? adults : 1).toString(),
    };

    const String url = 'https://flypakistan.pk/db-hotels-api.php';

    try {
      print('━━━ fetchOwnDbHotels REQUEST ━━━');
      print('URL: $url');
      print('Query: $queryParameters');

      final response = await Dio().get(
        url,
        queryParameters: queryParameters,
        options: Options(method: 'GET'),
      );

      print('━━━ fetchOwnDbHotels RESPONSE ━━━');
      print('Status: ${response.statusCode}');

      if (response.statusCode != 200) return [];

      var data = response.data;
      if (data is String) {
        try {
          data = json.decode(data);
        } catch (e) {
          return [];
        }
      }
      if (data is! Map) return [];

      final hotels = data['hotels'];
      if (hotels is! List) return [];

      print('Own DB hotels: ${hotels.length}');

      return hotels
          .whereType<Map>()
          .map((hotel) => _normalizeOwnDbHotel(hotel, nights))
          .where((hotel) => hotel['hotelCode'].toString().isNotEmpty)
          .toList();
    } catch (e) {
      print('━━━ fetchOwnDbHotels ERROR ━━━');
      print('$e');
      return [];
    }
  }

  /// Maps one own-DB hotel record onto the card shape used by the listing.
  Map<String, dynamic> _normalizeOwnDbHotel(Map hotel, int nights) {
    // 'price_after_margin' is a per-night PKR rate already carrying our margin,
    // so no ROE/margin conversion here. The card divides by nights to show a
    // nightly rate, so store the stay total like the third-party 'price' does.
    final double perNight =
        double.tryParse(hotel['price_after_margin']?.toString() ?? '') ?? 0.0;

    // Own-DB records ship a full, already percent-encoded image URL. Keep it
    // verbatim — some paths legitimately contain '&amp;' / '%E2%80%99', so it
    // must NOT be HTML-unescaped. The few records with no image fall through to
    // fetchHotelDetailImage and then the placeholder asset.
    final String image = hotel['image']?.toString() ?? '';
    final bool imageIsUsable = image.startsWith('http') || image.startsWith('/');

    final String address = _unescapeHtml(hotel['address']?.toString() ?? '');

    return {
      'name': _unescapeHtml(hotel['hotel_name']?.toString() ?? 'Unknown Hotel'),
      'price': perNight * nights,
      'address': address.isEmpty ? 'Address not available' : address,
      'image': imageIsUsable ? image : '',
      'rating': double.tryParse(hotel['rating']?.toString() ?? '') ?? 3.0,
      // Kept as strings: the controller stores lat/lon in RxString fields.
      'latitude': (hotel['lat'] ?? '').toString(),
      'longitude': (hotel['lon'] ?? '').toString(),
      'hotelCode': hotel['hotel_id']?.toString().trim() ?? '',
      'hotelCity': hotel['cs_city']?.toString() ?? '',
      // 'link' carries the exact `hid` token the details API expects, e.g.
      // 'hotel.php?hotelname=Serena+Hotel&hid=MklUU01ZX1NFQ1JFVF9WQUxVRUNPREU='.
      // Kept so the room-details call reuses it instead of rebuilding the token.
      'ownDetailLink': hotel['link']?.toString() ?? '',
      'roomsGstPercent':
          int.tryParse(hotel['rooms_gst']?.toString() ?? '') ?? 0,
      // Hotels sold "price on call" come back with price 0; the card shows the
      // text instead of an amount (see `isPriceOnCall`).
      'priceOnCall':
          hotel['price_on_call'] == true ||
          hotel['price_on_call']?.toString() == '1',
      'source': kHotelSourceOwn,
    };
  }

  Future<void> fetchHotels({
    required String destinationCode,
    required String countryCode,
    required String nationality,
    required String currency,
    required String checkInDate,
    required String checkOutDate,
    required List<Map<String, dynamic>> rooms,
    String? cityId,
    String? cityName,
  }) async {
    final searchController = Get.find<SearchHotelController>();

    // Set loading state
    searchController.isLoading.value = true;
    // Clear per-hotel images from previous search so we fetch again for new results
    searchController.hotelImagesByCode.value = {};
    searchController.clearHotelImageLoading();

    try {
      await fetchMarginAndROE();

      // Our own-DB hotels are fetched with the SAME search parameters, in
      // parallel with the Arabian request. It never throws, so a failure there
      // just leaves the third-party results untouched.
      final Future<List<Map<String, dynamic>>> ownHotelsFuture =
          fetchOwnDbHotels(
            cityName: cityName ?? '',
            checkInDate: checkInDate,
            checkOutDate: checkOutDate,
            rooms: rooms,
          );

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

      final response = await dio.post(
        '/hotel/Search',
        data: requestBody,
        options: _defaultHeaders(),
      );
      if (response.statusCode == 200) {
        final data = response.data;
        final hotels = data['hotels']?['hotel'] ?? [];
        final sessionId = data['generalInfo']?['sessionId'];
        final destinationCode = data['audit']?['destination']['code'];

        searchController.sessionId.value = sessionId ?? '';
        searchController.destinationCode.value = destinationCode ?? '';

        final List<Map<String, dynamic>> thirdPartyHotels =
            hotels.map<Map<String, dynamic>>((hotel) {
          double originalPrice = double.tryParse(hotel['minPrice']?.toString() ?? '0') ?? 0;
          double finalPrice = applyPricingLogic(originalPrice);
          String hotelCode = hotel['code']?.toString() ?? '';
          // Default image from search API; per-hotel image fetched on scroll via fetchHotelDetailImage
          String imageUrl = hotel['hotelInfo']?['image'] ?? '';

          return {
            'name': hotel['name'] ?? 'Unknown Hotel',
            'price': finalPrice,
            'address': hotel['hotelInfo']?['add1'] ?? 'Address not available',
            'image': imageUrl,
            'rating': double.tryParse(hotel['hotelInfo']?['starRating']?.toString() ?? '0') ?? 3.0,
            'latitude': hotel['hotelInfo']?['lat'] ?? 0.0,
            'longitude': hotel['hotelInfo']?['lon'] ?? 0.0,
            'hotelCode': hotelCode,
            'hotelCity': hotel['hotelInfo']?['city'] ?? '',
            'source': kHotelSourceThirdParty,
          };
        }).toList();

        // Own-DB records override the third-party entry for the same hotel id;
        // own-only hotels are appended. Only the 'source' flag differs.
        final List<Map<String, dynamic>> ownHotels = await ownHotelsFuture;
        searchController.hotels.value = mergeHotelLists(
          thirdPartyHotels: thirdPartyHotels,
          ownHotels: ownHotels,
        );

        // Initialize filter data after hotels are loaded
        searchController.filterhotler();
      }
    } catch (e) {
      // Error fetching hotels
      rethrow;
    } finally {
      // Set loading state to false when done
      searchController.isLoading.value = false;
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
        'https://flypakistan.pk/api/hotel-details',
        options: Options(
          method: 'POST',
          headers: headers,
        ),
        data: data,
      );

      if (response.statusCode == 200) {
        if (response.data is String) {
          try {
            var decodedData = json.decode(response.data);
            return decodedData as Map<String, dynamic>?;
          } catch (e) {
            return null;
          }
        } else if (response.data is Map<String, dynamic>) {
          return response.data as Map<String, dynamic>?;
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Updated fetchRoomDetails method with margin and ROE
  Future<void> fetchRoomDetails(String hotelCode, String sessionId) async {
  final guestsController = Get.find<GuestsController>();
  final searchController = Get.find<SearchHotelController>();

  // Third-party rooms: availability is validated with PreBook before booking.
  searchController.isOwnDbHotel.value = false;
  searchController.ownHotelGstPercent.value = 0;

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
      print(data);

      final hotelInfo = data['hotel']?['hotelInfo'];
      final roomData = data['hotel']?['rooms']?['room'];

      if (hotelInfo == null || roomData == null || (roomData is List && roomData.isEmpty)) {
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
    } else {
      searchController.roomsdata.value = [];
    }
  } catch (e) {
    searchController.roomsdata.value = [];
  }
}

  /// Loads the rooms of the tapped hotel card from the right source.
  ///
  /// Own-DB cards (`source == kHotelSourceOwn`) have no third-party session or
  /// hotel code on the Arabian side, so they are loaded from
  /// hotel-details-api.php. Everything else keeps the existing RoomDetails call.
  Future<void> fetchRoomsForHotel(Map<dynamic, dynamic> hotel) async {
    // Opening a new hotel: drop the rooms/policies selected on the previous one
    // so nothing stale (rate type, room id, price) reaches the booking request.
    if (Get.isRegistered<SelectRoomController>()) {
      Get.find<SelectRoomController>().clearData();
    }

    final int nights =
        Get.isRegistered<HotelDateController>()
            ? Get.find<HotelDateController>().nights.value
            : 1;

    if (isOwnHotel(hotel)) {
      await fetchOwnDbRoomDetails(
        hotelId: hotel['hotelCode']?.toString() ?? '',
        hotelName: hotel['name']?.toString() ?? '',
        latitude: hotel['latitude']?.toString() ?? '',
        longitude: hotel['longitude']?.toString() ?? '',
        detailLink: hotel['ownDetailLink']?.toString() ?? '',
        nights: nights > 0 ? nights : 1,
      );
      return;
    }

    await fetchRoomDetails(
      hotel['hotelCode']?.toString() ?? '',
      Get.find<SearchHotelController>().sessionId.value,
    );
  }

  /// The `hid` token hotel-details-api.php expects.
  ///
  /// The listing endpoint already ships it inside `link`
  /// (`hotel.php?...&hid=<token>`), so that value is reused when present.
  /// Otherwise it is rebuilt: base64 of `<hotel_id>ITSMY_SECRET_VALUECODE`.
  String _ownDbHid(String hotelId, String detailLink) {
    if (detailLink.isNotEmpty) {
      // Read it raw: the token is base64 and may contain '+', which query-string
      // decoding would turn into a space.
      final match = RegExp(r'[?&]hid=([^&]*)').firstMatch(detailLink);
      final String? fromLink = match?.group(1);
      if (fromLink != null && fromLink.isNotEmpty) return fromLink;
    }
    return base64Encode(utf8.encode('${hotelId}ITSMY_SECRET_VALUECODE'));
  }

  /// Fetches hotel + rooms of ONE own-database hotel and puts the rooms into
  /// `SearchHotelController.roomsdata` in the same shape the select-room screen
  /// already renders for third-party rooms.
  ///
  /// Never throws: on any failure `roomsdata` is left empty and the screen shows
  /// its "No Rooms Available" state.
  Future<void> fetchOwnDbRoomDetails({
    required String hotelId,
    required String hotelName,
    required String latitude,
    required String longitude,
    required int nights,
    String detailLink = '',
  }) async {
    final searchController = Get.find<SearchHotelController>();

    // Own-DB rooms are booked directly — no PreBook / availability round-trip.
    searchController.isOwnDbHotel.value = true;
    searchController.ownHotelGstPercent.value = 0;
    searchController.roomsdata.value = [];

    const String url = 'https://flypakistan.pk/api/hotel-details-api.php';
    final Map<String, dynamic> queryParameters = {
      'hotelname': hotelName,
      'hid': _ownDbHid(hotelId, detailLink),
      'lat': latitude,
      'long': longitude,
    };

    try {
      print('━━━ fetchOwnDbRoomDetails REQUEST ━━━');
      print('URL: $url');
      print('Query: $queryParameters');

      final response = await Dio().get(url, queryParameters: queryParameters);

      print('━━━ fetchOwnDbRoomDetails RESPONSE ━━━');
      print('Status: ${response.statusCode}');

      if (response.statusCode != 200) return;

      var data = response.data;
      if (data is String) {
        try {
          data = json.decode(data);
        } catch (e) {
          return;
        }
      }
      if (data is! Map || data['status']?.toString() != 'success') return;

      final payload = data['data'];
      if (payload is! Map) return;

      final hotel = payload['hotel'];
      final images = payload['images'];
      final rooms = payload['rooms'];

      // Header of the select-room screen.
      searchController.hotelName.value = _unescapeHtml(
        (hotel is Map ? hotel['name']?.toString() : null) ?? hotelName,
      );
      if (images is List && images.isNotEmpty) {
        searchController.image.value = images.first?.toString() ?? '';
      }
      if (hotel is Map) {
        final int starRating =
            int.tryParse(hotel['star_rating']?.toString() ?? '') ?? 0;
        if (starRating > 0) searchController.ratingstar.value = starRating;

        final String address = _unescapeHtml(hotel['address']?.toString() ?? '');
        if (address.isNotEmpty) searchController.hotelAddress.value = address;

        final status = hotel['status'];
        if (status is Map) {
          searchController.ownHotelGstPercent.value =
              int.tryParse(status['rooms_gst_percent']?.toString() ?? '') ?? 0;
        }
      }

      if (rooms is! List) return;

      final List<Map<String, dynamic>> normalized =
          rooms
              .whereType<Map>()
              .map(
                (room) => _normalizeOwnDbRoom(
                  room,
                  nights,
                  searchController.ownHotelGstPercent.value,
                ),
              )
              // Sold-out rooms must not be bookable: there is no availability
              // check later in the own-DB flow.
              .where((room) => (room['availableQuantity'] as int) > 0)
              .toList();

      print('Own DB rooms: ${normalized.length}');
      searchController.roomsdata.value = normalized;
    } catch (e) {
      print('━━━ fetchOwnDbRoomDetails ERROR ━━━');
      print('$e');
      searchController.roomsdata.value = [];
    }
  }

  /// Maps one own-DB room record onto the room shape the select-room screen and
  /// [SelectRoomController] read (`roomName`, `meal`, `rateType`, `price.net`).
  ///
  /// `price` is a per-night PKR rate that already carries our margin — it is the
  /// same number the listing shows as `price_after_margin` — so no ROE/margin
  /// conversion here. `price.net` holds the stay total because the room card
  /// divides by nights to display the nightly rate.
  Map<String, dynamic> _normalizeOwnDbRoom(
    Map room,
    int nights,
    int gstPercent,
  ) {
    final double perNight =
        double.tryParse(room['price']?.toString() ?? '') ?? 0.0;
    final double stayTotal = perNight * nights;

    final capacity = room['capacity'] is Map ? room['capacity'] as Map : const {};

    // '0' means no free cancellation on the own-DB side.
    final String cancellationPolicy =
        room['cancellation_policy']?.toString().trim() ?? '0';
    final bool isRefundable =
        cancellationPolicy.isNotEmpty &&
        cancellationPolicy != '0' &&
        cancellationPolicy.toLowerCase() != 'non-refundable';

    final String meal = room['meal']?.toString().trim() ?? '';

    return <String, dynamic>{
      'roomName': _unescapeHtml(room['name']?.toString().trim() ?? 'Room'),
      'meal': (meal.isEmpty || meal.toLowerCase() == 'none') ? 'Room Only' : meal,
      'rateType': isRefundable ? 'Refundable' : 'Non-Refundable',
      'price': {'net': stayTotal, 'gross': stayTotal},
      'perNightPrice': perNight,
      'roomId': room['id']?.toString() ?? '',
      'availableQuantity':
          int.tryParse(room['available_quantity']?.toString() ?? '') ?? 0,
      'maxAdults': int.tryParse(capacity['max_adults']?.toString() ?? '') ?? 0,
      'maxChilds': int.tryParse(capacity['max_childs']?.toString() ?? '') ?? 0,
      'extraBedPrice':
          double.tryParse(capacity['extra_bed_price']?.toString() ?? '') ?? 0.0,
      'sizeSqm': room['size_sqm']?.toString() ?? '',
      'image': room['image']?.toString() ?? '',
      'cancellationPolicy': cancellationPolicy,
      'gstPercent': gstPercent,
      'source': kHotelSourceOwn,
    };
  }

  /// Pre-book a room.
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

    const String bookingEndpoint = 'https://flypakistan.pk/api/create-hotel-booking';

    try {
      // Log request
      print('━━━ bookHotel REQUEST ━━━');
      print('URL: $bookingEndpoint');
      print('Body: ${jsonEncode(requestBody)}');

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

      // Log response
      print('━━━ bookHotel RESPONSE ━━━');
      print('Status: ${response.statusCode}');
      print('Data: ${response.data}');

      if (response.data != null) {
        final decoded = response.data is String
            ? jsonDecode(response.data)
            : response.data;

        if (decoded is Map && decoded['BookingNO'] != null) {
          String bookingStr = decoded['BookingNO'].toString();
          bookingStr = bookingStr.replaceAll('SHBK-', '');
          bookingcontroller.booking_num.value = int.tryParse(bookingStr) ?? 0;
          return true;
        }
      }

      return false;
    } on DioException catch (e) {
      print('━━━ bookHotel DIO ERROR ━━━');
      print('Message: ${e.message}');
      if (e.response != null) {
        print('Status: ${e.response?.statusCode}');
        print('Data: ${e.response?.data}');
      }
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return false;
    } catch (e, st) {
      print('━━━ bookHotel ERROR ━━━');
      print(e);
      print(st);
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return false;
    }
  }
}