// flydubai_extras_controller.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ready_flights/services/api_service_flydubai.dart';
import 'package:ready_flights/views/flight/search_flights/flydubai/flydubai_model.dart';
import 'flydubai_controller.dart';

class FlydubaiExtrasController extends GetxController {
  final ApiServiceFlyDubai _apiService = Get.find<ApiServiceFlyDubai>();

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // Extras data
  final RxList<dynamic> availableBaggage = <dynamic>[].obs;
  final RxList<dynamic> availableMeals = <dynamic>[].obs;
  final RxList<dynamic> availableSeats = <dynamic>[].obs;

  // Selected extras
  // Keys strategy:
  // - For baggage: "seg{segmentCode}|p{passengerId}"
  // - For meals:   "seg{segmentCode}|p{passengerId}"
  // - For seats:   "seg{segmentCode}|p{passengerId}"
  final RxMap<String, dynamic> selectedBaggage = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> selectedMeals = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> selectedSeats = <String, dynamic>{}.obs;

  // Flight information
  final Rx<FlydubaiFlight?> selectedFlight = Rx<FlydubaiFlight?>(null);
  final Rx<FlydubaiFlightFare?> selectedFare = Rx<FlydubaiFlightFare?>(null);
  final RxList<String> bookingIds = <String>[].obs;
  
  // Cart data from add-to-cart response (used for seat/baggage/meal APIs)
  Map<String, dynamic>? cartData;

  // Passengers (exclude infants for extras)
  final RxInt adultPassengers = 1.obs;
  final RxInt childPassengers = 0.obs;
  final RxInt infantPassengers = 0.obs;
  final RxList<String> passengerIds = <String>[].obs; // p0, p1, ... for adults+children only

  // Pricing
  final RxDouble basePrice = 0.0.obs;
  final RxDouble totalExtrasPrice = 0.0.obs;
  final RxString currency = 'PKR'.obs;

  @override
  void onInit() {
    super.onInit();
    reset();

    // Check if screen was called with arguments for extras
    final arguments = Get.arguments;
    if (arguments != null) {
      _loadExtras(arguments);
    }
  }

  @override
  void onReady() {
    super.onReady();
    // Ensure passengers are initialized even if not passed in arguments
    if (passengerIds.isEmpty) {
      _initializePassengerIds();
    }
  }

  Future<void> _loadExtras(Map<String, dynamic> args) async {
    final flight = args['flight'] as FlydubaiFlight?;
    final fare = args['fare'] as FlydubaiFlightFare?;
    final isReturn = args['isReturn'] as bool? ?? false;
    
    // Extract cart data if available (for seat/baggage/meal APIs)
    cartData = args['cartData'] as Map<String, dynamic>?;

    // Passenger counts (with defaults)
    adultPassengers.value = (args['adult'] as int?) ?? 1;
    childPassengers.value = (args['child'] as int?) ?? 0;
    infantPassengers.value = (args['infant'] as int?) ?? 0;

    // Initialize passenger IDs immediately
    _initializePassengerIds();

    if (flight != null && fare != null) {
      await loadFlightExtras(flight, fare, isReturn);
    }
  }
  Future<bool> loadFlightExtras(FlydubaiFlight flight, FlydubaiFlightFare fare, bool isReturnFlight) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Store flight and fare info
      selectedFlight.value = flight;
      selectedFare.value = fare;

      // Generate booking IDs only if not already set (for multi-city, they're set in loadExtras)
      if (bookingIds.isEmpty) {
        // Generate booking IDs. For round-trip, include both outbound and return.
        final List<String> ids = [];

        // If this is return-leg extras, try to add outbound bookingId first
        if (isReturnFlight) {
          try {
            final flyController = Get.find<FlydubaiFlightController>();
            final outboundFlight = flyController.selectedOutboundFlight;
            final outboundFare = flyController.selectedOutboundFareOption;
            if (outboundFlight != null && outboundFare != null) {
              final outboundFareIndex = _getFareIndex(outboundFlight, outboundFare);
              final outboundId = '${outboundFlight.flightSegment.lfid}_$outboundFareIndex';
              ids.add(outboundId);
            }
          } catch (e) {
            // Silent error handling
          }
        }

        // Always add current leg bookingId (outbound for one-way, return for round-trip)
        final currentFareIndex = _getFareIndex(flight, fare);
        final currentId = '${flight.flightSegment.lfid}_$currentFareIndex';
        ids.add(currentId);

        bookingIds.value = ids;
      } else {
        debugPrint('✅ Using pre-set booking IDs for multi-city: ${bookingIds.value}');
      }

      // Set base price
      basePrice.value = flight.price;
      currency.value = flight.currency;

      // Load all extras in parallel
      final results = await Future.wait([
        _apiService.getSeatOptions(bookingIds: bookingIds, flightData: flight.rawData),
        _apiService.getBaggageOptions(bookingIds: bookingIds, flightData: flight.rawData),
        _apiService.getMealOptions(bookingIds: bookingIds, flightData: flight.rawData),
      ]);

      // Extract data from responses
      final seatData = results[0]['data'];
      final baggageData = results[1]['data'];
      final mealData = results[2]['data'];

