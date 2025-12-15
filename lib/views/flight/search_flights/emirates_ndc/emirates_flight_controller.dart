import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ready_flights/views/flight/search_flights/emirates_ndc/emirates_model.dart';
import 'package:ready_flights/services/api_service_emirates.dart';
import 'package:ready_flights/views/flight/search_flights/flight_package/emirates_ndc/emirates_ndc_package.dart';
import 'package:ready_flights/views/flight/search_flights/emirates_ndc/emirates_return_flights_page.dart';
import 'package:ready_flights/views/flight/booking_flight/airblue/airblue_booking_flight.dart';
import 'package:ready_flights/views/flight/search_flights/emirates_ndc/emirates_multicity_flight_selection.dart';
import '../../form/flight_booking_controller.dart';
import '../filters/filter_flight_model.dart';

class EmiratesFlightController extends GetxController {
  // Store ALL flights with their complete offer data
  final RxMap<String, EmiratesFlight> _allFlights = <String, EmiratesFlight>{}.obs;

  // Filtered list showing flights based on filters
  final RxList<EmiratesFlight> filteredFlights = <EmiratesFlight>[].obs;
  final RxList<EmiratesFlight> outboundFlights = <EmiratesFlight>[].obs;
  final RxList<EmiratesFlight> returnFlights = <EmiratesFlight>[].obs;

  // Keep flights getter for backward compatibility
  RxList<EmiratesFlight> get flights => filteredFlights;

  // Selected flights
  EmiratesFlight? selectedOutboundFlight;
  EmiratesFarePackage? selectedOutboundPackage;
  EmiratesFlight? selectedReturnFlight;
  EmiratesFarePackage? selectedReturnPackage;

  // Multi-city selections - each index corresponds to a segment
  final RxList<EmiratesFlight?> selectedMultiCityFlights = <EmiratesFlight?>[].obs;
  final RxList<EmiratesFarePackage?> selectedMultiCityPackages = <EmiratesFarePackage?>[].obs;

  // Track current segment being selected for multi-city
  final RxInt currentMultiCitySegment = 0.obs;

  // Store flights by segment for multi-city support
  final RxMap<int, List<EmiratesFlight>> flightsBySegment = <int, List<EmiratesFlight>>{}.obs;

  String? _lastSearchOrigin;
  String? _lastSearchDestination;

  // Loading state
  final RxBool isLoading = false.obs;
  final RxBool isRoundTripSearch = false.obs;

  // Error message
  final RxString errorMessage = ''.obs;

  final RxString sortType = 'Suggested'.obs;

  void clearFlights() {
    _allFlights.clear();
    filteredFlights.clear();
    outboundFlights.clear();
    returnFlights.clear();
    errorMessage.value = '';
    selectedOutboundFlight = null;
    selectedOutboundPackage = null;
    selectedReturnFlight = null;
    selectedReturnPackage = null;
    selectedMultiCityFlights.clear();
    selectedMultiCityPackages.clear();
    flightsBySegment.clear();
    currentMultiCitySegment.value = 0;
    isRoundTripSearch.value = false;
    _lastSearchOrigin = null;
    _lastSearchDestination = null;
  }

  void setErrorMessage(String message) {
    errorMessage.value = message;
  }

