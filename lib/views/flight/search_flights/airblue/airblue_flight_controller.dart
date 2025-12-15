// FIXED: airblue_flight_controller.dart with proper multi-city workflow

// ignore_for_file: empty_catches

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../services/api_service_sabre.dart';

import '../../booking_flight/airblue/airblue_booking_flight.dart';
import '../../form/flight_booking_controller.dart';
import '../filters/filter_flight_model.dart';
import '../review_flight/airblue_review_flight.dart';
import '../search_flight_utils/filter_flight_model.dart';
import '../flight_package/airblue/airblue_flight_package.dart';
import 'airblue_flight_model.dart';
import 'airblue_multicity_flight_selection.dart';

class AirBlueFlightController extends GetxController {
  final ApiServiceSabre apiService = Get.find<ApiServiceSabre>();

  // Original list of AirBlue flights (never modified after parsing)
  final RxList<AirBlueFlight> _originalFlights = <AirBlueFlight>[].obs;

  // Filtered list of AirBlue flights (shown in UI)
  final RxList<AirBlueFlight> filteredFlights = <AirBlueFlight>[].obs;

  // Keep the flights getter for backward compatibility
  RxList<AirBlueFlight> get flights => filteredFlights;

  // Map to store all fare options for each RPH
  final RxMap<String, List<AirBlueFareOption>> fareOptionsByRPH = <String, List<AirBlueFareOption>>{}.obs;

  // FIXED: Store flights by segment for multi-city support
  final RxMap<int, List<AirBlueFlight>> flightsBySegment = <int, List<AirBlueFlight>>{}.obs;

  // Selected flights for round trip (keeping for backward compatibility)
  AirBlueFlight? selectedOutboundFlight;
  AirBlueFareOption? selectedOutboundFareOption;
  AirBlueFlight? selectedReturnFlight;
  AirBlueFareOption? selectedReturnFareOption;

  // Multi-city selections - each index corresponds to a segment
  final RxList<AirBlueFlight?> selectedMultiCityFlights = <AirBlueFlight?>[].obs;
  final RxList<AirBlueFareOption?> selectedMultiCityFareOptions = <AirBlueFareOption?>[].obs;



  // Track current segment being selected for multi-city
  final RxInt currentMultiCitySegment = 0.obs;

  // Loading state
  final RxBool isLoading = false.obs;

  // Error message
  final RxString errorMessage = ''.obs;

  final RxString sortType = 'Suggested'.obs;

  void clearFlights() {
    _originalFlights.clear();
    filteredFlights.clear();
    fareOptionsByRPH.clear();
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
  }

  void setErrorMessage(String message) {
    errorMessage.value = message;
  }

  // FIXED: Initialize multi-city flight selection
  void initializeMultiCitySelection() {
    final bookingController = Get.find<FlightBookingController>();
    final segmentCount = bookingController.cityPairs.length;

    print('DEBUG: Initializing multi-city selection for $segmentCount segments');

    // Clear and initialize lists with correct size
    selectedMultiCityFlights.clear();
    selectedMultiCityFareOptions.clear();

    // Add null placeholders for each segment
    for (int i = 0; i < segmentCount; i++) {
      selectedMultiCityFlights.add(null);
      selectedMultiCityFareOptions.add(null);
    }

    // Start from segment 0 (0-based indexing)
    currentMultiCitySegment.value = 0;

    print('DEBUG: Initialized lists with ${selectedMultiCityFlights.length} segments each');
    print('DEBUG: Starting with segment 0');
  }