      // Check baggage API result
      final baggageResult = results[1];
      if (baggageResult['success'] != true) {
        print('❌ Baggage API failed: ${baggageResult['error']}');
        errorMessage.value = baggageResult['error'] ?? 'Failed to load baggage';
        return false;
      }

      // Print baggage API response in readable format (chunked to avoid truncation)
      print('\n');
      print('═══════════════════════════════════════════════════════════════════════════════');
      print('📦 FLYDUBAI BAGGAGE API RESPONSE');
      print('═══════════════════════════════════════════════════════════════════════════════');
      try {
        final baggageFormatted = const JsonEncoder.withIndent('  ').convert(baggageResult);
        // Print in chunks to avoid truncation
        _printChunked(baggageFormatted);
      } catch (e) {
        print('Error formatting baggage response: $e');
        // Fallback: print raw response in chunks
        final rawString = baggageResult.toString();
        _printChunked(rawString);
      }
      print('═══════════════════════════════════════════════════════════════════════════════');
      print('\n');

      // Process data silently (no logs for seats and meals)
      _processSeatData(seatData);
      _processBaggageData(baggageData);
      _processMealData(mealData);

      return true;
    } catch (e) {
      errorMessage.value = 'Error loading extras: ${e.toString()}';
      return false;
    } finally {
      isLoading.value = false;
    }
  }



  void _processBaggageData(Map<String, dynamic> data) {
    try {
      final List<dynamic> baggageOptions = [];

      // Parse baggage data from API response
      if (data['ServiceOffers'] is List) {
        final serviceOffers = data['ServiceOffers'] as List;

        for (var offer in serviceOffers) {
          final offerCode = offer['offerCode']?.toString() ?? '';
          final description = offer['description']?.toString() ?? 'Baggage';
          final amount = offer['amount']?.toString() ?? '0';
          final currency = offer['currency']?.toString() ?? 'PKR';

          // Filter for baggage-related offers
          if (offerCode.contains('BAG') || offerCode.contains('BUP')) {
            final quantityAvailable = (offer['quantityAvailable'] as num?)?.toInt() ?? 0;
            
            baggageOptions.add({
              'id': offerCode,
              'description': description,
              'type': 'baggage',
              'charge': amount,
              'currency': currency,
              'offerID': offer['offerID']?.toString() ?? '',
              'quantityAvailable': quantityAvailable,
              'hashCode': offer['hashCode']?.toString() ?? '',
            });
          }
        }
      }

      // Add default options if none found
      if (baggageOptions.isEmpty) {
        baggageOptions.addAll([
          {
            'id': 'BAG20',
            'description': '20 kg Checked Baggage',
            'type': 'baggage',
            'charge': '5000',
            'currency': 'PKR',
          },
          {
            'id': 'BAG30',
            'description': '30 kg Checked Baggage',
            'type': 'baggage',
            'charge': '8000',
            'currency': 'PKR',
          },
        ]);
      }

      availableBaggage.value = baggageOptions;

    } catch (e) {
      debugPrint('❌ Error processing baggage data: $e');
      availableBaggage.value = [
        {
          'id': 'default_baggage',
          'description': '20 kg Baggage',
          'type': 'baggage',
          'charge': '5000',
        }
      ];
    }
  }

  void _processMealData(Map<String, dynamic> data) {
    try {
      final List<dynamic> mealOptions = [];

      // Parse meal data from API response
      if (data['ServiceOffers'] is List) {
        final serviceOffers = data['ServiceOffers'] as List;

        for (var offer in serviceOffers) {
          final offerCode = offer['offerCode']?.toString() ?? '';
          final description = offer['description']?.toString() ?? 'Meal';
          final amount = offer['amount']?.toString() ?? '0';
          final currency = offer['currency']?.toString() ?? 'PKR';

          // Filter for meal-related offers (excluding entertainment)
          if (offerCode.contains('ML') && !offerCode.contains('IFPP')) {
            mealOptions.add({
              'id': offerCode,
              'name': description,
              'description': description,
              'type': 'meal',
              'charge': amount,
              'currency': currency,
              'offerID': offer['offerID']?.toString() ?? '',
            });
          }
        }
      }

      // Add default options if none found
      if (mealOptions.isEmpty) {
        mealOptions.addAll([
          {
            'id': 'AVML',
            'name': 'Vegetarian Meal',
            'description': 'Vegetarian Indian Meal',
            'type': 'meal',
            'charge': '1500',
            'currency': 'PKR',
          },
          {
            'id': 'CHML',
            'name': 'Child Meal',
            'description': 'Special meal for children',
            'type': 'meal',
            'charge': '1200',
            'currency': 'PKR',
          },
        ]);
      }

      availableMeals.value = mealOptions;

    } catch (e) {
      availableMeals.value = [
        {
          'id': 'default_meal',
          'name': 'Standard Meal',
          'description': 'Regular meal service',
          'type': 'meal',
          'charge': '1000',
        }
      ];
    }
  }
  int _getFareIndex(FlydubaiFlight flight, FlydubaiFlightFare fare) {
    final options = flight.fareOptions ?? [];
    
    // Use FareID instead of array index - this matches the web implementation
    for (int i = 0; i < options.length; i++) {
      if (options[i].fareTypeId == fare.fareTypeId && options[i].fareId == fare.fareId) {
        return fare.fareId; // Return FareID, not array index!
      }
    }
    
    return fare.fareId; // Return FareID, not 0
  }

  void selectBaggage(String key, dynamic baggage) {
    // key should be composite: seg{code}|p{index}
    selectedBaggage[key] = baggage;
    _updateExtrasPrice();
  }

  void selectMeal(String key, dynamic meal) {
    // key should be composite: seg{code}|p{index}
    selectedMeals[key] = meal;
    _updateExtrasPrice();
  }

  // Add these methods to your FlydubaiExtrasController class

