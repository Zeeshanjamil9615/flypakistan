// flight_package/emirates/emirates_flight_package.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:ready_flights/utility/colors.dart';
import 'package:ready_flights/views/flight/search_flights/emirates_ndc/emirates_flight_controller.dart';
import 'package:ready_flights/views/flight/search_flights/emirates_ndc/emirates_model.dart';
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
          SizedBox(
            height: 320, // Fixed height for the horizontal scrolling cards
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
 void _onSelectPackage(EmiratesFarePackage package) {
    try {
      isLoading.value = true;

      debugPrint('\n=== PACKAGE SELECTED ===');
      debugPrint('Package: ${package.name}');
      debugPrint('Price: PKR ${package.price.toStringAsFixed(0)}');
      debugPrint('========================\n');

      // Store the selected package
      emiratesController.handlePackageSelection(flight, package);

      // Navigate to review page
      Get.back(); // Close package selection
      
      // Import the review page
      Get.to(() => EmiratesReviewTripPage(
        flight: flight,
        selectedPackage: package,
        isReturn: isReturnFlight,
      ));

    } catch (e) {
      debugPrint('❌ Error selecting package: $e');
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
  }}

    