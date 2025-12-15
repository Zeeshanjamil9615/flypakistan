// airarabia_flight_controller.dart
import 'package:get/get.dart';

import '../../../../services/api_service_airarabia.dart';
import '../../../users/login/login_api_service/login_api.dart';
import '../filters/filter_flight_model.dart';
import '../flight_package/airarabia/airarabia_flight_package.dart';
import '../../form/flight_booking_controller.dart';
import 'airarabia_flight_model.dart';

class AirArabiaFlightController extends GetxController {
  
  final ApiServiceAirArabia apiService = Get.find<ApiServiceAirArabia>();
  int selectedPackageIndex = 0;

  final RxList<AirArabiaFlight> flights = <AirArabiaFlight>[].obs;
  final RxList<AirArabiaFlight> filteredFlights = <AirArabiaFlight>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString sortType = 'Suggested'.obs;

  // Margin data storage
  final Rx<Map<String, dynamic>> marginData = Rx<Map<String, dynamic>>({});
  final RxBool isLoadingMargin = false.obs;

  // Selected flight and package for booking
  AirArabiaFlight? selectedFlight;
  AirArabiaPackage? selectedPackage;

  @override
  void onInit() {
    super.onInit();
    _fetchMarginData();
  }

  // Fetch margin data on controller initialization
  Future<void> _fetchMarginData() async {
    try {
      isLoadingMargin.value = true;
      
      // Check if user is logged in
      final authController = Get.find<AuthController>();
      final isLoggedIn = await authController.isLoggedIn();
      
      String? userEmail;
      if (isLoggedIn) {
        final userData = await authController.getUserData();
        userEmail = userData?['cs_email'];
        print('Fetching Air Arabia margin for logged-in user: $userEmail');
      } else {
        print('Fetching Air Arabia margin for guest user (default margin)');
      }

      // Fetch margin data
      final margin = await apiService.getAirArabiaMargin(userEmail);
      marginData.value = margin;
      
      print('Air Arabia Margin Data: $margin');
      
      // Validate margin data
      final marginVal = double.tryParse(margin['margin_val']?.toString() ?? '0') ?? 0.0;
      final marginPer = double.tryParse(margin['margin_per']?.toString() ?? '0') ?? 0.0;
      
      if (marginVal == 0 && marginPer == 0) {
        print('Warning: Both margin values are zero');
      }
      
    } catch (e) {
      print('Error fetching Air Arabia margin: $e');
      // Set default margin on error
      marginData.value = {
        'margin_val': '0.00',
        'margin_per': 0,
      };
    } finally {
      isLoadingMargin.value = false;
    }
  }

  // Calculate flight price with margin
  double calculateFlightPriceWithMargin(double basePrice) {
    if (marginData.value.isEmpty) {
      return basePrice;
    }
    return apiService.calculatePriceWithMargin(basePrice, marginData.value);
  }

  void clearFlights() {
    flights.clear();
    filteredFlights.clear();
    errorMessage.value = '';
  }

  void setErrorMessage(String message) {
    errorMessage.value = message;
  }

  Future<void> loadFlights(Map<String, dynamic> apiResponse) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      flights.clear();

      if (apiResponse['status'] != 200) {
        throw Exception(apiResponse['message'] ?? 'Failed to load flights');
      }

      final data = apiResponse['data'];
      final ondWiseFlights = data['ondWiseFlightCombinations'];

      // Check if this is a round trip (has both outbound and inbound flights)
      final isRoundTrip = ondWiseFlights.keys.length > 1;

      if (isRoundTrip) {
        // Handle round trip flights
        _processRoundTripFlights(ondWiseFlights);
      } else {
        // Handle one-way flights (original logic)
        _processOneWayFlights(ondWiseFlights);
      }

      // Apply margin to all flights
      _applyMarginToFlights();

      // Initialize filtered flights with all flights
      filteredFlights.value = List.from(flights);

