// flight_package/emirates/emirates_flight_package.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:ready_flights/utility/colors.dart';
import 'package:ready_flights/services/api_service_emirates.dart';
import 'package:ready_flights/views/flight/search_flights/emirates_ndc/emirates_flight_controller.dart';
import 'package:ready_flights/views/flight/search_flights/emirates_ndc/emirates_model.dart';
import 'package:ready_flights/views/flight/form/flight_booking_controller.dart';
import 'package:ready_flights/views/flight/search_flights/review_flight/emirates_ndc_review.dart';

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
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: TColors.secondary.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CachedNetworkImage(
                imageUrl: 'https://images.kiwi.com/airlines/64/EK.png',
                height: 40,
                width: 40,
                placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                errorWidget: (context, url, error) => const Icon(Icons.flight, size: 40),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EK-${flight.flightNumber}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      flight.cabinName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: TColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildAirportInfo(
                _getDepartureAirport(),
                _getDepartureTime(),
                true,
              ),
              Column(
                children: [
                  const Icon(Icons.flight, color: TColors.primary),
                  Text(
                    _getFlightDuration(),
                    style: const TextStyle(fontSize: 12, color: TColors.grey),
                  ),
                ],
              ),
              _buildAirportInfo(
                _getArrivalAirport(),
                _getArrivalTime(),
                false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAirportInfo(String airport, String time, bool isDeparture) {
    return Column(
      crossAxisAlignment: isDeparture ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          airport,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          time,
          style: const TextStyle(
            fontSize: 14,
            color: TColors.grey,
          ),
        ),
      ],
    );
  }

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

  String _getDepartureTime() {
    if (flight.legSchedules.isNotEmpty) {
      return _formatTimeFromDateTime(
        flight.legSchedules[0]['departure']['dateTime'],
      );
    }
    return 'N/A';
  }

  String _getArrivalTime() {
    if (flight.legSchedules.isNotEmpty) {
      return _formatTimeFromDateTime(
        flight.legSchedules[0]['arrival']['dateTime'],
      );
    }
    return 'N/A';
  }

  String _getFlightDuration() {
    if (flight.legSchedules.isNotEmpty) {
      final elapsedTime = flight.legSchedules[0]['elapsedTime'] ?? 0;
      return '${elapsedTime ~/ 60}h ${elapsedTime % 60}m';
    }
    return 'N/A';
  }

  String _formatTimeFromDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return DateFormat('HH:mm').format(dateTime);
    } catch (e) {
      return 'N/A';
    }
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

      debugPrint('\n=== PACKAGE SELECTED ===');
      debugPrint('Package: ${package.name}');
      debugPrint('Price: PKR ${package.price.toStringAsFixed(0)}');
      debugPrint('========================\n');

      final passengerDetails = _extractPassengerDetails(package.rawFlightData);
      final offerItem = _extractOfferItem(package.rawFlightData);
      final offerItemId = offerItem?['OfferItemID']?.toString() ?? '${package.offerId}-1';
      final owner = package.rawFlightData['Owner']?.toString() ?? 'EK';
      final responseId = _deriveResponseId(package);

      if (responseId.isEmpty) {
        throw Exception('Missing ResponseID for selected offer.');
      }

      if (offerItemId.isEmpty) {
        throw Exception('Missing OfferItemID for selected offer.');
      }

      final pricingResult = await ApiServiceEmirates().priceEmiratesOffer(
        offerId: package.offerId,
        offerItemId: offerItemId,
        owner: owner,
        responseId: responseId,
        passengerDetails: passengerDetails,
      );

      if (pricingResult['success'] != true) {
        final error = pricingResult['error'] ?? 'Failed to price offer';
        debugPrint('❌ Offer pricing failed: $error');
        Get.snackbar(
          'Error',
          error.toString(),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      final Map<String, dynamic> pricedOffer =
          Map<String, dynamic>.from(pricingResult['pricedOffer'] as Map<String, dynamic>);
      final Map<String, dynamic>? shoppingResponse =
          pricingResult['shoppingResponse'] as Map<String, dynamic>?;
      final String pricedResponseId =
          pricingResult['responseId']?.toString() ??
          _toText(shoppingResponse?['ResponseID']) ??
          responseId;

      pricedOffer['ResponseID'] = pricedResponseId;
      if (shoppingResponse != null) {
        pricedOffer['ShoppingResponseID'] = shoppingResponse;
      }
      if (pricingResult['dataLists'] != null) {
        pricedOffer['DataLists'] = pricingResult['dataLists'];
      }
      if (!pricedOffer.containsKey('Owner')) {
        pricedOffer['Owner'] = owner;
      }

      final Map<String, dynamic>? pricedOfferItem = _extractOfferItem(pricedOffer);
      final double pricedTotal =
          _parseAmount(((pricedOffer['TotalPrice'] ?? {})['DetailCurrencyPrice'] ?? {})['Total']);
      final String pricedCurrency =
          _extractCurrency(((pricedOffer['TotalPrice'] ?? {})['DetailCurrencyPrice'] ?? {})['Total']) ??
              package.currency;
      final double pricedBase = _parseAmount(
        (((pricedOfferItem?['FareDetail'] ?? {})['Price'] ?? {})['BaseAmount']),
      );
      final double pricedTaxes = _parseAmount(
        ((((pricedOfferItem?['FareDetail'] ?? {})['Price'] ?? {})['Taxes'] ?? {})['Total']),
      );

      final EmiratesFarePackage updatedPackage = EmiratesFarePackage(
        name: package.name,
        code: package.code,
        price: pricedTotal > 0 ? pricedTotal : package.price,
        basePrice: pricedBase > 0 ? pricedBase : package.basePrice,
        taxAmount: pricedTaxes >= 0 ? pricedTaxes : package.taxAmount,
        currency: pricedCurrency.isNotEmpty ? pricedCurrency : package.currency,
        isRefundable: package.isRefundable,
        cabinName: package.cabinName,
        checkedWeight: package.checkedWeight,
        checkedUnit: package.checkedUnit,
        carryOnPieces: package.carryOnPieces,
        amenities: package.amenities,
        offerId: pricedOffer['OfferID']?.toString() ?? package.offerId,
        rawFlightData: pricedOffer,
      );

      emiratesController.handlePackageSelection(
        flight,
        updatedPackage,
        isReturnFlight: isReturnFlight,
      );

      final bookingController = Get.find<FlightBookingController>();
      final tripType = bookingController.tripType.value;
      final bool isRoundTrip = tripType == TripType.roundTrip;

      Get.back(); // Close package selection

      Future.delayed(const Duration(milliseconds: 200), () {
        if (isRoundTrip && !isReturnFlight) {
          emiratesController.openReturnFlightsSelection();
        } else {
          Get.to(() => EmiratesReviewTripPage(
                outboundFlight:
                    emiratesController.selectedOutboundFlight ?? flight,
                outboundPackage:
                    emiratesController.selectedOutboundPackage ?? updatedPackage,
                returnFlight: emiratesController.selectedReturnFlight,
                returnPackage: emiratesController.selectedReturnPackage,
                isRoundTrip: isRoundTrip,
              ));
        }
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Error selecting package: $e');
      debugPrint('Stack trace: $stackTrace');
      Get.snackbar(
        'Error',
        'Failed to select package. Please try again.',
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

  Map<String, dynamic>? _extractOfferItem(Map<String, dynamic> rawData) {
    final offerItem = rawData['OfferItem'];
    if (offerItem is List) {
      return offerItem.isNotEmpty ? Map<String, dynamic>.from(offerItem.first) : null;
    }
    if (offerItem is Map<String, dynamic>) {
      return offerItem;
    }
    return null;
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

    