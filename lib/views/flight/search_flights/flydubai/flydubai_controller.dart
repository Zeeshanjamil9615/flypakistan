// controllers/flydubai_flight_controller.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ready_flights/views/flight/search_flights/flydubai/flydubai_model.dart';
import 'dart:developer' as developer;

import '../../../../services/api_service_flydubai.dart';
import '../../../../services/api_service_sabre.dart';
import '../../form/flight_booking_controller.dart';
import '../filters/filter_flight_model.dart';
import '../flight_package/flydubai/flydubai_package.dart';
import '../sabre/sabre_flight_models.dart';
import '../../booking_flight/airblue/airblue_booking_flight.dart';
import 'flydubai_extras_controller.dart';
import 'flydubai_multicity_flight_selection.dart';

class FlydubaiFlightController extends GetxController {
  // Use the separate API service
  final ApiServiceFlyDubai apiService = Get.put(ApiServiceFlyDubai());
  // Use Sabre service for margin
  final ApiServiceSabre sabreApiService = Get.put(ApiServiceSabre());

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

  // Store flights by segment for multi-city support
  final RxMap<int, List<FlydubaiFlight>> flightsBySegment = <int, List<FlydubaiFlight>>{}.obs;

  // Selected flights for round trip
  FlydubaiFlight? selectedOutboundFlight;
  FlydubaiFlightFare? selectedOutboundFareOption;
  FlydubaiFlight? selectedReturnFlight;
  FlydubaiFlightFare? selectedReturnFareOption;

  // Multi-city selections - each index corresponds to a segment
  final RxList<FlydubaiFlight?> selectedMultiCityFlights = <FlydubaiFlight?>[].obs;
  final RxList<FlydubaiFlightFare?> selectedMultiCityFareOptions = <FlydubaiFlightFare?>[].obs;

  // Track current segment being selected for multi-city
  final RxInt currentMultiCitySegment = 0.obs;

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
    flightsBySegment.clear();
    errorMessage.value = '';

    // Clear selected flights too
    selectedOutboundFlight = null;
    selectedOutboundFareOption = null;
    selectedReturnFlight = null;
    selectedReturnFareOption = null;

    // Clear multi-city selections
    selectedMultiCityFlights.clear();
    selectedMultiCityFareOptions.clear();
    currentMultiCitySegment.value = 0;