// Enhanced seat selection method
  void selectSeat(String key, dynamic seat) {
    if (seat['seatNumber']?.toString().isEmpty == true) {
      // Deselect current seat
      selectedSeats.remove(key);
    } else {
      // Select new seat
      selectedSeats[key] = seat;
    }
    _updateExtrasPrice();
  }

// Get selected seat for a key
  Map<String, dynamic>? getSelectedSeat(String key) {
    return selectedSeats[key];
  }

// Check if a specific seat is selected for a key
  bool isSeatSelected(String key, String seatNumber) {
    final selectedSeat = selectedSeats[key];
    if (selectedSeat == null) return false;

    return selectedSeat['seatNumber']?.toString() == seatNumber ||
        selectedSeat['id']?.toString().contains(seatNumber) == true;
  }

// Get seats for a specific segment (if you have multiple segments)
  List<dynamic> getSeatsForSegment(String segmentCode) {
    // For Flydubai, you might not have segments like AirArabia
    // But you can filter seats based on your data structure
    return availableSeats.where((seat) {
      // Add your filtering logic here if needed
      return true; // Return all seats for now
    }).toList();
  }

  // Helpers for passengers/segments
  void _initializePassengerIds() {
    passengerIds.clear();
    final total = adultPassengers.value + childPassengers.value;

    for (int i = 0; i < total; i++) {
      passengerIds.add('p$i');
    }
  }

  String getPassengerDisplayName(int index) {
    if (index < 0 || index >= passengerIds.length) {
      return 'Passenger ${index + 1}';
    }

    final adt = adultPassengers.value;
    if (index < adt) {
      return adt == 1 ? 'Adult' : 'Adult ${index + 1}';
    }
    final chIndex = index - adt;
    final totalChildren = childPassengers.value;
    return totalChildren == 1 ? 'Child' : 'Child ${chIndex + 1}';
  }
  // Add after the existing passenger selection methods

// Get selected baggage for specific passenger
  Map<String, dynamic>? getSelectedBaggageForPassenger(String segmentCode, String passengerId) {
    final key = 'seg$segmentCode|$passengerId';
    return selectedBaggage[key];
  }

// Get selected meal for specific passenger (now supports leg codes)
  Map<String, dynamic>? getSelectedMealForPassenger(String legCode, String passengerId) {
    final key = 'leg$legCode|$passengerId';
    return selectedMeals[key];
  }

// Get selected seat for specific passenger (now supports leg codes)
  Map<String, dynamic>? getSelectedSeatForPassenger(String legCode, String passengerId) {
    final key = 'leg$legCode|$passengerId';
    return selectedSeats[key];
  }

// Remove selection for a passenger
  void removePassengerSelection(String segmentCode, String passengerId, String type) {
    final key = 'seg$segmentCode|$passengerId';
    switch (type) {
      case 'baggage':
        selectedBaggage.remove(key);
        break;
      case 'meal':
        selectedMeals.remove(key);
        break;
      case 'seat':
        selectedSeats.remove(key);
        break;
    }
    _updateExtrasPrice();
  }

// Get all selections for a passenger (for summary)
  Map<String, dynamic> getPassengerSelections(String segmentCode, String passengerId) {
    final key = 'seg$segmentCode|$passengerId';
    return {
      'baggage': selectedBaggage[key],
      'meal': selectedMeals[key],
      'seat': selectedSeats[key],
    };
  }