  // FIXED: Check if all multi-city segments are selected
  bool get isAllMultiCitySegmentsSelected {
    final bookingController = Get.find<FlightBookingController>();
    final requiredSegments = bookingController.cityPairs.length;

    print('DEBUG: Checking if all segments selected - Required: $requiredSegments');
    print('DEBUG: Current flights list size: ${selectedMultiCityFlights.length}');
    print('DEBUG: Current options list size: ${selectedMultiCityFareOptions.length}');

    // Check if we have selections for all segments
    for (int i = 0; i < requiredSegments; i++) {
      bool flightMissing = i >= selectedMultiCityFlights.length || selectedMultiCityFlights[i] == null;
      bool fareOptionMissing = i >= selectedMultiCityFareOptions.length || selectedMultiCityFareOptions[i] == null;

      print('DEBUG: Segment $i - Flight missing: $flightMissing, Fare option missing: $fareOptionMissing');

      if (flightMissing || fareOptionMissing) {
        return false;
      }
    }

    print('DEBUG: All segments are selected!');
    return true;
  }

  // FIXED: Get the next segment that needs to be selected
  int getNextUnselectedSegment() {
    final bookingController = Get.find<FlightBookingController>();
    final requiredSegments = bookingController.cityPairs.length;

    print('DEBUG: Looking for next unselected segment');
    print('DEBUG: Required segments: $requiredSegments');
    print('DEBUG: Current selectedMultiCityFlights: ${selectedMultiCityFlights.length}');
    print('DEBUG: Current selectedMultiCityFareOptions: ${selectedMultiCityFareOptions.length}');

    for (int i = 0; i < requiredSegments; i++) {
      // Check if this segment needs both flight and fare option
      bool flightMissing = i >= selectedMultiCityFlights.length || selectedMultiCityFlights[i] == null;
      bool fareOptionMissing = i >= selectedMultiCityFareOptions.length || selectedMultiCityFareOptions[i] == null;

      print('DEBUG: Segment $i - Flight missing: $flightMissing, Fare option missing: $fareOptionMissing');

      if (flightMissing || fareOptionMissing) {
        print('DEBUG: Next unselected segment found: $i');
        return i;
      }
    }

    print('DEBUG: All segments selected, returning -1');
    return -1; // All segments selected
  }

  // FIXED: Updated parseApiResponse to properly handle multi-city flights
  Future<void> parseApiResponse(Map<String, dynamic>? response) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Clear previous flights and options
      _originalFlights.clear();
      filteredFlights.clear();
      fareOptionsByRPH.clear();
      flightsBySegment.clear();

      // Parse the response
      if (response == null ||
          response['soap\$Envelope'] == null ||
          response['soap\$Envelope']['soap\$Body'] == null) {
        isLoading.value = false;
        return;
      }

      final pricedItineraries =
      response['soap\$Envelope']['soap\$Body']['AirLowFareSearchResponse']?['AirLowFareSearchResult']?['PricedItineraries']?['PricedItinerary'];

      if (pricedItineraries == null) {
        isLoading.value = false;
        return;
      }

      // FIXED: Group flights by OriginDestinationRefNumber (segment)
      Map<int, List<Map<String, dynamic>>> flightsByRefNumber = {};

      // First, group all flights by OriginDestinationRefNumber
      if (pricedItineraries is List) {
        for (var itinerary in pricedItineraries) {
          try {
            final refNumber = int.tryParse(itinerary['OriginDestinationRefNumber']?.toString() ?? '1') ?? 1;
            final segmentIndex = refNumber - 1; // Convert to 0-based index

            if (!flightsByRefNumber.containsKey(segmentIndex)) {
              flightsByRefNumber[segmentIndex] = [];
            }
            flightsByRefNumber[segmentIndex]!.add(Map<String, dynamic>.from(itinerary));
          } catch (e) {
            print('DEBUG: Error processing itinerary: $e');
          }
        }
      } else if (pricedItineraries is Map) {
        try {
          final refNumber = int.tryParse(pricedItineraries['OriginDestinationRefNumber']?.toString() ?? '1') ?? 1;
          final segmentIndex = refNumber - 1; // Convert to 0-based index
          flightsByRefNumber[segmentIndex] = [Map<String, dynamic>.from(pricedItineraries)];
        } catch (e) {
          print('DEBUG: Error processing single itinerary: $e');
        }
      }

      print('DEBUG: Found flights for segments: ${flightsByRefNumber.keys.toList()}');

