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
      }

      // Fetch margin data
      final margin = await apiService.getAirArabiaMargin(userEmail);
      marginData.value = margin;
      
      // Validate margin data
      final marginVal = double.tryParse(margin['margin_val']?.toString() ?? '0') ?? 0.0;
      final marginPer = double.tryParse(margin['margin_per']?.toString() ?? '0') ?? 0.0;
      
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

      // Check trip type from booking controller to distinguish round trip from multicity
      final bookingController = Get.find<FlightBookingController>();
      final isMultiCity = bookingController.tripType.value == TripType.multiCity;
      final isRoundTrip = bookingController.tripType.value == TripType.roundTrip && 
                          ondWiseFlights.keys.length > 1;

      if (isRoundTrip) {
        // Handle round trip flights
        _processRoundTripFlights(ondWiseFlights);
      } else if (isMultiCity) {
        // Handle multicity flights - combine segments from multiple routes
        _processMultiCityFlights(ondWiseFlights, bookingController);
      } else {
        // Handle one-way flights
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
  }

  void _processOneWayFlights(Map<String, dynamic> ondWiseFlights) {
    // Process all flights normally (one-way only)
    ondWiseFlights.forEach((route, dateWiseFlights) {
      final dateFlights = dateWiseFlights['dateWiseFlightCombinations'];
      dateFlights.forEach((date, flightData) {
        final flightOptions = flightData['flightOptions'];
        for (var option in flightOptions) {
          if (option['availabilityStatus'] == 'AVAILABLE') {
            try {
              final flight = AirArabiaFlight.fromJson(option);
              flights.add(flight);
            } catch (e) {
              // Skip invalid flight options
            }
          }
        }
      });
    });
  }

  void _processMultiCityFlights(Map<String, dynamic> ondWiseFlights, FlightBookingController bookingController) {
    // Build route keys in cityPairs order to ensure correct segment order
    final orderedRoutes = <String>[];
    for (var cityPair in bookingController.cityPairs) {
      final routeKey = '${cityPair.fromCity.value}/${cityPair.toCity.value}';
      if (ondWiseFlights.containsKey(routeKey)) {
        orderedRoutes.add(routeKey);
      }
    }
    
    // Also add any routes not in cityPairs (fallback)
    for (var route in ondWiseFlights.keys) {
      if (!orderedRoutes.contains(route)) {
        orderedRoutes.add(route);
      }
    }
    
    // Collect all flight options from all routes, grouped by date combinations
    final flightOptionsByDate = <String, List<Map<String, dynamic>>>{};
    
    // Process routes in the correct order
    for (var route in orderedRoutes) {
      final dateWiseFlights = ondWiseFlights[route];
      if (dateWiseFlights == null) continue;
      
      final dateFlights = dateWiseFlights['dateWiseFlightCombinations'];
      dateFlights.forEach((date, flightData) {
        final flightOptions = flightData['flightOptions'];
        for (var option in flightOptions) {
          if (option['availabilityStatus'] == 'AVAILABLE') {
            // Create a unique key based on date combination
            final dateKey = date;
            if (!flightOptionsByDate.containsKey(dateKey)) {
              flightOptionsByDate[dateKey] = [];
            }
            flightOptionsByDate[dateKey]!.add(option);
          }
        }
      });
    }
    
    // Now combine flight options from different routes into single flights
    // For multicity, we need to create cartesian product of all route combinations
    // But for simplicity, let's combine segments from routes in order
    if (flightOptionsByDate.isEmpty) {
      return;
    }
    
    // Get the first date (or combine all dates)
    final firstDate = flightOptionsByDate.keys.first;
    final flightOptionsForDate = flightOptionsByDate[firstDate]!;
    
    // For each flight option from first route, try to combine with options from other routes
    // Simplified: just take first option from each route and combine segments
    final List<Map<String, dynamic>> segmentsToCombine = [];
    double totalPrice = 0.0;
    
    for (var route in orderedRoutes) {
      final dateWiseFlights = ondWiseFlights[route];
      if (dateWiseFlights == null) continue;
      
      final dateFlights = dateWiseFlights['dateWiseFlightCombinations'];
      bool foundOption = false;
      
      dateFlights.forEach((date, flightData) {
        if (foundOption) return;
        final flightOptions = flightData['flightOptions'];
        for (var option in flightOptions) {
          if (option['availabilityStatus'] == 'AVAILABLE' && !foundOption) {
            // Add segments from this route
            final routeSegmentsRaw = option['flightSegments'] as List? ?? [];
            final routeSegments = routeSegmentsRaw
                .map((seg) => Map<String, dynamic>.from(seg as Map))
                .toList();
            segmentsToCombine.addAll(routeSegments);
            
            // Add price
            final cabinPrices = option['cabinPrices'] as List?;
            if (cabinPrices != null && cabinPrices.isNotEmpty) {
              final price = (cabinPrices[0]['price'] as num?)?.toDouble() ?? 0.0;
              totalPrice += price;
            }
            
            foundOption = true;
          }
        }
      });
    }
    
    if (segmentsToCombine.isNotEmpty) {
      // Create combined flight option
      final combinedOption = {
        'flightSegments': segmentsToCombine,
        'cabinPrices': [{
          'cabinClass': 'Y',
          'fareFamily': 'Y',
          'price': totalPrice,
          'availabilityStatus': 'AVAILABLE',
        }],
        'availabilityStatus': 'AVAILABLE',
      };
      
      try {
        final flight = AirArabiaFlight.fromJson(combinedOption);
        
        // Reorder segments to match cityPairs order
        final reorderedFlight = _reorderSegmentsForMultiCity(flight, bookingController);
        flights.add(reorderedFlight);
      } catch (e) {
        print('Error creating combined flight: $e');
      }
    }
  }

  AirArabiaFlight _reorderSegmentsForMultiCity(AirArabiaFlight flight, FlightBookingController bookingController) {
    // Reorder segments to match cityPairs order
    var originalSegments = List<Map<String, dynamic>>.from(flight.flightSegments);
    
    // Check if segments are reversed by comparing first segment with last cityPair
    if (originalSegments.isNotEmpty && bookingController.cityPairs.length > 1) {
      final firstSegment = originalSegments.first;
      final firstCityPair = bookingController.cityPairs.first;
      final lastCityPair = bookingController.cityPairs.last;
      
      final segmentDep = (firstSegment['departure']?['airport']?.toString() ?? '').toUpperCase().trim();
      final segmentArr = (firstSegment['arrival']?['airport']?.toString() ?? '').toUpperCase().trim();
      final firstCityPairFrom = firstCityPair.fromCity.value.toUpperCase().trim();
      final firstCityPairTo = firstCityPair.toCity.value.toUpperCase().trim();
      final lastCityPairFrom = lastCityPair.fromCity.value.toUpperCase().trim();
      final lastCityPairTo = lastCityPair.toCity.value.toUpperCase().trim();
      
      final firstMatchesFirst = (segmentDep == firstCityPairFrom && segmentArr == firstCityPairTo);
      final firstMatchesLast = (segmentDep == lastCityPairFrom && segmentArr == lastCityPairTo);
      
      // If first segment matches last cityPair, segments are reversed
      if (!firstMatchesFirst && firstMatchesLast) {
        originalSegments = originalSegments.reversed.toList();
      }
    }
    
    final reorderedSegments = <Map<String, dynamic>>[];
    final usedSegmentIndices = <int>{};
    
    // Match each cityPair to a segment
    for (int i = 0; i < bookingController.cityPairs.length; i++) {
      final cityPair = bookingController.cityPairs[i];
      final fromCity = cityPair.fromCity.value.toUpperCase().trim();
      final toCity = cityPair.toCity.value.toUpperCase().trim();
      
      // Find segment that matches this cityPair (not already used)
      Map<String, dynamic>? matchingSegment;
      int matchingIndex = -1;
      
      for (int j = 0; j < originalSegments.length; j++) {
        if (usedSegmentIndices.contains(j)) {
          continue;
        }
        
        final segment = originalSegments[j];
        final depAirport = (segment['departure']?['airport']?.toString() ?? '').toUpperCase().trim();
        final arrAirport = (segment['arrival']?['airport']?.toString() ?? '').toUpperCase().trim();
        
        // Exact match (airport codes)
        if (depAirport == fromCity && arrAirport == toCity) {
          matchingSegment = segment;
          matchingIndex = j;
          break;
        }
      }
      
      if (matchingSegment != null && matchingIndex != -1) {
        reorderedSegments.add(matchingSegment);
        usedSegmentIndices.add(matchingIndex);
      } else {
        // If no match found, try to use next unused segment as fallback
        for (int j = 0; j < originalSegments.length; j++) {
          if (!usedSegmentIndices.contains(j)) {
            reorderedSegments.add(originalSegments[j]);
            usedSegmentIndices.add(j);
            break;
          }
        }
      }
    }
    
    // If we couldn't reorder all segments, use original segments (possibly reversed)
    if (reorderedSegments.length != bookingController.cityPairs.length || 
        reorderedSegments.length != originalSegments.length) {
      reorderedSegments.clear();
      reorderedSegments.addAll(originalSegments);
    }
    
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