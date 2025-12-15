// flight_package/emirates/emirates_flight_package.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:ready_flights/utility/colors.dart';
import 'package:ready_flights/services/api_service_emirates.dart'
    as emirates_service;
import 'package:ready_flights/views/flight/search_flights/emirates_ndc/emirates_flight_controller.dart';
import 'package:ready_flights/views/flight/search_flights/emirates_ndc/emirates_model.dart';
import 'package:ready_flights/views/flight/form/flight_booking_controller.dart';
import 'package:ready_flights/widgets/travelers_selection_bottom_sheet.dart';
import '../../../booking_flight/airblue/airblue_booking_flight.dart';
import '../../search_flight_utils/widgets/emirates_ndc_card.dart';

class EmiratesPackageSelectionDialog extends StatelessWidget {
  final EmiratesFlight flight;
  final bool isReturnFlight;
  final RxBool isLoading = false.obs;
  final int segmentIndex;
  final bool isMultiCity;

  EmiratesPackageSelectionDialog({
    super.key,
    required this.flight,
    required this.isReturnFlight,
    required this.segmentIndex,
    required this.isMultiCity,
  });

  final emiratesController = Get.find<EmiratesFlightController>();

  @override
  Widget build(BuildContext context) {
    // Debug: Print flight details when dialog opens
    debugPrint('\n=== PACKAGE DIALOG OPENED ===');
    debugPrint('Flight ID: ${flight.id}');
    debugPrint('Route: ${_getDepartureAirport()} -> ${_getArrivalAirport()}');
    debugPrint('Date: ${flight.departureDate}');
    debugPrint('Time: ${flight.departureTime}');
    debugPrint('Flight Number: ${flight.flightNumber}');
    debugPrint('Current Price Class: ${flight.priceClassName}');
    debugPrint('===========================\n');
    
    return Scaffold(
      backgroundColor: TColors.background,
      appBar: AppBar(
        backgroundColor: TColors.background,
        surfaceTintColor: TColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Select a fare option',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _buildFlightInfo(),
          SizedBox(height: 12),
          Expanded(
            child: _buildPackagesList(),
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    if (isReturnFlight) {
      return 'Select Return Package';
    } else {
      return 'Select Package';
    }
  }

  Widget _buildFlightInfo() {
    return EmiratesFlightCard(
      flight: flight,
      showReturnFlight: false,
      isShowBookButton: false,
      isMultiCity: isMultiCity,
      currentSegment: segmentIndex,
    );
  }

  // Helper methods for debug prints
  String _getDepartureAirport() {
    if (flight.legSchedules.isNotEmpty) {
      return flight.legSchedules[0]['departure']['airport'] ?? 'N/A';
    }
    return 'N/A';
  }

  String _getArrivalAirport() {
    if (flight.legSchedules.isNotEmpty) {
      return flight.legSchedules[0]['arrival']['airport'] ?? 'N/A';
    }
    return 'N/A';
  }

  Widget _buildPackagesList() {
    // Get all fare options for this flight (different price classes)
    debugPrint('\n🔍 Fetching packages for flight...');
    final List<EmiratesFarePackage> packages = emiratesController.getFarePackagesForFlight(flight);
    debugPrint('📦 Packages received: ${packages.length}\n');

    if (packages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              'No packages available for this flight',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Flight: ${flight.departureDate} ${flight.departureTime} EK-${flight.flightNumber}',
              style: const TextStyle(fontSize: 12, color: TColors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                emiratesController.debugPrintStoredFlights();
              },
              icon: const Icon(Icons.bug_report),
              label: const Text('Debug Storage'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.vertical,
      physics: const BouncingScrollPhysics(),
      primary: false,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: packages.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildHorizontalPackageCard(packages[index], index),
        );
      },
    );
  }

  Widget _buildHorizontalPackageCard(EmiratesFarePackage package, int index) {
    // Determine if this is the cheapest option
    final List<EmiratesFarePackage> allPackages = emiratesController.getFarePackagesForFlight(flight);
    final sortedPackages = List<EmiratesFarePackage>.from(allPackages);
    sortedPackages.sort((a, b) => a.price.compareTo(b.price));
    
    // Compare by package properties instead of object reference
    final isCheapest = sortedPackages.isNotEmpty && 
        package.name == sortedPackages.first.name && 
        package.price == sortedPackages.first.price;
    
    // Debug print to check if cheapest logic is working
    debugPrint('Package: ${package.name}, Price: ${package.price}, Is Cheapest: $isCheapest');
    if (sortedPackages.isNotEmpty) {
      debugPrint('Cheapest package: ${sortedPackages.first.name} with price: ${sortedPackages.first.price}');
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: TColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  package.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: TColors.text,
                  ),
                ),
              ),
              
              // Package details
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildCompactPackageDetail(
                      Icons.work_outline_rounded,
                      'Carry-On Baggage',
                      '${package.carryOnPieces} piece(s)',
                    ),
                    const SizedBox(height: 12),
                    _buildCompactPackageDetail(
                      Icons.luggage,
                      'Checked Baggage',
                      '${package.checkedWeight.toStringAsFixed(0)} ${package.checkedUnit}',
                    ),
                    const SizedBox(height: 12),
                    _buildCompactPackageDetail(
                      Icons.restaurant_rounded,
                      'Meal',
                      'Included',
                    ),
                    const SizedBox(height: 12),
                    _buildCompactPackageDetail(
                      Icons.airline_seat_recline_normal,
                      'Cabin',
                      package.cabinName,
                    ),
                    const SizedBox(height: 12),
                    _buildCompactPackageDetail(
                      Icons.swap_horiz_rounded,
                      'Changes',
                      package.isRefundable ? 'Allowed with fee' : 'Restricted',
                    ),
                    const SizedBox(height: 12),
                    _buildCompactPackageDetail(
                      Icons.money_off_rounded,
                      'Refund',
                      package.isRefundable ? 'Allowed with fee' : 'Non-refundable',
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              
              // Price button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Obx(() => SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isLoading.value
                        ? null
                        : () => _onSelectPackage(package),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TColors.primary,
                      foregroundColor: TColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading.value
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(TColors.white),
                      ),
                    )
                        : Text(
                      '${package.currency} ${package.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )),
              ),
            ],
          ),
          
          // "Cheapest" text positioned on top border
          if (isCheapest)
            Positioned(
              top: -10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.shade300,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'Cheapest',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactPackageDetail(
      IconData icon,
      String title,
      String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: TColors.text.withOpacity(0.6),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: TColors.text.withOpacity(0.7),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: TColors.text,
          ),
        ),
      ],
    );
  }

  int _calculatePassengerCount(FlightBookingController bookingController) {
    try {
      final travelersController = Get.find<TravelersController>();
      final count = travelersController.adultCount.value +
          travelersController.childrenCount.value +
          travelersController.infantCount.value;
      if (count > 0) return count;
    } catch (_) {}

    final fallback = bookingController.adultCount.value +
        bookingController.childrenCount.value +
        bookingController.infantCount.value;
    return fallback > 0 ? fallback : 1;
  }

  Widget _buildPackageDetail(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TColors.secondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: TColors.background, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: TColors.grey,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: TColors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Future<void> _onSelectPackage(EmiratesFarePackage package) async {
    try {
      isLoading.value = true;

      final bookingController = Get.find<FlightBookingController>();
      final tripType = bookingController.tripType.value;
      final bool isRoundTrip = tripType == TripType.roundTrip;
      final bool isMultiCity = tripType == TripType.multiCity;

      // Handle multicity package selection (with price revalidation)
      if (isMultiCity) {
        final pricedPackage = await _pricePackage(package);
        isLoading.value = false;
        Get.back();
        emiratesController.handleMultiCityPackageSelection(flight, pricedPackage, segmentIndex);
        return;
      }

      if (isRoundTrip && !isReturnFlight) {
        // Store outbound package and prompt for return selection
      emiratesController.handlePackageSelection(
        flight,
        package,
        isReturnFlight: false,
      );
        isLoading.value = false;
        Get.back();
        Future.delayed(const Duration(milliseconds: 250), () {
          emiratesController.openReturnFlightsSelection();
        });
        return;
      }

      debugPrint('\n=== PACKAGE SELECTED ===');
      debugPrint('Package: ${package.name}');
      debugPrint('Price: PKR ${package.price.toStringAsFixed(0)}');
      debugPrint('========================\n');

      if (isRoundTrip && isReturnFlight) {
        final outboundFlight = emiratesController.selectedOutboundFlight;
        final outboundPackage = emiratesController.selectedOutboundPackage;
        if (outboundFlight == null || outboundPackage == null) {
          throw Exception('Outbound selection missing. Please reselect outbound flight.');
        }

        final pricedPackages = await _pricePackages([outboundPackage, package]);
        final pricedOutbound = pricedPackages[0];
        final pricedReturn = pricedPackages[1];

        emiratesController.handlePackageSelection(
          outboundFlight,
          pricedOutbound,
          isReturnFlight: false,
        );
        emiratesController.handlePackageSelection(
          flight,
          pricedReturn,
          isReturnFlight: true,
        );

        final passengerCount = _calculatePassengerCount(bookingController);
        final perPassengerTotal = pricedOutbound.price + pricedReturn.price;
        final totalPrice = perPassengerTotal * passengerCount;

        Get.back();
        Future.delayed(const Duration(milliseconds: 200), () {
          Get.to(
            () => AirBlueBookingFlight.forEmirates(
              flight: outboundFlight,
              returnFlight: flight,
              selectedPackage: pricedOutbound,
              returnPackage: pricedReturn,
              totalPrice: totalPrice,
              currency: pricedOutbound.currency,
            ),
          );
        });
        return;
      }

      final pricedPackage = await _pricePackage(package);
      emiratesController.handlePackageSelection(
        flight,
        pricedPackage,
        isReturnFlight: isReturnFlight,
      );

      final passengerCount = _calculatePassengerCount(bookingController);
      final totalPrice = pricedPackage.price * passengerCount;

      Get.back();
      Future.delayed(const Duration(milliseconds: 200), () {
        Get.to(
          () => AirBlueBookingFlight.forEmirates(
            flight: flight,
            selectedPackage: pricedPackage,
            totalPrice: totalPrice,
            currency: pricedPackage.currency,
          ),
        );
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Error selecting package: $e');
      debugPrint('Stack trace: $stackTrace');
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  List<Map<String, String>> _extractPassengerDetails(Map<String, dynamic> rawData) {
    final results = <Map<String, String>>[];
    final dataLists = rawData['DataLists'];
    if (dataLists is Map) {
      final passengerListNode = dataLists['PassengerList'];
      dynamic passengers;
      if (passengerListNode is Map) {
        passengers = passengerListNode['Passenger'] ?? passengerListNode;
      } else {
        passengers = passengerListNode;
      }

      void handle(dynamic node) {
        if (node == null) return;
        if (node is List) {
          for (final item in node) {
            handle(item);
          }
        } else if (node is Map) {
          if (node.containsKey('PassengerID')) {
            final id = node['PassengerID']?.toString() ?? '';
            final ptc = _toText(node['PTC']);
            if (id.isNotEmpty) {
              results.add({'id': id, 'ptc': ptc.isNotEmpty ? ptc : 'ADT'});
            }
          } else {
            for (final entry in node.values) {
              handle(entry);
            }
          }
        }
      }

      handle(passengers);
    }

    if (results.isEmpty) {
      return [
        {'id': 'T1', 'ptc': 'ADT'}
      ];
    }

    results.sort((a, b) => (a['id'] ?? '').compareTo(b['id'] ?? ''));
    return results;
  }

  List<Map<String, dynamic>> _extractOfferItems(Map<String, dynamic> rawData) {
    final offerItem = rawData['OfferItem'];
    if (offerItem is List) {
      return offerItem
          .whereType<Map>()
          .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item.cast<String, dynamic>()))
          .toList();
    }
    if (offerItem is Map) {
      return [Map<String, dynamic>.from(offerItem.cast<String, dynamic>())];
    }
    return const [];
  }

  Future<EmiratesFarePackage> _pricePackage(EmiratesFarePackage package) async {
    final results = await _pricePackages([package]);
    if (results.isEmpty) {
      throw Exception('Failed to price offer.');
    }
    return results.first;
  }

  Future<List<EmiratesFarePackage>> _pricePackages(
    List<EmiratesFarePackage> packages,
  ) async {
    if (packages.isEmpty) return const [];

    final passengerDetails = _extractPassengerDetails(packages.first.rawFlightData);
    final passengerIds = passengerDetails
        .map((p) => p['id'])
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    final fallbackPassengerRefs =
        passengerIds.isNotEmpty ? passengerIds.join(' ') : 'T1';
    final validPassengerIds = passengerIds.isNotEmpty
        ? passengerIds.toSet()
        : <String>{'T1'};

    final entries = packages
        .map(
          (pkg) => _buildOfferPricingEntry(
            pkg,
            fallbackPassengerRefs,
            validPassengerIds,
          ),
        )
        .toList();

    final pricingResult =
        await emirates_service.ApiServiceEmirates().priceEmiratesOffer(
      offers: entries,
      passengerDetails: passengerDetails,
    );

    if (pricingResult['success'] != true) {
      final error = pricingResult['error'] ?? 'Failed to price offer';
      throw Exception(error.toString());
    }

    final responseIdFromPricing = pricingResult['responseId']?.toString() ?? '';
    final shoppingResponse = pricingResult['shoppingResponse'];

    final List<dynamic> pricedOffersData = pricingResult['pricedOffers'] is List
        ? pricingResult['pricedOffers'] as List<dynamic>
        : [];
    if (pricedOffersData.isEmpty && pricingResult['PricedOffer'] != null) {
      pricedOffersData.add(pricingResult['PricedOffer']);
    }

    final pricedById = <String, Map<String, dynamic>>{};
    for (final data in pricedOffersData) {
      if (data is Map<String, dynamic>) {
        final offerId = _toText(data['OfferID']);
        if (offerId.isNotEmpty) {
          pricedById[offerId] = data;
        }
      }
    }

    final List<EmiratesFarePackage> updated = [];
    for (final package in packages) {
      final pricedOffer = pricedById[package.offerId] ??
          (pricedOffersData.length == 1 && pricedOffersData.first is Map<String, dynamic>
              ? pricedOffersData.first as Map<String, dynamic>
              : null);

      if (pricedOffer is Map<String, dynamic>) {
        updated.add(
          _buildPricedPackage(
            package,
            Map<String, dynamic>.from(pricedOffer),
            pricingResult['dataLists'],
            responseIdFromPricing,
            shoppingResponse,
          ),
        );
      } else {
        updated.add(package);
      }
    }

    return updated;
  }

  emirates_service.OfferPricingEntry _buildOfferPricingEntry(
    EmiratesFarePackage package,
    String fallbackPassengerRefs,
    Set<String> validPassengerIds,
  ) {
    final offerItems = _extractOfferItems(package.rawFlightData);
    final items = <emirates_service.OfferPricingItem>[];

    for (final offerItem in offerItems) {
      final offerItemId = offerItem['OfferItemID']?.toString() ?? '';
      if (offerItemId.isEmpty) continue;
      final passengerRefs =
          _extractPassengerRefsFromOfferItem(
        offerItem,
        fallbackPassengerRefs,
        validPassengerIds,
      );
      items.add(
        emirates_service.OfferPricingItem(
          offerItemId: offerItemId,
          passengerRefs: passengerRefs.isNotEmpty ? passengerRefs : fallbackPassengerRefs,
        ),
      );
    }

    if (items.isEmpty) {
      throw Exception('Missing OfferItemIDs for selected offer.');
    }

    final owner = package.rawFlightData['Owner']?.toString() ?? 'EK';
    final responseId = _deriveResponseId(package);
    if (responseId.isEmpty) {
      throw Exception('Missing ResponseID for selected offer.');
    }

    return emirates_service.OfferPricingEntry(
      offerId: package.offerId,
      owner: owner,
      responseId: responseId,
      items: items,
    );
  }

  EmiratesFarePackage _buildPricedPackage(
    EmiratesFarePackage original,
    Map<String, dynamic> pricedOffer,
    dynamic dataLists,
    String responseIdFromPricing,
    dynamic shoppingResponse,
  ) {
    if (dataLists != null) {
      pricedOffer['DataLists'] ??= dataLists;
    }
    if (shoppingResponse != null) {
      pricedOffer['ShoppingResponseID'] ??= shoppingResponse;
    }
    if (responseIdFromPricing.isNotEmpty) {
      pricedOffer['ResponseID'] ??= responseIdFromPricing;
    }
    if (!pricedOffer.containsKey('Owner')) {
      pricedOffer['Owner'] = original.rawFlightData['Owner'] ?? 'EK';
    }

    final List<Map<String, dynamic>> pricedOfferItems = _extractOfferItems(pricedOffer);
    final Map<String, dynamic>? pricedOfferItem =
        pricedOfferItems.isNotEmpty ? pricedOfferItems.first : null;
    final double pricedTotal =
        _parseAmount(((pricedOffer['TotalPrice'] ?? {})['DetailCurrencyPrice'] ?? {})['Total']);
    final String pricedCurrency =
        _extractCurrency(((pricedOffer['TotalPrice'] ?? {})['DetailCurrencyPrice'] ?? {})['Total']) ??
            original.currency;

    double pricedBase = _parseAmount(
      (((pricedOfferItem?['FareDetail'] ?? {})['Price'] ?? {})['BaseAmount']),
    );
    double pricedTaxes = _parseAmount(
      ((((pricedOfferItem?['FareDetail'] ?? {})['Price'] ?? {})['Taxes'] ?? {})['Total']),
    );

    if (pricedOfferItems.length > 1) {
      pricedBase = pricedOfferItems.fold<double>(
        0,
        (sum, item) =>
            sum +
            _parseAmount(
              (((item['FareDetail'] ?? {})['Price'] ?? {})['BaseAmount']),
            ),
      );
      pricedTaxes = pricedOfferItems.fold<double>(
        0,
        (sum, item) =>
            sum +
            _parseAmount(
              ((((item['FareDetail'] ?? {})['Price'] ?? {})['Taxes'] ?? {})['Total']),
            ),
      );
    }

    if (pricedBase <= 0) pricedBase = original.basePrice;
    if (pricedTaxes < 0) pricedTaxes = original.taxAmount;

    return EmiratesFarePackage(
      name: original.name,
      code: original.code,
      price: pricedTotal > 0 ? pricedTotal : original.price,
      basePrice: pricedBase > 0 ? pricedBase : original.basePrice,
      taxAmount: pricedTaxes >= 0 ? pricedTaxes : original.taxAmount,
      currency: pricedCurrency.isNotEmpty ? pricedCurrency : original.currency,
      isRefundable: original.isRefundable,
      cabinName: original.cabinName,
      checkedWeight: original.checkedWeight,
      checkedUnit: original.checkedUnit,
      carryOnPieces: original.carryOnPieces,
      amenities: original.amenities,
      offerId: pricedOffer['OfferID']?.toString() ?? original.offerId,
      rawFlightData: pricedOffer,
    );
  }

  String _extractPassengerRefsFromOfferItem(
    Map<String, dynamic> offerItem,
    String fallback,
    Set<String> validPassengerIds,
  ) {
    final directRefs = _extractPassengerIds(offerItem['PassengerRefs'], validPassengerIds);
    if (directRefs.isNotEmpty) {
      return directRefs.join(' ');
    }

    final serviceRefs = _extractPassengerIds(offerItem['Service'], validPassengerIds);
    if (serviceRefs.isNotEmpty) {
      return serviceRefs.join(' ');
    }

    return fallback;
  }

  List<String> _extractPassengerIds(
    dynamic node,
    Set<String> validPassengerIds,
  ) {
    if (node == null) return const [];

    final collected = <String>[];

    void collect(dynamic current) {
      if (current == null) return;

      if (current is String) {
        for (final token in current.split(RegExp(r'\s+'))) {
          final trimmed = token.trim();
          if (trimmed.isEmpty) continue;
          if (validPassengerIds.isEmpty || validPassengerIds.contains(trimmed)) {
            collected.add(trimmed);
          }
        }
        return;
      }

      if (current is Map) {
        if (current.containsKey('\$t')) {
          collect(current['\$t']);
          return;
        }
        if (current.containsKey('value')) {
          collect(current['value']);
          return;
        }
        if (current.containsKey('PassengerRefs')) {
          collect(current['PassengerRefs']);
        } else {
          for (final value in current.values) {
            collect(value);
          }
        }
        return;
      }

      if (current is Iterable) {
        for (final value in current) {
          collect(value);
        }
        return;
      }

      collect(current.toString());
    }

    collect(node);

    final seen = <String>{};
    final ordered = <String>[];
    for (final id in collected) {
      if (seen.add(id)) {
        ordered.add(id);
      }
    }
    return ordered;
  }

  double _parseAmount(dynamic node) {
    final text = _toText(node);
    if (text.isEmpty) return 0;
    return double.tryParse(text.replaceAll(',', '')) ?? 0;
  }

  String? _extractCurrency(dynamic node) {
    if (node is Map) {
      if (node['Code'] != null) return node['Code'].toString();
      if (node['CurrencyCode'] != null) return node['CurrencyCode'].toString();
    }
    return null;
  }

  String _toText(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is Map) {
      if (value.containsKey('\$t')) {
        return _toText(value['\$t']);
      }
      if (value.length == 1) {
        return _toText(value.values.first);
      }
      for (final entry in value.entries) {
        final extracted = _toText(entry.value);
        if (extracted.isNotEmpty) return extracted;
      }
      return '';
    }
    if (value is Iterable) {
      for (final item in value) {
        final extracted = _toText(item);
        if (extracted.isNotEmpty) return extracted;
      }
      return '';
    }
    return value.toString().trim();
  }

  String _deriveResponseId(EmiratesFarePackage package) {
    final raw = package.rawFlightData;

    String searchForResponseId(dynamic source) {
      if (source == null) return '';
      if (source is Map) {
        if (source.containsKey('ResponseID')) {
          final value = _toText(source['ResponseID']);
          if (value.isNotEmpty) return value;
        }
        for (final entry in source.entries) {
          final found = searchForResponseId(entry.value);
          if (found.isNotEmpty) return found;
        }
        return '';
      }
      if (source is Iterable) {
        for (final item in source) {
          final found = searchForResponseId(item);
          if (found.isNotEmpty) return found;
        }
        return '';
      }
      return '';
    }

    final candidates = <String>[
      searchForResponseId(raw),
      flight.responseId,
      searchForResponseId(flight.rawData),
    ];

    for (final candidate in candidates) {
      if (candidate.isNotEmpty) return candidate;
    }

    final offerId = package.offerId;
    if (offerId.isEmpty) return '';

    final lastDash = offerId.lastIndexOf('-');
    if (lastDash > 0) {
      return offerId.substring(0, lastDash);
    }

    return offerId;
  }
}

    