      // Process each segment's flights
      flightsByRefNumber.forEach((segmentIndex, itineraries) {
        print('DEBUG: Processing segment $segmentIndex with ${itineraries.length} itineraries');

        // Group itineraries by RPH for this segment
        Map<String, List<Map<String, dynamic>>> itinerariesByRPH = {};

        for (var itinerary in itineraries) {
          try {
            final originDestOption = itinerary['AirItinerary']?['OriginDestinationOptions']?['OriginDestinationOption'];
            final rph = originDestOption?['RPH']?.toString() ?? '';

            if (!itinerariesByRPH.containsKey(rph)) {
              itinerariesByRPH[rph] = [];
            }
            itinerariesByRPH[rph]!.add(itinerary);
          } catch (e) {
            print('DEBUG: Error processing itinerary RPH: $e');
          }
        }

        // Process each RPH group for this segment
        List<AirBlueFlight> segmentFlights = [];

        itinerariesByRPH.forEach((rph, rphItineraries) {
          try {
            List<AirBlueFareOption> fareOptions = [];

            for (var itinerary in rphItineraries) {
              try {
                final flight = AirBlueFlight.fromJson(
                  itinerary,
                  apiService.airlineMap.value,
                );
                fareOptions.add(AirBlueFareOption.fromFlight(flight, itinerary));
              } catch (e) {
                print('DEBUG: Error creating fare option: $e');
              }
            }

            if (fareOptions.isNotEmpty) {
              fareOptions.sort((a, b) => a.price.compareTo(b.price));
              final bookingController = Get.find<FlightBookingController>();
              final tripType = bookingController.tripType.value;
              // Create unique key for this segment and RPH
              // Inside the RPH processing loop:
              String fareKey;
              if (tripType == TripType.multiCity) {
                fareKey = 'segment_${segmentIndex}_$rph';
              } else if (tripType == TripType.roundTrip && segmentIndex > 0) {
                // For round trip, segment 0 is outbound, segment 1 is return
                fareKey = 'return_$rph';
              } else {
                fareKey = rph;
              }

              fareOptionsByRPH[fareKey] = fareOptions;

              print('DEBUG: Storing fare options with key: $fareKey (${fareOptions.length} options)');

              final lowestPriceOption = fareOptions.first;
              final representativeFlight = AirBlueFlight.fromJson(
                lowestPriceOption.rawData,
                apiService.airlineMap.value,
              ).copyWithFareOptions(fareOptions);

              segmentFlights.add(representativeFlight);

              print('DEBUG: Added flight for segment $segmentIndex, RPH $rph');
            }
          } catch (e) {
            print('DEBUG: Error processing RPH $rph: $e');
          }
        });

        // Store flights for this segment
        if (segmentFlights.isNotEmpty) {
          segmentFlights.sort((a, b) => a.price.compareTo(b.price));
          flightsBySegment[segmentIndex] = segmentFlights;

          // For segment 0, also add to original flights for backward compatibility
          if (segmentIndex == 0) {
            _originalFlights.addAll(segmentFlights);
          }

          print('DEBUG: Stored ${segmentFlights.length} flights for segment $segmentIndex');
        }
      });

      // Sort original flights by price (for segment 0)
      _originalFlights.sort((a, b) => a.price.compareTo(b.price));

      // Initialize filtered flights with segment 0 flights
      filteredFlights.assignAll(_originalFlights);

