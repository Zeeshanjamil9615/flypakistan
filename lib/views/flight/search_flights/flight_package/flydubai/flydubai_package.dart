// ignore_for_file: dead_code, empty_catches

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../services/api_service_sabre.dart';
import '../../../../../utility/colors.dart';
import '../../../form/flight_booking_controller.dart';
import '../../flydubai/flydubai_controller.dart';
import 'package:ready_flights/views/flight/search_flights/flydubai/flydubai_model.dart';

import '../../flydubai/flydubai_extras.dart';
import '../../flydubai/flydubai_extras_controller.dart';
import '../../flydubai/flydubai_return_flight.dart';
import '../../search_flight_utils/widgets/flydubai_flight_card.dart';
import '../../../booking_flight/airblue/airblue_booking_flight.dart';
class FlyDubaiPackageSelectionDialog extends StatelessWidget {
  final FlydubaiFlight flight;
  final bool isReturnFlight;
  final bool isMultiCity;
  final int? segmentIndex;
  final RxBool isLoading = false.obs;

  // Cache for margin data and calculated prices
  final Rx<Map<String, dynamic>> marginData = Rx<Map<String, dynamic>>({});
  final Map<String, RxDouble> finalPrices = {};

  FlyDubaiPackageSelectionDialog({
    super.key,
    required this.flight,
    required this.isReturnFlight,
    this.isMultiCity = false,
    this.segmentIndex,
  });

  final flyDubaiController = Get.find<FlydubaiFlightController>();
  final bookingController = Get.find<FlightBookingController>();
  late final FlightBookingController flightBookingController;

  @override
  Widget build(BuildContext context) {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🏗️ FlyDubaiPackageSelectionDialog.build()');
    print('  isMultiCity: $isMultiCity');
    print('  segmentIndex: $segmentIndex');
    print('  Flight LFID: ${flight.flightSegment.lfid}');
    print('  Flight RPH: ${flight.rph}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    // Pre-fetch margin data when dialog opens
    _prefetchMarginData();
    flightBookingController = Get.find<FlightBookingController>();

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

  Widget _buildFlightInfo() {
    return FlyDubaiFlightCard(flight: flight, showReturnFlight: false);
  }

  Future<void> _prefetchMarginData() async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('💰 _prefetchMarginData called');
      print('  isMultiCity: $isMultiCity');
      print('  segmentIndex: $segmentIndex');
      print('  Flight LFID: ${flight.flightSegment.lfid}');
      
      if (marginData.value.isEmpty) {
        final apiService = Get.find<ApiServiceSabre>();
        marginData.value = await apiService.getMargin(flight.airlineCode, flight.airlineName);
      }

      // Pre-calculate prices for all fare options
      final fareOptions = flyDubaiController.getFareOptionsForFlight(
        flight,
        segmentIndex: isMultiCity ? segmentIndex : null,
      );
      
      print('  Fare options in prefetch: ${fareOptions.length}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      for (var option in fareOptions) {
        final String packageKey = '${option.cabin}-${option.fareTypeName}';

        if (!finalPrices.containsKey(packageKey)) {
          final apiService = Get.find<ApiServiceSabre>();

          final marginedBasePrice = apiService.calculatePriceWithMargin(
            option.baseFareAmountIncludingTax,
            marginData.value,
          );

          final totalPrice = marginedBasePrice;

          finalPrices[packageKey] = totalPrice.obs;
        }
      }
    } catch (e) {
      print('DEBUG: Error in _prefetchMarginData: $e');
    }
  }

