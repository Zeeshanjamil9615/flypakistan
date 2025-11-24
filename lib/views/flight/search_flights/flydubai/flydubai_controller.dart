// controllers/flydubai_flight_controller.dart

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:ready_flights/views/flight/search_flights/flydubai/flydubai_model.dart';
import 'dart:developer' as developer;

import '../../../../services/api_service_flydubai.dart';
import '../filters/filter_flight_model.dart';
import '../flight_package/flydubai/flydubai_package.dart';
import '../sabre/sabre_flight_models.dart';
import 'flydubai_extras_controller.dart';

class FlydubaiFlightController extends GetxController {
  // Use the separate API service
  final ApiServiceFlyDubai apiService = Get.put(ApiServiceFlyDubai());

  // Separate lists for outbound and return flights
  final RxList<FlydubaiFlight> _originalOutboundFlights =
      <FlydubaiFlight>[].obs;
  final RxList<FlydubaiFlight> _originalReturnFlights = <FlydubaiFlight>[].obs;

  // Filtered lists (shown in UI)
  final RxList<FlydubaiFlight> filteredOutboundFlights = <FlydubaiFlight>[].obs;
  final RxList<FlydubaiFlight> filteredReturnFlights = <FlydubaiFlight>[].obs;

  // Keep the flights getter for backward compatibility (shows outbound by default)
  RxList<FlydubaiFlight> get flights => filteredOutboundFlights;

  // Map to store all fare options for each LFID
  final RxMap<String, List<FlydubaiFlightFare>> fareOptionsByLFID =
      <String, List<FlydubaiFlightFare>>{}.obs;

  // Selected flights for round trip
  FlydubaiFlight? selectedOutboundFlight;
  FlydubaiFlightFare? selectedOutboundFareOption;
  FlydubaiFlight? selectedReturnFlight;
  FlydubaiFlightFare? selectedReturnFareOption;

  // Observable selected flight for UI updates
  final Rx<FlydubaiFlight?> selectedFlight = Rx<FlydubaiFlight?>(null);
  //
  // final FlightBookingController bookingController = Get.put(FlightBookingController());


  // Loading state
  final RxBool isLoading = false.obs;

  // Error message
  final RxString errorMessage = ''.obs;

  // Sort type
  final RxString sortType = 'Suggested'.obs;

  // Store search parameters for return flight identification
  String? _searchOrigin;
  String? _searchDestination;
  DateTime? _outboundDate;
  DateTime? _returnDate;

  // Add these properties to your controller class
  Map<String, dynamic>? _outboundCartData;
  Map<String, dynamic>? _returnCartData;
  Map<String, dynamic>? _cartData;

// Getters for cart data
  Map<String, dynamic>? get outboundCartData => _outboundCartData;
  Map<String, dynamic>? get returnCartData => _returnCartData;
  Map<String, dynamic>? get cartData => _cartData;




  void clearFlights() {
    _originalOutboundFlights.clear();
    _originalReturnFlights.clear();
    filteredOutboundFlights.clear();
    filteredReturnFlights.clear();
    fareOptionsByLFID.clear();
    errorMessage.value = '';

    // Clear selected flights too
    selectedOutboundFlight = null;
    selectedOutboundFareOption = null;
    selectedReturnFlight = null;
    selectedReturnFareOption = null;

    // Clear search parameters
    _searchOrigin = null;
    _searchDestination = null;
    _outboundDate = null;
    _returnDate = null;
  }

  void loadFlights(Map<String, dynamic> result, String fromCity, String toCity, int tripTpe) {
    try {
      debugPrint('=== LOADING FLYDUBAI FLIGHTS ===');

      if (result.containsKey('flights')) {
        parseApiResponse(
          result['flights'],
          expectedOrigin: fromCity,
          expectedDestination: toCity,
          tripType: tripTpe,
        );
        debugPrint('FlyDubai flights loaded from API result');
      } else {
        setErrorMessage('No flights data in result');
        debugPrint('No flights key found in result: ${result.keys}');
      }
    } catch (e) {
      debugPrint('Error loading FlyDubai flights: $e');
      setErrorMessage('Failed to load flights: $e');
    }
  }

  void setErrorMessage(String message) {
    errorMessage.value = message;
    developer.log('FlyDubai Controller Error: $message');
  }

