// controllers/flydubai_flight_controller.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ready_flights/views/flight/search_flights/flydubai/flydubai_model.dart';


import '../../../../services/api_service_flydubai.dart';
import '../../../../services/api_service_sabre.dart';
import '../../../../services/margin_service_flight.dart';
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
  final ApiServiceMargin marginApiService = Get.put(ApiServiceMargin());

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

  // Cache for margin data so we can reuse it between search and booking
  Map<String, dynamic>? _cachedMarginData;

  // Expose a safe setter so other layers (e.g. controllers) can inject margin data
  void setMarginData(Map<String, dynamic> margin) {
    _cachedMarginData = Map<String, dynamic>.from(margin);
  }



  // Calculate price with margin and BSP (BSP only for FlyDubai GDS, not Sabre)
  // BSP is a special fee that should be added only to FlyDubai GDS flights
  double _calculateFlyDubaiSellingPrice(double buyingPrice, Map<String, dynamic> marginData) {
    // First calculate price with margin
    double priceWithMargin = marginApiService.calculatePriceWithMargin(buyingPrice, marginData);
    
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
      }
    }
    
    // Round up to next integer if there's a decimal (matching Laravel PHP behavior)
    return priceWithMargin.ceil().toDouble();
  }

  void loadFlights(Map<String, dynamic> result, String fromCity, String toCity, int tripTpe) {
    try {

      if (result.containsKey('flights')) {
        parseApiResponse(
          result['flights'],
          expectedOrigin: fromCity,
          expectedDestination: toCity,
          tripType: tripTpe,
        );
      } else {
        setErrorMessage('No flights data in result');
      }
    } catch (e) {
      setErrorMessage('Failed to load flights: $e');
    }
  }

  void setErrorMessage(String message) {
    errorMessage.value = message;
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
        } else {
          // Try splitting by comma first (in case there are commas)
          final originParts = origin.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          final destParts = destination.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          
          // For round trip: originParts = [LHE, DXB], destParts = [DXB, LHE]
          // We want first pair: LHE -> DXB
          cleanOrigin = originParts.isNotEmpty ? originParts[0] : originCleaned;
          cleanDestination = destParts.isNotEmpty ? destParts[0] : destCleaned;
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

      // Process the result
      if (result.containsKey('error')) {
        setErrorMessage(result['error']);
      } else if (result.containsKey('flights') && result['success'] == true) {
        // Parse the response with search parameters for validation
        await parseApiResponse(
          result['flights'],
          expectedOrigin: cleanOrigin,
          expectedDestination: cleanDestination,
          tripType: type,
        );
      } else {
        setErrorMessage('Invalid FlyDubai API response format');
      }
    } catch (e) {
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


      // Check response structure
      final retrieveResult = response?['RetrieveFareQuoteDateRangeResponse']?['RetrieveFareQuoteDateRangeResult'];
      if (retrieveResult != null) {
      }

      final flydubaiResponse = FlydubaiResponse.fromJson(response);

      if (!flydubaiResponse.success) {
        setErrorMessage(
          flydubaiResponse.errorMessage ?? 'Failed to parse response',
        );
        return;
      }

      // Fetch margin for FlyDubai (airline code FZ)
      Map<String, dynamic> marginData = {};
      try {
        marginData = await marginApiService.getMargin('FZ', 'flydubai', "Fly Dubai");
        // Cache margin data in FlyDubai API service for reuse during booking/PNR creation
        setMarginData(marginData);
      } catch (e) {
        // Margin fetch failed, using defaults
      }

      // Create airline map for FlyDubai
      final airlineMap = {
        'FZ': AirlineInfo(
          'FlyDubai',
          'https://images.kiwi.com/airlines/64/FZ.png',
        ),
      };

      // For multi-city, organize flights by segment FIRST
      if (tripType == 2) {
        
        // Get city pairs from booking controller
        final bookingController = Get.find<FlightBookingController>();
        final cityPairs = bookingController.cityPairs;
        
        // Initialize flightsBySegment for each city pair
        for (int i = 0; i < cityPairs.length; i++) {
          flightsBySegment[i] = [];
        }
        
        int processedCount = 0;
        int skippedNoFareCount = 0;
        int skippedNoMatchCount = 0;
        int errorCount = 0;
        
        // Process all segments and match them to city pairs
        for (var segment in flydubaiResponse.flightSegments) {
          try {
            // Check if segment has valid fare data
            if (segment.fareTypes.isEmpty) {
              skippedNoFareCount++;
              continue;
            }

            // Find matching city pair segment
            int? matchingSegmentIndex;
            final segmentDate = DateTime(
              segment.departureDateTime.year,
              segment.departureDateTime.month,
              segment.departureDateTime.day,
            );
            
            for (int i = 0; i < cityPairs.length; i++) {
              final cityPair = cityPairs[i];
              final cityPairDate = DateTime(
                cityPair.departureDateTime.value.year,
                cityPair.departureDateTime.value.month,
                cityPair.departureDateTime.value.day,
              );
              
              if (segment.origin == cityPair.fromCity.value &&
                  segment.destination == cityPair.toCity.value &&
                  segmentDate.isAtSameMomentAs(cityPairDate)) {
                matchingSegmentIndex = i;
                break;
              }
            }

            if (matchingSegmentIndex == null) {
              skippedNoMatchCount++;
              continue;
            }

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
            }

            // Add to segment-specific list
            flightsBySegment[matchingSegmentIndex]!.add(flight);
            processedCount++;
          } catch (e, stackTrace) {
            errorCount++;
            continue;
          }
        }
        
        // Sort flights in each segment by price
        for (int i = 0; i < cityPairs.length; i++) {
          flightsBySegment[i]?.sort((a, b) => a.price.compareTo(b.price));
        }
        
        // Initialize multi-city selection
        initializeMultiCitySelection();
      } else {
        // Process all segments and separate outbound/return (existing logic)
      for (var segment in flydubaiResponse.flightSegments) {
        try {
          // Check if segment has valid fare data
          if (segment.fareTypes.isEmpty) {
            continue;
          }

          // Determine if this is outbound or return flight
          bool isOutboundFlight = _isOutboundFlight(
            segment,
            expectedOrigin,
            expectedDestination,
            tripType,
          );

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
            _originalOutboundFlights.add(flight);
          } else {
            _originalReturnFlights.add(flight);
          }
        } catch (e) {
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

      if (_originalOutboundFlights.isEmpty && _originalReturnFlights.isEmpty) {
        setErrorMessage(
          'No FlyDubai flights found for the selected route and dates',
        );
      } else if (tripType == 1 && _originalReturnFlights.isEmpty) {
        setErrorMessage(
          'No return flights found for the selected dates. Please try different dates.',
        );
      }
    } catch (e, stackTrace) {
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
      return true;
    }

    // For round-trip flights, separate by route and date
    if (tripType == 1) {
      // Check if we have the expected origin/destination from search
      if (expectedOrigin != null && expectedDestination != null) {
        bool isOutboundRoute =
            (segment.origin == expectedOrigin &&
                segment.destination == expectedDestination);
        bool isReturnRoute =
            (segment.origin == expectedDestination &&
                segment.destination == expectedOrigin);
        
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
          
          // Check if flight is on outbound date with outbound route
          if (segmentDate.isAtSameMomentAs(outboundDateOnly) &&
              isOutboundRoute) {
            return true;
          }
          // Check if flight is on return date with return route
          if (segmentDate.isAtSameMomentAs(returnDateOnly) && isReturnRoute) {
            return false;
          }
        }
        
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
    // Check if we're in multi-city mode
    final bookingController = Get.find<FlightBookingController>();
    final isMultiCity = bookingController.tripType.value == TripType.multiCity;
    
    if (isMultiCity) {
      // For multi-city, use the multi-city handler
      final segmentIndex = currentMultiCitySegment.value;
      handleMultiCityFlightSelection(flight, segmentIndex);
      return;
    }
    
    // For one-way/return, use existing logic
    if (isReturnFlight) {
      selectedReturnFlight = flight;

      // Show package selection for return flight
      Get.dialog(
        FlyDubaiPackageSelectionDialog(flight: flight, isReturnFlight: true),
        barrierDismissible: false,
      );
    } else {
      selectedOutboundFlight = flight;
      selectedFlight.value = flight;

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
      options = fareOptionsByLFID[multiCityKey] ?? [];
    } else {
      // For one-way/return, use standard LFID key
      options = fareOptionsByLFID[flight.rph] ?? [];
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
    } else {
      filteredOutboundFlights.assignAll(filtered);
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

      // Generate booking ID (LFID_FareIndex)
      final bookingId = '${flight.flightSegment.lfid}_${_getFareIndex(flight, selectedFare)}';

      // Call revalidation API
      final result = await apiService.revalidateFlight(
        bookingId: bookingId,
        flightData: flight.rawData,
      );

      if (result['success'] == true) {
        final updatedPrice = result['updatedPrice'] ?? flight.price;

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
        return false;
      }
    } catch (e) {
      return false;
    }
  }

// Add flight to cart (for final booking)
  // In FlydubaiFlightController, update the addFlightsToCart method
  Future<Map<String, dynamic>> addFlightsToCart() async {
  try {

    // Check if this is a round-trip flight
    final isRoundTrip = selectedOutboundFlight != null && selectedReturnFlight != null;
    
    if (isRoundTrip) {
      // Apply combinability logic for round-trip flights
      final combinabilityResult = _applyCombinabilityLogic();
      if (!combinabilityResult['success']) {
        return combinabilityResult;
      }
    }

    final List<String> bookingIds = [];

    // Add outbound flight if selected
    if (selectedOutboundFlight != null && selectedOutboundFareOption != null) {
      final fareIndex = _getFareIndex(selectedOutboundFlight!, selectedOutboundFareOption!);
      final outboundId = '${selectedOutboundFlight!.flightSegment.lfid}_$fareIndex';
      bookingIds.add(outboundId);
    }

    // Add return flight if selected
    if (selectedReturnFlight != null && selectedReturnFareOption != null) {
      final fareIndex = _getFareIndex(selectedReturnFlight!, selectedReturnFareOption!);
      final returnId = '${selectedReturnFlight!.flightSegment.lfid}_$fareIndex';
      bookingIds.add(returnId);
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

      // Store cart data AND security GUID for booking process
      _cartData = result['data'];
      final securityGuid = result['securityGuid'];
      
      if (securityGuid != null) {
        _cartData?['SecurityGuid'] = securityGuid;
      }
      
    }

    return result;
  } catch (e) {
    return {
      'success': false,
      'error': 'Failed to add flights to cart: $e',
    };
  }
}
// Apply combinability logic for round-trip flights
  Map<String, dynamic> _applyCombinabilityLogic() {
    try {
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
        return {'success': true};
      }

      final combinability = retrieveResult['Combinability']?['BS'];
      if (combinability == null || combinability is! List) {
        return {'success': true};
      }

      // Get selected fare solution IDs
      final outboundSolnId = selectedOutboundFareOption?.solnId;
      final returnSolnId = selectedReturnFareOption?.solnId;
      
      if (outboundSolnId == null || returnSolnId == null) {
        return {'success': true};
      }

      // Check if the selected combination is valid
      bool foundValidCombination = false;
      for (final combo in combinability) {
        if (combo is Map && combo['SolnRef'] is List) {
          final solnRef = combo['SolnRef'] as List;
          if (solnRef.length >= 2) {
            final comboOutboundSoln = solnRef[0];
            final comboReturnSoln = solnRef[1];
            
            if (comboOutboundSoln == outboundSolnId && comboReturnSoln == returnSolnId) {
              foundValidCombination = true;
              break;
            }
          }
        }
      }

      if (foundValidCombination) {
        return {'success': true};
      }

      // If not found, try to find alternative combinations
      // Try to find a valid combination with the return flight
      for (final combo in combinability) {
        if (combo is Map && combo['SolnRef'] is List) {
          final solnRef = combo['SolnRef'] as List;
          if (solnRef.length >= 2) {
            final comboOutboundSoln = solnRef[0];
            final comboReturnSoln = solnRef[1];
            
            // If return flight matches, try to find compatible outbound
            if (comboReturnSoln == returnSolnId) {
              // Find alternative outbound fare with matching solution ID
              final alternativeOutbound = _findAlternativeFare(
                selectedOutboundFlight!, 
                comboOutboundSoln,
                selectedOutboundFareOption!.fareTypeName
              );
              
              if (alternativeOutbound != null) {
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
    
    // Use FareID instead of array index - this matches the web implementation
    for (int i = 0; i < options.length; i++) {
      if (options[i].fareTypeId == fare.fareTypeId && options[i].fareId == fare.fareId) {
        return fare.fareId; // Return FareID, not array index!
      }
    }
    
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
        
        // Build segments for each multi-city flight
        for (int segmentIndex = 0; segmentIndex < selectedMultiCityFlightsList.length; segmentIndex++) {
          final flight = selectedMultiCityFlightsList[segmentIndex];
          final fareOption = selectedMultiCityFareOptionsList[segmentIndex];
          
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

        segments.add({
          'pax': 1, // First passenger
          'fareID': fareId,
          'extra': {
            'baggage': baggageExtras,
            'meal': mealExtras,
            'seat': seatExtras
          }
        });
      }

      // Build segments for return flight
      if (selectedReturnFlight != null && selectedReturnFareOption != null) {
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

        segments.add({
          'pax': 1, // First passenger
          'fareID': fareId,
          'extra': {
            'baggage': baggageExtras,
            'meal': mealExtras,
            'seat': seatExtras
          }
        });
        }
      }
      
    } catch (e) {
      // Error building segment array
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
        // Error in fallback leg code extraction
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
      // Error extracting leg count
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
      // Error extracting PFID
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
              continue;
            }
            
            // IMPORTANT: API only allows meals on the first leg of a segment
            // Skip meals for connecting legs (legs other than the first)
            if (legCount > 1 && pfid != firstLegPfid) {
              continue;
            }
            
            // Get departure date for this specific leg from flight data
            departureDate = _getLegDepartureDate(flight, pfid);
          } else {
            continue;
          }
        } else {
          continue;
        }
        
        // Use first leg PFID for meals (API requirement)
        final finalPfid = firstLegPfid;
        
        // For meals, API requires midnight format (YYYY-MM-DDT00:00:00)
        // Use segment departure date (first leg date) for all meals
        final mealDepartureDate = segmentMeta['departureDateMidnight'];
        

        final code = meal['id']?.toString() ?? 'MLIN';
        final amount = meal['charge']?.toString() ?? '0';
        final currency = meal['currency']?.toString() ?? 'PKR';
        final description = meal['description']?.toString() ?? meal['name']?.toString() ?? 'Meal';

        meals.add('$code!!${segmentMeta['lfid']}!!$mealDepartureDate!!$amount!!$currency!!$description!!$finalPfid');
      }
    } catch (e) {
      // Error building meal extras
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
      // Error building seat extras
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
      // Error getting leg departure date
    }
    
    return null;
  }

  // ==================== MULTI-CITY METHODS ====================

  // Initialize multi-city flight selection
  void initializeMultiCitySelection() {
    final bookingController = Get.find<FlightBookingController>();
    final segmentCount = bookingController.cityPairs.length;


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
  }

  // Get flights for a specific segment
  List<FlydubaiFlight> getFlightsForSegment(int segmentIndex) {
    final bookingController = Get.find<FlightBookingController>();
    final totalSegments = bookingController.cityPairs.length;

    if (segmentIndex >= totalSegments) {
      return [];
    }

    final cityPair = bookingController.cityPairs[segmentIndex];

    // Get flights from the segment-specific storage
    final segmentFlights = flightsBySegment[segmentIndex] ?? [];

    if (segmentFlights.isNotEmpty) {
      return segmentFlights;
    }

    // Fallback: try to match flights by route (cityPair already defined above)
    final fromCity = cityPair.fromCity.value;
    final toCity = cityPair.toCity.value;
    final departureDate = DateTime(
      cityPair.departureDateTime.value.year,
      cityPair.departureDateTime.value.month,
      cityPair.departureDateTime.value.day,
    );

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

        return matches;
      } catch (e) {
        return false;
      }
    }).toList();

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

    // Open package selection dialog
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

    // Ensure the fare options list is properly sized
    while (selectedMultiCityFareOptions.length < requiredSize) {
      selectedMultiCityFareOptions.add(null);
    }

    // Store the fare option
    selectedMultiCityFareOptions[segmentIndex] = fareOption;

    // Force trigger the reactive update
    selectedMultiCityFlights.refresh();
    selectedMultiCityFareOptions.refresh();

    // Small delay to ensure reactive updates are processed
    Future.delayed(const Duration(milliseconds: 100), () {
      // Check if all segments are selected
      if (isAllMultiCitySegmentsSelected) {
        _proceedToMultiCityReview();
      } else {
        proceedToNextMultiCitySegment();
      }
    });
  }

  // Proceed to next multi-city segment
  void proceedToNextMultiCitySegment() {
    final nextSegment = getNextUnselectedSegment();

    if (nextSegment != -1) {
      currentMultiCitySegment.value = nextSegment;

      // Get flights for the next segment
      final segmentFlights = getFlightsForSegment(nextSegment);

      if (segmentFlights.isEmpty) {
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
        Future.delayed(const Duration(milliseconds: 300), () {
          _showMultiCityFlightSelection(nextSegment);
        });
      }
    } else {
      _proceedToMultiCityReview();
    }
  }

  // Show multi-city flight selection for a segment
  void _showMultiCityFlightSelection(int segmentIndex) {
    final bookingController = Get.find<FlightBookingController>();

    if (segmentIndex >= bookingController.cityPairs.length) {
      return;
    }

    final cityPair = bookingController.cityPairs[segmentIndex];
    final segmentFlights = getFlightsForSegment(segmentIndex);

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
        
        final fareIndex = _getFareIndex(flight, fareOption);
        final bookingId = '${flight.flightSegment.lfid}_$fareIndex';
        bookingIds.add(bookingId);
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

      final result = await apiService.addToCart(
        bookingIds: bookingIds,
        flightData: flightData,
      );

      if (result['success'] == true) {
        // Store cart data AND security GUID for booking process
        _cartData = result['data'];
        final securityGuid = result['securityGuid'];
        
        if (securityGuid != null) {
          _cartData?['SecurityGuid'] = securityGuid;
        }
      }

      return result;
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to add multi-city flights to cart: $e',
      };
    }
  }

  void _proceedToMultiCityReview() async {
    final selectedFlights = selectedMultiCityFlights
        .where((f) => f != null)
        .cast<FlydubaiFlight>()
        .toList();
    final selectedFareOptions = selectedMultiCityFareOptions
        .where((f) => f != null)
        .cast<FlydubaiFlightFare>()
        .toList();

    if (selectedFlights.isEmpty || selectedFareOptions.isEmpty) {
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
      Get.snackbar(
        'Selection Error',
        'Mismatch between flights and packages',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // Show loading indicator
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      // Add all multi-city flights to cart
      final cartResult = await addMultiCityFlightsToCart();

      Get.back(); // Close loading dialog

      if (cartResult['success'] != true) {
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

      // Calculate total price
      double totalPrice = 0.0;
      for (int i = 0; i < selectedFareOptions.length; i++) {
        totalPrice += selectedFareOptions[i].baseFareAmountIncludingTax;
      }

      // Navigate to booking form
      // Use first flight as primary, but pass all flights and fare options
      // Note: AirBlueBookingFlight.forFlyDubai doesn't support multi-city yet,
      // so we'll use the first flight and pass the rest via cartData
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