// Check if passenger has any selections
  bool hasPassengerSelections(String segmentCode, String passengerId) {
    final key = 'seg$segmentCode|$passengerId';
    return selectedBaggage.containsKey(key) ||
        selectedMeals.containsKey(key) ||
        selectedSeats.containsKey(key);
  }


  List<String> getSegmentCodes() {
    // Check if this is a multi-city booking
    try {
      final flyController = Get.find<FlydubaiFlightController>();
      final selectedMultiCityFlightsList = flyController.selectedMultiCityFlights
          .where((f) => f != null)
          .cast<FlydubaiFlight>()
          .toList();
      final selectedMultiCityFareOptionsList = flyController.selectedMultiCityFareOptions
          .where((f) => f != null)
          .cast<FlydubaiFlightFare>()
          .toList();

      final isMultiCity = selectedMultiCityFlightsList.isNotEmpty && 
                          selectedMultiCityFareOptionsList.isNotEmpty &&
                          selectedMultiCityFlightsList.length == selectedMultiCityFareOptionsList.length;

      if (isMultiCity) {
        // Return LFIDs for all multi-city segments
        debugPrint('🌍 getSegmentCodes: Returning ${selectedMultiCityFlightsList.length} multi-city segments');
        return selectedMultiCityFlightsList
            .map((flight) => flight.flightSegment.lfid.toString())
            .toList();
      }
    } catch (e) {
      debugPrint('⚠️ Error checking multi-city in getSegmentCodes: $e');
    }

    // For one-way or round-trip, return single segment
    final flight = selectedFlight.value;
    if (flight == null) return ['0'];
    
    // For round-trip, check if there's a return flight
    try {
      final flyController = Get.find<FlydubaiFlightController>();
      final returnFlight = flyController.selectedReturnFlight;
      if (returnFlight != null) {
        return [
          flight.flightSegment.lfid.toString(),
          returnFlight.flightSegment.lfid.toString(),
        ];
      }
    } catch (e) {
      // Silent error handling
    }
    
    return [flight.flightSegment.lfid.toString()];
  }

  /// Gets leg codes (PFIDs) for a specific segment
  /// Returns list of leg codes in format: "seg{segmentCode}_leg{legIndex}" or PFID
  List<String> getLegCodesForSegment(String segmentCode) {
    try {
      final flyController = Get.find<FlydubaiFlightController>();
      final selectedMultiCityFlightsList = flyController.selectedMultiCityFlights
          .where((f) => f != null)
          .cast<FlydubaiFlight>()
          .toList();

      final isMultiCity = selectedMultiCityFlightsList.isNotEmpty;

      FlydubaiFlight? targetFlight;
      
      if (isMultiCity) {
        // Find the flight for this segment
        final segmentLfid = int.tryParse(segmentCode);
        if (segmentLfid != null) {
          for (final flight in selectedMultiCityFlightsList) {
            if (flight.flightSegment.lfid == segmentLfid) {
              targetFlight = flight;
              break;
            }
          }
        }
      } else {
        // For one-way/return, use selected flight
        targetFlight = selectedFlight.value;
      }

      if (targetFlight == null) {
        // Fallback: return segment code as single leg
        return [segmentCode];
      }

      // Extract leg codes from legSchedules
      // Try to get PFIDs from raw data first
      final legCodes = <String>[];
      try {
        final rawData = targetFlight.rawData;
        final retrieveResult = rawData['RetrieveFareQuoteDateRangeResponse']?['RetrieveFareQuoteDateRangeResult'];
        final flightSegments = retrieveResult?['FlightSegments']?['FlightSegment'];
        final flightSegmentList = flightSegments is List ? flightSegments : (flightSegments != null ? [flightSegments] : []);
        
        // Find matching segment
        Map<String, dynamic>? matchingSegment;
        final segmentLfid = int.tryParse(segmentCode);
        for (final seg in flightSegmentList) {
          if ((seg['LFID'] as num?)?.toInt() == segmentLfid) {
            matchingSegment = seg as Map<String, dynamic>;
            break;
          }
        }
        
        if (matchingSegment != null) {
          // Get PFIDs from FlightLegDetails
          final flightLegDetails = matchingSegment['FlightLegDetails']?['FlightLegDetail'];
          final legList = flightLegDetails is List ? flightLegDetails : (flightLegDetails != null ? [flightLegDetails] : []);
          
          for (final legRef in legList) {
            final pfid = (legRef['PFID'] as num?)?.toInt();
            if (pfid != null) {
              legCodes.add('seg${segmentCode}_leg$pfid');
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error extracting PFIDs from raw data: $e');
      }
      
      // Fallback: use legSchedules with index if no PFIDs found
      if (legCodes.isEmpty && targetFlight.legSchedules.isNotEmpty) {
        for (int i = 0; i < targetFlight.legSchedules.length; i++) {
          legCodes.add('seg${segmentCode}_leg$i');
        }
      }

      // If no legs found, return segment code as single leg
      if (legCodes.isEmpty) {
        return [segmentCode];
      }

      return legCodes;
    } catch (e) {
      debugPrint('⚠️ Error getting leg codes for segment $segmentCode: $e');
      return [segmentCode]; // Fallback
    }
  }

  /// Gets leg information for display (origin -> destination)
  Map<String, String> getLegInfo(String legCode) {
    try {
      // Parse leg code: "seg{segmentCode}_leg{pfid}" or "seg{segmentCode}_leg{index}"
      final parts = legCode.split('_leg');
      if (parts.length != 2) return {'origin': '', 'destination': ''};

      final segmentCode = parts[0].replaceFirst('seg', '');
      final legIdentifier = parts[1];

      final flyController = Get.find<FlydubaiFlightController>();
      final selectedMultiCityFlightsList = flyController.selectedMultiCityFlights
          .where((f) => f != null)
          .cast<FlydubaiFlight>()
          .toList();

      final isMultiCity = selectedMultiCityFlightsList.isNotEmpty;

      FlydubaiFlight? targetFlight;
      
      if (isMultiCity) {
        final segmentLfid = int.tryParse(segmentCode);
        if (segmentLfid != null) {
          for (final flight in selectedMultiCityFlightsList) {
            if (flight.flightSegment.lfid == segmentLfid) {
              targetFlight = flight;
              break;
            }
          }
        }
      } else {
        targetFlight = selectedFlight.value;
      }

      if (targetFlight == null || targetFlight.legSchedules.isEmpty) {
        return {'origin': '', 'destination': ''};
      }

      // Try to find leg by PFID or index
      int? legIndex;
      if (legIdentifier.contains(RegExp(r'^\d+$'))) {
        // It's a PFID or index, try to find matching leg from raw data first
        try {
          final rawData = targetFlight.rawData;
          final retrieveResult = rawData['RetrieveFareQuoteDateRangeResponse']?['RetrieveFareQuoteDateRangeResult'];
          final flightSegments = retrieveResult?['FlightSegments']?['FlightSegment'];
          final flightSegmentList = flightSegments is List ? flightSegments : (flightSegments != null ? [flightSegments] : []);
          
          final segmentLfid = int.tryParse(segmentCode);
          Map<String, dynamic>? matchingSegment;
          for (final seg in flightSegmentList) {
            if ((seg['LFID'] as num?)?.toInt() == segmentLfid) {
              matchingSegment = seg as Map<String, dynamic>;
              break;
            }
          }
          
          if (matchingSegment != null) {
            final flightLegDetails = matchingSegment['FlightLegDetails']?['FlightLegDetail'];
            final legList = flightLegDetails is List ? flightLegDetails : (flightLegDetails != null ? [flightLegDetails] : []);
            
            final pfid = int.tryParse(legIdentifier);
            if (pfid != null) {
              for (int i = 0; i < legList.length; i++) {
                final legRef = legList[i];
                final legPfid = (legRef['PFID'] as num?)?.toInt();
                if (legPfid == pfid) {
                  legIndex = i;
                  break;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error finding leg by PFID: $e');
        }
        
        // Fallback: try to find by index in legSchedules
        if (legIndex == null) {
          legIndex = int.tryParse(legIdentifier);
        }
      } else {
        // It's an index
        legIndex = int.tryParse(legIdentifier);
      }

      if (legIndex == null || legIndex < 0 || legIndex >= targetFlight.legSchedules.length) {
        return {'origin': '', 'destination': ''};
      }

      final leg = targetFlight.legSchedules[legIndex];
      final schedules = leg['schedules'] as List?;
      if (schedules != null && schedules.isNotEmpty) {
        final firstSchedule = schedules[0] as Map<String, dynamic>?;
        final lastSchedule = schedules[schedules.length - 1] as Map<String, dynamic>?;
        
        final origin = firstSchedule?['departure']?['airport']?.toString() ?? '';
        final destination = lastSchedule?['arrival']?['airport']?.toString() ?? '';
        
        return {'origin': origin, 'destination': destination};
      }

      return {'origin': '', 'destination': ''};
    } catch (e) {
      debugPrint('⚠️ Error getting leg info for $legCode: $e');
      return {'origin': '', 'destination': ''};
    }
  }

  /// Gets the fare baggage code based on fare type name
  /// Returns: 'BAGB' (20kg), 'BAGL' (30kg), 'BAGX' (40kg), or null (no baggage/LITE)
  String? getFareBaggageCode({String? segmentCode}) {
    // For multi-city, get fare for the specific segment
    if (segmentCode != null) {
      try {
        final flyController = Get.find<FlydubaiFlightController>();
        final selectedMultiCityFlightsList = flyController.selectedMultiCityFlights
            .where((f) => f != null)
            .cast<FlydubaiFlight>()
            .toList();
        final selectedMultiCityFareOptionsList = flyController.selectedMultiCityFareOptions
            .where((f) => f != null)
            .cast<FlydubaiFlightFare>()
            .toList();

        final isMultiCity = selectedMultiCityFlightsList.isNotEmpty && 
                            selectedMultiCityFareOptionsList.isNotEmpty &&
                            selectedMultiCityFlightsList.length == selectedMultiCityFareOptionsList.length;

        if (isMultiCity) {
          // Find the segment index by LFID
          final segmentLfid = int.tryParse(segmentCode);
          if (segmentLfid != null) {
            for (int i = 0; i < selectedMultiCityFlightsList.length; i++) {
              if (selectedMultiCityFlightsList[i].flightSegment.lfid == segmentLfid) {
                final fare = selectedMultiCityFareOptionsList[i];
                final fareTypeName = fare.fareTypeName.toUpperCase();
                switch (fareTypeName) {
                  case 'VALUE':
                    return 'BAGB'; // 20kg
                  case 'FLEX':
                    return 'BAGL'; // 30kg
                  case 'BUSINESS':
                    return 'BAGX'; // 40kg
                  case 'LITE':
                  default:
                    return null; // No baggage included
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error getting fare baggage code for segment: $e');
      }
    }

    // Fallback to default fare
    final fare = selectedFare.value;
    if (fare == null) return null;
    
    final fareTypeName = fare.fareTypeName.toUpperCase();
    
    // Map fare types to baggage codes
    switch (fareTypeName) {
      case 'VALUE':
        return 'BAGB'; // 20kg
      case 'FLEX':
        return 'BAGL'; // 30kg
      case 'BUSINESS':
        return 'BAGX'; // 40kg
      case 'LITE':
      default:
        return null; // No baggage included
    }
  }

  /// Filters baggage options based on fare baggage code
  /// Logic matches web implementation:
  /// - If fare has BAGL (30kg): show only BUPZ (10kg upgrade)
  /// - If fare has BAGB (20kg): show only BUPL or BUPX (10kg or 20kg upgrade)
  /// - Otherwise (no baggage): show BAGB, BAGL, or BAGX (20kg, 30kg, 40kg allowance)
  List<dynamic> getFilteredBaggageOptions({String? segmentCode}) {
    final fareBagCode = getFareBaggageCode(segmentCode: segmentCode);
    final allBaggage = availableBaggage;
    
    debugPrint('🔍 getFilteredBaggageOptions called with segmentCode: $segmentCode');
    debugPrint('   Fare baggage code: $fareBagCode');
    debugPrint('   Total available baggage: ${allBaggage.length}');
    
    List<dynamic> filtered;
    if (fareBagCode == 'BAGL') {
      // Show only BUPZ (10kg upgrade)
      filtered = allBaggage.where((bag) {
        final code = bag['id']?.toString() ?? '';
        return code == 'BUPZ';
      }).toList();
      debugPrint('   Filtering for BAGL (30kg included): showing ${filtered.length} options (BUPZ only)');
    } else if (fareBagCode == 'BAGB') {
      // Show only BUPL or BUPX (10kg or 20kg upgrade)
      filtered = allBaggage.where((bag) {
        final code = bag['id']?.toString() ?? '';
        return code == 'BUPL' || code == 'BUPX';
      }).toList();
      debugPrint('   Filtering for BAGB (20kg included): showing ${filtered.length} options (BUPL/BUPX only)');
    } else {
      // Show BAGB, BAGL, or BAGX (20kg, 30kg, 40kg allowance)
      filtered = allBaggage.where((bag) {
        final code = bag['id']?.toString() ?? '';
        return code == 'BAGB' || code == 'BAGL' || code == 'BAGX';
      }).toList();
      debugPrint('   Filtering for no baggage (LITE): showing ${filtered.length} options (BAGB/BAGL/BAGX)');
    }
    return filtered;
  }

  /// Extracts weight from baggage description
  /// Returns weight in kg as int, or 999 if not found (for sorting)
  int _extractWeightFromDescription(String description) {
    final match = RegExp(r'(\d+)\s*kg', caseSensitive: false).firstMatch(description);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '0') ?? 999;
    }
    return 999; // Sort items without weight to the end
  }

  /// Gets filtered and sorted baggage options
  List<dynamic> getFilteredAndSortedBaggageOptions({String? segmentCode}) {
    final filtered = getFilteredBaggageOptions(segmentCode: segmentCode);
    
    // Filter out items with quantity 0 or invalid (matching web logic)
    final validBaggage = filtered.where((bag) {
      // Check quantity available (web checks quantity != '0')
      final quantity = bag['quantityAvailable'] as int? ?? 0;
      if (quantity == 0) return false;
      
      // Check if charge is valid
      final charge = double.tryParse(bag['charge']?.toString() ?? '0') ?? 0.0;
      final description = (bag['description'] ?? '').toString().toLowerCase();
      
      // Filter out "No Bag" options
      if (description.contains('no bag')) return false;
      
      return true;
    }).toList();
    
    // Sort by weight extracted from description (20kg, 30kg, 40kg order)
    validBaggage.sort((a, b) {
      final weightA = _extractWeightFromDescription(a['description']?.toString() ?? '');
      final weightB = _extractWeightFromDescription(b['description']?.toString() ?? '');
      return weightA.compareTo(weightB);
    });
    
    return validBaggage;
  }

  /// Prints JSON nicely with chunking
  void printJsonPretty(dynamic jsonData) {
    const int chunkSize = 1000;
    final jsonString = const JsonEncoder.withIndent(' ').convert(jsonData);

    for (int i = 0; i < jsonString.length; i += chunkSize) {
      final chunk = jsonString.substring(
        i,
        i + chunkSize < jsonString.length ? i + chunkSize : jsonString.length,
      );
      print(chunk);
    }
  }

  /// Prints large strings in chunks to avoid truncation
  void _printChunked(String text) {
    const int chunkSize = 800; // Smaller chunks for better reliability
    for (int i = 0; i < text.length; i += chunkSize) {
      final chunk = text.substring(
        i,
        i + chunkSize < text.length ? i + chunkSize : text.length,
      );
      print(chunk);
    }
  }
// Enhanced _processSeatData method with better seat mapping
  void _processSeatData(Map<String, dynamic> data) {
    try {
      final List<dynamic> seats = [];

      // Parse seat data from API response
      if (data['seatQuotes'] != null && data['seatQuotes']['flights'] is List) {
        final flights = data['seatQuotes']['flights'] as List;

        for (var flight in flights) {
          // Process actual seat prices from cabins
          if (flight['cabins'] is List) {
            final cabins = flight['cabins'] as List;

            for (var cabin in cabins) {
              if (cabin['seatMaps'] is List) {
                final seatMaps = cabin['seatMaps'] as List;

                for (var seatMap in seatMaps) {
                  final rowNumber = seatMap['rowNumber']?.toString() ?? '';

                  if (seatMap['seats'] is List) {
                    final seatsList = seatMap['seats'] as List;

                    for (var seat in seatsList) {
                      final seatLetter = seat['seat']?.toString() ?? '';
                      final seatNumber = '$rowNumber$seatLetter';
                      final amount = seat['amount']?.toString() ?? '0';
                      final serviceCode = seat['serviceCode']?.toString() ?? '';
                      final isAssigned = seat['assigned'] == true;
                      final isBlocked = seat['isBlocked'] == true || seat['isPreBlocked'] == true;

                      if (seatLetter.isNotEmpty && rowNumber.isNotEmpty) {
                        seats.add({
                          'id': '${serviceCode}_$seatNumber',
                          'seatNumber': seatNumber,
                          'seatLetter': seatLetter,
                          'description': 'Seat $seatNumber',
                          'type': 'seat',
                          'charge': amount,
                          'serviceCode': serviceCode,
                          'rowNumber': rowNumber,
                          'isAvailable': !isAssigned && !isBlocked && serviceCode.isNotEmpty,
                          'isAssigned': isAssigned,
                          'isBlocked': isBlocked,
                          'isPremium': _isPremiumSeat(rowNumber),
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

      // If no seats from API, generate some demo seats for testing
      if (seats.isEmpty) {
        seats.addAll(_generateDemoSeats());
      }

      availableSeats.value = seats;

    } catch (e) {
      // Generate demo seats as fallback
      availableSeats.value = _generateDemoSeats();
    }
  }

// Helper method to determine if a seat is premium
  bool _isPremiumSeat(String seatNumber) {
    if (seatNumber.isEmpty) return false;

    final rowMatch = RegExp(r'(\d+)').firstMatch(seatNumber);
    if (rowMatch != null) {
      final rowNumber = int.tryParse(rowMatch.group(1) ?? '0') ?? 0;
      return rowNumber <= 6; // First 6 rows are typically premium in Flydubai
    }
    return false;
  }

// Generate demo seats for testing purposes
  List<Map<String, dynamic>> _generateDemoSeats() {
    final List<Map<String, dynamic>> demoSeats = [];
    final List<int> availableRows = [3, 4, 5, 7, 8, 9, 12, 13, 14, 16, 17, 18, 20, 21, 22, 25, 26, 28];
    final List<String> columns = ['A', 'B', 'C', 'D', 'E', 'F'];

    for (final row in availableRows) {
      for (final column in columns) {
        final seatNumber = '$row$column';
        double charge = 0;

        // Premium seats (rows 1-6)
        if (row <= 6) {
          charge = [2500, 3000, 3500].elementAt((row + column.codeUnitAt(0)) % 3) as double;
        }
        // Standard seats with extra legroom
        else if ([12, 13, 14].contains(row)) {
          charge = [1500, 2000].elementAt(column.codeUnitAt(0) % 2) as double;
        }
        // Regular seats
        else {
          charge = [500, 750, 1000].elementAt((row + column.codeUnitAt(0)) % 3) as double;
        }

        demoSeats.add({
          'id': 'SEAT_$seatNumber',
          'seatNumber': seatNumber,
          'description': 'Seat $seatNumber',
          'type': 'seat',
          'charge': charge.toString(),
          'serviceCode': 'SEAT',
          'rowNumber': row.toString(),
          'isAvailable': true,
          'isPremium': row <= 6,
        });
      }
    }

    return demoSeats;
  }
  void _updateExtrasPrice() {
    double extrasTotal = 0.0;

    // Add baggage charges
    for (final baggage in selectedBaggage.values) {
      // Extract price from baggage object
      final price = double.tryParse(baggage['charge']?.toString() ?? '0') ?? 0.0;
      extrasTotal += price;
    }

    // Add meal charges
    for (final meal in selectedMeals.values) {
      // Extract price from meal object
      final price = double.tryParse(meal['charge']?.toString() ?? '0') ?? 0.0;
      extrasTotal += price;
    }

    // Add seat charges
    for (final seat in selectedSeats.values) {
      // Extract price from seat object
      final price = double.tryParse(seat['charge']?.toString() ?? '0') ?? 0.0;
      extrasTotal += price;
    }

    totalExtrasPrice.value = extrasTotal;
  }

  double get totalPrice {
    return basePrice.value + totalExtrasPrice.value;
  }

  // Public method to load extras (called from booking form)
  Future<void> loadExtras({
    required FlydubaiFlight flight,
    required FlydubaiFlightFare fare,
    FlydubaiFlight? returnFlight,
    FlydubaiFlightFare? returnFare,
    Map<String, dynamic>? cartData,
    required int adult,
    required int child,
    required int infant,
  }) async {
    reset();
    
    // Check if this is a multi-city booking
    final flyController = Get.find<FlydubaiFlightController>();
    final selectedMultiCityFlightsList = flyController.selectedMultiCityFlights
        .where((f) => f != null)
        .cast<FlydubaiFlight>()
        .toList();
    final selectedMultiCityFareOptionsList = flyController.selectedMultiCityFareOptions
        .where((f) => f != null)
        .cast<FlydubaiFlightFare>()
        .toList();

    final isMultiCity = selectedMultiCityFlightsList.isNotEmpty && 
                        selectedMultiCityFareOptionsList.isNotEmpty &&
                        selectedMultiCityFlightsList.length == selectedMultiCityFareOptionsList.length;

    if (isMultiCity) {
      // Load extras for all multi-city segments
      debugPrint('🌍 Loading extras for MULTI-CITY booking (${selectedMultiCityFlightsList.length} segments)');
      
      selectedFlight.value = selectedMultiCityFlightsList.first; // Use first flight for display
      selectedFare.value = selectedMultiCityFareOptionsList.first;
      this.cartData = cartData;
      adultPassengers.value = adult;
      childPassengers.value = child;
      infantPassengers.value = infant;
      
      // Calculate total base price from all segments
      double totalPrice = 0.0;
      for (final fareOption in selectedMultiCityFareOptionsList) {
        totalPrice += fareOption.baseFareAmountIncludingTax;
      }
      basePrice.value = totalPrice;
      currency.value = selectedMultiCityFlightsList.first.currency;
      
      _initializePassengerIds();
      
      // Generate booking IDs for all multi-city segments
      final List<String> bookingIdsList = [];
      for (int i = 0; i < selectedMultiCityFlightsList.length; i++) {
        final multiCityFlight = selectedMultiCityFlightsList[i];
        final multiCityFare = selectedMultiCityFareOptionsList[i];
        final fareIndex = _getFareIndex(multiCityFlight, multiCityFare);
        final bookingId = '${multiCityFlight.flightSegment.lfid}_$fareIndex';
        bookingIdsList.add(bookingId);
        debugPrint('  📍 Multi-city segment $i: $bookingId (${multiCityFlight.flightSegment.origin} -> ${multiCityFlight.flightSegment.destination})');
      }
      
      bookingIds.value = bookingIdsList;
      
      // Load extras using the first flight's rawData (all flights should have similar structure)
      // The booking IDs will include all segments, so the API will return options for all flights
      await loadFlightExtras(selectedMultiCityFlightsList.first, selectedMultiCityFareOptionsList.first, false);
    } else {
      // One-way or round-trip
      selectedFlight.value = flight;
      selectedFare.value = fare;
      this.cartData = cartData;
      adultPassengers.value = adult;
      childPassengers.value = child;
      infantPassengers.value = infant;
      basePrice.value = flight.price;
      currency.value = flight.currency;
      
      _initializePassengerIds();
      
      final isReturn = returnFlight != null;
      await loadFlightExtras(flight, fare, isReturn);
    }
  }

  void reset() {
    selectedFlight.value = null;
    selectedFare.value = null;
    bookingIds.clear();
    availableBaggage.clear();
    availableMeals.clear();
    availableSeats.clear();
    selectedBaggage.clear();
    selectedMeals.clear();
    selectedSeats.clear();
    basePrice.value = 0.0;
    totalExtrasPrice.value = 0.0;
    currency.value = 'PKR';
    errorMessage.value = '';
    cartData = null;
  }

  Map<String, dynamic> getBookingSummary() {
    // Group selections by passenger for better organization
    Map<String, Map<String, dynamic>> passengerSelections = {};

    for (final passengerId in passengerIds) {
      passengerSelections[passengerId] = {
        'passengerName': getPassengerDisplayName(passengerIds.indexOf(passengerId)),
        'baggage': {},
        'meals': {},
        'seats': {},
      };
    }

    // Process baggage selections
    selectedBaggage.forEach((key, value) {
      final parts = key.split('|');
      if (parts.length == 2) {
        final passengerId = parts[1];
        if (passengerSelections.containsKey(passengerId)) {
          passengerSelections[passengerId]!['baggage'] = {
            'description': value['description'] ?? '',
            'charge': value['charge'] ?? '0',
          };
        }
      }
    });

    // Process meal selections
    selectedMeals.forEach((key, value) {
      final parts = key.split('|');
      if (parts.length == 2) {
        final passengerId = parts[1];
        if (passengerSelections.containsKey(passengerId)) {












          
          passengerSelections[passengerId]!['meals'] = {
            'name': value['name'] ?? '',
            'charge': value['charge'] ?? '0',
          };
        }
      }
    });

    // Process seat selections
    selectedSeats.forEach((key, value) {
      final parts = key.split('|');
      if (parts.length == 2) {
        final passengerId = parts[1];
        if (passengerSelections.containsKey(passengerId)) {
          passengerSelections[passengerId]!['seats'] = {
            'number': value['seatNumber'] ?? '',
            'charge': value['charge'] ?? '0',
          };
        }
      }
    });

    return {
      'base_price': basePrice.value,
      'extras_price': totalExtrasPrice.value,
      'total_price': totalPrice,
      'currency': currency.value,
      'passenger_count': passengerIds.length,
      'passengers': passengerSelections,
      // Legacy format for backward compatibility
      'baggage': selectedBaggage.map((key, value) => MapEntry(key, {
        'description': value['description'] ?? '',
        'charge': value['charge'] ?? '0',
      })),
      'meals': selectedMeals.map((key, value) => MapEntry(key, {
        'name': value['name'] ?? '',
        'charge': value['charge'] ?? '0',
      })),
      'seats': selectedSeats.map((key, value) => MapEntry(key, {
        'number': value['seatNumber'] ?? '',
        'charge': value['charge'] ?? '0',
      })),
    };
  }
}