  // Main method to search flights - uses the API service
  Future<void> searchFlights({
    required int type, // 0 = one-way, 1 = round-trip, 2 = multi-city
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
      isLoading.value = true;
      errorMessage.value = '';
      clearFlights();

      developer.log('=== FlyDubai Controller: Starting flight search ===');
      developer.log('Search Parameters:');
      developer.log('Type: $type');
      developer.log('Origin: $origin');
      developer.log('Destination: $destination');
      developer.log('Departure Date: $depDate');
      developer.log('Passengers: Adult=$adult, Child=$child, Infant=$infant');
      developer.log('Cabin: $cabin');

      // Clean the origin and destination parameters
      String cleanOrigin = origin.replaceAll(',', '').trim();
      String cleanDestination = destination.replaceAll(',', '').trim();
      String cleanDepDate = depDate.replaceAll(',', '').trim();

      // Store search parameters for flight separation
      _searchOrigin = cleanOrigin;
      _searchDestination = cleanDestination;

      // Parse dates for round trip
      if (type == 1) {
        List<String> datesList =
            cleanDepDate
                .split(',')
                .map((d) => d.trim())
                .where((d) => d.isNotEmpty)
                .toList();
        if (datesList.length >= 2) {
          _outboundDate = DateTime.parse(datesList[0]);
          _returnDate = DateTime.parse(datesList[1]);
          developer.log('Outbound Date: $_outboundDate');
          developer.log('Return Date: $_returnDate');
        }
      } else {
        _outboundDate = DateTime.parse(cleanDepDate);
      }

      developer.log('Cleaned Parameters:');
      developer.log('Clean Origin: $cleanOrigin');
      developer.log('Clean Destination: $cleanDestination');
      developer.log('Clean DepDate: $cleanDepDate');

      // Call the API service with cleaned parameters
      final result = await apiService.searchFlights(
        type: type,
        origin: ',$cleanOrigin', // Add comma back for API format
        destination: ',$cleanDestination', // Add comma back for API format
        depDate: ',$cleanDepDate', // Add comma back for API format
        adult: adult,
        child: child,
        infant: infant,
        cabin: cabin,
        multiCitySegments: multiCitySegments,
      );

      developer.log('FlyDubai API Result Keys: ${result.keys}');

      // Process the result
      if (result.containsKey('error')) {
        setErrorMessage(result['error']);
        developer.log('FlyDubai API Error: ${result['error']}');
      } else if (result.containsKey('flights') && result['success'] == true) {
        // Parse the response with search parameters for validation
        await parseApiResponse(
          result['flights'],
          expectedOrigin: cleanOrigin,
          expectedDestination: cleanDestination,
          tripType: type,
        );
        developer.log(
          'FlyDubai outbound flights loaded: ${filteredOutboundFlights.length}',
        );
        developer.log(
          'FlyDubai return flights loaded: ${filteredReturnFlights.length}',
        );
      } else {
        setErrorMessage('Invalid FlyDubai API response format');
        developer.log(
          'Invalid FlyDubai API response structure: ${result.keys}',
        );
      }
    } catch (e) {
      developer.log('FlyDubai Controller search error: $e');
      setErrorMessage('Failed to search flights: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Updated parseApiResponse method with flight separation
  // Update the parseApiResponse method to use proper flight separation
  Future<void> parseApiResponse(
    Map<String, dynamic>? response, {
    String? expectedOrigin,
    String? expectedDestination,
    int? tripType,
  }) async {
    try {
      // Clear previous flights and options
      _originalOutboundFlights.clear();
      _originalReturnFlights.clear();
      filteredOutboundFlights.clear();
      filteredReturnFlights.clear();
      fareOptionsByLFID.clear();

      if (response == null) {
        setErrorMessage('No response data received');
        return;
      }

      developer.log('=== PARSING FLYDUBAI API RESPONSE ===');

      final flydubaiResponse = FlydubaiResponse.fromJson(response);

      if (!flydubaiResponse.success) {
        setErrorMessage(
          flydubaiResponse.errorMessage ?? 'Failed to parse response',
        );
        return;
      }

      developer.log(
        'Found ${flydubaiResponse.flightSegments.length} flight segments',
      );

      // Create airline map for FlyDubai
      final airlineMap = {
        'FZ': AirlineInfo(
          'FlyDubai',
          'https://images.kiwi.com/airlines/64/FZ.png',
        ),
      };

      // Process all segments and separate outbound/return
      for (var segment in flydubaiResponse.flightSegments) {
        try {
          developer.log('Processing segment LFID: ${segment.lfid}');
          developer.log(
            'Segment route: ${segment.origin} -> ${segment.destination}',
          );
          developer.log('Segment date: ${segment.departureDateTime}');

          // Check if segment has valid fare data
          if (segment.fareTypes.isEmpty) {
            developer.log('Skipping segment ${segment.lfid} - no fare data');
            continue;
          }

          // Determine if this is outbound or return flight
          bool isOutboundFlight = _isOutboundFlight(
            segment,
            expectedOrigin,
            expectedDestination,
            tripType,
          );

          developer.log(
            'Flight ${segment.lfid} classified as: ${isOutboundFlight ? "OUTBOUND" : "RETURN"}',
          );

          // Create flight with actual segment data
          final flight = FlydubaiFlight.fromFlightSegment(
            segment,
            airlineMap,
            response,
            expectedOrigin:
                isOutboundFlight ? expectedOrigin : expectedDestination,
            expectedDestination:
                isOutboundFlight ? expectedDestination : expectedOrigin,
          );

          // Store fare options by LFID
          fareOptionsByLFID[segment.lfid.toString()] = segment.fareTypes;

          // Add to appropriate list
          if (isOutboundFlight) {
            print("outboudn flight flydubai");
            _originalOutboundFlights.add(flight);
            developer.log(
              '✅ Added OUTBOUND flight: ${flight.airlineCode} ${flight.flightSegment.flightNumber} - ${flight.flightSegment.origin} to ${flight.flightSegment.destination} - PKR ${flight.price}',
            );
          } else {
            print("return flight flydubai");
            _originalReturnFlights.add(flight);
            developer.log(
              '✅ Added RETURN flight: ${flight.airlineCode} ${flight.flightSegment.flightNumber} - ${flight.flightSegment.origin} to ${flight.flightSegment.destination} - PKR ${flight.price}',
            );
          }
        } catch (e) {
          developer.log('❌ Error processing segment ${segment.lfid}: $e');
          continue;
        }
      }

      // Sort flights by price
      _originalOutboundFlights.sort((a, b) => a.price.compareTo(b.price));
      _originalReturnFlights.sort((a, b) => a.price.compareTo(b.price));

      // Initialize filtered flights with all flights
      filteredOutboundFlights.assignAll(_originalOutboundFlights);
      filteredReturnFlights.assignAll(_originalReturnFlights);

      developer.log('=== PARSING COMPLETE ===');
      developer.log(
        'Successfully parsed ${_originalOutboundFlights.length} FlyDubai outbound flights',
      );
      developer.log(
        'Successfully parsed ${_originalReturnFlights.length} FlyDubai return flights',
      );

      if (_originalOutboundFlights.isEmpty && _originalReturnFlights.isEmpty) {
        setErrorMessage(
          'No FlyDubai flights found for the selected route and dates',
        );
      }
    } catch (e, stackTrace) {
      developer.log('❌ Parse API response error: $e');
      developer.log('Stack trace: $stackTrace');
      setErrorMessage('Failed to parse FlyDubai response: $e');
    }
  }

  // Helper method to determine if a flight segment is outbound or return
  bool _isOutboundFlight(
    FlydubaiFlightSegment segment,
    String? expectedOrigin,
    String? expectedDestination,
    int? tripType,
  ) {
    // For one-way flights, all flights are outbound
    if (tripType == 0) {
      print("check 1");
      return true;
    }

    print("check 2");

    // For round-trip flights, separate by route and date
    if (tripType == 1) {
      print("check 3");
      // Check if we have the expected origin/destination from search
      if (expectedOrigin != null && expectedDestination != null) {
        print("check 4");
        print(expectedOrigin);
        print(expectedDestination);
        bool isOutboundRoute =
            (segment.origin == expectedOrigin &&
                segment.destination == expectedDestination);
        bool isReturnRoute =
            (segment.origin == expectedDestination &&
                segment.destination == expectedOrigin);
        print("check 4.5");
        print(isOutboundRoute);
        print(isReturnRoute);
        // If we have dates, use them for more accurate classification
        if (_outboundDate != null && _returnDate != null) {
          print("check 5");
          DateTime segmentDate = DateTime(
            segment.departureDateTime.year,
            segment.departureDateTime.month,
            segment.departureDateTime.day,
          );

          print(segmentDate);
          DateTime outboundDateOnly = DateTime(
            _outboundDate!.year,
            _outboundDate!.month,
            _outboundDate!.day,
          );
          DateTime returnDateOnly = DateTime(
            _returnDate!.year,
            _returnDate!.month,
            _returnDate!.day,
          );
          print(outboundDateOnly);
          print(returnDateOnly);
          // Check if flight is on outbound date with outbound route
          if (segmentDate.isAtSameMomentAs(outboundDateOnly) &&
              isOutboundRoute) {
            print("check 6");
            return true;
          }
          // Check if flight is on return date with return route
          if (segmentDate.isAtSameMomentAs(returnDateOnly) && isReturnRoute) {
            print("check 7");
            return false;
          }
        }
        print("check 8");
        // Fallback: if we can't determine by date, use route direction
        return isOutboundRoute;
      }
    }

    // Default to outbound for multi-city or unknown cases
    return true;
  }

  void handleFlydubaiFlightSelection(
    FlydubaiFlight flight, {
    bool isReturnFlight = false,
  }) {
    if (isReturnFlight) {
      selectedReturnFlight = flight;
      developer.log(
        'Selected FlyDubai return flight: ${flight.airlineCode} ${flight.flightSegment.flightNumber}',
      );

      // Show package selection for return flight
      Get.dialog(
        FlyDubaiPackageSelectionDialog(flight: flight, isReturnFlight: true),
        barrierDismissible: false,
      );
    } else {
      selectedOutboundFlight = flight;
      selectedFlight.value = flight;
      developer.log(
        'Selected FlyDubai outbound flight: ${flight.airlineCode} ${flight.flightSegment.flightNumber}',
      );

      // Show package selection for outbound flight
      Get.dialog(
        FlyDubaiPackageSelectionDialog(flight: flight, isReturnFlight: false),
        barrierDismissible: false,
      );
    }
  }

  // Get return flights (now properly separated)
  List<FlydubaiFlight> getReturnFlights() {
    return List.from(_originalReturnFlights);
  }

  // Get outbound flights
  List<FlydubaiFlight> getOutboundFlights() {
    return List.from(_originalOutboundFlights);
  }

  // Get fare options for a selected flight
  List<FlydubaiFlightFare> getFareOptionsForFlight(FlydubaiFlight flight) {
    return fareOptionsByLFID[flight.rph] ?? [];
  }

  // Apply filters method - works on both outbound and return flights
  void applyFilters({
    List<String>? airlines,
    List<String>? stops,
    String? sortType,
    bool isReturnFlights = false,
  }) {
    if (sortType != null) {
      this.sortType.value = sortType;
    }
    _applySortingAndFiltering(
      airlines: airlines,
      stops: stops,
      isReturnFlights: isReturnFlights,
    );
  }

  // Method to apply sorting and filtering
  void _applySortingAndFiltering({
    List<String>? airlines,
    List<String>? stops,
    bool isReturnFlights = false,
  }) {
    // Choose the appropriate original flights list
    List<FlydubaiFlight> originalFlights =
        isReturnFlights ? _originalReturnFlights : _originalOutboundFlights;

    // Start with original flights (never modified)
    List<FlydubaiFlight> filtered = List.from(originalFlights);

    // Apply airline filter (for FlyDubai, only FZ is available)
    if (airlines != null &&
        !airlines.contains('all') &&
        !airlines.contains('FZ')) {
      filtered.clear(); // No flights if FlyDubai is not selected
    }

    // Apply stops filter
    if (stops != null && !stops.contains('all')) {
      filtered =
          filtered.where((flight) {
            int stopCount = flight.segmentInfo.length - 1;

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

    // Apply sorting
    switch (sortType.value) {
      case 'Cheapest':
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Fastest':
        filtered.sort((a, b) {
          final aDuration = a.legSchedules.fold(
            0,
            (sum, leg) => sum + (leg['elapsedTime'] as int),
          );
          final bDuration = b.legSchedules.fold(
            0,
            (sum, leg) => sum + (leg['elapsedTime'] as int),
          );
          return aDuration.compareTo(bDuration);
        });
        break;
      case 'Suggested':
      default:
        // Keep original order (already sorted by price during parsing)
        break;
    }

    // Update the appropriate filtered flights list
    if (isReturnFlights) {
      filteredReturnFlights.assignAll(filtered);
      developer.log(
        'Applied filters: ${filtered.length} FlyDubai return flights after filtering',
      );
    } else {
      filteredOutboundFlights.assignAll(filtered);
      developer.log(
        'Applied filters: ${filtered.length} FlyDubai outbound flights after filtering',
      );
    }
  }

  // Method to get available airlines (for Flydubai, it's always just FZ)
  List<FilterAirline> getAvailableAirlines() {
    if (_originalOutboundFlights.isEmpty && _originalReturnFlights.isEmpty)
      return [];

    return [
      FilterAirline(
        code: 'FZ',
        name: 'FlyDubai',
        logoPath: 'https://images.kiwi.com/airlines/64/FZ.png',
      ),
    ];
  }


  // Add these methods to your FlydubaiFlightController class

// Revalidate flight before proceeding to review
  Future<bool> revalidateFlightBeforeReview({
    required FlydubaiFlight flight,
    required FlydubaiFlightFare selectedFare,
    required bool isReturnFlight,
  }) async {
    try {
      developer.log('=== REVALIDATING FLIGHT PRICING ===');

      // Generate booking ID (LFID_FareIndex)
      final bookingId = '${flight.flightSegment.lfid}_${_getFareIndex(flight, selectedFare)}';

      developer.log('Booking ID: $bookingId');
      developer.log('Flight: ${flight.airlineCode} ${flight.flightSegment.flightNumber}');
      developer.log('Fare Type: ${selectedFare.fareTypeName}');

      // Call revalidation API
      final result = await apiService.revalidateFlight(
        bookingId: bookingId,
        flightData: flight.rawData,
      );

      if (result['success'] == true) {
        final updatedPrice = result['updatedPrice'] ?? flight.price;
        developer.log('Revalidation successful. Updated price: $updatedPrice');

        // Update the flight price with revalidated price
        if (isReturnFlight) {
          selectedReturnFlight = _updateFlightPrice(flight, updatedPrice);
        } else {
          selectedOutboundFlight = _updateFlightPrice(flight, updatedPrice);
        }

        // Store cart data for later use in booking process
        _storeCartData(result['cartData'], isReturnFlight);

        return true;
      } else {
        developer.log('Revalidation failed: ${result['error']}');
        return false;
      }
    } catch (e) {
      developer.log('Revalidation error: $e');
      return false;
    }
  }

// Add flight to cart (for final booking)
  // In FlydubaiFlightController, update the addFlightsToCart method
  Future<Map<String, dynamic>> addFlightsToCart() async {
  try {
    print('═══════════════════════════════════════════════════════');
    print('🛒 ADDING FLIGHTS TO CART');
    print('═══════════════════════════════════════════════════════');

    // Check if this is a round-trip flight
    final isRoundTrip = selectedOutboundFlight != null && selectedReturnFlight != null;
    
    if (isRoundTrip) {
      print('🔄 Round-trip flight detected - checking combinability...');
      
      // Apply combinability logic for round-trip flights
      final combinabilityResult = _applyCombinabilityLogic();
      if (!combinabilityResult['success']) {
        return combinabilityResult;
      }
    }

    final List<String> bookingIds = [];

    // Add outbound flight if selected
    if (selectedOutboundFlight != null && selectedOutboundFareOption != null) {
      print('📍 Processing Outbound Flight:');
      print('   - Flight: ${selectedOutboundFlight!.airlineCode} ${selectedOutboundFlight!.flightSegment.flightNumber}');
      print('   - LFID: ${selectedOutboundFlight!.flightSegment.lfid}');
      print('   - Selected Fare: ${selectedOutboundFareOption!.fareTypeName}');
      
      final fareIndex = _getFareIndex(selectedOutboundFlight!, selectedOutboundFareOption!);
      final outboundId = '${selectedOutboundFlight!.flightSegment.lfid}_$fareIndex';
      bookingIds.add(outboundId);
      print('   ✅ Outbound Booking ID: $outboundId');
    }

    // Add return flight if selected
    if (selectedReturnFlight != null && selectedReturnFareOption != null) {
      print('📍 Processing Return Flight:');
      print('   - Flight: ${selectedReturnFlight!.airlineCode} ${selectedReturnFlight!.flightSegment.flightNumber}');
      print('   - LFID: ${selectedReturnFlight!.flightSegment.lfid}');
      print('   - Selected Fare: ${selectedReturnFareOption!.fareTypeName}');
      
      final fareIndex = _getFareIndex(selectedReturnFlight!, selectedReturnFareOption!);
      final returnId = '${selectedReturnFlight!.flightSegment.lfid}_$fareIndex';
      bookingIds.add(returnId);
      print('   ✅ Return Booking ID: $returnId');
    }

    if (bookingIds.isEmpty) {
      return {
        'success': false,
        'error': 'No flights selected for cart',
      };
    }

    // Use outbound flight data for cart (assuming both flights have similar structure)
    final flightData = selectedOutboundFlight?.rawData ?? selectedReturnFlight?.rawData;

    if (flightData == null) {
      return {
        'success': false,
        'error': 'No flight data available',
      };
    }

    final result = await apiService.addToCart(
      bookingIds: bookingIds,
      flightData: flightData,
    );

    if (result['success'] == true) {
      print("✅ Add to cart successful");
      developer.log('Successfully added flights to cart');
      
      // Store cart data AND security GUID for booking process
      _cartData = result['data'];
      final securityGuid = result['securityGuid'];
      
      if (securityGuid != null) {
        _cartData?['SecurityGuid'] = securityGuid;
      }
      
      // Debug: Check cart response structure
      if (result['data'] != null) {
        final cartData = result['data'] as Map<String, dynamic>;
        print('🔍 Cart Response Analysis:');
        print('   - Keys: ${cartData.keys.toList()}');
        print('   - SecurityGUID (uppercase): ${cartData['SecurityGUID']}');
        print('   - SecurityGuid (mixed): ${cartData['SecurityGuid']}');
        print('   - securityGUID (lowercase): ${cartData['securityGUID']}');
        print('   - Has originDestinations: ${cartData.containsKey('originDestinations')}');
        
        // Extract and log the actual GUID value
        final extractedGuid = cartData['SecurityGUID'] ?? cartData['SecurityGuid'] ?? cartData['securityGUID'];
        if (extractedGuid != null && extractedGuid.toString().isNotEmpty) {
          print('✅ Extracted SecurityGUID from cart: $extractedGuid');
        } else {
          print('⚠️ No SecurityGUID found in cart response');
        }
      }
      
      developer.log('Security GUID for PNR: $securityGuid');
    }

    return result;
  } catch (e) {
    developer.log('Add to cart error: $e');
    return {
      'success': false,
      'error': 'Failed to add flights to cart: $e',
    };
  }
}
// Apply combinability logic for round-trip flights
  Map<String, dynamic> _applyCombinabilityLogic() {
    try {
      print('🔍 Applying combinability logic...');
      
      // Get flight data to access combinability information
      final flightData = selectedOutboundFlight?.rawData ?? selectedReturnFlight?.rawData;
      if (flightData == null) {
        return {
          'success': false,
          'error': 'No flight data available for combinability check',
        };
      }

      // Extract combinability data
      final retrieveResult = flightData['RetrieveFareQuoteDateRangeResponse']?['RetrieveFareQuoteDateRangeResult'];
      if (retrieveResult == null) {
        print('⚠️ No combinability data found, proceeding without check');
        return {'success': true};
      }

      final combinability = retrieveResult['Combinability']?['BS'];
      if (combinability == null || combinability is! List) {
        print('⚠️ No combinability rules found, proceeding without check');
        return {'success': true};
      }

      // Get selected fare solution IDs
      final outboundSolnId = selectedOutboundFareOption?.solnId;
      final returnSolnId = selectedReturnFareOption?.solnId;
      
      if (outboundSolnId == null || returnSolnId == null) {
        print('⚠️ Missing solution IDs, proceeding without check');
        return {'success': true};
      }

      print('🔍 Checking combinability:');
      print('   Outbound SolnId: $outboundSolnId');
      print('   Return SolnId: $returnSolnId');

      // Check if the selected combination is valid
      bool foundValidCombination = false;
      for (final combo in combinability) {
        if (combo is Map && combo['SolnRef'] is List) {
          final solnRef = combo['SolnRef'] as List;
          if (solnRef.length >= 2) {
            final comboOutboundSoln = solnRef[0];
            final comboReturnSoln = solnRef[1];
            
            print('   Checking combination: [$comboOutboundSoln, $comboReturnSoln]');
            
            if (comboOutboundSoln == outboundSolnId && comboReturnSoln == returnSolnId) {
              print('   ✅ Found valid combination!');
              foundValidCombination = true;
              break;
            }
          }
        }
      }

      if (foundValidCombination) {
        print('✅ Selected fare combination is valid');
        return {'success': true};
      }

      // If not found, try to find alternative combinations
      print('⚠️ Selected combination not valid, looking for alternatives...');
      
      // Try to find a valid combination with the return flight
      for (final combo in combinability) {
        if (combo is Map && combo['SolnRef'] is List) {
          final solnRef = combo['SolnRef'] as List;
          if (solnRef.length >= 2) {
            final comboOutboundSoln = solnRef[0];
            final comboReturnSoln = solnRef[1];
            
            // If return flight matches, try to find compatible outbound
            if (comboReturnSoln == returnSolnId) {
              print('   Found compatible return flight, looking for outbound alternative...');
              
              // Find alternative outbound fare with matching solution ID
              final alternativeOutbound = _findAlternativeFare(
                selectedOutboundFlight!, 
                comboOutboundSoln,
                selectedOutboundFareOption!.fareTypeName
              );
              
              if (alternativeOutbound != null) {
                print('   ✅ Found alternative outbound fare: ${alternativeOutbound.fareTypeName}');
                selectedOutboundFareOption = alternativeOutbound;
                return {'success': true};
              }
            }
          }
        }
      }

      // If still no valid combination found, return error with helpful message
      return {
        'success': false,
        'error': 'Selected fare combination is not compatible for round-trip booking. Please try selecting different fare types (e.g., both LITE, both VALUE, or both FLEX).',
      };

    } catch (e) {
      print('❌ Error in combinability logic: $e');
      return {
        'success': false,
        'error': 'Error checking fare compatibility: $e',
      };
    }
  }

  // Find alternative fare with specific solution ID and fare type name
  FlydubaiFlightFare? _findAlternativeFare(
    FlydubaiFlight flight, 
    int targetSolnId, 
    String targetFareTypeName
  ) {
    final options = fareOptionsByLFID[flight.rph] ?? [];
    
    for (final option in options) {
      if (option.solnId == targetSolnId && option.fareTypeName == targetFareTypeName) {
        return option;
      }
    }
    
    return null;
  }

// Helper method to get fare index
  int _getFareIndex(FlydubaiFlight flight, FlydubaiFlightFare fare) {
    final options = fareOptionsByLFID[flight.rph] ?? [];
    print('🔍 _getFareIndex called:');
    print('   Flight LFID/RPH: ${flight.rph}');
    print('   Looking for Fare Type ID: ${fare.fareTypeId} (${fare.fareTypeName})');
    print('   Looking for Fare ID: ${fare.fareId}');
    print('   Available options: ${options.length}');
    
    // Use FareID instead of array index - this matches the web implementation
    for (int i = 0; i < options.length; i++) {
      print('   [$i] ${options[i].fareTypeName} (TypeID: ${options[i].fareTypeId}, FareID: ${options[i].fareId})');
      if (options[i].fareTypeId == fare.fareTypeId && options[i].fareId == fare.fareId) {
        print('   ✅ Found match - using FareID: ${fare.fareId} (not array index)');
        return fare.fareId; // Return FareID, not array index!
      }
    }
    
    print('   ⚠️ No match found, returning FareID: ${fare.fareId}');
    return fare.fareId; // Return FareID, not 0
  }

// Helper method to update flight price
  FlydubaiFlight _updateFlightPrice(FlydubaiFlight flight, double newPrice) {
    // Create a new flight object with updated price
    return FlydubaiFlight(
      id: flight.id,
      price: newPrice,
      basePrice: newPrice * 0.75, // Approximate base price (75% of total)
      taxAmount: newPrice * 0.25, // Approximate tax (25% of total)
      feeAmount: flight.feeAmount,
      currency: flight.currency,
      isRefundable: flight.isRefundable,
      baggageAllowance: flight.baggageAllowance,
      legSchedules: flight.legSchedules,
      stopSchedules: flight.stopSchedules,
      segmentInfo: flight.segmentInfo,
      airlineCode: flight.airlineCode,
      airlineName: flight.airlineName,
      airlineImg: flight.airlineImg,
      rph: flight.rph,
      flightSegment: flight.flightSegment,
      fareOptions: flight.fareOptions,
      rawData: flight.rawData,
      changeFeeDetails: flight.changeFeeDetails,
      refundFeeDetails: flight.refundFeeDetails, stops: flight.stops, isNonStop: flight.isNonStop, stopCities: flight.stopCities,
    );
  }

// Store cart data
  void _storeCartData(Map<String, dynamic>? cartData, bool isReturnFlight) {
    if (cartData != null) {
      if (isReturnFlight) {
        _returnCartData = cartData;
      } else {
        _outboundCartData = cartData;
      }
    }
  }


// Update the buildSegmentArray method in FlydubaiFlightController
  List<Map<String, dynamic>> buildSegmentArray({required FlydubaiExtrasController extrasController}) {
    final List<Map<String, dynamic>> segments = [];

    print('═══════════════════════════════════════════════════════');
    print('🔧 BUILDING SEGMENT ARRAY FOR PNR');
    print('═══════════════════════════════════════════════════════');

    try {
      // Build segments for outbound flight
      if (selectedOutboundFlight != null && selectedOutboundFareOption != null) {
        print('📍 Building Outbound Segment:');
        print('   - Flight: ${selectedOutboundFlight!.airlineCode} ${selectedOutboundFlight!.flightSegment.flightNumber}');
        print('   - LFID: ${selectedOutboundFlight!.flightSegment.lfid}');
        print('   - Fare: ${selectedOutboundFareOption!.fareTypeName}');
        print('   - Fare ID: ${selectedOutboundFareOption!.fareId}');
        
        final fareId = selectedOutboundFareOption!.fareId;

        // Get extras data from extras controller
        final baggageExtras = _buildBaggageExtras(extrasController.selectedBaggage);
        final mealExtras = _buildMealExtras(extrasController.selectedMeals);
        final seatExtras = _buildSeatExtras(extrasController.selectedSeats);

        print('   - Baggage extras: ${baggageExtras.isNotEmpty ? "Yes" : "No"}');
        print('   - Meal extras: ${mealExtras.length}');
        print('   - Seat extras: ${seatExtras.length}');

        segments.add({
          'pax': 1, // First passenger
          'fareID': fareId,
          'extra': {
            'baggage': baggageExtras,
            'meal': mealExtras,
            'seat': seatExtras
          }
        });
        
        print('   ✅ Outbound segment added');
      }

      // Build segments for return flight
      if (selectedReturnFlight != null && selectedReturnFareOption != null) {
        print('📍 Building Return Segment:');
        print('   - Flight: ${selectedReturnFlight!.airlineCode} ${selectedReturnFlight!.flightSegment.flightNumber}');
        print('   - LFID: ${selectedReturnFlight!.flightSegment.lfid}');
        print('   - Fare: ${selectedReturnFareOption!.fareTypeName}');
        print('   - Fare ID: ${selectedReturnFareOption!.fareId}');
        
        final fareId = selectedReturnFareOption!.fareId;

        // Get extras data from extras controller (you might want separate handling for return flight)
        final baggageExtras = _buildBaggageExtras(extrasController.selectedBaggage);
        final mealExtras = _buildMealExtras(extrasController.selectedMeals);
        final seatExtras = _buildSeatExtras(extrasController.selectedSeats);

        print('   - Baggage extras: ${baggageExtras.isNotEmpty ? "Yes" : "No"}');
        print('   - Meal extras: ${mealExtras.length}');
        print('   - Seat extras: ${seatExtras.length}');

        segments.add({
          'pax': 1, // First passenger
          'fareID': fareId,
          'extra': {
            'baggage': baggageExtras,
            'meal': mealExtras,
            'seat': seatExtras
          }
        });
        
        print('   ✅ Return segment added');
      }
      
      print('📋 Total segments built: ${segments.length}');
      for (int i = 0; i < segments.length; i++) {
        print('   Segment $i: pax=${segments[i]['pax']}, fareID=${segments[i]['fareID']}');
      }
      
    } catch (e) {
      print('❌ Error building segment array: $e');
    }

    return segments;
  }

// Helper methods to build extras in the correct format
  String _buildBaggageExtras(RxMap<String, dynamic> selectedBaggage) {
    if (selectedBaggage.isEmpty) return '';

    try {
      // Format: OfferCode!!LFID!!DepartureDate!!Amount!!Currency!!RuleId!!PFID
      final baggage = selectedBaggage.values.first;
      return '${baggage['id']}!!0!!${DateTime.now().toIso8601String()}!!${baggage['charge']}!!PKR!!BAGGAGE_RULE!!0';
    } catch (e) {
      return '';
    }
  }

  List<String> _buildMealExtras(RxMap<String, dynamic> selectedMeals) {
    final List<String> meals = [];

    if (selectedMeals.isEmpty) return meals;

    try {
      // Format: OfferCode!!LFID!!DepartureDate!!Amount!!Currency!!RuleId!!PFID
      for (final meal in selectedMeals.values) {
        meals.add('${meal['id']}!!0!!${DateTime.now().toIso8601String()}!!${meal['charge']}!!PKR!!MEAL_RULE!!0');
      }
    } catch (e) {
      print('Error building meal extras: $e');
    }

    return meals;
  }

  List<String> _buildSeatExtras(RxMap<String, dynamic> selectedSeats) {
    final List<String> seats = [];

    if (selectedSeats.isEmpty) return seats;

    try {
      // Format: OfferCode!!LFID!!DepartureDate!!Amount!!Currency!!RuleId!!PFID!!RowNumber!!SeatNumber
      for (final seat in selectedSeats.values) {
        seats.add('SEAT!!0!!${DateTime.now().toIso8601String()}!!${seat['charge']}!!PKR!!SEAT_RULE!!0!!${seat['rowNumber']}!!${seat['seatNumber']}');
      }
    } catch (e) {
      print('Error building seat extras: $e');
    }

    return seats;
  }
}

// AirlineInfo is now imported from sabre_flight_models.dart AirlineInfo(this.name, this.logoPath);