      print('DEBUG: Total segments with flights: ${flightsBySegment.length}');
      print('DEBUG: Original flights (segment 0): ${_originalFlights.length}');

    } catch (e) {
      errorMessage.value = 'Failed to load AirBlue flights: $e';
      print('DEBUG: Error in parseApiResponse: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void loadFlights(Map<String, dynamic> apiResponse) {
    parseApiResponse(apiResponse);
  }

  // Current selected flight for package selection
  final Rx<AirBlueFlight?> selectedFlight = Rx<AirBlueFlight?>(null);

  // FIXED: Updated handleAirBlueFlightSelection method
  void handleAirBlueFlightSelection(AirBlueFlight flight, {bool isReturnFlight = false}) {
    selectedFlight.value = flight;
    final bookingController = Get.find<FlightBookingController>();
    final tripType = bookingController.tripType.value;

    if (tripType == TripType.multiCity) {
      handleMultiCityFlightSelection(flight, currentMultiCitySegment.value);
      return;
    }

    // For one-way or return flights
    Get.dialog(
      AirBluePackageSelectionDialog(
        flight: flight,
        isReturnFlight: isReturnFlight,
        segmentIndex: 0, // Always 0 for non-multi-city
        isMultiCity: false,
      ),
      barrierDismissible: false,
    );
  }
// MAIN FIX: Replace the existing getFareOptionsForFlight method in airblue_flight_controller.dart
  List<AirBlueFareOption> getFareOptionsForFlight(AirBlueFlight flight, {int segmentIndex = 0}) {
    final bookingController = Get.find<FlightBookingController>();
    final tripType = bookingController.tripType.value;

    String rphKey;

    if (tripType == TripType.multiCity) {
      // For multi-city, use segment-specific key
      rphKey = 'segment_${segmentIndex}_${flight.rph}';
    } else if (tripType == TripType.roundTrip && segmentIndex > 0) {
      // For return flight in round trip
      rphKey = 'return_${flight.rph}';
    } else {
      // Default case for outbound flights
      rphKey = flight.rph;
    }

    print('DEBUG: Getting fare options for flight with RPH: ${flight.rph}');
    print('DEBUG: Using key: $rphKey');
    print('DEBUG: Available keys: ${fareOptionsByRPH.keys.toList()}');

    // Rest of the method remains the same...
    final options = fareOptionsByRPH[rphKey] ?? [];

    if (options.isEmpty) {
      print('DEBUG: No options found for key $rphKey, trying fallback approaches');

      // Fallback 1: Try without segment prefix for multi-city
      if (tripType == TripType.multiCity) {
        final fallbackOptions = fareOptionsByRPH[flight.rph] ?? [];
        if (fallbackOptions.isNotEmpty) {
          print('DEBUG: Found ${fallbackOptions.length} options without segment prefix');
          return fallbackOptions;
        }
      }

      // Fallback 2: Try matching by RPH only
      final matchingOptions = fareOptionsByRPH.entries
          .where((entry) => entry.key.endsWith('_${flight.rph}'))
          .expand((entry) => entry.value)
          .toList();

      if (matchingOptions.isNotEmpty) {
        print('DEBUG: Found ${matchingOptions.length} options by RPH matching');
        return matchingOptions;
      }
    }

    return options;
  }// ALSO NEED TO FIX: Update the AirBluePackageSelectionDialog usage
// The issue is also in how the fare options are retrieved in the dialog// FIXED: Handle flight selection - properly store flight immediately
  void handleMultiCityFlightSelection(AirBlueFlight flight, int segmentIndex) {
    print('DEBUG: handleMultiCityFlightSelection called with segment $segmentIndex');

    // Ensure the lists are properly sized
    final bookingController = Get.find<FlightBookingController>();
    final requiredSize = bookingController.cityPairs.length;

    print('DEBUG: Required size: $requiredSize');
    print('DEBUG: Current flights list size: ${selectedMultiCityFlights.length}');
    print('DEBUG: Current options list size: ${selectedMultiCityFareOptions.length}');

    // Ensure both lists have the correct size
    while (selectedMultiCityFlights.length < requiredSize) {
      selectedMultiCityFlights.add(null);
    }
    while (selectedMultiCityFareOptions.length < requiredSize) {
      selectedMultiCityFareOptions.add(null);
    }

    // Store the flight IMMEDIATELY
    selectedMultiCityFlights[segmentIndex] = flight;
    currentMultiCitySegment.value = segmentIndex;

    print('DEBUG: Flight stored for segment $segmentIndex');
    print('DEBUG: Flight route: ${flight.legSchedules.first['departure']['airport']} -> ${flight.legSchedules.last['arrival']['airport']}');
    print('DEBUG: Selected flights after storage: ${selectedMultiCityFlights.map((f) => f != null ? '${f!.legSchedules.first['departure']['airport']}->${f.legSchedules.last['arrival']['airport']}' : 'null').toList()}');

    // Open package selection
    Get.off(
      AirBluePackageSelectionDialog(
        flight: flight,
        segmentIndex: segmentIndex,
        isMultiCity: true,
        isReturnFlight: false,
      ),
      // barrierDismissible: false,
    );
  }

  // FIXED: Handle package selection with better debugging
  void handleMultiCityPackageSelection(AirBlueFareOption option, int segmentIndex) {
    final flightBookingController = Get.find<FlightBookingController>();
    final requiredSize = flightBookingController.cityPairs.length;

    print('DEBUG: handleMultiCityPackageSelection called with segment $segmentIndex');
    print('DEBUG: Required segments: $requiredSize');

    // Ensure the fare options list is properly sized
    while (selectedMultiCityFareOptions.length < requiredSize) {
      selectedMultiCityFareOptions.add(null);
    }

    // Store the fare option
    selectedMultiCityFareOptions[segmentIndex] = option;

    print('DEBUG: Package selected for segment $segmentIndex');
    print('DEBUG: Package brand: ${option.brandName}');

    // Print current selections for debugging
    for (int i = 0; i < requiredSize; i++) {
      final hasF = i < selectedMultiCityFlights.length && selectedMultiCityFlights[i] != null;
      final hasO = i < selectedMultiCityFareOptions.length && selectedMultiCityFareOptions[i] != null;
      print('DEBUG: Segment $i - Flight: $hasF, Option: $hasO');
      if (hasF && hasO) {
        final flight = selectedMultiCityFlights[i]!;
        final option = selectedMultiCityFareOptions[i]!;
        print('DEBUG: Segment $i - Route: ${flight.legSchedules.first['departure']['airport']}->${flight.legSchedules.last['arrival']['airport']}, Package: ${option.brandName}');
      }
    }

    // Force trigger the reactive update
    selectedMultiCityFlights.refresh();
    selectedMultiCityFareOptions.refresh();

    // Small delay to ensure reactive updates are processed
    Future.delayed(Duration(milliseconds: 100), () {
      // Check if all segments are selected
      if (isAllMultiCitySegmentsSelected) {
        print('DEBUG: All segments selected, proceeding to review');
        _proceedToMultiCityReview();
      } else {
        print('DEBUG: Moving to next segment');
        proceedToNextMultiCitySegment();
      }
    });
  }

  // FIXED: Get flights for a specific segment
  List<AirBlueFlight> getFlightsForSegment(int segmentIndex) {
    final bookingController = Get.find<FlightBookingController>();

    if (segmentIndex >= bookingController.cityPairs.length) {
      return [];
    }

    // Get flights from the segment-specific storage
    final segmentFlights = flightsBySegment[segmentIndex] ?? [];

    print('DEBUG: Getting flights for segment $segmentIndex');
    print('DEBUG: Found ${segmentFlights.length} flights directly from segment storage');

    if (segmentFlights.isNotEmpty) {
      return segmentFlights;
    }

    // Fallback: try to match flights by route (for backward compatibility)
    final cityPair = bookingController.cityPairs[segmentIndex];
    final fromCity = cityPair.fromCity.value;
    final toCity = cityPair.toCity.value;
    final departureDate = DateFormat('yyyy-MM-dd').format(cityPair.departureDateTime.value);

    print('DEBUG: Fallback route matching for segment $segmentIndex');
    print('DEBUG: Route: $fromCity -> $toCity on $departureDate');

    // Filter flights that match this segment from all flights
    final matchingFlights = _originalFlights.where((flight) {
      try {
        final firstLeg = flight.legSchedules.first;
        final lastLeg = flight.legSchedules.last;

        final flightFrom = firstLeg['departure']['airport'];
        final flightTo = lastLeg['arrival']['airport'];
        final flightDate = DateFormat('yyyy-MM-dd').format(
            DateTime.parse(firstLeg['departure']['dateTime'])
        );

        final matches = flightFrom == fromCity &&
            flightTo == toCity &&
            flightDate == departureDate;

        if (matches) {
          print('DEBUG: Found matching flight via fallback: $flightFrom -> $flightTo on $flightDate');
        }

        return matches;
      } catch (e) {
        return false;
      }
    }).toList();

    print('DEBUG: Found ${matchingFlights.length} matching flights for segment $segmentIndex via fallback');
    return matchingFlights;
  }

  void proceedToNextMultiCitySegment() {
    print('DEBUG: proceedToNextMultiCitySegment called');

    final nextSegment = getNextUnselectedSegment();
    print('DEBUG: Next segment to select: $nextSegment');

    if (nextSegment != -1) {
      // Check if we're already on this segment to prevent loops
      if (currentMultiCitySegment.value == nextSegment) {
        print('DEBUG: Already on segment $nextSegment, forcing navigation');
        _showMultiCityFlightSelection(nextSegment);
        return;
      }

      currentMultiCitySegment.value = nextSegment;
      print('DEBUG: Updated current segment to: $nextSegment');

      // Get flights for the next segment
      final segmentFlights = getFlightsForSegment(nextSegment);
      print('DEBUG: Found ${segmentFlights.length} flights for segment $nextSegment');

      if (segmentFlights.isEmpty) {
        print('DEBUG: No flights found for segment $nextSegment');
        Get.snackbar(
          'No Flights Available',
          'No flights found for this segment. Please try different dates or routes.',
          snackPosition: SnackPosition.BOTTOM,
        );

        // Try to find the next available segment
        bool foundNextSegment = false;
        for (int i = nextSegment + 1; i < Get.find<FlightBookingController>().cityPairs.length; i++) {
          final testFlights = getFlightsForSegment(i);
          if (testFlights.isNotEmpty) {
            currentMultiCitySegment.value = i;
            _showMultiCityFlightSelection(i);
            foundNextSegment = true;
            break;
          }
        }

        if (!foundNextSegment) {
          // No more segments with flights, proceed to review with what we have
          _proceedToMultiCityReview();
        }
      } else {
        print('DEBUG: Showing flight selection for segment $nextSegment');
        // Use a small delay to ensure the UI is ready
        Future.delayed(Duration(milliseconds: 300), () {
          _showMultiCityFlightSelection(nextSegment);
        });
      }
    } else {
      print('DEBUG: All segments processed, proceeding to review');
      _proceedToMultiCityReview();
    }
  }

  void _showMultiCityFlightSelection(int segmentIndex) {
    final bookingController = Get.find<FlightBookingController>();

    if (segmentIndex >= bookingController.cityPairs.length) {
      print('DEBUG: Invalid segment index: $segmentIndex');
      return;
    }

    final cityPair = bookingController.cityPairs[segmentIndex];
    final segmentFlights = getFlightsForSegment(segmentIndex);

    print('DEBUG: _showMultiCityFlightSelection for segment $segmentIndex');
    print('DEBUG: Route: ${cityPair.fromCity.value} -> ${cityPair.toCity.value}');
    print('DEBUG: Date: ${cityPair.departureDateTime.value}');
    print('DEBUG: Available flights for segment: ${segmentFlights.length}');

    // Update current segment before showing selection
    currentMultiCitySegment.value = segmentIndex;

    // // Close any open dialogs first
    // if (Get.isDialogOpen ?? false) {
    //   Get.back();
    // }

    // Close any open dialogs first
    if (Get.isDialogOpen == true) {
      Get.back();
    }

    // Ensure navigation happens on the next frame after dialog is gone
    Future.microtask(() {
      Get.off(() => AirBlueMultiCityFlightPage(
        currentSegment: segmentIndex,
        availableFlights: segmentFlights,
      ));
    });

    // Get.off(() => AirBlueMultiCityFlightPage(
    //   currentSegment: segmentIndex,
    //   availableFlights: segmentFlights, // Pass the list even if empty
    // ));
    // // FIXED: Always navigate to the page, even if no flights - let the page handle empty flights
    // Future.delayed(Duration(milliseconds: 200), () {
    //
    // });
  }

  // Proceed to multi-city booking (skip review, go directly to booking form)
  void _proceedToMultiCityReview() {
    print('DEBUG: Proceeding to multi-city booking (skipping review)');

    final selectedFlightsList = selectedMultiCityFlights.where((f) => f != null).cast<AirBlueFlight>().toList();
    final selectedOptionsList = selectedMultiCityFareOptions.where((f) => f != null).cast<AirBlueFareOption>().toList();

    print('DEBUG: Selected flights: ${selectedFlightsList.length}');
    print('DEBUG: Selected options: ${selectedOptionsList.length}');

    if (selectedFlightsList.isEmpty || selectedOptionsList.isEmpty) {
      Get.snackbar(
        'Error',
        'Please select flights for all segments',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // Calculate total price
    final bookingController = Get.find<FlightBookingController>();
    final passengerCount = bookingController.adultCount.value + 
                          bookingController.childrenCount.value + 
                          bookingController.infantCount.value;
    
    double totalPrice = 0;
    String currency = selectedOptionsList.first.currency;
    
    for (final option in selectedOptionsList) {
      totalPrice += option.price * passengerCount;
    }

    // Navigate directly to booking form (skip review screen)
    Get.to(() => AirBlueBookingFlight(
      flight: selectedFlightsList.first,
      multicityFlights: selectedFlightsList,
      outboundFareOption: selectedOptionsList.first,
      multicityFareOptions: selectedOptionsList,
      totalPrice: totalPrice,
      currency: currency,
    ));
  }

  // Add to airblue_flight_controller.dart
  void handleReturnFlightSelection(AirBlueFlight flight) {
    selectedReturnFlight = flight;

    // Open package selection for return flight with segmentIndex 1
    Get.dialog(
      AirBluePackageSelectionDialog(
        flight: flight,
        isReturnFlight: true,
        segmentIndex: 1, // Return flight is segment 1 in round trip
        isMultiCity: false,
      ),
      barrierDismissible: false,
    );
  }

  // FIXED: Method to start multi-city flow
  void startMultiCityFlightSelection() {
    print('DEBUG: Starting multi-city flight selection');
    initializeMultiCitySelection();
    _showMultiCityFlightSelection(0); // Start with segment 0
  }

  // Add this method to get return flights when needed
  List<AirBlueFlight> getReturnFlights() {
    // For multi-city, return flights are stored in their respective segments
    // For round trip, return flights are in segment 1
    final bookingController = Get.find<FlightBookingController>();
    final tripType = bookingController.tripType.value;

    final returnFlights = <AirBlueFlight>[];

    if (tripType == TripType.roundTrip) {
      // For round trip, look for flights marked with 'return_' prefix
      fareOptionsByRPH.forEach((rph, options) {
        if (rph.startsWith('return_') && options.isNotEmpty) {
          final representativeFlight = AirBlueFlight.fromJson(
            options.first.rawData,
            apiService.airlineMap.value,
          ).copyWithFareOptions(options);
          returnFlights.add(representativeFlight);
        }
      });

      // Fallback: check segment 1 if no flights found with return_ prefix
      if (returnFlights.isEmpty && flightsBySegment.containsKey(1)) {
        returnFlights.addAll(flightsBySegment[1] ?? []);
      }
    } else if (tripType == TripType.multiCity) {
      // For multi-city, return flights would be in their respective segments
      // This method shouldn't be called for multi-city trips
      print('DEBUG: getReturnFlights called for multi-city trip - not supported');
    }

    // Sort return flights by price
    returnFlights.sort((a, b) => a.price.compareTo(b.price));

    return returnFlights;
  }
  // Updated apply filters method - now works on original flights and updates filtered flights
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

  // Method to apply sorting and filtering - works on _originalFlights, updates filteredFlights
  void _applySortingAndFiltering({
    List<String>? airlines,
    List<String>? stops,
  }) {
    // Start with original flights (never modified)
    List<AirBlueFlight> filtered = List.from(_originalFlights);

    // Apply airline filter
    if (airlines != null && !airlines.contains('all')) {
      filtered = filtered.where((flight) {
        // For AirBlue, check if PA is in the selected airlines
        // Since all AirBlue flights have airlineCode 'PA'
        return airlines.any((airlineCode) =>
        flight.airlineCode.toUpperCase() == airlineCode.toUpperCase());
      }).toList();
    }

    // Apply stops filter
    if (stops != null && !stops.contains('all')) {
      filtered = filtered.where((flight) {
        // Calculate stops based on segmentInfo
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
          // Calculate total duration from legSchedules
          final aDuration = a.legSchedules.fold(0, (sum, leg) => sum + (leg['elapsedTime'] as int));
          final bDuration = b.legSchedules.fold(0, (sum, leg) => sum + (leg['elapsedTime'] as int));
          return aDuration.compareTo(bDuration);
        });
        break;
      case 'Suggested':
      default:
      // Keep original order (already sorted by price during parsing)
        break;
    }

    // Update the filtered flights list (this is what the UI shows)
    filteredFlights.assignAll(filtered);
  }

  // Method to get filtered flights by airline
  List<AirBlueFlight> getFlightsByAirline(String airlineCode) {
    return filteredFlights.where((flight) {
      return flight.airlineCode.toUpperCase() == airlineCode.toUpperCase();
    }).toList();
  }

  // Method to get flight count by airline
  int getFlightCountByAirline(String airlineCode) {
    return getFlightsByAirline(airlineCode).length;
  }

  // Method to get available airlines (for AirBlue, it's always just PA)
  List<FilterAirline> getAvailableAirlines() {
    if (_originalFlights.isEmpty) return [];

    return [
      FilterAirline(
        code: 'PA',
        name: 'Air Blue',
        logoPath: 'https://images.kiwi.com/airlines/64/PA.png',
      )
    ];
  }

  // DEBUGGING: Method to print current multi-city state
  void debugMultiCityState() {
    final bookingController = Get.find<FlightBookingController>();
    print('=== DEBUG MULTI-CITY STATE ===');
    print('Required segments: ${bookingController.cityPairs.length}');
    print('Current segment: ${currentMultiCitySegment.value}');
    print('Selected flights list size: ${selectedMultiCityFlights.length}');
    print('Selected options list size: ${selectedMultiCityFareOptions.length}');
    print('Flights by segment: ${flightsBySegment.keys.toList()}');

    // Print segment details
    flightsBySegment.forEach((segmentIndex, flights) {
      print('Segment $segmentIndex has ${flights.length} flights available');
      if (flights.isNotEmpty) {
        final firstFlight = flights.first;
        print('  First flight: ${firstFlight.legSchedules.first['departure']['airport']} -> ${firstFlight.legSchedules.last['arrival']['airport']}');
      }
    });

    for (int i = 0; i < bookingController.cityPairs.length; i++) {
      final cityPair = bookingController.cityPairs[i];
      final hasFlight = i < selectedMultiCityFlights.length && selectedMultiCityFlights[i] != null;
      final hasOption = i < selectedMultiCityFareOptions.length && selectedMultiCityFareOptions[i] != null;

      print('Segment $i: ${cityPair.fromCity.value} -> ${cityPair.toCity.value}');
      print('  Flight selected: $hasFlight');
      print('  Option selected: $hasOption');

      if (hasFlight) {
        final flight = selectedMultiCityFlights[i]!;
        print('  Flight route: ${flight.legSchedules.first['departure']['airport']} -> ${flight.legSchedules.last['arrival']['airport']}');
      }

      if (hasOption) {
        final option = selectedMultiCityFareOptions[i]!;
        print('  Package: ${option.brandName} - ${option.price}');
      }
    }
    print('=== END DEBUG STATE ===');
  }

  void resetLoadingState() {
    isLoading.value = true;
  }
}