  void loadFlights(
    Map<String, dynamic> response, {
    String? searchOrigin,
    String? searchDestination,
    bool isRoundTrip = false,
  }) {
     try {
    isLoading.value = true;
    errorMessage.value = '';
    _allFlights.clear();
    filteredFlights.clear();
    outboundFlights.clear();
    returnFlights.clear();
    selectedOutboundFlight = null;
    selectedOutboundPackage = null;
    selectedReturnFlight = null;
    selectedReturnPackage = null;
    isRoundTripSearch.value = isRoundTrip;
    _lastSearchOrigin = searchOrigin?.toUpperCase();
    _lastSearchDestination = searchDestination?.toUpperCase();

    debugPrint('\n=== PARSING EMIRATES RESPONSE ===');
    
    if (response.containsKey('error')) {
      setErrorMessage(response['error'].toString());
      return;
    }

    final data = response['data'] ?? response;
    
    // ✅ Extract ResponseID from root level
    String shoppingResponseId = '';
    if (data['AirShoppingRS'] != null) {
      final shoppingRS = data['AirShoppingRS'];
      final shopRespId = shoppingRS['ShoppingResponseID'];
      if (shopRespId != null) {
        shoppingResponseId = _extractNodeText(shopRespId['ResponseID']);
        debugPrint('✅ Found ShoppingResponseID: $shoppingResponseId');
      }
    }

    // Navigate to offers
    dynamic offersData;
    
    if (data['offers'] != null) {
      offersData = data['offers'];
    } else if (data['AirShoppingRS'] != null) {
      final airShoppingRS = data['AirShoppingRS'];
      final offersGroup = airShoppingRS['OffersGroup'];
      if (offersGroup != null) {
        final airlineOffers = offersGroup['AirlineOffers'];
        if (airlineOffers != null) {
          offersData = airlineOffers['Offer'] ?? airlineOffers['Offers'];
        }
      }
    }

    List<dynamic> offersList = [];
    if (offersData is List) {
      offersList = offersData;
    } else if (offersData is Map) {
      offersList = [offersData];
    }
    
    debugPrint('📦 Total offers found: ${offersList.length}');

    if (offersList.isEmpty) {
      setErrorMessage('No flights found');
      return;
    }

    // Get DataLists
    Map<String, dynamic> dataLists = {};
    if (data['AirShoppingRS'] != null) {
      dataLists = data['AirShoppingRS']['DataLists'] ?? {};
    }

    int flightCount = 0;
    int skippedCount = 0;
    
    for (int i = 0; i < offersList.length; i++) {
      try {
        var offerData = offersList[i];
        if (offerData is! Map<String, dynamic>) continue;
        
        // ✅ Inject ResponseID into each offer
        offerData = Map<String, dynamic>.from(offerData);
        offerData['ResponseID'] = shoppingResponseId;
        
        if (!offerData.containsKey('DataLists') && dataLists.isNotEmpty) {
          offerData['DataLists'] = dataLists;
        }
        
        final flight = EmiratesFlight.fromJson(offerData, searchOrigin: searchOrigin, searchDestination: searchDestination);
        
        final uniqueKey = '${flight.offerId}-${flight.priceClassName}';
        
        if (!_allFlights.containsKey(uniqueKey)) {
          _allFlights[uniqueKey] = flight;
          flightCount++;
        } else {
          skippedCount++;
        }
        
      } catch (e, stackTrace) {
        debugPrint('❌ Error processing offer ${i + 1}: $e');
        skippedCount++;
      }
    }
      
      debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      debugPrint('\n📊 STORAGE SUMMARY:');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('Total offers received: ${offersList.length}');
      debugPrint('Successfully stored: $flightCount');
      debugPrint('Skipped (duplicates): $skippedCount');
      debugPrint('Total in storage: ${_allFlights.length}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
      // Print all stored keys for verification
      debugPrint('🗂️  ALL STORED KEYS:');
      _allFlights.keys.forEach((key) {
        final flight = _allFlights[key]!;
        debugPrint('  - $key');
        debugPrint('    └─ ${flight.priceClassName} @ ${flight.currency} ${flight.price.toStringAsFixed(0)}');
      });
      debugPrint('');

      // Group flights by physical flight (date/time/number) for display
      Map<String, List<EmiratesFlight>> groupedByFlight = {};
      
      _allFlights.forEach((key, flight) {
        // Group by actual flight schedule (not price class)
        final flightKey = '${flight.departureDate}|${flight.departureTime}|${flight.flightNumber}|'
            '${flight.legSchedules.first['departure']['airport']}|'
            '${flight.legSchedules.last['arrival']['airport']}';
        
        if (!groupedByFlight.containsKey(flightKey)) {
          groupedByFlight[flightKey] = [];
        }
        groupedByFlight[flightKey]!.add(flight);
      });

      debugPrint('\n🛫 FLIGHT GROUPING:');
      debugPrint('Physical flights found: ${groupedByFlight.length}');
      
      // For display: show the lowest-priced option for each physical flight
      List<EmiratesFlight> displayFlights = [];
      groupedByFlight.forEach((flightKey, priceOptions) {
        debugPrint('\nFlight: $flightKey');
        debugPrint('  Price options available: ${priceOptions.length}');
        
        // Sort by price and show the cheapest (real price)
        priceOptions.sort((a, b) => a.price.compareTo(b.price));
        displayFlights.add(priceOptions.first);
        
        // Debug: show all price options
        for (var opt in priceOptions) {
          debugPrint('    - ${opt.priceClassName}: ${opt.currency} ${opt.price.toStringAsFixed(0)}');
        }
      });

      // Sort display flights by departure time
      displayFlights.sort((a, b) {
        final dateCompare = a.departureDate.compareTo(b.departureDate);
        if (dateCompare != 0) return dateCompare;
        return a.departureTime.compareTo(b.departureTime);
      });

      // For multicity, organize flights by segment FIRST, before any categorization
      final bookingController = Get.find<FlightBookingController>();
      final tripType = bookingController.tripType.value;
      
      if (tripType == TripType.multiCity) {
        // For multicity, organize by segment and skip outbound/return categorization
        _organizeFlightsBySegment(displayFlights, bookingController);
        // Initialize multicity selection
        initializeMultiCitySelection();
        // For multicity, only show first segment flights initially
        if (flightsBySegment.containsKey(0)) {
          filteredFlights.assignAll(flightsBySegment[0]!);
          debugPrint('✅ Multicity: Showing ${flightsBySegment[0]!.length} flights for segment 0');
        } else {
          filteredFlights.assignAll(displayFlights);
        }
        // Clear outbound/return lists for multicity
        outboundFlights.clear();
        returnFlights.clear();
        return;
      }

      // For non-multicity, categorize into outbound/return
      final searchOriginUpper = searchOrigin?.toUpperCase();
      final searchDestinationUpper = searchDestination?.toUpperCase();

      final List<EmiratesFlight> outboundList = [];
      final List<EmiratesFlight> returnList = [];

      for (final flight in displayFlights) {
        final firstLeg = flight.legSchedules.isNotEmpty ? flight.legSchedules.first : null;
        final lastLeg = flight.legSchedules.isNotEmpty ? flight.legSchedules.last : null;

        final firstDeparture = _extractAirportCode(firstLeg, 'departure');
        final finalArrival = _extractAirportCode(lastLeg, 'arrival');

        if (searchOriginUpper != null &&
            searchDestinationUpper != null &&
            firstDeparture != null &&
            finalArrival != null) {
          if (firstDeparture == searchOriginUpper &&
              finalArrival == searchDestinationUpper) {
            outboundList.add(flight);
            continue;
          }
          if (firstDeparture == searchDestinationUpper &&
              finalArrival == searchOriginUpper) {
            returnList.add(flight);
            continue;
          }
        }

        outboundList.add(flight);
      }

      outboundList.sort((a, b) => a.price.compareTo(b.price));
      returnList.sort((a, b) => a.price.compareTo(b.price));

      outboundFlights.assignAll(outboundList);
      returnFlights.assignAll(returnList);

      if (isRoundTrip) {
        filteredFlights.assignAll(outboundList);
      } else {
        filteredFlights.assignAll(displayFlights);
      }

      debugPrint('\n🎉 FINAL RESULTS:');
      debugPrint('Flights to display: ${filteredFlights.length}');
      debugPrint('Total price options stored: ${_allFlights.length}');
      debugPrint('Each flight has ${_allFlights.length} package options available');
      if (tripType == TripType.multiCity) {
        debugPrint('Multi-city segments: ${flightsBySegment.length}');
      }
      debugPrint('================================\n');

    } catch (e, stackTrace) {
      debugPrint('💥 Error loading Emirates flights: $e');
      debugPrint('Stack trace: $stackTrace');
      setErrorMessage('Failed to load Emirates flights: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  // Get all fare packages for a specific physical flight
  List<EmiratesFarePackage> getFarePackagesForFlight(EmiratesFlight flight) {
    try {
      debugPrint('\n=== GETTING PACKAGES FOR FLIGHT ===');
      debugPrint('Flight Number: EK-${flight.flightNumber}');
      debugPrint('Date: ${flight.departureDate}');
      debugPrint('Time: ${flight.departureTime}');
      debugPrint('Route: ${flight.legSchedules.first['departure']['airport']} → ${flight.legSchedules.last['arrival']['airport']}');
      debugPrint('Total stored flights: ${_allFlights.length}');

      List<EmiratesFarePackage> packages = [];
      Map<String, EmiratesFlight> uniquePackages = {};

      // Create the flight key for matching
      final targetFlightKey = '${flight.departureDate}|${flight.departureTime}|${flight.flightNumber}|'
          '${flight.legSchedules.first['departure']['airport']}|'
          '${flight.legSchedules.last['arrival']['airport']}';

      debugPrint('\nSearching for matching flights...');
      debugPrint('Target flight key: $targetFlightKey');

      // Search through ALL stored flights
      int matchCount = 0;
      _allFlights.forEach((key, storedFlight) {
        // Build the same key format for comparison
        final storedFlightKey = '${storedFlight.departureDate}|${storedFlight.departureTime}|${storedFlight.flightNumber}|'
            '${storedFlight.legSchedules.first['departure']['airport']}|'
            '${storedFlight.legSchedules.last['arrival']['airport']}';

        debugPrint('\nComparing with: $key');
        debugPrint('  Stored key: $storedFlightKey');
        debugPrint('  Price Class: ${storedFlight.priceClassName}');
        debugPrint('  Match: ${storedFlightKey == targetFlightKey ? "✓" : "✗"}');

        // Match if same physical flight
        if (storedFlightKey == targetFlightKey) {
          matchCount++;
          
          // Use offer ID + price class as unique identifier
          final packageKey = '${storedFlight.offerId}-${storedFlight.priceClassName}';
          
          // Only add if we haven't seen this exact offer yet
          if (!uniquePackages.containsKey(packageKey)) {
            uniquePackages[packageKey] = storedFlight;
            debugPrint('  ✓ ADDED: ${storedFlight.priceClassName} - ${storedFlight.currency} ${storedFlight.price.toStringAsFixed(0)}');
          } else {
            debugPrint('  ⚠️ SKIPPED: Duplicate ${storedFlight.priceClassName}');
          }
        }
      });

      debugPrint('\n📊 MATCHING RESULTS:');
      debugPrint('Total matches found: $matchCount');
      debugPrint('Unique packages: ${uniquePackages.length}');

      // Convert to packages (using real price)
      uniquePackages.forEach((packageKey, flightData) {
        packages.add(EmiratesFarePackage(
          name: flightData.priceClassName,
          code: flightData.fareBasisCode,
          price: flightData.price,
          basePrice: flightData.basePrice,
          taxAmount: flightData.taxAmount,
          currency: flightData.currency,
          isRefundable: flightData.isRefundable,
          cabinName: flightData.cabinName,
          checkedWeight: flightData.baggageAllowance.weight,
          checkedUnit: flightData.baggageAllowance.unit,
          carryOnPieces: 1,
          amenities: flightData.amenities,
          offerId: flightData.offerId,
          rawFlightData: flightData.rawData,
        ));
      });

      // Sort packages by price
      packages.sort((a, b) => a.price.compareTo(b.price));

      debugPrint('\n✅ PACKAGES READY (Total: ${packages.length}):');
      for (int i = 0; i < packages.length; i++) {
        debugPrint('  ${i + 1}. ${packages[i].name}');
        debugPrint('     Price: ${packages[i].currency} ${packages[i].price.toStringAsFixed(0)}');
        debugPrint('     Base: ${packages[i].currency} ${packages[i].basePrice.toStringAsFixed(0)}');
        debugPrint('     Tax: ${packages[i].currency} ${packages[i].taxAmount.toStringAsFixed(0)}');
        debugPrint('     Cabin: ${packages[i].cabinName}');
        debugPrint('     Baggage: ${packages[i].checkedWeight} ${packages[i].checkedUnit}');
        debugPrint('     Refundable: ${packages[i].isRefundable ? "Yes" : "No"}');
      }
      debugPrint('================================\n');

      return packages;

    } catch (e, stackTrace) {
      debugPrint('❌ Error getting fare packages: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  // Handle flight selection - show package selection dialog
  void handleEmiratesFlightSelection(EmiratesFlight flight) {
    debugPrint('\n🎯 Flight selected: EK-${flight.flightNumber}');
    debugPrint('Opening package selection dialog...\n');

    final bookingController = Get.find<FlightBookingController>();
    final tripType = bookingController.tripType.value;
    final isRoundTrip = tripType == TripType.roundTrip;
    final isMultiCity = tripType == TripType.multiCity;

    if (isMultiCity) {
      // Handle multicity flight selection
      handleMultiCityFlightSelection(flight, currentMultiCitySegment.value);
      return;
    }

    selectedOutboundFlight = flight;
    selectedOutboundPackage = null;
    selectedReturnFlight = null;
    selectedReturnPackage = null;

    Get.to(() => EmiratesPackageSelectionDialog(
          flight: flight,
          isReturnFlight: false,
          segmentIndex: 0,
          isMultiCity: false,
        ));

    if (!isRoundTrip) {
      selectedReturnFlight = null;
      selectedReturnPackage = null;
    }
  }

  // Handle package selection
  void handlePackageSelection(
    EmiratesFlight flight,
    EmiratesFarePackage package, {
    bool isReturnFlight = false,
  }) {
    if (isReturnFlight) {
      selectedReturnFlight = flight;
      selectedReturnPackage = package;
    } else {
      selectedOutboundFlight = flight;
      selectedOutboundPackage = package;
    }

    debugPrint('\n✅ Package selected:');
    debugPrint('  ${package.name}');
    debugPrint('  ${package.currency} ${package.price.toStringAsFixed(0)}');
    debugPrint('  Segment: ${isReturnFlight ? 'Return' : 'Outbound'}\n');
  }

  void handleReturnFlightSelection(EmiratesFlight flight) {
    debugPrint('\n🎯 Return flight selected: EK-${flight.flightNumber}');
    selectedReturnFlight = flight;
    selectedReturnPackage = null;

    Get.to(() => EmiratesPackageSelectionDialog(
          flight: flight,
          isReturnFlight: true,
          segmentIndex: 1,
          isMultiCity: false,
        ));
  }

  void openReturnFlightsSelection() {
    if (returnFlights.isEmpty) {
      Get.snackbar(
        'No Return Flights',
        'We could not find any return flights for the selected route.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    Get.to(() => EmiratesReturnFlightsPage(returnFlights: returnFlights.toList()));
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
    // Group by physical flight
    Map<String, List<EmiratesFlight>> groupedByFlight = {};
    
    _allFlights.forEach((key, flight) {
      final flightKey = '${flight.departureDate}|${flight.departureTime}|${flight.flightNumber}|'
          '${flight.legSchedules.first['departure']['airport']}|'
          '${flight.legSchedules.last['arrival']['airport']}';
      
      if (!groupedByFlight.containsKey(flightKey)) {
        groupedByFlight[flightKey] = [];
      }
      groupedByFlight[flightKey]!.add(flight);
    });

    // Get lowest price for each physical flight (real price)
    List<EmiratesFlight> allDisplayFlights = [];
    groupedByFlight.forEach((flightKey, priceOptions) {
      if (priceOptions.isNotEmpty) {
        priceOptions.sort((a, b) => a.price.compareTo(b.price));
        allDisplayFlights.add(priceOptions.first);
      }
    });

    List<EmiratesFlight> filtered = List.from(allDisplayFlights);

    // Apply airline filter
    if (airlines != null && !airlines.contains('all')) {
      filtered = filtered.where((flight) {
        return airlines.any((airlineCode) =>
            flight.airlineCode.toUpperCase() == airlineCode.toUpperCase());
      }).toList();
    }

    // Apply stops filter
    if (stops != null && !stops.contains('all')) {
      filtered = filtered.where((flight) {
        int stopCount = flight.legSchedules.length - 1;
        if (stops.contains('nonstop')) return stopCount == 0;
        if (stops.contains('1stop')) return stopCount == 1;
        if (stops.contains('2stop')) return stopCount == 2;
        return false;
      }).toList();
    }

    // Apply sorting (using real price)
    switch (sortType.value) {
      case 'Cheapest':
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Fastest':
        filtered.sort((a, b) {
          final aDuration = a.legSchedules.fold(0, (sum, leg) => sum + (leg['elapsedTime'] as int));
          final bDuration = b.legSchedules.fold(0, (sum, leg) => sum + (leg['elapsedTime'] as int));
          return aDuration.compareTo(bDuration);
        });
        break;
      case 'Suggested':
      default:
        filtered.sort((a, b) {
          final dateCompare = a.departureDate.compareTo(b.departureDate);
          if (dateCompare != 0) return dateCompare;
          return a.departureTime.compareTo(b.departureTime);
        });
        break;
    }

    final searchOriginUpper = _lastSearchOrigin;
    final searchDestinationUpper = _lastSearchDestination;

    final List<EmiratesFlight> outboundList = [];
    final List<EmiratesFlight> returnList = [];

    for (final flight in filtered) {
      final firstLeg = flight.legSchedules.isNotEmpty ? flight.legSchedules.first : null;
      final lastLeg = flight.legSchedules.isNotEmpty ? flight.legSchedules.last : null;

      final firstDeparture = _extractAirportCode(firstLeg, 'departure');
      final finalArrival = _extractAirportCode(lastLeg, 'arrival');

      if (searchOriginUpper != null &&
          searchDestinationUpper != null &&
          firstDeparture != null &&
          finalArrival != null) {
        if (firstDeparture == searchOriginUpper &&
            finalArrival == searchDestinationUpper) {
          outboundList.add(flight);
          continue;
        }
        if (firstDeparture == searchDestinationUpper &&
            finalArrival == searchOriginUpper) {
          returnList.add(flight);
          continue;
        }
      }

      outboundList.add(flight);
    }

    outboundList.sort((a, b) => a.price.compareTo(b.price));
    returnList.sort((a, b) => a.price.compareTo(b.price));

    outboundFlights.assignAll(outboundList);
    returnFlights.assignAll(returnList);

    if (isRoundTripSearch.value) {
      filteredFlights.assignAll(outboundList);
    } else {
      filteredFlights.assignAll(filtered);
    }
  }

  List<EmiratesFlight> getFlightsByAirline(String airlineCode) {
    return filteredFlights.where((flight) {
      return flight.airlineCode.toUpperCase() == airlineCode.toUpperCase();
    }).toList();
  }

  String _extractNodeText(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is Map) {
      for (final key in ['\$t', 'value', 'text', '_text']) {
        if (value.containsKey(key)) {
          final extracted = _extractNodeText(value[key]);
          if (extracted.isNotEmpty) return extracted;
        }
      }
      if (value.length == 1) {
        return _extractNodeText(value.values.first);
      }
      for (final entry in value.entries) {
        final extracted = _extractNodeText(entry.value);
        if (extracted.isNotEmpty) return extracted;
      }
      return '';
    }
    if (value is Iterable) {
      for (final item in value) {
        final extracted = _extractNodeText(item);
        if (extracted.isNotEmpty) return extracted;
      }
      return '';
    }
    return value.toString().trim();
  }

  String? _extractAirportCode(dynamic leg, String key) {
    if (leg is Map) {
      final segmentInfo = leg[key];
      if (segmentInfo is Map) {
        final airport = segmentInfo['airport'] ?? segmentInfo['AirportCode'];
        if (airport != null) {
          return airport.toString().toUpperCase();
        }
      }
    }
    return null;
  }

  List<EmiratesFlight> getReturnFlightOptions() {
    return returnFlights.toList();
  }

  int getFlightCountByAirline(String airlineCode) {
    return getFlightsByAirline(airlineCode).length;
  }

  List<FilterAirline> getAvailableAirlines() {
    if (filteredFlights.isEmpty) return [];
    return [
      FilterAirline(
        code: 'EK',
        name: 'Emirates',
        logoPath: 'https://images.kiwi.com/airlines/64/EK.png',
      )
    ];
  }

  @override
  void onInit() {
    super.onInit();
    debugPrint('Emirates Flight Controller initialized');
  }

  @override
  void onClose() {
    clearFlights();
    super.onClose();
  }

  // Debug method to inspect stored flights
  void debugPrintStoredFlights() {
    debugPrint('\n=== STORED FLIGHTS DEBUG ===');
    debugPrint('Total stored: ${_allFlights.length}\n');
    
    debugPrint('All stored keys:');
    _allFlights.keys.forEach((key) {
      debugPrint('  - $key');
    });
    debugPrint('');
    
    Map<String, List<String>> grouped = {};
    
    _allFlights.forEach((key, flight) {
      final groupKey = '${flight.departureDate} ${flight.departureTime} EK-${flight.flightNumber}';
      if (!grouped.containsKey(groupKey)) {
        grouped[groupKey] = [];
      }
      grouped[groupKey]!.add('${flight.priceClassName} (${flight.currency} ${flight.price.toStringAsFixed(0)}) [${flight.offerId}]');
    });
    
    debugPrint('Grouped by flight:');
    grouped.forEach((dateTimeFlight, priceClasses) {
      debugPrint('$dateTimeFlight:');
      for (var pc in priceClasses) {
        debugPrint('  - $pc');
      }
      debugPrint('');
    });
    
    debugPrint('===========================\n');
  }

  // Organize flights by segment for multicity
  void _organizeFlightsBySegment(List<EmiratesFlight> allFlights, FlightBookingController bookingController) {
    flightsBySegment.clear();
    
    debugPrint('\n🔍 Organizing ${allFlights.length} flights into segments...');
    
    for (int segmentIndex = 0; segmentIndex < bookingController.cityPairs.length; segmentIndex++) {
      final cityPair = bookingController.cityPairs[segmentIndex];
      final fromCity = cityPair.fromCity.value.toUpperCase();
      final toCity = cityPair.toCity.value.toUpperCase();
      
      final segmentFlights = <EmiratesFlight>[];
      
      debugPrint('\n📋 Segment $segmentIndex: Looking for flights from $fromCity to $toCity');
      
      for (final flight in allFlights) {
        final firstLeg = flight.legSchedules.isNotEmpty ? flight.legSchedules.first : null;
        final lastLeg = flight.legSchedules.isNotEmpty ? flight.legSchedules.last : null;
        
        final firstDeparture = _extractAirportCode(firstLeg, 'departure');
        final finalArrival = _extractAirportCode(lastLeg, 'arrival');
        
        debugPrint('   Flight: $firstDeparture -> $finalArrival (Match: ${firstDeparture == fromCity && finalArrival == toCity})');
        
        if (firstDeparture == fromCity && finalArrival == toCity) {
          segmentFlights.add(flight);
        }
      }
      
      // Sort by price
      segmentFlights.sort((a, b) => a.price.compareTo(b.price));
      flightsBySegment[segmentIndex] = segmentFlights;
      
      debugPrint('✅ Segment $segmentIndex ($fromCity -> $toCity): ${segmentFlights.length} flights found');
    }
    
    debugPrint('\n📊 Segment organization complete:\n');
    flightsBySegment.forEach((index, flights) {
      debugPrint('   Segment $index: ${flights.length} flights');
    });
  }

  // Get flights for a specific segment
  List<EmiratesFlight> getFlightsForSegment(int segmentIndex) {
    return flightsBySegment[segmentIndex] ?? [];
  }

  // Handle multicity flight selection
  void handleMultiCityFlightSelection(EmiratesFlight flight, int segmentIndex) {
    debugPrint('\n🎯 Multi-city flight selected for segment $segmentIndex: EK-${flight.flightNumber}');
    
    final bookingController = Get.find<FlightBookingController>();
    final requiredSize = bookingController.cityPairs.length;
    
    // Ensure lists are properly sized
    while (selectedMultiCityFlights.length < requiredSize) {
      selectedMultiCityFlights.add(null);
    }
    while (selectedMultiCityPackages.length < requiredSize) {
      selectedMultiCityPackages.add(null);
    }
    
    // Store the flight
    selectedMultiCityFlights[segmentIndex] = flight;
    currentMultiCitySegment.value = segmentIndex;
    
    // Open package selection
    Get.to(() => EmiratesPackageSelectionDialog(
      flight: flight,
      isReturnFlight: false,
      segmentIndex: segmentIndex,
      isMultiCity: true,
    ));
  }

  // Handle multicity package selection
  void handleMultiCityPackageSelection(EmiratesFlight flight, EmiratesFarePackage package, int segmentIndex) {
    debugPrint('\n✅ Multi-city package selected for segment $segmentIndex');
    
    final bookingController = Get.find<FlightBookingController>();
    final requiredSize = bookingController.cityPairs.length;
    
    // Ensure lists are properly sized
    while (selectedMultiCityFlights.length < requiredSize) {
      selectedMultiCityFlights.add(null);
    }
    while (selectedMultiCityPackages.length < requiredSize) {
      selectedMultiCityPackages.add(null);
    }
    
    // Store the package
    selectedMultiCityPackages[segmentIndex] = package;
    
    // Check if all segments are selected
    if (isAllMultiCitySegmentsSelected) {
      debugPrint('All segments selected, proceeding to booking');
      _proceedToMultiCityBooking();
    } else {
      debugPrint('Moving to next segment');
      proceedToNextMultiCitySegment();
    }
  }

  // Check if all multicity segments are selected
  bool get isAllMultiCitySegmentsSelected {
    final bookingController = Get.find<FlightBookingController>();
    final requiredSize = bookingController.cityPairs.length;
    
    if (selectedMultiCityFlights.length < requiredSize || selectedMultiCityPackages.length < requiredSize) {
      return false;
    }
    
    for (int i = 0; i < requiredSize; i++) {
      if (selectedMultiCityFlights[i] == null || selectedMultiCityPackages[i] == null) {
        return false;
      }
    }
    
    return true;
  }

  // Get next unselected segment
  int getNextUnselectedSegment() {
    final bookingController = Get.find<FlightBookingController>();
    final requiredSize = bookingController.cityPairs.length;
    
    for (int i = 0; i < requiredSize; i++) {
      if (i >= selectedMultiCityFlights.length || selectedMultiCityFlights[i] == null ||
          i >= selectedMultiCityPackages.length || selectedMultiCityPackages[i] == null) {
        return i;
      }
    }
    
    return -1; // All segments selected
  }

  // Proceed to next multicity segment
  void proceedToNextMultiCitySegment() {
    final nextSegment = getNextUnselectedSegment();
    
    if (nextSegment != -1) {
      currentMultiCitySegment.value = nextSegment;
      final segmentFlights = getFlightsForSegment(nextSegment);
      
      if (segmentFlights.isEmpty) {
        Get.snackbar(
          'No Flights Available',
          'No flights found for this segment. Please try different dates or routes.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      
      // Show flight selection for next segment
      Future.delayed(const Duration(milliseconds: 300), () {
        _showMultiCityFlightSelection(nextSegment);
      });
    } else {
      _proceedToMultiCityBooking();
    }
  }

  // Show multicity flight selection for a segment
  void _showMultiCityFlightSelection(int segmentIndex) {
    final bookingController = Get.find<FlightBookingController>();
    
    if (segmentIndex >= bookingController.cityPairs.length) {
      debugPrint('Invalid segment index: $segmentIndex');
      return;
    }
    
    final segmentFlights = getFlightsForSegment(segmentIndex);
    currentMultiCitySegment.value = segmentIndex;
    
    // Navigate to dedicated multi-city flight selection page (like AirBlue)
    Future.microtask(() {
      Get.off(() => EmiratesMultiCityFlightPage(
            currentSegment: segmentIndex,
            availableFlights: segmentFlights,
          ));
    });
    
    debugPrint('✅ Showing flight selection page for segment $segmentIndex: ${segmentFlights.length} flights');
  }

  // Proceed to multicity booking (skip review, go directly to booking form)
  void _proceedToMultiCityBooking() {
    debugPrint('Proceeding to multicity booking');
    
    final selectedFlights = selectedMultiCityFlights.where((f) => f != null).cast<EmiratesFlight>().toList();
    final selectedPackages = selectedMultiCityPackages.where((p) => p != null).cast<EmiratesFarePackage>().toList();
    
    if (selectedFlights.isEmpty || selectedPackages.isEmpty) {
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
    String currency = selectedPackages.first.currency;
    
    for (final package in selectedPackages) {
      totalPrice += package.price * passengerCount;
    }
    
    // Use first flight/package for main, rest as multicity
    // For now, use the existing forEmirates with first flight
    // TODO: Add proper multicity support to AirBlueBookingFlight
    Get.to(() => AirBlueBookingFlight.forEmirates(
      flight: selectedFlights.first,
      selectedPackage: selectedPackages.first,
      totalPrice: totalPrice,
      currency: currency,
    ));
  }

  // Initialize multicity selection
  void initializeMultiCitySelection() {
    final bookingController = Get.find<FlightBookingController>();
    final requiredSize = bookingController.cityPairs.length;
    
    while (selectedMultiCityFlights.length < requiredSize) {
      selectedMultiCityFlights.add(null);
    }
    while (selectedMultiCityPackages.length < requiredSize) {
      selectedMultiCityPackages.add(null);
    }
    
    currentMultiCitySegment.value = 0;
    
    // Show first segment flights
    if (flightsBySegment.containsKey(0)) {
      filteredFlights.assignAll(flightsBySegment[0]!);
    }
  }
}

class EmiratesFarePackage {
  final String name;
  final String code;
  final double price;
  final double basePrice;
  final double taxAmount;
  final String currency;
  final bool isRefundable;
  final String cabinName;
  final double checkedWeight;
  final String checkedUnit;
  final int carryOnPieces;
  final List<String> amenities;
  final String offerId;
  final Map<String, dynamic> rawFlightData;

  EmiratesFarePackage({
    required this.name,
    required this.code,
    required this.price,
    required this.basePrice,
    required this.taxAmount,
    required this.currency,
    required this.isRefundable,
    required this.cabinName,
    required this.checkedWeight,
    required this.checkedUnit,
    required this.carryOnPieces,
    required this.amenities,
    required this.offerId,
    required this.rawFlightData,
  });
}