    // Clear search parameters
    _searchOrigin = null;
    _searchDestination = null;
    _outboundDate = null;
    _returnDate = null;
  }

  // Calculate price with margin and BSP (BSP only for FlyDubai GDS, not Sabre)
  // BSP is a special fee that should be added only to FlyDubai GDS flights
  double _calculateFlyDubaiSellingPrice(double buyingPrice, Map<String, dynamic> marginData) {
    // First calculate price with margin
    double priceWithMargin = sabreApiService.calculatePriceWithMargin(buyingPrice, marginData);
    
    // Then add BSP if it exists in marginData (only for FlyDubai GDS)
    final bspRaw = marginData['bsp'];
    if (bspRaw != null) {
      double bsp = 0.0;
      if (bspRaw is num) {
        bsp = bspRaw.toDouble();
      } else {
        bsp = double.tryParse(bspRaw.toString()) ?? 0.0;
      }
      
      if (bsp > 0) {
        priceWithMargin += bsp;
        developer.log('Added BSP fee: $bsp to FlyDubai GDS flight. Final price: $priceWithMargin');
      }
    }
    
    // Round up to next integer if there's a decimal (matching Laravel PHP behavior)
    return priceWithMargin.ceil().toDouble();
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
      developer.log('Raw Origin: "$origin" (length: ${origin.length})');
      developer.log('Raw Destination: "$destination" (length: ${destination.length})');
      developer.log('Departure Date: $depDate');
      developer.log('Passengers: Adult=$adult, Child=$child, Infant=$infant');
      developer.log('Cabin: $cabin');

      // Clean and parse origin/destination parameters
      // For round trip: origin can come as ",LHE,DXB", "LHEDXB" (concatenated), or "LHE"
      // For one-way: origin comes as ",LHE" or "LHE"
      // We need to extract the first origin/destination pair for the API call
      String cleanOrigin;
      String cleanDestination;
      String cleanDepDate;
      
      // Parse dates for round trip first (needed before cleaning origin/destination)
      if (type == 1) {
        // Round trip - extract first origin/destination pair
        String originCleaned = origin.replaceAll(',', '').trim();
        String destCleaned = destination.replaceAll(',', '').trim();
        
        // Check if origin/destination are concatenated (e.g., "LHEDXB" = 6 chars, should split into two 3-char codes)
        // Airport codes are typically 3 characters, so concatenated would be 6 characters
        if (originCleaned.length == 6 && destCleaned.length == 6) {
          // Likely concatenated format: "LHEDXB" = "LHE" + "DXB"
          // Extract first 3 characters for outbound origin/destination
          cleanOrigin = originCleaned.substring(0, 3);
          cleanDestination = destCleaned.substring(0, 3);
          developer.log('Detected concatenated format - Extracted: origin=$cleanOrigin, destination=$cleanDestination');
        } else {
          // Try splitting by comma first (in case there are commas)
          final originParts = origin.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          final destParts = destination.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          
          // For round trip: originParts = [LHE, DXB], destParts = [DXB, LHE]
          // We want first pair: LHE -> DXB
          cleanOrigin = originParts.isNotEmpty ? originParts[0] : originCleaned;
          cleanDestination = destParts.isNotEmpty ? destParts[0] : destCleaned;
        }
        
        // Ensure we have valid 3-character airport codes
        if (cleanOrigin.length != 3 || cleanDestination.length != 3) {
          developer.log('⚠️ Warning: Invalid airport code length - Origin: ${cleanOrigin.length} chars, Destination: ${cleanDestination.length} chars');
          developer.log('  Origin value: "$cleanOrigin"');
          developer.log('  Destination value: "$cleanDestination"');
        }
        
        // Store search parameters for flight separation (first pair for outbound)
        _searchOrigin = cleanOrigin;
        _searchDestination = cleanDestination;
        
        final datesList = depDate
            .split(',')
            .map((d) => d.trim())
            .where((d) => d.isNotEmpty)
            .toList();
        if (datesList.length >= 2) {
          cleanDepDate = datesList[0] + ',' + datesList[1]; // Keep both dates
          _outboundDate = DateTime.parse(datesList[0]);
          _returnDate = DateTime.parse(datesList[1]);
          developer.log('Outbound Date: $_outboundDate');
          developer.log('Return Date: $_returnDate');
        } else {
          cleanDepDate = depDate.replaceAll(',', '').trim();
          _outboundDate = DateTime.parse(cleanDepDate);
        }
      } else {
        // One-way - just remove commas
        cleanOrigin = origin.replaceAll(',', '').trim();
        cleanDestination = destination.replaceAll(',', '').trim();
        cleanDepDate = depDate.replaceAll(',', '').trim();
        
        // Store search parameters
        _searchOrigin = cleanOrigin;
        _searchDestination = cleanDestination;
        _outboundDate = DateTime.parse(cleanDepDate);
      }

      developer.log('Cleaned Parameters:');
      developer.log('Clean Origin: $cleanOrigin');
      developer.log('Clean Destination: $cleanDestination');
      developer.log('Clean DepDate: $cleanDepDate');

      // Call the API service with cleaned parameters (no comma prefix for FlyDubai)
      final result = await apiService.searchFlights(
        type: type,
        origin: cleanOrigin, // FlyDubai doesn't need comma prefix
        destination: cleanDestination, // FlyDubai doesn't need comma prefix
        depDate: cleanDepDate,
        adult: adult,
        child: child,
        infant: infant,
        cabin: cabin,
        multiCitySegments: multiCitySegments,
      );

      developer.log('FlyDubai API Result Keys: ${result.keys}');

      // Process the result
      developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      developer.log('📥 Processing FlyDubai API result');
      developer.log('  Result keys: ${result.keys}');
      developer.log('  Success: ${result['success']}');
      developer.log('  Trip type: $type (${type == 0 ? "One-way" : type == 1 ? "Round-trip" : "Multi-city"})');
      
      if (result.containsKey('error')) {
        setErrorMessage(result['error']);
        developer.log('  ❌ FlyDubai API Error: ${result['error']}');
      } else if (result.containsKey('flights') && result['success'] == true) {
        developer.log('  ✅ Valid response received');
        developer.log('  📦 Flights data type: ${result['flights'].runtimeType}');
        
        // Parse the response with search parameters for validation
        await parseApiResponse(
          result['flights'],
          expectedOrigin: cleanOrigin,
          expectedDestination: cleanDestination,
          tripType: type,
        );
        
        if (type == 2) {
          // Multi-city summary
          developer.log('  📊 Multi-city summary:');
          for (int i = 0; i < flightsBySegment.length; i++) {
            final count = flightsBySegment[i]?.length ?? 0;
            developer.log('    Segment $i: $count flights');
          }
        } else {
        developer.log(
            '  FlyDubai outbound flights loaded: ${filteredOutboundFlights.length}',
        );
        developer.log(
            '  FlyDubai return flights loaded: ${filteredReturnFlights.length}',
        );
        }
      } else {
        setErrorMessage('Invalid FlyDubai API response format');
        developer.log('  ❌ Invalid FlyDubai API response structure');
        developer.log('  Available keys: ${result.keys}');
        developer.log('  Has flights key: ${result.containsKey('flights')}');
        developer.log('  Success value: ${result['success']}');
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

      developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      developer.log('=== PARSING FLYDUBAI API RESPONSE ===');
      developer.log('  Trip Type parameter: $tripType (${tripType == 0 ? "One-way" : tripType == 1 ? "Round-trip" : tripType == 2 ? "Multi-city" : "Unknown"})');
      developer.log('  Expected Origin: $expectedOrigin');
      developer.log('  Expected Destination: $expectedDestination');
      
      // Check response structure
      developer.log('  Response keys: ${response?.keys}');
      final retrieveResult = response?['RetrieveFareQuoteDateRangeResponse']?['RetrieveFareQuoteDateRangeResult'];
      if (retrieveResult != null) {
        developer.log('  RetrieveResult keys: ${retrieveResult.keys}');
        developer.log('  Has SegmentDetails: ${retrieveResult.containsKey('SegmentDetails')}');
        developer.log('  Has LegDetails: ${retrieveResult.containsKey('LegDetails')}');
        if (retrieveResult.containsKey('SegmentDetails')) {
          final segDetails = retrieveResult['SegmentDetails']?['SegmentDetail'];
          if (segDetails != null) {
            final count = segDetails is List ? segDetails.length : 1;
            developer.log('  SegmentDetails count: $count');
            if (segDetails is List && segDetails.isNotEmpty) {
              developer.log('  First SegmentDetail: LFID=${segDetails[0]['LFID']}, Origin=${segDetails[0]['Origin']}, Destination=${segDetails[0]['Destination']}');
            }
          }
        }
      }

      final flydubaiResponse = FlydubaiResponse.fromJson(response);

      if (!flydubaiResponse.success) {
        developer.log('  ❌ FlyDubai response parsing failed: ${flydubaiResponse.errorMessage}');
        setErrorMessage(
          flydubaiResponse.errorMessage ?? 'Failed to parse response',
        );
        return;
      }

      developer.log(
        '  ✅ Found ${flydubaiResponse.flightSegments.length} flight segments',
      );
      
      // Debug: Log all parsed segments
      developer.log('  📋 Parsed segments details:');
      for (int i = 0; i < flydubaiResponse.flightSegments.length; i++) {
        final seg = flydubaiResponse.flightSegments[i];
        developer.log('    Segment $i: LFID=${seg.lfid}, Origin=${seg.origin}, Destination=${seg.destination}, Date=${seg.departureDateTime.toIso8601String().substring(0, 10)}, Fares=${seg.fareTypes.length}');
        if (seg.origin.isEmpty || seg.destination.isEmpty) {
          developer.log('      ⚠️ WARNING: Segment $i has empty origin/destination!');
        }
      }

      // Fetch margin for FlyDubai (airline code FZ)
      Map<String, dynamic> marginData = {};
      try {
        marginData = await sabreApiService.getMargin('FZ', 'flydubai');
      } catch (e) {
        developer.log('Error fetching FlyDubai margin: $e');
      }

      // Create airline map for FlyDubai
      final airlineMap = {
        'FZ': AirlineInfo(
          'FlyDubai',
          'https://images.kiwi.com/airlines/64/FZ.png',
        ),
      };

      // For multi-city, organize flights by segment FIRST
      developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      developer.log('🔀 Checking trip type routing...');
      developer.log('  tripType value: $tripType');
      developer.log('  tripType == 2: ${tripType == 2}');
      
      if (tripType == 2) {
        developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        developer.log('=== PROCESSING MULTI-CITY FLIGHTS ===');
        developer.log('Total flight segments from API: ${flydubaiResponse.flightSegments.length}');
        
        // Get city pairs from booking controller
        final bookingController = Get.find<FlightBookingController>();
        final cityPairs = bookingController.cityPairs;
        
        developer.log('📋 City pairs count: ${cityPairs.length}');
        for (int i = 0; i < cityPairs.length; i++) {
          final pair = cityPairs[i];
          developer.log('  City Pair $i: ${pair.fromCity.value} -> ${pair.toCity.value} on ${pair.departureDate.value}');
        }
        
        // Initialize flightsBySegment for each city pair
        for (int i = 0; i < cityPairs.length; i++) {
          flightsBySegment[i] = [];
          developer.log('  Initialized flightsBySegment[$i]');
        }
        
        int processedCount = 0;
        int skippedNoFareCount = 0;
        int skippedNoMatchCount = 0;
        int errorCount = 0;
        
        // Process all segments and match them to city pairs
        for (var segment in flydubaiResponse.flightSegments) {
          try {
            developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            developer.log('🔍 Processing segment LFID: ${segment.lfid}');
            developer.log('  Route: ${segment.origin} -> ${segment.destination}');
            developer.log('  Date: ${segment.departureDateTime}');
            developer.log('  Fare types count: ${segment.fareTypes.length}');

            // Check if segment has valid fare data
            if (segment.fareTypes.isEmpty) {
              skippedNoFareCount++;
              developer.log('  ⚠️ Skipping segment ${segment.lfid} - no fare data');
              continue;
            }

            // Find matching city pair segment
            int? matchingSegmentIndex;
            final segmentDate = DateTime(
              segment.departureDateTime.year,
              segment.departureDateTime.month,
              segment.departureDateTime.day,
            );
            
            developer.log('  🔎 Searching for matching city pair...');
            developer.log('  Segment date (date only): ${segmentDate.toIso8601String().substring(0, 10)}');
            
            for (int i = 0; i < cityPairs.length; i++) {
              final cityPair = cityPairs[i];
              final cityPairDate = DateTime(
                cityPair.departureDateTime.value.year,
                cityPair.departureDateTime.value.month,
                cityPair.departureDateTime.value.day,
              );
              
              developer.log('    Checking city pair $i:');
              developer.log('      Expected: ${cityPair.fromCity.value} -> ${cityPair.toCity.value}');
              developer.log('      Actual: ${segment.origin} -> ${segment.destination}');
              developer.log('      Expected date: ${cityPairDate.toIso8601String().substring(0, 10)}');
              developer.log('      Actual date: ${segmentDate.toIso8601String().substring(0, 10)}');
              developer.log('      Origin match: ${segment.origin == cityPair.fromCity.value}');
              developer.log('      Destination match: ${segment.destination == cityPair.toCity.value}');
              developer.log('      Date match: ${segmentDate.isAtSameMomentAs(cityPairDate)}');
              
              if (segment.origin == cityPair.fromCity.value &&
                  segment.destination == cityPair.toCity.value &&
                  segmentDate.isAtSameMomentAs(cityPairDate)) {
                matchingSegmentIndex = i;
                developer.log('    ✅ MATCH FOUND! Segment ${segment.lfid} matches city pair $i');
                break;
              } else {
                developer.log('    ❌ No match for city pair $i');
              }
            }

            if (matchingSegmentIndex == null) {
              skippedNoMatchCount++;
              developer.log('  ⚠️ No matching city pair found for segment ${segment.lfid}');
              developer.log('  Segment details: ${segment.origin} -> ${segment.destination} on ${segmentDate.toIso8601String().substring(0, 10)}');
              continue;
            }

            // Create flight with actual segment data
            developer.log('  ✈️ Creating FlydubaiFlight object...');
            // Get buying price from lowest fare
            final lowestFare = segment.fareTypes.isNotEmpty
                ? segment.fareTypes.reduce((a, b) => a.baseFareAmountIncludingTax < b.baseFareAmountIncludingTax ? a : b)
                : null;
            final buyingPrice = lowestFare?.baseFareAmountIncludingTax ?? 0.0;
            // Calculate selling price with margin + BSP (BSP only for FlyDubai GDS)
            final sellingPrice = _calculateFlyDubaiSellingPrice(buyingPrice, marginData);
            
            final flight = FlydubaiFlight.fromFlightSegment(
              segment,
              airlineMap,
              response,
              expectedOrigin: cityPairs[matchingSegmentIndex].fromCity.value,
              expectedDestination: cityPairs[matchingSegmentIndex].toCity.value,
              sellingPrice: sellingPrice,
            );

            // Store fare options by LFID (use segment index in key for multi-city)
            final fareKey = 'segment_${matchingSegmentIndex}_${segment.lfid}';
            
            // KEY FIX: For each segment LFID, we should only keep ONE fare option per fareTypeName
            // (LITE, VALUE, FLEX, Business). Multiple occurrences of the same LFID are due to combinability,
            // but users only need to see one option per fare type. We'll keep the cheapest one.
            
            // Check if fare options already exist for this key
            if (fareOptionsByLFID.containsKey(fareKey)) {
              final existingFares = fareOptionsByLFID[fareKey]!;
              
              // Group existing fares by fareTypeName
              final existingByType = <String, FlydubaiFlightFare>{};
              for (final fare in existingFares) {
                final typeKey = '${fare.fareTypeName}_${fare.cabin}';
                // Keep the cheapest option for each type
                if (!existingByType.containsKey(typeKey) || 
                    fare.baseFareAmountIncludingTax < existingByType[typeKey]!.baseFareAmountIncludingTax) {
                  existingByType[typeKey] = fare;
                }
              }
              
              // Process new fares and keep only the cheapest per type
              for (final fare in segment.fareTypes) {
                final typeKey = '${fare.fareTypeName}_${fare.cabin}';
                if (!existingByType.containsKey(typeKey) || 
                    fare.baseFareAmountIncludingTax < existingByType[typeKey]!.baseFareAmountIncludingTax) {
                  existingByType[typeKey] = fare;
                }
              }
              
              fareOptionsByLFID[fareKey] = existingByType.values.toList();
              developer.log('  💾 Updated fare options: ${existingByType.length} unique types (kept cheapest per type) for key: $fareKey');
            } else {
              // First time storing for this key - keep only one fare option per fareTypeName (cheapest)
              final faresByType = <String, FlydubaiFlightFare>{};
              
              for (final fare in segment.fareTypes) {
                final typeKey = '${fare.fareTypeName}_${fare.cabin}';
                // Keep the cheapest option for each type
                if (!faresByType.containsKey(typeKey) || 
                    fare.baseFareAmountIncludingTax < faresByType[typeKey]!.baseFareAmountIncludingTax) {
                  faresByType[typeKey] = fare;
                }
              }
              
              fareOptionsByLFID[fareKey] = faresByType.values.toList();
              developer.log('  💾 Stored ${faresByType.length} unique fare types with key: $fareKey (${segment.fareTypes.length} total options, kept cheapest per type)');
            }

            // Add to segment-specific list
            flightsBySegment[matchingSegmentIndex]!.add(flight);
            processedCount++;
            developer.log(
              '  ✅ Added MULTI-CITY flight for segment $matchingSegmentIndex: ${flight.airlineCode} ${flight.flightSegment.flightNumber} - ${flight.flightSegment.origin} to ${flight.flightSegment.destination} - PKR ${flight.price}',
            );
          } catch (e, stackTrace) {
            errorCount++;
            developer.log('  ❌ Error processing segment ${segment.lfid}: $e');
            developer.log('  Stack trace: $stackTrace');
            continue;
          }
        }
        
        developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        developer.log('📊 MULTI-CITY PROCESSING SUMMARY:');
        developer.log('  Total segments from API: ${flydubaiResponse.flightSegments.length}');
        developer.log('  Successfully processed: $processedCount');
        developer.log('  Skipped (no fare data): $skippedNoFareCount');
        developer.log('  Skipped (no city pair match): $skippedNoMatchCount');
        developer.log('  Errors: $errorCount');
        
        // Sort flights in each segment by price
        for (int i = 0; i < cityPairs.length; i++) {
          flightsBySegment[i]?.sort((a, b) => a.price.compareTo(b.price));
          final count = flightsBySegment[i]?.length ?? 0;
          developer.log('  📦 Segment $i: $count flights stored');
          if (count > 0) {
            developer.log('    First flight: ${flightsBySegment[i]!.first.flightSegment.origin} -> ${flightsBySegment[i]!.first.flightSegment.destination}');
            developer.log('    Last flight: ${flightsBySegment[i]!.last.flightSegment.origin} -> ${flightsBySegment[i]!.last.flightSegment.destination}');
          }
        }
        
        // Initialize multi-city selection
        developer.log('  🔄 Initializing multi-city selection...');
        initializeMultiCitySelection();
        developer.log('  ✅ Multi-city initialization complete');
      } else {
        developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        developer.log('=== PROCESSING ONE-WAY/RETURN FLIGHTS ===');
        developer.log('  Trip type: ${tripType == 0 ? "One-way" : tripType == 1 ? "Round-trip" : "Unknown ($tripType)"}');
        developer.log('  Processing ${flydubaiResponse.flightSegments.length} segments');
        
        // Process all segments and separate outbound/return (existing logic)
      developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      developer.log('📊 Round-trip flight separation:');
      developer.log('  Expected Origin: $expectedOrigin');
      developer.log('  Expected Destination: $expectedDestination');
      developer.log('  Outbound Date: $_outboundDate');
      developer.log('  Return Date: $_returnDate');
      developer.log('  Total segments to process: ${flydubaiResponse.flightSegments.length}');
      developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      for (var segment in flydubaiResponse.flightSegments) {
        try {
          developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          developer.log('🔍 Processing segment LFID: ${segment.lfid}');
          developer.log('  Route: ${segment.origin} -> ${segment.destination}');
          developer.log('  Date: ${segment.departureDateTime}');
          developer.log('  Date (date only): ${segment.departureDateTime.toIso8601String().substring(0, 10)}');
          developer.log('  Fare types count: ${segment.fareTypes.length}');

          // Check if segment has valid fare data
          if (segment.fareTypes.isEmpty) {
            developer.log('  ⚠️ Skipping segment ${segment.lfid} - no fare data');
            continue;
          }

          // Determine if this is outbound or return flight
          developer.log('  🔎 Determining flight type (outbound/return)...');
          bool isOutboundFlight = _isOutboundFlight(
            segment,
            expectedOrigin,
            expectedDestination,
            tripType,
          );

          developer.log('  ✅ Flight ${segment.lfid} classified as: ${isOutboundFlight ? "OUTBOUND" : "RETURN"}');

          // Create flight with actual segment data
          // Get buying price from lowest fare
          final lowestFare = segment.fareTypes.isNotEmpty
              ? segment.fareTypes.reduce((a, b) => a.baseFareAmountIncludingTax < b.baseFareAmountIncludingTax ? a : b)
              : null;
          final buyingPrice = lowestFare?.baseFareAmountIncludingTax ?? 0.0;
          // Calculate selling price with margin + BSP (BSP only for FlyDubai GDS)
          final sellingPrice = _calculateFlyDubaiSellingPrice(buyingPrice, marginData);
          
          final flight = FlydubaiFlight.fromFlightSegment(
            segment,
            airlineMap,
            response,
            expectedOrigin:
                isOutboundFlight ? expectedOrigin : expectedDestination,
            expectedDestination:
                isOutboundFlight ? expectedDestination : expectedOrigin,
            sellingPrice: sellingPrice,
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
      }

      // Sort flights by price
      _originalOutboundFlights.sort((a, b) => a.price.compareTo(b.price));
      _originalReturnFlights.sort((a, b) => a.price.compareTo(b.price));

      // Initialize filtered flights with all flights
      filteredOutboundFlights.assignAll(_originalOutboundFlights);
      filteredReturnFlights.assignAll(_originalReturnFlights);

      developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      developer.log('=== PARSING COMPLETE ===');
      developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      developer.log('📊 Final Results:');
      developer.log('  ✅ Outbound flights: ${_originalOutboundFlights.length}');
      if (_originalOutboundFlights.isNotEmpty) {
        developer.log('    First outbound: ${_originalOutboundFlights.first.flightSegment.origin} -> ${_originalOutboundFlights.first.flightSegment.destination} (PKR ${_originalOutboundFlights.first.price})');
        developer.log('    Last outbound: ${_originalOutboundFlights.last.flightSegment.origin} -> ${_originalOutboundFlights.last.flightSegment.destination} (PKR ${_originalOutboundFlights.last.price})');
      }
      developer.log('  ✅ Return flights: ${_originalReturnFlights.length}');
      if (_originalReturnFlights.isNotEmpty) {
        developer.log('    First return: ${_originalReturnFlights.first.flightSegment.origin} -> ${_originalReturnFlights.first.flightSegment.destination} (PKR ${_originalReturnFlights.first.price})');
        developer.log('    Last return: ${_originalReturnFlights.last.flightSegment.origin} -> ${_originalReturnFlights.last.flightSegment.destination} (PKR ${_originalReturnFlights.last.price})');
      } else {
        developer.log('    ⚠️ WARNING: No return flights found!');
        developer.log('    Check if:');
        developer.log('      1. Return date matches segment dates');
        developer.log('      2. Route is correct (expected: $expectedDestination -> $expectedOrigin)');
        developer.log('      3. API response contains return segments');
      }
      developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (_originalOutboundFlights.isEmpty && _originalReturnFlights.isEmpty) {
        setErrorMessage(
          'No FlyDubai flights found for the selected route and dates',
        );
      } else if (tripType == 1 && _originalReturnFlights.isEmpty) {
        developer.log('⚠️ WARNING: Round-trip search but no return flights found!');
        setErrorMessage(
          'No return flights found for the selected dates. Please try different dates.',
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
    developer.log('    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    developer.log('    📍 _isOutboundFlight called:');
    developer.log('      Segment: ${segment.origin} -> ${segment.destination}');
    developer.log('      Segment Date: ${segment.departureDateTime.toIso8601String().substring(0, 10)}');
    developer.log('      Trip Type: $tripType (${tripType == 0 ? "One-way" : tripType == 1 ? "Round-trip" : tripType == 2 ? "Multi-city" : "Unknown"})');
    developer.log('      Expected Origin: $expectedOrigin');
    developer.log('      Expected Destination: $expectedDestination');
    developer.log('      Stored Outbound Date: $_outboundDate');
    developer.log('      Stored Return Date: $_returnDate');
    
    // For one-way flights, all flights are outbound
    if (tripType == 0) {
      developer.log('      ✅ One-way flight - classifying as OUTBOUND');
      return true;
    }

    // For round-trip flights, separate by route and date
    if (tripType == 1) {
      developer.log('      🔄 Round-trip flight - analyzing route and date...');
      
      // Check if we have the expected origin/destination from search
      if (expectedOrigin != null && expectedDestination != null) {
        bool isOutboundRoute =
            (segment.origin == expectedOrigin &&
                segment.destination == expectedDestination);
        bool isReturnRoute =
            (segment.origin == expectedDestination &&
                segment.destination == expectedOrigin);
        
        developer.log('      Route analysis:');
        developer.log('        Is Outbound Route (${segment.origin}->${segment.destination} == $expectedOrigin->$expectedDestination): $isOutboundRoute');
        developer.log('        Is Return Route (${segment.origin}->${segment.destination} == $expectedDestination->$expectedOrigin): $isReturnRoute');
        
        // If we have dates, use them for more accurate classification
        if (_outboundDate != null && _returnDate != null) {
          DateTime segmentDate = DateTime(
            segment.departureDateTime.year,
            segment.departureDateTime.month,
            segment.departureDateTime.day,
          );

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
          
          developer.log('      Date analysis:');
          developer.log('        Segment Date: ${segmentDate.toIso8601String().substring(0, 10)}');
          developer.log('        Outbound Date: ${outboundDateOnly.toIso8601String().substring(0, 10)}');
          developer.log('        Return Date: ${returnDateOnly.toIso8601String().substring(0, 10)}');
          developer.log('        Matches Outbound Date: ${segmentDate.isAtSameMomentAs(outboundDateOnly)}');
          developer.log('        Matches Return Date: ${segmentDate.isAtSameMomentAs(returnDateOnly)}');
          
          // Check if flight is on outbound date with outbound route
          if (segmentDate.isAtSameMomentAs(outboundDateOnly) &&
              isOutboundRoute) {
            developer.log('      ✅ Classified as OUTBOUND (matches outbound date + route)');
            return true;
          }
          // Check if flight is on return date with return route
          if (segmentDate.isAtSameMomentAs(returnDateOnly) && isReturnRoute) {
            developer.log('      ✅ Classified as RETURN (matches return date + route)');
            return false;
          }
          
          // If date matches but route doesn't match perfectly, log warning
          if (segmentDate.isAtSameMomentAs(outboundDateOnly) && !isOutboundRoute) {
            developer.log('      ⚠️ WARNING: Date matches outbound but route doesn\'t! Route: ${segment.origin}->${segment.destination}, Expected: $expectedOrigin->$expectedDestination');
          }
          if (segmentDate.isAtSameMomentAs(returnDateOnly) && !isReturnRoute) {
            developer.log('      ⚠️ WARNING: Date matches return but route doesn\'t! Route: ${segment.origin}->${segment.destination}, Expected: $expectedDestination->$expectedOrigin');
          }
        }
        
        // Fallback: if we can't determine by date, use route direction
        developer.log('      📍 Using route direction fallback (no date match or dates not available)');
        developer.log('      ${isOutboundRoute ? "✅ Classified as OUTBOUND" : isReturnRoute ? "✅ Classified as RETURN" : "⚠️ WARNING: Route doesn\'t match expected - defaulting to OUTBOUND"}');
        return isOutboundRoute;
      } else {
        developer.log('      ⚠️ WARNING: Expected origin/destination is null - defaulting to OUTBOUND');
      }
    }

    // Default to outbound for multi-city or unknown cases
    developer.log('      📍 Default case - classifying as OUTBOUND');
    return true;
  }

  void handleFlydubaiFlightSelection(
    FlydubaiFlight flight, {
    bool isReturnFlight = false,
  }) {
    developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    developer.log('🎯 handleFlydubaiFlightSelection called');
    developer.log('  Flight: ${flight.airlineCode} ${flight.flightSegment.flightNumber}');
    developer.log('  isReturnFlight: $isReturnFlight');
    
    // Check if we're in multi-city mode
    final bookingController = Get.find<FlightBookingController>();
    final isMultiCity = bookingController.tripType.value == TripType.multiCity;
    
    developer.log('  isMultiCity: $isMultiCity');
    developer.log('  currentMultiCitySegment: ${currentMultiCitySegment.value}');
    
    if (isMultiCity) {
      // For multi-city, use the multi-city handler
      developer.log('  🔀 Routing to multi-city handler');
      final segmentIndex = currentMultiCitySegment.value;
      handleMultiCityFlightSelection(flight, segmentIndex);
      return;
    }
    
    // For one-way/return, use existing logic
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
  List<FlydubaiFlightFare> getFareOptionsForFlight(FlydubaiFlight flight, {int? segmentIndex}) {
    List<FlydubaiFlightFare> options;
    
    // For multi-city, use segment-specific key
    if (segmentIndex != null) {
      final multiCityKey = 'segment_${segmentIndex}_${flight.flightSegment.lfid}';
      developer.log('🔍 getFareOptionsForFlight (multi-city):');
      developer.log('  Segment index: $segmentIndex');
      developer.log('  Flight LFID: ${flight.flightSegment.lfid}');
      developer.log('  Looking for key: $multiCityKey');
      developer.log('  Available keys: ${fareOptionsByLFID.keys.where((k) => k.startsWith('segment_')).toList()}');
      
      options = fareOptionsByLFID[multiCityKey] ?? [];
      developer.log('  Found ${options.length} fare options before deduplication');
      
      // Debug: Log all fare options to see duplicates
      if (options.isNotEmpty) {
        developer.log('  📋 All fare options:');
        for (int i = 0; i < options.length; i++) {
          final opt = options[i];
          developer.log('    [$i] FareID: ${opt.fareId}, Type: ${opt.fareTypeName}, SolnId: ${opt.solnId}, Cabin: ${opt.cabin}');
        }
      }
    } else {
      // For one-way/return, use standard LFID key
      options = fareOptionsByLFID[flight.rph] ?? [];
      if (options.isEmpty) {
        developer.log('⚠️ No fare options found for flight RPH: ${flight.rph}');
        developer.log('  Available keys: ${fareOptionsByLFID.keys.toList()}');
      }
    }
    
    // Deduplicate by fareId AND solnId to ensure no duplicates are returned
    // Use composite key: fareId + solnId + fareTypeName to catch all duplicates
    // Final deduplication: Keep only ONE fare option per fareTypeName (LITE, VALUE, FLEX, Business)
    // This ensures users only see one option per package type, even if combinability created multiple
    final uniqueByType = <String, FlydubaiFlightFare>{};
    
    for (final option in options) {
      final typeKey = '${option.fareTypeName}_${option.cabin}';
      // Keep the cheapest option for each type
      if (!uniqueByType.containsKey(typeKey) || 
          option.baseFareAmountIncludingTax < uniqueByType[typeKey]!.baseFareAmountIncludingTax) {
        uniqueByType[typeKey] = option;
      }
    }
    
    final finalOptions = uniqueByType.values.toList();
    
    if (finalOptions.length != options.length) {
      developer.log('  ⚠️ Removed ${options.length - finalOptions.length} duplicate fare types (kept cheapest per type)');
    }
    developer.log('  ✅ Returning ${finalOptions.length} unique fare types (was ${options.length} total options)');
    
    // Debug: Log final options
    if (finalOptions.isNotEmpty) {
      developer.log('  📋 Final fare options (one per type):');
      for (int i = 0; i < finalOptions.length; i++) {
        final opt = finalOptions[i];
        developer.log('    [$i] Type: ${opt.fareTypeName}, FareID: ${opt.fareId}, Price: ${opt.baseFareAmountIncludingTax}');
      }
    }
    
    return finalOptions;
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
      price: newPrice, // Selling price (display price)
      buyingPrice: flight.buyingPrice, // Keep original buying price
      sellingPrice: newPrice, // Update selling price to new price
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
      // Check if this is a multi-city booking
      final selectedMultiCityFlightsList = selectedMultiCityFlights
          .where((f) => f != null)
          .cast<FlydubaiFlight>()
          .toList();
      final selectedMultiCityFareOptionsList = selectedMultiCityFareOptions
          .where((f) => f != null)
          .cast<FlydubaiFlightFare>()
          .toList();

      final isMultiCity = selectedMultiCityFlightsList.isNotEmpty && 
                          selectedMultiCityFareOptionsList.isNotEmpty &&
                          selectedMultiCityFlightsList.length == selectedMultiCityFareOptionsList.length;

      if (isMultiCity) {
        // Get passenger counts from extras controller
        final int adultCount = extrasController.adultPassengers.value;
        final int childCount = extrasController.childPassengers.value;
        final int infantCount = extrasController.infantPassengers.value;
        final int totalPassengers = adultCount + childCount + infantCount;
        
        print('🌍 Building segments for MULTI-CITY booking (${selectedMultiCityFlightsList.length} segments)');
        print('👥 Passengers: $adultCount adults, $childCount children, $infantCount infants (Total: $totalPassengers)');
        
        // Build segments for each multi-city flight
        for (int segmentIndex = 0; segmentIndex < selectedMultiCityFlightsList.length; segmentIndex++) {
          final flight = selectedMultiCityFlightsList[segmentIndex];
          final fareOption = selectedMultiCityFareOptionsList[segmentIndex];
          
          print('📍 Building Multi-City Segment $segmentIndex:');
          print('   - Flight: ${flight.airlineCode} ${flight.flightSegment.flightNumber}');
          print('   - LFID: ${flight.flightSegment.lfid}');
          print('   - Route: ${flight.flightSegment.origin} -> ${flight.flightSegment.destination}');
          print('   - Fare: ${fareOption.fareTypeName}');
          print('   - Fare ID: ${fareOption.fareId}');
          
          final adultFareId = fareOption.fareId;
          final segmentMeta = _buildSegmentMeta(flight);
          final segmentLfid = flight.flightSegment.lfid.toString();
          
          // Get extras data from extras controller - filter by segment LFID for multi-city
          final filteredBaggage = _filterExtrasBySegment(extrasController.selectedBaggage, segmentLfid);
          final filteredMeals = _filterExtrasByLegForSegment(extrasController.selectedMeals, segmentLfid, flight);
          final filteredSeats = _filterExtrasByLegForSegment(extrasController.selectedSeats, segmentLfid, flight);
          
          // Build segments for EACH ADULT passenger (skip children/infants for multi-city)
          // For multi-city, we create segments for all adults for each flight segment
          int passengerId = 0;
          
          // Add segments for adults only
          for (int adultIndex = 0; adultIndex < adultCount; adultIndex++) {
            passengerId++;
            final passengerKey = 'p$adultIndex'; // p0, p1, etc.
            
            // Filter extras for this specific passenger
            final passengerBaggage = _filterExtrasByPassenger(filteredBaggage, passengerKey);
            final passengerMeals = _filterExtrasByPassenger(filteredMeals, passengerKey);
            final passengerSeats = _filterExtrasByPassenger(filteredSeats, passengerKey);
            
            final baggageExtras = _buildBaggageExtras(passengerBaggage, segmentMeta);
            final mealExtras = _buildMealExtras(passengerMeals, segmentMeta, flight);
            final seatExtras = _buildSeatExtras(passengerSeats, segmentMeta, flight);

            segments.add({
              'pax': passengerId,
              'fareID': adultFareId,
              'lfid': flight.flightSegment.lfid,
              'extra': {
                'baggage': baggageExtras,
                'meal': mealExtras,
                'seat': seatExtras
              }
            });
          }
          
          // Skip children and infants for multi-city (they're in Passengers array but not in Segments)
          // TODO: Add child/infant segment support when API supports it
        }
      } else {
        // Build segments for outbound flight (one-way or round-trip)
      if (selectedOutboundFlight != null && selectedOutboundFareOption != null) {
        print('📍 Building Outbound Segment:');
        print('   - Flight: ${selectedOutboundFlight!.airlineCode} ${selectedOutboundFlight!.flightSegment.flightNumber}');
        print('   - LFID: ${selectedOutboundFlight!.flightSegment.lfid}');
        print('   - Fare: ${selectedOutboundFareOption!.fareTypeName}');
        print('   - Fare ID: ${selectedOutboundFareOption!.fareId}');
        
        final fareId = selectedOutboundFareOption!.fareId;
        final outboundMeta = _buildSegmentMeta(selectedOutboundFlight!);

        // Get extras data from extras controller
        final baggageExtras = _buildBaggageExtras(
          extrasController.selectedBaggage,
          outboundMeta,
        );
        final mealExtras = _buildMealExtras(
          extrasController.selectedMeals,
          outboundMeta,
            selectedOutboundFlight!,
        );
        final seatExtras = _buildSeatExtras(
          extrasController.selectedSeats,
          outboundMeta,
            selectedOutboundFlight!,
        );

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
        final returnMeta = _buildSegmentMeta(selectedReturnFlight!);

        // Get extras data from extras controller (you might want separate handling for return flight)
        final baggageExtras = _buildBaggageExtras(
          extrasController.selectedBaggage,
          returnMeta,
        );
        final mealExtras = _buildMealExtras(
          extrasController.selectedMeals,
          returnMeta,
            selectedReturnFlight!,
        );
        final seatExtras = _buildSeatExtras(
          extrasController.selectedSeats,
          returnMeta,
            selectedReturnFlight!,
        );

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

  // Helper method to filter extras by segment code
  Map<String, dynamic> _filterExtrasBySegment(RxMap<String, dynamic> allExtras, String segmentLfid) {
    final filtered = <String, dynamic>{};
    
    for (final entry in allExtras.entries) {
      final key = entry.key;
      // Key format: seg{segmentCode}|p{passengerId}
      final expectedPrefix = 'seg$segmentLfid|';
      if (key.startsWith(expectedPrefix)) {
        filtered[key] = entry.value;
      }
    }
    
    return filtered;
  }

  // Helper method to filter extras by passenger ID
  // Extras keys are in format: 
  // - Baggage: seg{segmentCode}|p{passengerId}
  // - Meals/Seats: legseg{segmentCode}_leg{pfid}|p{passengerId}
  Map<String, dynamic> _filterExtrasByPassenger(Map<String, dynamic> allExtras, String passengerKey) {
    final filtered = <String, dynamic>{};
    
    for (final entry in allExtras.entries) {
      final key = entry.key;
      // Check if key ends with |{passengerKey}
      // This works for both formats: seg{code}|p{id} and legseg{code}_leg{pfid}|p{id}
      final expectedSuffix = '|$passengerKey';
      if (key.endsWith(expectedSuffix)) {
        filtered[key] = entry.value;
      }
    }
    
    return filtered;
  }

  // Helper method to filter meals/seats by leg code (for segments with stops)
  // Keys are stored as: legseg{segmentCode}_leg{pfid}|p{passengerId}
  Map<String, dynamic> _filterExtrasByLegForSegment(RxMap<String, dynamic> allExtras, String segmentLfid, FlydubaiFlight flight) {
    final filtered = <String, dynamic>{};
    
    // Get all leg codes for this segment from the extras controller
    try {
      final flyController = Get.find<FlydubaiFlightController>();
      final extrasController = Get.find<FlydubaiExtrasController>();
      final legCodes = extrasController.getLegCodesForSegment(segmentLfid);
      
      // Keys are stored as: leg{legCode}|p{passengerId}
      // where legCode is from getLegCodesForSegment (format: seg{segmentCode}_leg{pfid})
      for (final entry in allExtras.entries) {
        final key = entry.key;
        // Check if this key matches any leg code for this segment
        for (final legCode in legCodes) {
          // Key format: leg{legCode}|p{passengerId}
          if (key.startsWith('leg$legCode|')) {
            filtered[key] = entry.value;
            break; // Found a match, no need to check other legs
          }
        }
      }
    } catch (e) {
      print('⚠️ Error filtering extras by leg: $e');
      // Fallback: try to match by PFID directly from flight data
      final legCodes = <String>[];
      try {
        final rawData = flight.rawData;
        final retrieveResult = rawData['RetrieveFareQuoteDateRangeResponse']?['RetrieveFareQuoteDateRangeResult'];
        final flightSegments = retrieveResult?['FlightSegments']?['FlightSegment'];
        final flightSegmentList = flightSegments is List ? flightSegments : (flightSegments != null ? [flightSegments] : []);
        
        for (final seg in flightSegmentList) {
          if ((seg['LFID'] as num?)?.toInt() == int.tryParse(segmentLfid)) {
            final flightLegDetails = seg['FlightLegDetails']?['FlightLegDetail'];
            final legList = flightLegDetails is List ? flightLegDetails : (flightLegDetails != null ? [flightLegDetails] : []);
            
            for (final legRef in legList) {
              final pfid = (legRef['PFID'] as num?)?.toInt();
              if (pfid != null) {
                final legCode = 'seg${segmentLfid}_leg$pfid';
                legCodes.add(legCode);
              }
            }
            break;
          }
        }
      } catch (e2) {
        print('⚠️ Error in fallback leg code extraction: $e2');
      }
      
      // Try to match with extracted leg codes
      for (final entry in allExtras.entries) {
        final key = entry.key;
        for (final legCode in legCodes) {
          if (key.startsWith('leg$legCode|')) {
            filtered[key] = entry.value;
            break;
          }
        }
      }
    }
    
    return filtered;
  }

  Map<String, dynamic> _buildSegmentMeta(FlydubaiFlight flight) {
    final int lfid = flight.flightSegment.lfid;
    final departureDateTime = flight.flightSegment.departureDateTime;
    final String departureIso = departureDateTime.toIso8601String();

    final physicalFlightId = _extractPhysicalFlightId(
      flight.rawData,
      lfid,
    );
    
    // Get leg count from flight segment
    int legCount = 1;
    try {
      final rawData = flight.rawData;
      final retrieveResult = rawData['RetrieveFareQuoteDateRangeResponse']?['RetrieveFareQuoteDateRangeResult'];
      final flightSegments = retrieveResult?['FlightSegments']?['FlightSegment'];
      final flightSegmentList = flightSegments is List ? flightSegments : (flightSegments != null ? [flightSegments] : []);
      
      for (final seg in flightSegmentList) {
        if (seg is Map && (seg['LFID'] as num?)?.toInt() == lfid) {
          legCount = (seg['LegCount'] as num?)?.toInt() ?? 1;
          break;
        }
      }
    } catch (e) {
      print('⚠️ Error extracting leg count: $e');
    }

    final departureDateOnly = departureIso.split('T').first;

    return {
      'lfid': lfid,
      'physicalFlightId': physicalFlightId,
      'legCount': legCount,
      'departureDateTime': departureIso,
      'departureDateMidnight': '${departureDateOnly}T00:00:00',
    };
  }

  int _extractPhysicalFlightId(Map<String, dynamic> rawData, int lfid) {
    try {
      final retrieveResult = rawData['RetrieveFareQuoteDateRangeResponse']
          ?['RetrieveFareQuoteDateRangeResult'];
      if (retrieveResult == null) return 0;

      final segmentData = retrieveResult['FlightSegments']?['FlightSegment'];
      final List<dynamic> segments;

      if (segmentData is List) {
        segments = segmentData;
      } else if (segmentData is Map) {
        segments = [segmentData];
      } else {
        return 0;
      }

      for (final segment in segments) {
        if (segment is! Map) continue;
        final segmentLfid = (segment['LFID'] as num?)?.toInt();
        if (segmentLfid != lfid) continue;

        final legDetails = segment['FlightLegDetails']?['FlightLegDetail'];
        if (legDetails is List && legDetails.isNotEmpty) {
          return (legDetails.first['PFID'] as num?)?.toInt() ?? 0;
        } else if (legDetails is Map) {
          return (legDetails['PFID'] as num?)?.toInt() ?? 0;
        }
        break;
      }
    } catch (e) {
      debugPrint('Error extracting PFID: $e');
    }
    return 0;
  }

// Helper methods to build extras in the correct format
  String _buildBaggageExtras(
    Map<String, dynamic> selectedBaggage,
    Map<String, dynamic> segmentMeta,
  ) {
    if (selectedBaggage.isEmpty) return '';

    try {
      // Format: OfferCode!!LFID!!DepartureDate!!Amount!!Currency!!RuleId!!PFID
      // For baggage, use PFID 0 for segments with multiple legs, or first leg PFID for single leg
      final baggage = selectedBaggage.values.first;
      final code = baggage['id']?.toString() ?? 'BAGB';
      final amount = baggage['charge']?.toString() ?? '0';
      final currency = baggage['currency']?.toString() ?? 'PKR';
      final description = baggage['description']?.toString() ?? 'Baggage';

      // Check if segment has multiple legs - if so, use PFID 0 for baggage
      // Otherwise use first leg's PFID
      final legCount = segmentMeta['legCount'] as int? ?? 1;
      final baggagePfid = legCount > 1 ? 0 : (segmentMeta['physicalFlightId'] ?? 0);

      return '$code!!${segmentMeta['lfid']}!!${segmentMeta['departureDateMidnight']}!!$amount!!$currency!!$description!!$baggagePfid';
    } catch (e) {
      print('⚠️ Error building baggage extras: $e');
      return '';
    }
  }

  List<String> _buildMealExtras(
    Map<String, dynamic> selectedMeals,
    Map<String, dynamic> segmentMeta,
    FlydubaiFlight flight,
  ) {
    final List<String> meals = [];

    if (selectedMeals.isEmpty) return meals;

    try {
      // Get the first leg PFID for this segment
      // API only allows meals on the first leg of a segment, not on connecting legs
      final firstLegPfid = segmentMeta['physicalFlightId'] as int? ?? 0;
      final legCount = segmentMeta['legCount'] as int? ?? 1;
      
      print('   🍽️ Building meals for segment with $legCount leg(s)');
      print('   📍 First leg PFID: $firstLegPfid');
      
      // Format: OfferCode!!LFID!!DepartureDate!!Amount!!Currency!!RuleId!!PFID
      // Keys are in format: legseg{segmentCode}_leg{pfid}|p{passengerId}
      for (final entry in selectedMeals.entries) {
        final key = entry.key;
        final meal = entry.value;
        
        // Extract PFID from key: legseg{segmentCode}_leg{pfid}|p{passengerId}
        int? pfid;
        String? departureDate;
        
        if (key.contains('_leg')) {
          final parts = key.split('_leg');
          if (parts.length >= 2) {
            final pfidStr = parts[1].split('|').first;
            pfid = int.tryParse(pfidStr);
            
            if (pfid == null) {
              print('   ⚠️ Failed to parse PFID from meal key: $key, pfidStr: $pfidStr');
              continue;
            }
            
            // IMPORTANT: API only allows meals on the first leg of a segment
            // Skip meals for connecting legs (legs other than the first)
            if (legCount > 1 && pfid != firstLegPfid) {
              print('   ⏭️ Skipping meal for connecting leg PFID: $pfid (meals only allowed on first leg PFID: $firstLegPfid)');
              continue;
            }
            
            print('   ✅ Extracted meal PFID: $pfid from key: $key');
            
            // Get departure date for this specific leg from flight data
            departureDate = _getLegDepartureDate(flight, pfid);
            if (departureDate == null && pfid != null) {
              print('   ⚠️ Could not get departure date for PFID: $pfid');
            }
          } else {
            print('   ⚠️ Meal key format incorrect: $key (expected legseg{segmentCode}_leg{pfid}|p{passengerId})');
            continue;
          }
        } else {
          print('   ⚠️ Meal key does not contain _leg: $key');
          continue;
        }
        
        // Use first leg PFID for meals (API requirement)
        final finalPfid = firstLegPfid;
        
        // For meals, API requires midnight format (YYYY-MM-DDT00:00:00)
        // Use segment departure date (first leg date) for all meals
        final mealDepartureDate = segmentMeta['departureDateMidnight'];
        
        print('   📅 Meal date: $mealDepartureDate (using segment first leg date)');
        
        final code = meal['id']?.toString() ?? 'MLIN';
        final amount = meal['charge']?.toString() ?? '0';
        final currency = meal['currency']?.toString() ?? 'PKR';
        final description = meal['description']?.toString() ?? meal['name']?.toString() ?? 'Meal';

        meals.add('$code!!${segmentMeta['lfid']}!!$mealDepartureDate!!$amount!!$currency!!$description!!$finalPfid');
        print('   ✅ Added meal: $code for PFID: $finalPfid, Date: $mealDepartureDate');
      }
      
      if (legCount > 1 && selectedMeals.length > meals.length) {
        print('   ⚠️ Note: ${selectedMeals.length - meals.length} meal(s) skipped (meals only allowed on first leg for multi-leg segments)');
      }
    } catch (e) {
      print('Error building meal extras: $e');
    }

    return meals;
  }

  List<String> _buildSeatExtras(
    Map<String, dynamic> selectedSeats,
    Map<String, dynamic> segmentMeta,
    FlydubaiFlight flight,
  ) {
    final List<String> seats = [];

    if (selectedSeats.isEmpty) return seats;

    try {
      // Format: OfferCode!!LFID!!DepartureDate!!Amount!!Currency!!RuleId!!PFID!!RowNumber!!SeatNumber
      // Keys are in format: legseg{segmentCode}_leg{pfid}|p{passengerId}
      for (final entry in selectedSeats.entries) {
        final key = entry.key;
        final seat = entry.value;
        
        // Extract PFID from key: legseg{segmentCode}_leg{pfid}|p{passengerId}
        int? pfid;
        String? departureDate;
        
        if (key.contains('_leg')) {
          final parts = key.split('_leg');
          if (parts.length >= 2) {
            final pfidStr = parts[1].split('|').first;
            pfid = int.tryParse(pfidStr);
            
            // Get departure date for this specific leg from flight data
            departureDate = _getLegDepartureDate(flight, pfid);
          }
        }
        
        // Fallback to segment PFID and date if leg-specific not found
        final finalPfid = pfid ?? segmentMeta['physicalFlightId'];
        // For seats, use actual departure time from leg if available
        // If leg-specific date not found, use from seat data or segment
        String departure = departureDate ?? 
                          (seat['departureDate']?.toString().isNotEmpty == true
                              ? seat['departureDate'].toString()
                              : segmentMeta['departureDateTime']);
        
        // Ensure departure date has proper format
        // For seats, API accepts both midnight format and actual time
        // Use actual time if available from leg, otherwise use segment departure time
        if (!departure.contains('T')) {
          departure = '${departure}T00:00:00';
        } else {
          // If we have actual departure time from leg, use it; otherwise use midnight
          // The API should accept both formats
          final timePart = departure.split('T')[1];
          if (!timePart.contains(':') || timePart == '00:00:00') {
            // If it's midnight or missing time, keep as is or use segment time
            if (departureDate == null) {
              // No leg-specific date, use segment departure time
              departure = segmentMeta['departureDateTime'];
            }
          }
        }
        
        final code = seat['serviceCode']?.toString();
        final amount = seat['charge']?.toString() ?? '0';
        final currency = seat['currency']?.toString() ?? 'PKR';
        final row = seat['rowNumber']?.toString() ?? '';
        final seatNumber = seat['seatNumber']?.toString() ?? '';
        final comment = 'Seat $seatNumber';

        seats.add('${code ?? 'SPST'}!!${segmentMeta['lfid']}!!$departure!!$amount!!$currency!!$comment!!$finalPfid!!$row!!$seatNumber');
      }
    } catch (e) {
      print('Error building seat extras: $e');
    }

    return seats;
  }
  
  // Helper method to get departure date for a specific leg (PFID)
  // Returns date in format: YYYY-MM-DDTHH:mm:ss (actual departure time)
  String? _getLegDepartureDate(FlydubaiFlight flight, int? pfid) {
    if (pfid == null) return null;
    
    try {
      final rawData = flight.rawData;
      final retrieveResult = rawData['RetrieveFareQuoteDateRangeResponse']?['RetrieveFareQuoteDateRangeResult'];
      final legDetails = retrieveResult?['LegDetails']?['LegDetail'];
      
      if (legDetails != null) {
        final legList = legDetails is List ? legDetails : [legDetails];
        for (final leg in legList) {
          if (leg is Map) {
            final legPfid = (leg['PFID'] as num?)?.toInt();
            if (legPfid == pfid) {
              final depDate = leg['DepartureDate']?.toString();
              if (depDate != null && depDate.isNotEmpty) {
                // Return the actual departure date/time as-is
                // For meals: API accepts midnight format (T00:00:00)
                // For seats: API might need actual time, but midnight also works
                return depDate;
              }
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ Error getting leg departure date: $e');
    }
    
    return null;
  }

  // ==================== MULTI-CITY METHODS ====================

  // Initialize multi-city flight selection
  void initializeMultiCitySelection() {
    final bookingController = Get.find<FlightBookingController>();
    final segmentCount = bookingController.cityPairs.length;

    developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    developer.log('🔄 initializeMultiCitySelection called');
    developer.log('  Segment count: $segmentCount');

    // Clear and initialize lists with correct size
    selectedMultiCityFlights.clear();
    selectedMultiCityFareOptions.clear();

    // Add null placeholders for each segment
    for (int i = 0; i < segmentCount; i++) {
      selectedMultiCityFlights.add(null);
      selectedMultiCityFareOptions.add(null);
    }

    // Start from segment 0
    currentMultiCitySegment.value = 0;

    developer.log('  ✅ Initialized lists with ${selectedMultiCityFlights.length} segments each');
    developer.log('  📍 Current segment set to: 0');
    developer.log('  📊 Flights available per segment:');
    for (int i = 0; i < segmentCount; i++) {
      final count = flightsBySegment[i]?.length ?? 0;
      developer.log('    Segment $i: $count flights');
    }
  }

  // Get flights for a specific segment
  List<FlydubaiFlight> getFlightsForSegment(int segmentIndex) {
    developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    developer.log('🔍 getFlightsForSegment called for segment $segmentIndex');
    
    final bookingController = Get.find<FlightBookingController>();
    final totalSegments = bookingController.cityPairs.length;

    developer.log('  Total city pairs: $totalSegments');
    
    if (segmentIndex >= totalSegments) {
      developer.log('  ❌ Invalid segment index: $segmentIndex (max: ${totalSegments - 1})');
      return [];
    }

    final cityPair = bookingController.cityPairs[segmentIndex];
    developer.log('  City pair $segmentIndex: ${cityPair.fromCity.value} -> ${cityPair.toCity.value}');
    developer.log('  Expected date: ${cityPair.departureDate.value}');

    // Get flights from the segment-specific storage
    final segmentFlights = flightsBySegment[segmentIndex] ?? [];
    
    developer.log('  📦 Flights in flightsBySegment[$segmentIndex]: ${segmentFlights.length}');
    developer.log('  📊 Total segments in flightsBySegment: ${flightsBySegment.length}');
    developer.log('  📋 Available segment keys: ${flightsBySegment.keys.toList()}');

    if (segmentFlights.isNotEmpty) {
      developer.log('  ✅ Returning ${segmentFlights.length} flights from segment storage');
      for (int i = 0; i < segmentFlights.length; i++) {
        final flight = segmentFlights[i];
        developer.log('    Flight $i: ${flight.flightSegment.origin} -> ${flight.flightSegment.destination} (PKR ${flight.price})');
      }
      return segmentFlights;
    }
    
    developer.log('  ⚠️ No flights found in segment storage, trying fallback...');

    // Fallback: try to match flights by route (cityPair already defined above)
    final fromCity = cityPair.fromCity.value;
    final toCity = cityPair.toCity.value;
    final departureDate = DateTime(
      cityPair.departureDateTime.value.year,
      cityPair.departureDateTime.value.month,
      cityPair.departureDateTime.value.day,
    );

    developer.log('Fallback route matching for segment $segmentIndex');
    developer.log('Route: $fromCity -> $toCity on ${departureDate.toIso8601String().substring(0, 10)}');

    // Combine all flights from all segments for fallback search
    final allFlights = <FlydubaiFlight>[];
    for (var flights in flightsBySegment.values) {
      allFlights.addAll(flights);
    }

    // Filter flights that match this segment
    final matchingFlights = allFlights.where((flight) {
      try {
        final flightOrigin = flight.flightSegment.origin;
        final flightDestination = flight.flightSegment.destination;
        final flightDate = DateTime(
          flight.flightSegment.departureDateTime.year,
          flight.flightSegment.departureDateTime.month,
          flight.flightSegment.departureDateTime.day,
        );

        final matches = flightOrigin == fromCity &&
            flightDestination == toCity &&
            flightDate.isAtSameMomentAs(departureDate);

        if (matches) {
          developer.log('Found matching flight via fallback: $flightOrigin -> $flightDestination');
        }

        return matches;
      } catch (e) {
        return false;
      }
    }).toList();

    developer.log('Found ${matchingFlights.length} matching flights for segment $segmentIndex via fallback');
    return matchingFlights;
  }

  // Check if all multi-city segments are selected
  bool get isAllMultiCitySegmentsSelected {
    final bookingController = Get.find<FlightBookingController>();
    final requiredSize = bookingController.cityPairs.length;

    if (selectedMultiCityFlights.length < requiredSize ||
        selectedMultiCityFareOptions.length < requiredSize) {
      return false;
    }

    for (int i = 0; i < requiredSize; i++) {
      if (selectedMultiCityFlights[i] == null ||
          selectedMultiCityFareOptions[i] == null) {
        return false;
      }
    }

    return true;
  }

  // Get the next segment that needs to be selected
  int getNextUnselectedSegment() {
    final bookingController = Get.find<FlightBookingController>();
    final requiredSegments = bookingController.cityPairs.length;

    for (int i = 0; i < requiredSegments; i++) {
      bool flightMissing = i >= selectedMultiCityFlights.length ||
          selectedMultiCityFlights[i] == null;
      bool fareOptionMissing = i >= selectedMultiCityFareOptions.length ||
          selectedMultiCityFareOptions[i] == null;

      if (flightMissing || fareOptionMissing) {
        return i;
      }
    }

    return -1; // All segments selected
  }

  // Handle multi-city flight selection
  void handleMultiCityFlightSelection(FlydubaiFlight flight, int segmentIndex) {
    developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    developer.log('🎯 handleMultiCityFlightSelection called');
    developer.log('  Segment index: $segmentIndex');
    developer.log('  Flight LFID: ${flight.flightSegment.lfid}');
    developer.log('  Flight RPH: ${flight.rph}');
    developer.log('  Flight route: ${flight.flightSegment.origin} -> ${flight.flightSegment.destination}');

    // Ensure the lists are properly sized
    final bookingController = Get.find<FlightBookingController>();
    final requiredSize = bookingController.cityPairs.length;

    while (selectedMultiCityFlights.length < requiredSize) {
      selectedMultiCityFlights.add(null);
    }
    while (selectedMultiCityFareOptions.length < requiredSize) {
      selectedMultiCityFareOptions.add(null);
    }

    // Store the flight IMMEDIATELY
    selectedMultiCityFlights[segmentIndex] = flight;
    currentMultiCitySegment.value = segmentIndex;

    developer.log('  ✅ Flight stored for segment $segmentIndex');
    
    // Verify fare options exist before opening dialog
    final fareKey = 'segment_${segmentIndex}_${flight.flightSegment.lfid}';
    final fareOptions = fareOptionsByLFID[fareKey] ?? [];
    developer.log('  🔍 Checking fare options before opening dialog:');
    developer.log('    Fare key: $fareKey');
    developer.log('    Fare options found: ${fareOptions.length}');
    if (fareOptions.isEmpty) {
      developer.log('    ⚠️ WARNING: No fare options found for key $fareKey');
      developer.log('    Available keys: ${fareOptionsByLFID.keys.where((k) => k.startsWith('segment_')).toList()}');
    }

    // Open package selection dialog
    developer.log('  📦 Opening package selection dialog...');
    developer.log('    Dialog parameters: isMultiCity=true, segmentIndex=$segmentIndex');
    Get.dialog(
      FlyDubaiPackageSelectionDialog(
        flight: flight,
        isReturnFlight: false,
        isMultiCity: true,
        segmentIndex: segmentIndex,
      ),
      barrierDismissible: false,
    );
  }

  // Handle multi-city package selection
  void handleMultiCityPackageSelection(
    FlydubaiFlightFare fareOption,
    int segmentIndex,
  ) {
    final bookingController = Get.find<FlightBookingController>();
    final requiredSize = bookingController.cityPairs.length;

    developer.log('handleMultiCityPackageSelection called with segment $segmentIndex');

    // Ensure the fare options list is properly sized
    while (selectedMultiCityFareOptions.length < requiredSize) {
      selectedMultiCityFareOptions.add(null);
    }

    // Store the fare option
    selectedMultiCityFareOptions[segmentIndex] = fareOption;

    developer.log('Package selected for segment $segmentIndex');
    developer.log('Package fare type: ${fareOption.fareTypeName}');

    // Force trigger the reactive update
    selectedMultiCityFlights.refresh();
    selectedMultiCityFareOptions.refresh();

    // Small delay to ensure reactive updates are processed
    Future.delayed(const Duration(milliseconds: 100), () {
      // Check if all segments are selected
      if (isAllMultiCitySegmentsSelected) {
        developer.log('All segments selected, proceeding to review');
        _proceedToMultiCityReview();
      } else {
        developer.log('Moving to next segment');
        proceedToNextMultiCitySegment();
      }
    });
  }

  // Proceed to next multi-city segment
  void proceedToNextMultiCitySegment() {
    developer.log('proceedToNextMultiCitySegment called');

    final nextSegment = getNextUnselectedSegment();
    developer.log('Next segment to select: $nextSegment');

    if (nextSegment != -1) {
      currentMultiCitySegment.value = nextSegment;

      // Get flights for the next segment
      final segmentFlights = getFlightsForSegment(nextSegment);
      developer.log('Found ${segmentFlights.length} flights for segment $nextSegment');

      if (segmentFlights.isEmpty) {
        developer.log('No flights found for segment $nextSegment');
        Get.snackbar(
          'No Flights Available',
          'No flights found for this segment. Please try different dates or routes.',
          snackPosition: SnackPosition.BOTTOM,
        );

        // Try to find the next available segment
        bool foundNextSegment = false;
        final bookingController = Get.find<FlightBookingController>();
        for (int i = nextSegment + 1;
            i < bookingController.cityPairs.length;
            i++) {
          final testFlights = getFlightsForSegment(i);
          if (testFlights.isNotEmpty) {
            currentMultiCitySegment.value = i;
            _showMultiCityFlightSelection(i);
            foundNextSegment = true;
            break;
          }
        }

        if (!foundNextSegment) {
          // No more segments with flights, proceed to review
          _proceedToMultiCityReview();
        }
      } else {
        developer.log('Showing flight selection for segment $nextSegment');
        Future.delayed(const Duration(milliseconds: 300), () {
          _showMultiCityFlightSelection(nextSegment);
        });
      }
    } else {
      developer.log('All segments processed, proceeding to review');
      _proceedToMultiCityReview();
    }
  }

  // Show multi-city flight selection for a segment
  void _showMultiCityFlightSelection(int segmentIndex) {
    final bookingController = Get.find<FlightBookingController>();

    if (segmentIndex >= bookingController.cityPairs.length) {
      developer.log('Invalid segment index: $segmentIndex');
      return;
    }

    final cityPair = bookingController.cityPairs[segmentIndex];
    final segmentFlights = getFlightsForSegment(segmentIndex);

    developer.log('_showMultiCityFlightSelection for segment $segmentIndex');
    developer.log('Route: ${cityPair.fromCity.value} -> ${cityPair.toCity.value}');
    developer.log('Available flights for segment: ${segmentFlights.length}');

    // Update current segment before showing selection
    currentMultiCitySegment.value = segmentIndex;

    // Close any open dialogs first
    if (Get.isDialogOpen == true) {
      Get.back();
    }

    // Navigate to multi-city flight selection page
    Future.microtask(() {
      Get.off(() => FlyDubaiMultiCityFlightPage(
            currentSegment: segmentIndex,
            availableFlights: segmentFlights,
          ));
    });
  }

  // Proceed to multi-city review/booking
  // Add multi-city flights to cart
  Future<Map<String, dynamic>> addMultiCityFlightsToCart() async {
    try {
      developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      developer.log('🛒 ADDING MULTI-CITY FLIGHTS TO CART');
      developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final selectedFlights = selectedMultiCityFlights
          .where((f) => f != null)
          .cast<FlydubaiFlight>()
          .toList();
      final selectedFareOptions = selectedMultiCityFareOptions
          .where((f) => f != null)
          .cast<FlydubaiFlightFare>()
          .toList();

      if (selectedFlights.isEmpty || selectedFareOptions.isEmpty) {
        return {
          'success': false,
          'error': 'No flights selected for multi-city cart',
        };
      }

      if (selectedFlights.length != selectedFareOptions.length) {
        return {
          'success': false,
          'error': 'Mismatch between selected flights and fare options',
        };
      }

      final List<String> bookingIds = [];

      // Add all multi-city segments to booking IDs
      for (int i = 0; i < selectedFlights.length; i++) {
        final flight = selectedFlights[i];
        final fareOption = selectedFareOptions[i];
        
        developer.log('📍 Processing Multi-City Segment $i:');
        developer.log('   - Flight: ${flight.airlineCode} ${flight.flightSegment.flightNumber}');
        developer.log('   - LFID: ${flight.flightSegment.lfid}');
        developer.log('   - Route: ${flight.flightSegment.origin} -> ${flight.flightSegment.destination}');
        developer.log('   - Selected Fare: ${fareOption.fareTypeName}');
        
        final fareIndex = _getFareIndex(flight, fareOption);
        final bookingId = '${flight.flightSegment.lfid}_$fareIndex';
        bookingIds.add(bookingId);
        developer.log('   ✅ Segment $i Booking ID: $bookingId');
      }

      if (bookingIds.isEmpty) {
        return {
          'success': false,
          'error': 'No booking IDs generated for multi-city cart',
        };
      }

      // Use first flight's raw data for cart (all flights should have similar structure)
      final flightData = selectedFlights.first.rawData;

      if (flightData == null) {
        return {
          'success': false,
          'error': 'No flight data available for multi-city cart',
        };
      }

      developer.log('📤 Calling addToCart API with ${bookingIds.length} segments');
      final result = await apiService.addToCart(
        bookingIds: bookingIds,
        flightData: flightData,
      );

      if (result['success'] == true) {
        developer.log('✅ Multi-city flights added to cart successfully');
        
        // Store cart data AND security GUID for booking process
        _cartData = result['data'];
        final securityGuid = result['securityGuid'];
        
        if (securityGuid != null) {
          _cartData?['SecurityGuid'] = securityGuid;
        }
        
        developer.log('Security GUID for PNR: $securityGuid');
      } else {
        developer.log('❌ Failed to add multi-city flights to cart: ${result['error']}');
      }

      return result;
    } catch (e) {
      developer.log('❌ Add multi-city to cart error: $e');
      return {
        'success': false,
        'error': 'Failed to add multi-city flights to cart: $e',
      };
    }
  }

  void _proceedToMultiCityReview() async {
    developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    developer.log('🚀 PROCEEDING TO MULTI-CITY REVIEW');
    developer.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final selectedFlights = selectedMultiCityFlights
        .where((f) => f != null)
        .cast<FlydubaiFlight>()
        .toList();
    final selectedFareOptions = selectedMultiCityFareOptions
        .where((f) => f != null)
        .cast<FlydubaiFlightFare>()
        .toList();

    if (selectedFlights.isEmpty || selectedFareOptions.isEmpty) {
      developer.log('❌ No flights selected for multi-city booking');
      Get.snackbar(
        'Selection Incomplete',
        'Please select flights for all segments',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (selectedFlights.length != selectedFareOptions.length) {
      developer.log('❌ Mismatch: ${selectedFlights.length} flights but ${selectedFareOptions.length} fare options');
      Get.snackbar(
        'Selection Error',
        'Mismatch between flights and packages',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    developer.log('✅ All ${selectedFlights.length} segments selected');
    for (int i = 0; i < selectedFlights.length; i++) {
      developer.log(
        '  Segment $i: ${selectedFlights[i].flightSegment.origin} -> ${selectedFlights[i].flightSegment.destination} (${selectedFareOptions[i].fareTypeName})',
      );
    }

    // Show loading indicator
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      // Add all multi-city flights to cart
      developer.log('🛒 Adding multi-city flights to cart...');
      final cartResult = await addMultiCityFlightsToCart();

      Get.back(); // Close loading dialog

      if (cartResult['success'] != true) {
        developer.log('❌ Failed to add flights to cart: ${cartResult['error']}');
        Get.snackbar(
          'Error',
          'Failed to add flights to cart: ${cartResult['error'] ?? "Unknown error"}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      developer.log('✅ Multi-city flights added to cart successfully');
      
      // Calculate total price
      double totalPrice = 0.0;
      for (int i = 0; i < selectedFareOptions.length; i++) {
        totalPrice += selectedFareOptions[i].baseFareAmountIncludingTax;
      }

      developer.log('💰 Total price: $totalPrice ${selectedFlights.first.currency}');

      // Navigate to booking form
      // Use first flight as primary, but pass all flights and fare options
      // Note: AirBlueBookingFlight.forFlyDubai doesn't support multi-city yet,
      // so we'll use the first flight and pass the rest via cartData
      developer.log('📋 Navigating to booking form...');
      Get.to(
        () => AirBlueBookingFlight.forFlyDubai(
          flight: selectedFlights.first,
          returnFlight: selectedFlights.length > 1 ? selectedFlights[1] : null,
          outboundFare: selectedFareOptions.first,
          returnFare: selectedFareOptions.length > 1 ? selectedFareOptions[1] : null,
          totalPrice: totalPrice,
          currency: selectedFlights.first.currency,
          cartData: _cartData,
        ),
      );
    } catch (e, stackTrace) {
      Get.back(); // Close loading dialog
      developer.log('❌ Error in _proceedToMultiCityReview: $e');
      developer.log('Stack trace: $stackTrace');
      Get.snackbar(
        'Error',
        'Failed to proceed to booking: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }
}

// AirlineInfo is now imported from sabre_flight_models.dart AirlineInfo(this.name, this.logoPath);