      // Apply any existing filters immediately
      _applySortingAndFiltering();

    } catch (e) {
      errorMessage.value = 'Failed to load Air Arabia flights: $e';
    } finally {
      isLoading.value = false;
    }
  }

  // Apply margin to all loaded flights
  void _applyMarginToFlights() {
    if (marginData.value.isEmpty) {
      print('Warning: Margin data not loaded yet');
      return;
    }

    for (int i = 0; i < flights.length; i++) {
      final flight = flights[i];
      final priceWithMargin = calculateFlightPriceWithMargin(flight.price);
      
      // Update flight price with margin
      flights[i] = AirArabiaFlight(
        id: flight.id,
        price: priceWithMargin,
        currency: flight.currency,
        flightSegments: flight.flightSegments,
        airlineCode: flight.airlineCode,
        airlineName: flight.airlineName,
        airlineImg: flight.airlineImg,
        cabinClass: flight.cabinClass,
        isRefundable: flight.isRefundable,
        availabilityStatus: flight.availabilityStatus,
        isRoundTrip: flight.isRoundTrip,
        outboundFlight: flight.outboundFlight,
        inboundFlight: flight.inboundFlight,
      );
    }
    
    print('Applied margin to ${flights.length} flights');
  }

  void _processOneWayFlights(Map<String, dynamic> ondWiseFlights) {
    // Check if this is multicity
    final bookingController = Get.find<FlightBookingController>();
    final isMultiCity = bookingController.tripType.value == TripType.multiCity;
    
    // Process all flights normally
    ondWiseFlights.forEach((route, dateWiseFlights) {
      final dateFlights = dateWiseFlights['dateWiseFlightCombinations'];
      dateFlights.forEach((date, flightData) {
        final flightOptions = flightData['flightOptions'];
        for (var option in flightOptions) {
          if (option['availabilityStatus'] == 'AVAILABLE') {
            try {
              final flight = AirArabiaFlight.fromJson(option);
              
              // For multicity, reorder segments to match cityPairs order
              if (isMultiCity && bookingController.cityPairs.length > 1) {
                final reorderedFlight = _reorderSegmentsForMultiCity(flight, bookingController);
                flights.add(reorderedFlight);
              } else {
                flights.add(flight);
              }
            } catch (e) {
              // Skip invalid flight options
            }
          }
        }
      });
    });
  }

  AirArabiaFlight _reorderSegmentsForMultiCity(AirArabiaFlight flight, FlightBookingController bookingController) {
    // Reorder segments to match cityPairs order
    final reorderedSegments = <Map<String, dynamic>>[];
    final usedSegmentIndices = <int>{};
    
    print('\n🔄 ===== REORDERING SEGMENTS FOR MULTICITY =====');
    print('   Flight has ${flight.flightSegments.length} segments');
    print('   CityPairs: ${bookingController.cityPairs.length}');
    
    // Print all segments for debugging
    print('\n   Original segments:');
    for (int i = 0; i < flight.flightSegments.length; i++) {
      final segment = flight.flightSegments[i];
      final depAirport = segment['departure']?['airport']?.toString().toUpperCase().trim() ?? '';
      final arrAirport = segment['arrival']?['airport']?.toString().toUpperCase().trim() ?? '';
      final depTime = segment['departure']?['dateTime']?.toString() ?? '';
      print('     [$i] $depAirport -> $arrAirport (${depTime.substring(0, depTime.length > 10 ? 10 : depTime.length)})');
    }
    
    // Print cityPairs
    print('\n   CityPairs (search order):');
    for (int i = 0; i < bookingController.cityPairs.length; i++) {
      final cityPair = bookingController.cityPairs[i];
      final fromCity = cityPair.fromCity.value.toUpperCase().trim();
      final toCity = cityPair.toCity.value.toUpperCase().trim();
      final date = cityPair.departureDate.value;
      print('     [$i] $fromCity -> $toCity ($date)');
    }
    
    // Match each cityPair to a segment
    print('\n   Matching segments to cityPairs:');
    for (int i = 0; i < bookingController.cityPairs.length; i++) {
      final cityPair = bookingController.cityPairs[i];
      final fromCity = cityPair.fromCity.value.toUpperCase().trim();
      final toCity = cityPair.toCity.value.toUpperCase().trim();
      final cityPairDate = cityPair.departureDate.value;
      
      print('   CityPair $i: Looking for $fromCity -> $toCity (date: $cityPairDate)');
      
      // Find segment that matches this cityPair (not already used)
      Map<String, dynamic>? matchingSegment;
      int matchingIndex = -1;
      int bestDateMatchIndex = -1;
      DateTime? bestDateMatch;
      
      for (int j = 0; j < flight.flightSegments.length; j++) {
        if (usedSegmentIndices.contains(j)) {
          continue;
        }
        
        final segment = flight.flightSegments[j];
        final depAirport = (segment['departure']?['airport']?.toString() ?? '').toUpperCase().trim();
        final arrAirport = (segment['arrival']?['airport']?.toString() ?? '').toUpperCase().trim();
        final depDateTime = segment['departure']?['dateTime']?.toString() ?? '';
        
        print('     Checking segment $j: $depAirport -> $arrAirport (${depDateTime.substring(0, depDateTime.length > 10 ? 10 : depDateTime.length)})');
        
        // Exact match (airport codes)
        if (depAirport == fromCity && arrAirport == toCity) {
          // Also try to match by date if possible
          try {
            final segmentDate = DateTime.parse(depDateTime);
            final cityPairDateTime = DateTime.parse(cityPairDate);
            final dateDiff = (segmentDate.difference(cityPairDateTime).inDays).abs();
            
            if (dateDiff <= 1) { // Allow 1 day difference
              matchingSegment = segment;
              matchingIndex = j;
              print('     ✅ EXACT MATCH (with date) found at index $j');
              break;
            } else {
              // Store as potential match if no exact date match found
              if (matchingSegment == null) {
                matchingSegment = segment;
                matchingIndex = j;
                print('     ⚠️ Airport match but date differs by $dateDiff days');
              }
            }
          } catch (e) {
            // If date parsing fails, use airport match
            matchingSegment = segment;
            matchingIndex = j;
            print('     ✅ EXACT MATCH (airport only) found at index $j');
            break;
          }
        }
      }
      
      if (matchingSegment != null && matchingIndex != -1) {
        reorderedSegments.add(matchingSegment);
        usedSegmentIndices.add(matchingIndex);
        print('     ✅ Added segment $matchingIndex to position $i');
      } else {
        print('     ❌ NO MATCH found for cityPair $i: $fromCity -> $toCity');
        // If no match found, try to use next unused segment as fallback
        for (int j = 0; j < flight.flightSegments.length; j++) {
          if (!usedSegmentIndices.contains(j)) {
            print('     ⚠️ Using segment $j as fallback');
            reorderedSegments.add(flight.flightSegments[j]);
            usedSegmentIndices.add(j);
            break;
          }
        }
      }
    }
    
    // If we couldn't reorder all segments, try fallback: sort by departure date
    if (reorderedSegments.length != bookingController.cityPairs.length || 
        reorderedSegments.length != flight.flightSegments.length) {
      print('\n⚠️ WARNING: Could not reorder all segments by matching.');
      print('   Expected: ${bookingController.cityPairs.length}, Got: ${reorderedSegments.length}');
      print('   Flight segments: ${flight.flightSegments.length}');
      print('   Trying fallback: sort by departure date to match cityPairs...');
      
      // Fallback: sort segments by departure date to match cityPairs order
      final sortedSegments = <Map<String, dynamic>>[];
      final remainingSegments = <Map<String, dynamic>>[];
      
      // Get all unused segments
      for (int i = 0; i < flight.flightSegments.length; i++) {
        if (!usedSegmentIndices.contains(i)) {
          remainingSegments.add(flight.flightSegments[i]);
        }
      }
      
      // Sort remaining segments by departure date
      remainingSegments.sort((a, b) {
        try {
          final dateA = DateTime.parse(a['departure']?['dateTime'] ?? '');
          final dateB = DateTime.parse(b['departure']?['dateTime'] ?? '');
          return dateA.compareTo(dateB);
        } catch (e) {
          return 0;
        }
      });
      
      // Combine reordered segments with sorted remaining segments
      sortedSegments.addAll(reorderedSegments);
      sortedSegments.addAll(remainingSegments);
      
      if (sortedSegments.length == flight.flightSegments.length) {
        print('   ✅ Fallback sorting successful');
        reorderedSegments.clear();
        reorderedSegments.addAll(sortedSegments);
      } else {
        print('   ❌ Fallback also failed. Using original order.');
        print('==========================================\n');
        return flight;
      }
    }
    
    print('\n   Reordered segments:');
    for (int i = 0; i < reorderedSegments.length; i++) {
      final segment = reorderedSegments[i];
      final depAirport = segment['departure']?['airport']?.toString().toUpperCase().trim() ?? '';
      final arrAirport = segment['arrival']?['airport']?.toString().toUpperCase().trim() ?? '';
      print('     [$i] $depAirport -> $arrAirport');
    }
    
    print('✅ Successfully reordered ${reorderedSegments.length} segments');
    print('==========================================\n');
    
    // Create new flight with reordered segments
    return AirArabiaFlight(
      id: flight.id,
      price: flight.price,
      currency: flight.currency,
      flightSegments: reorderedSegments,
      airlineCode: flight.airlineCode,
      airlineName: flight.airlineName,
      airlineImg: flight.airlineImg,
      cabinClass: flight.cabinClass,
      isRefundable: flight.isRefundable,
      availabilityStatus: flight.availabilityStatus,
      isRoundTrip: flight.isRoundTrip,
      outboundFlight: flight.outboundFlight,
      inboundFlight: flight.inboundFlight,
    );
  }

  void _processRoundTripFlights(Map<String, dynamic> ondWiseFlights) {
    final routes = ondWiseFlights.keys.toList();
    final outboundRoute = routes[1];
    
    final outboundFlights = <Map<String, dynamic>>[];
    final inboundFlights = <Map<String, dynamic>>[];

    ondWiseFlights.forEach((route, dateWiseFlights) {
      final dateFlights = dateWiseFlights['dateWiseFlightCombinations'];

      dateFlights.forEach((date, flightData) {
        final flightOptions = flightData['flightOptions'];
        for (var option in flightOptions) {
          if (option['availabilityStatus'] == 'AVAILABLE') {
            final isOutbound = route == outboundRoute;

            if (isOutbound) {
              outboundFlights.add(option);
            } else {
              inboundFlights.add(option);
            }
          }
        }
      });
    });

    if (outboundFlights.isEmpty || inboundFlights.isEmpty) {
      errorMessage.value = 'Incomplete round trip options available';
      return;
    }

    for (var outbound in outboundFlights) {
      outbound['isOutbound'] = true;
      for (var inbound in inboundFlights) {
        inbound['isOutbound'] = false;
        try {
          final combinedFlight = _createRoundTripPackage(outbound, inbound);
          flights.add(combinedFlight);
        } catch (e) {
          // Skip invalid combinations
        }
      }
    }
  }

  AirArabiaFlight _createRoundTripPackage(
      Map<String, dynamic> outbound,
      Map<String, dynamic> inbound
  ) {
    final combinedSegments = [
      ...outbound['flightSegments'],
      ...inbound['flightSegments']
    ];

    final outboundPrice = outbound['cabinPrices'][0]['price'] as num;
    final inboundPrice = inbound['cabinPrices'][0]['price'] as num;
    final totalPrice = outboundPrice + inboundPrice;

    final combinedOption = {
      ...outbound,
      'flightSegments': combinedSegments,
      'cabinPrices': [
        {
          ...outbound['cabinPrices'][0],
          'price': totalPrice,
        }
      ],
      'isRoundTrip': true,
      'outboundFlight': outbound,
      'inboundFlight': inbound,
    };

    return AirArabiaFlight.fromJson(combinedOption);
  }

  void handleAirArabiaFlightSelection(AirArabiaFlight flight) {
    Get.to(
      () => AirArabiaPackageSelectionDialog(
        flight: flight,
        isReturnFlight: false,
      ),
    );
  }

  void applyFilters({
    List<String>? airlines,
    List<String>? stops,
    String? sortType,
  }) {
    if (sortType != null) {
      this.sortType.value = sortType;
    }
    _applySortingAndFiltering(airlines: airlines, stops: stops);
  }

  void _applySortingAndFiltering({
    List<String>? airlines,
    List<String>? stops,
  }) {
    List<AirArabiaFlight> filtered = List.from(flights);

    if (airlines != null && !airlines.contains('all')) {
      filtered = filtered.where((flight) {
        return airlines.any((airlineCode) =>
            flight.airlineCode.toUpperCase() == airlineCode.toUpperCase()
        );
      }).toList();
    }

    if (stops != null && !stops.contains('all')) {
      filtered = filtered.where((flight) {
        int stopCount = flight.flightSegments.length - 1;

        if (stops.contains('nonstop')) {
          return stopCount == 0;
        }
        if (stops.contains('1stop')) {
          return stopCount == 1;
        }
        if (stops.contains('2stop')) {
          return stopCount == 2;
        }
        if (stops.contains('3stop')) {
          return stopCount == 3;
        }
        return false;
      }).toList();
    }

    switch (sortType.value) {
      case 'Cheapest':
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Fastest':
        filtered.sort((a, b) => a.totalDuration.compareTo(b.totalDuration));
        break;
      case 'Suggested':
      default:
        break;
    }

    filteredFlights.value = filtered;
  }

  List<AirArabiaFlight> getFlightsByAirline(String airlineCode) {
    return flights.where((flight) {
      return flight.airlineCode.toUpperCase() == airlineCode.toUpperCase();
    }).toList();
  }

  int getFlightCountByAirline(String airlineCode) {
    return getFlightsByAirline(airlineCode).length;
  }

  List<FilterAirline> getAvailableAirlines() {
    if (flights.isEmpty) return [];

    return [
      FilterAirline(
        code: 'G9',
        name: 'Air Arabia',
        logoPath: 'https://images.kiwi.com/airlines/64/G9.png',
      )
    ];
  }
}