  Widget _buildPackagesList() {
    // Get fare options for the selected flight
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📦 _buildPackagesList called');
    print('  isMultiCity: $isMultiCity');
    print('  segmentIndex: $segmentIndex');
    print('  Flight LFID: ${flight.flightSegment.lfid}');
    print('  Flight RPH: ${flight.rph}');
    
    final List<FlydubaiFlightFare> fareOptions = flyDubaiController.getFareOptionsForFlight(
      flight,
      segmentIndex: isMultiCity ? segmentIndex : null,
    );
    
    print('  Fare options retrieved: ${fareOptions.length}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Handle empty state
    if (fareOptions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, size: 48, color: Colors.amber),
            SizedBox(height: 16),
            Text(
              'No packages available for this flight',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              'Please select another flight',
              style: TextStyle(fontSize: 14, color: Colors.grey),
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
      itemCount: fareOptions.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildHorizontalPackageCard(fareOptions[index], flight, index),
        );
      },
    );
  }

  Widget _buildHorizontalPackageCard(FlydubaiFlightFare package, FlydubaiFlight flight, int index) {
    final isSoldOut = package.seatsAvailable <= 0;
    final price = finalPrices['${package.cabin}-${package.fareTypeName}']?.value ??
        package.baseFareAmountIncludingTax;

    // Determine if this is the cheapest option
    final List<FlydubaiFlightFare> allOptions = flyDubaiController.getFareOptionsForFlight(
      flight,
      segmentIndex: isMultiCity ? segmentIndex : null,
    );
    final sortedOptions = List<FlydubaiFlightFare>.from(allOptions);
    sortedOptions.sort((a, b) => (finalPrices['${a.cabin}-${a.fareTypeName}']?.value ?? a.baseFareAmountIncludingTax).compareTo(finalPrices['${b.cabin}-${b.fareTypeName}']?.value ?? b.baseFareAmountIncludingTax));
    final isCheapest = sortedOptions.isNotEmpty && package == sortedOptions.first;

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
                  package.fareTypeName,
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
                      'Hand Baggage',
                      '7 KG',
                    ),
                    const SizedBox(height: 12),
                    _buildCompactPackageDetail(
                      Icons.luggage,
                      'Checked Baggage',
                      getBaggageInfo(package.fareTypeName),
                    ),
                    const SizedBox(height: 12),
                    _buildCompactPackageDetail(
                      Icons.restaurant_rounded,
                      'Meal',
                      _getMealInfo(package.fareTypeName),
                    ),
                    const SizedBox(height: 12),
                    _buildCompactPackageDetail(
                      Icons.airline_seat_recline_normal,
                      'Cabin',
                      getCabinDisplayName(package.cabin),
                    ),
                    const SizedBox(height: 12),
                    _buildCompactPackageDetail(
                      Icons.event_seat,
                      'Seat Selection',
                      _getSeatSelectionInfo(package.fareTypeName),
                    ),
                    const SizedBox(height: 12),
                    _buildCompactPackageDetail(
                      Icons.swap_horiz_rounded,
                      'Change Fee',
                      _getChangeFeeDisplay(package.fareTypeName),
                    ),
                    const SizedBox(height: 12),
                    _buildCompactPackageDetail(
                      Icons.money_off_rounded,
                      'Refund Fee',
                      _getRefundFeeDisplay(package.fareTypeName),
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
                    onPressed: isSoldOut || isLoading.value
                        ? null
                        : () => onSelectPackage(index),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSoldOut ? Colors.grey : TColors.primary,
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
                      '${package.currency} ${price.toStringAsFixed(0)}',
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
              top: -8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
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

  String _getButtonText() {
    if (isReturnFlight) {
      return 'Complete Selection';
    } else {
      return 'Select Package';
    }
  }

  String getBaggageInfo(String fareTypeName) {
    final type = fareTypeName.toLowerCase();

    if (type.contains('lite')) {
      return '0 KG';
    }

    if (type.contains('value')) {
      return '20 KG';
    }

    if (type.contains('flex')) {
      return '30 KG';
    }

    if (type.contains('economy')) {
      return '30 KG';
    }

    if (type.contains('business')) {
      return '40 KG';
    }

    // Default
    return '20 KG';
  }


  String getCabinDisplayName(String cabin) {
    switch (cabin.toUpperCase()) {
      case 'ECONOMY':
        return 'Economy';
      case 'BUSINESS':
        return 'Business';
      default:
        return 'Economy';
    }
  }

  String _getMealInfo(String fareTypeName) {
    switch (fareTypeName.toUpperCase()) {
      case 'LITE':
        return 'Purchase onboard';
      case 'VALUE':
        return 'Included';
      case 'FLEX':
        return 'Premium meal';
      case 'BUSINESS':
        return 'Gourmet dining';
      default:
        return 'Included';
    }
  }

  String _getSeatSelectionInfo(String fareTypeName) {
    switch (fareTypeName.toUpperCase()) {
      case 'LITE':
        return 'Fee applies';
      case 'VALUE':
        return 'Standard seats free';
      case 'FLEX':
        return 'Premium seats free';
      case 'BUSINESS':
        return 'All seats included';
      default:
        return 'Standard selection';
    }
  }

  String _getChangeFeeDisplay(String fareTypeName) {
    switch (fareTypeName.toUpperCase()) {
      case 'LITE':
        return 'Not permitted';
      case 'VALUE':
        return 'AED 150';
      case 'FLEX':
        return 'Free (>12h)';
      case 'BUSINESS':
        return 'Free (>12h)';
      default:
        return 'Fee applies';
    }
  }

  String _getRefundFeeDisplay(String fareTypeName) {
    switch (fareTypeName.toUpperCase()) {
      case 'LITE':
        return 'Non-refundable';
      case 'VALUE':
        return 'AED 200';
      case 'FLEX':
        return 'Free (>24h)';
      case 'BUSINESS':
        return 'Free (>24h)';
      default:
        return 'Fee applies';
    }
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

  Widget _buildPackageDetail(IconData icon, String title, String value,
      {List<Map<String, dynamic>>? details, bool showInfoIcon = false}) {
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: TColors.text,
                        ),
                      ),
                    ),
                    if (showInfoIcon && details != null && details.isNotEmpty)
                      GestureDetector(
                        onTap: () => _showFeeDetailsDialog(title, details),
                        child: const Icon(
                          Icons.help_outline,
                          size: 18,
                          color: TColors.primary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Update the onSelectPackage method in FlyDubaiPackageSelectionDialog
  void onSelectPackage(int selectedPackageIndex) async {
    try {
      isLoading.value = true;

      print('═══════════════════════════════════════════════════════');
      print('📦 PACKAGE SELECTION STARTED');
      print('═══════════════════════════════════════════════════════');
      print('Flight: ${flight.airlineCode} ${flight.flightSegment.flightNumber}');
      print('LFID: ${flight.flightSegment.lfid}');
      print('Is Return Flight: $isReturnFlight');
      print('Selected Package Index: $selectedPackageIndex');

      // Get all fare options for this flight
      final List<FlydubaiFlightFare> fareOptions =
      flyDubaiController.getFareOptionsForFlight(
        flight,
        segmentIndex: isMultiCity ? segmentIndex : null,
      );

      print('Available Fare Options: ${fareOptions.length}');
      for (int i = 0; i < fareOptions.length; i++) {
        print('  [$i] ${fareOptions[i].fareTypeName} (FareID: ${fareOptions[i].fareId}, TypeID: ${fareOptions[i].fareTypeId})');
      }

      // Get the selected fare option
      final selectedFareOption = fareOptions[selectedPackageIndex];
      
      print('✅ Selected Fare: ${selectedFareOption.fareTypeName}');
      print('   - Fare ID: ${selectedFareOption.fareId}');
      print('   - Fare Type ID: ${selectedFareOption.fareTypeId}');
      print('   - Price: ${selectedFareOption.baseFareAmountIncludingTax}');
      print('   - Booking Code: ${selectedFareOption.bookingCode}');

      // For round trips, skip revalidation for the return flight
      // We'll add both flights to cart together later
      final tripType = flightBookingController.tripType.value;
      final shouldRevalidate = !(isReturnFlight && tripType == TripType.roundTrip);
      
      if (shouldRevalidate) {
        print('🔄 Revalidating ${isReturnFlight ? "return" : "outbound"} flight...');
        
        // Revalidate flight pricing before proceeding
        final revalidationSuccess = await flyDubaiController.revalidateFlightBeforeReview(
          flight: flight,
          selectedFare: selectedFareOption,
          isReturnFlight: isReturnFlight,
        );

        if (!revalidationSuccess) {
          Get.snackbar(
            'Price Update Required',
            'Flight prices have changed. Please review the updated pricing.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );

          // Refresh the package list to show updated prices
          await _prefetchMarginData();
          isLoading.value = false;
          return;
        }
      } else {
        print('⏭️ Skipping revalidation for return flight (will add both to cart together)');
      }

      // Handle multi-city selection
      if (isMultiCity && segmentIndex != null) {
        Get.back(); // Close the package selection dialog
        
        // Store multi-city selection
        flyDubaiController.handleMultiCityPackageSelection(
          selectedFareOption,
          segmentIndex!,
        );
        
        return;
      }

      // Check if this is a one-way flight or we need to select a return flight
      if (tripType == TripType.oneWay || isReturnFlight) {
        // For one-way trip or if this is already the return flight selection
        Get.back(); // Close the package selection dialog

        // Store the selected flight and package
        if (isReturnFlight) {
          flyDubaiController.selectedReturnFlight = flight;
          flyDubaiController.selectedReturnFareOption = selectedFareOption;
        } else {
          flyDubaiController.selectedOutboundFlight = flight;
          flyDubaiController.selectedOutboundFareOption = selectedFareOption;
        }

        // Navigate to review page
        Get.snackbar(
          'Success',
          isReturnFlight
              ? 'Return flight package selected. Proceeding to booking details.'
              : 'Flight package selected. Proceeding to booking details.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );

        // For round trips, we need to add BOTH flights to cart together
        // before navigating to booking form (so the server has both in the session)
        if (isReturnFlight && flyDubaiController.selectedOutboundFlight != null) {
          print('🛒 Adding both flights to cart for round trip...');
          
          // Add both outbound and return flights to cart together
          final cartResult = await flyDubaiController.addFlightsToCart();
          
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
          
          print('✅ Both flights added to cart successfully');
        }
        
        // Calculate total price
        final outboundPrice = finalPrices['${selectedFareOption.cabin}-${selectedFareOption.fareTypeName}']?.value ??
            selectedFareOption.baseFareAmountIncludingTax;
        double totalPrice = outboundPrice;
        FlydubaiFlightFare? returnFare;
        
        if (isReturnFlight && flyDubaiController.selectedReturnFareOption != null) {
          returnFare = flyDubaiController.selectedReturnFareOption;
          final returnPriceKey = '${returnFare!.cabin}-${returnFare.fareTypeName}';
          final returnPrice = finalPrices[returnPriceKey]?.value ??
              returnFare.baseFareAmountIncludingTax;
          totalPrice += returnPrice;
        }
        
        // Navigate directly to unified booking form (skip review screen)
        Get.to(
          () => AirBlueBookingFlight.forFlyDubai(
            flight: isReturnFlight && flyDubaiController.selectedOutboundFlight != null
                ? flyDubaiController.selectedOutboundFlight!
                : flight,
            returnFlight: isReturnFlight ? flight : null,
            outboundFare: isReturnFlight && flyDubaiController.selectedOutboundFareOption != null
                ? flyDubaiController.selectedOutboundFareOption!
                : selectedFareOption,
            returnFare: returnFare,
            totalPrice: totalPrice,
            currency: flight.currency,
            cartData: flyDubaiController.cartData,
          ),
        );
      } else {
        // For round trip, show return flights after selecting outbound package
        Get.back(); // Close the package selection dialog

        // Store the selected outbound flight and package
        flyDubaiController.selectedOutboundFlight = flight;
        flyDubaiController.selectedOutboundFareOption = selectedFareOption;

        // Show success message
        Get.snackbar(
          'Outbound Selected',
          'Outbound flight package selected. Now select your return flight.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );

        // Show return flights
        _showReturnFlights();
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'This flight package is no longer available. Please select another option.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isLoading.value = false;
    }
  }
  // Helper method to create a flight with combined rawData for round trips
  FlydubaiFlight _createCombinedFlight(FlydubaiFlight outbound, FlydubaiFlight returnFlight) {
    print('🔗 Creating combined flight data for round trip');
    print('Outbound LFID: ${outbound.flightSegment.lfid}');
    print('Return LFID: ${returnFlight.flightSegment.lfid}');
    
    // Merge the rawData to include both segments
    final combinedRawData = Map<String, dynamic>.from(returnFlight.rawData);
    
    // The rawData should already contain both segments from the original search
    // But let's ensure both are present by checking and logging
    try {
      final retrieveResult = combinedRawData['RetrieveFareQuoteDateRangeResponse']?['RetrieveFareQuoteDateRangeResult'];
      if (retrieveResult != null) {
        final segmentDetails = retrieveResult['SegmentDetails']?['SegmentDetail'];
        if (segmentDetails is List) {
          print('✅ Combined rawData has ${segmentDetails.length} segments');
          for (var seg in segmentDetails) {
            if (seg is Map) {
              print('   - LFID: ${seg['LFID']}, ${seg['Origin']}->${seg['Destination']}');
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ Error checking combined rawData: $e');
    }
    
    // Return the return flight but with confirmed combined rawData
    return returnFlight;
  }
  
  void _showReturnFlights() {
    final returnFlights = flyDubaiController.getReturnFlights();

    if (returnFlights.isEmpty) {
      Get.snackbar(
        'No Return Flights',
        'No return flights found for your search criteria.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Navigate to return flights page
    Get.to(
          () => FlyDubaiReturnFlightsPage(returnFlights: returnFlights),
      transition: Transition.rightToLeft,
    );
  }

  void _showFeeDetailsDialog(String title, List<Map<String, dynamic>> details) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: TColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: TColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      title.toLowerCase().contains('change')
                          ? Icons.swap_horiz_rounded
                          : Icons.money_off_rounded,
                      color: TColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: TColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Fee details list
              Container(
                constraints: const BoxConstraints(maxHeight: 250),
                child: SingleChildScrollView(
                  child: Column(
                    children: details.map((detail) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: TColors.background3.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: TColors.primary.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Time icon and condition
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: TColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.access_time_rounded,
                                      color: TColors.primary,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _formatConditionText(detail['condition'] ?? ''),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: TColors.text,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Amount
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: TColors.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                detail['amount'] ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: TColors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TColors.primary,
                    foregroundColor: TColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  String _formatConditionText(String condition) {
    switch (condition.toLowerCase()) {
      case 'any time':
        return 'Any time before departure';
      case '>24h':
        return 'More than 24 hours before';
      case '<24h':
        return 'Within 24 hours';
      case '>12h':
        return 'More than 12 hours before';
      case '<12h':
        return 'Within 12 hours';
      case '<0':
        return 'Time is <0 hour(s)';
      case '<48':
        return 'Time is <48 hour(s)';
      case '>48':
        return 'Time is >48 hour(s)';
      default:
        if (condition.contains('>')) {
          final hours = condition.replaceAll('>', '').trim();
          return 'More than $hours hours before';
        } else if (condition.contains('<')) {
          final hours = condition.replaceAll('<', '').trim();
          return 'Within $hours hours';
        }
        return condition;
    }
  }


}