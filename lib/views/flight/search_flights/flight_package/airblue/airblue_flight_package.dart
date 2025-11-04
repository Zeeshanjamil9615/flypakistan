// Updated airblue_flight_package.dart with proper multi-city support

// ignore_for_file: dead_code, empty_catches

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../services/api_service_sabre.dart';
import '../../../../../utility/colors.dart';
import '../../../form/flight_booking_controller.dart';
import '../../airblue/airblue_flight_model.dart';
import '../../airblue/airblue_return_flight_page.dart';
import '../../review_flight/airblue_review_flight.dart';
import '../../airblue/airblue_flight_controller.dart';
import '../../search_flight_utils/widgets/airblue_flight_card.dart';

class AirBluePackageSelectionDialog extends StatelessWidget {
  final AirBlueFlight flight;
  final bool isReturnFlight;
  final RxBool isLoading = false.obs;
  final int segmentIndex; // Which segment of the trip this is
  final bool isMultiCity;

  // Cache for margin data and calculated prices
  final Rx<Map<String, dynamic>> marginData = Rx<Map<String, dynamic>>({});
  final Map<String, RxDouble> finalPrices = {};

  AirBluePackageSelectionDialog({
    super.key,
    required this.flight,
    required this.isReturnFlight,
    required this.segmentIndex,
    required this.isMultiCity,
  });

  final PageController _pageController = PageController(viewportFraction: 0.9);
  final airBlueController = Get.find<AirBlueFlightController>();
  late final FlightBookingController flightBookingController;

  @override
  Widget build(BuildContext context) {
    // Pre-fetch margin data when dialog opens
    _prefetchMarginData();
    flightBookingController = Get.find<FlightBookingController>();

    print("mulicity confition:");
    print(isMultiCity);

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
          SizedBox(height: 12,),
          Expanded(
            child: _buildPackagesList(),
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    if (isMultiCity) {
      final bookingController = Get.find<FlightBookingController>();
      if (segmentIndex < bookingController.cityPairs.length) {
        final cityPair = bookingController.cityPairs[segmentIndex];
        return 'Select: ${cityPair.fromCity.value} → ${cityPair.toCity.value}';
      }
      return 'Select Flight for Segment ${segmentIndex + 1}';
    } else if (isReturnFlight) {
      return 'Select Return Flight ';
    } else {
      return 'Select Flight ';
    }
  }

  Widget _buildFlightInfo() {
    return AirBlueFlightCard(flight: flight, showReturnFlight: false, isShowBookButton: false,);
  }

  Future<void> _prefetchMarginData() async {
    try {
      if (marginData.value.isEmpty) {
        final apiService = Get.find<ApiServiceSabre>();
        marginData.value = await apiService.getMargin(flight.airlineCode, flight.airlineName);
      }

      // Get fare options using the controller method
      final fareOptions = airBlueController.getFareOptionsForFlight(
          flight,
          segmentIndex: segmentIndex
      );

      print('DEBUG: Found ${fareOptions.length} fare options for flight ${flight.rph}');

      for (var option in fareOptions) {
        final String packageKey = '${option.cabinCode}-${option.brandName}';

        if (!finalPrices.containsKey(packageKey)) {
          final apiService = Get.find<ApiServiceSabre>();
          final marginedBasePrice = apiService.calculatePriceWithMargin(
            option.basePrice,
            marginData.value,
          );
          final totalPrice = marginedBasePrice + option.taxAmount + option.feeAmount;
          finalPrices[packageKey] = totalPrice.obs;
        }
      }
    } catch (e) {
      print('DEBUG: Error in _prefetchMarginData: $e');
    }
  }

  String getMealInfo(String mealCode) {
    switch (mealCode.toUpperCase()) {
      case 'P':
        return 'Alcoholic beverages for purchase';
      case 'C':
        return 'Complimentary alcoholic beverages';
      case 'B':
        return 'Breakfast';
      case 'K':
        return 'Continental breakfast';
      case 'D':
        return 'Dinner';
      case 'F':
        return 'Food for purchase';
      case 'G':
        return 'Food/Beverages for purchase';
      case 'M':
        return 'Meal';
      case 'N':
        return 'No meal service';
      case 'R':
        return 'Complimentary refreshments';
      case 'V':
        return 'Refreshments for purchase';
      case 'S':
        return 'Snack';
      default:
        return 'No Meal';
    }
  }

  Widget _buildPackagesList() {
    // Get fare options for the selected flight based on RPH
    final List<AirBlueFareOption> fareOptions = airBlueController.getFareOptionsForFlight(
        flight,
        segmentIndex: segmentIndex
    );

    print('DEBUG: Getting packages for segment $segmentIndex');
    print('DEBUG: Flight RPH: ${flight.rph}');
    print('DEBUG: Expected fare key: segment_${segmentIndex}_${flight.rph}');

    // Handle empty state
    if (fareOptions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, size: 48, color: Colors.amber),
            SizedBox(height: 16),
            Text(
              'No flights available for this flight',
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


  Widget _buildHorizontalPackageCard(AirBlueFareOption package, AirBlueFlight flight, int index) {
    final isSoldOut = false;
    final price = finalPrices['${package.cabinCode}-${package.fareName}']?.value ?? package.price;
    
    // Determine if this is the cheapest option
    final List<AirBlueFareOption> allOptions = airBlueController.getFareOptionsForFlight(flight, segmentIndex: segmentIndex);
    final sortedOptions = List<AirBlueFareOption>.from(allOptions);
    sortedOptions.sort((a, b) => (finalPrices['${a.cabinCode}-${a.fareName}']?.value ?? a.price).compareTo(finalPrices['${b.cabinCode}-${b.fareName}']?.value ?? b.price));
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
                  package.fareName,
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
                      'Carry-on Baggage',
                      '6kg 1 Piece',
                    ),
                    const SizedBox(height: 12),
                    _buildCompactPackageDetail(
                      Icons.luggage,
                      'Check-in Baggage',
                      package.baggageAllowance,
                    ),
                    const SizedBox(height: 12),
                    _buildCompactPackageDetail(
                      Icons.airline_seat_recline_normal,
                      'Seat Selection',
                      'Additional Cost',
                    ),
                    const SizedBox(height: 12),
                    _buildCompactPackageDetail(
                      Icons.restaurant_rounded,
                      'Meal',
                      'Additional Cost',
                    ),
                    const SizedBox(height: 12),
                    _buildCompactPackageDetail(
                      Icons.flight_takeoff,
                      'Cancellation',
                      'From PKR${(price * 0.4).toStringAsFixed(0)}',
                      isPrice: true,
                    ),
                    const SizedBox(height: 12),
                    _buildCompactPackageDetail(
                      Icons.edit_rounded,
                      'Change',
                      'From PKR${(price * 0.34).toStringAsFixed(0)}',
                      isPrice: true,
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
                      'PKR ${price.toStringAsFixed(0)}',
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

  Widget _buildVerticalPackageCard(AirBlueFareOption package, AirBlueFlight flight, int index) {
    final headerColor = TColors.primary;
    final isSoldOut = false;
    final price = finalPrices['${package.cabinCode}-${package.fareName}']?.value ?? package.price;

    return Container(
      decoration: BoxDecoration(
        color: TColors.white,
        borderRadius: BorderRadius.circular(16), // smaller radius
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12, // reduced
            offset: const Offset(0, 4), // reduced
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // reduced
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  headerColor,
                  headerColor.withOpacity(0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        package.fareName,
                        style: const TextStyle(
                          fontSize: 16, // reduced
                          fontWeight: FontWeight.bold,
                          color: TColors.white,
                        ),
                      ),

                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // reduced
                  decoration: BoxDecoration(
                    color: TColors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: TColors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${package.currency} ${price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: TColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Package details
          Padding(
            padding: const EdgeInsets.all(14), // reduced
            child: Column(
              children: [
                // First row
                _buildPackageDetail(
                  Icons.work_outline_rounded,
                  'Hand Baggage',
                  '7 KG',

                ),
                const SizedBox(height: 12), // reduced
                _buildPackageDetail(
                  Icons.luggage,
                  'Checked Baggage',
                  package.baggageAllowance,

                ),

                const SizedBox(height: 12),

                // Second row
                _buildPackageDetail(
                  Icons.restaurant_rounded,
                  'Meal',
                  'Included',

                ),
                const SizedBox(height: 12),
                _buildPackageDetail(
                  Icons.airline_seat_recline_normal,
                  'Cabin',
                  // package.cabinCode,
                  "Economy",

                ),

                const SizedBox(height: 12),

                // Third row
                _buildPackageDetail(
                  Icons.swap_horiz_rounded,
                  'Change Fee',
                  package.changeFee,

                  details: flight.changeFeeDetails,
                ),
                const SizedBox(height: 12),
                _buildPackageDetail(
                  Icons.money_off_rounded,
                  'Refund Fee',
                  package.refundFee,

                  details: flight.refundFeeDetails,
                ),

                const SizedBox(height: 16),

                // Button
                Obx(() => SizedBox(
                  width: double.infinity,
                  height: 44, // reduced button height
                  child: ElevatedButton(
                    onPressed: isSoldOut || isLoading.value
                        ? null
                        : () => onSelectPackage(index),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSoldOut ? Colors.grey : TColors.primary,
                      foregroundColor: TColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getButtonText(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactPackageDetail(
      IconData icon,
      String title,
      String value, {
        bool isPrice = false,
      }) {
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
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isPrice ? TColors.primary : TColors.text,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactDetail(
      IconData icon,
      String title,
      String value,
      Color iconColor, {
        List<Map<String, dynamic>>? details,
      }) {
    final bool hasDetails = details != null && details.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(10), // reduced
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: iconColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4), // reduced
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: iconColor, size: 14), // smaller icon
              ),
              const Spacer(),
              if (hasDetails)
                GestureDetector(
                  onTap: () => _showFeeDetailsDialog(title, details!),
                  child: Icon(Icons.info_outline_rounded,
                      size: 14, color: iconColor),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: TColors.text.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: TColors.text,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _getButtonText() {
    if (isMultiCity) {
      final bookingController = Get.find<FlightBookingController>();
      final isLastSegment = segmentIndex == bookingController.cityPairs.length - 1;
      return isLastSegment ? 'Complete Selection' : 'Next Segment';
    } else if (isReturnFlight) {
      return 'Select Return Flight';
    } else {
      return 'Select';
    }
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

  // ALSO FIX: In onSelectPackage method
  void onSelectPackage(int selectedPackageIndex) async {
    try {

      isLoading.value = true;

      print('DEBUG: onSelectPackage called - isReturnFlight: $isReturnFlight, segmentIndex: $segmentIndex');

      // FIXED: Get fare options with correct segment index
      final List<AirBlueFareOption> fareOptions = airBlueController.getFareOptionsForFlight(
        flight,
        segmentIndex: segmentIndex,  // Pass the segment index here too
      );

      // Get the selected fare option
      final selectedFareOption = fareOptions[selectedPackageIndex];
      print("check abc 1");
      print(isReturnFlight);
      // Check trip type
      final tripType = flightBookingController.tripType.value;

      if (isMultiCity) {
        // Handle multi-city selection
        _handleMultiCitySelection(selectedFareOption);
      } else if (tripType == TripType.oneWay || isReturnFlight) {
        print("check abc 1");
        // For one-way trip or if this is already the return flight selection
        _handleOneWayOrReturnSelection(selectedFareOption);
      } else {

        // For round trip (only 2 segments: outbound and return)
        _handleRoundTripSelection(selectedFareOption);
      }
    } catch (e) {
      print('DEBUG: Error in onSelectPackage: $e');
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
  // FIXED: Method in airblue_flight_package.dart

// NEW: Dedicated method to handle multi-city selections
  void _handleMultiCitySelection(AirBlueFareOption selectedFareOption) {
    final bookingController = Get.find<FlightBookingController>();

    print('DEBUG: _handleMultiCitySelection for segment $segmentIndex');
    print('DEBUG: Total segments: ${bookingController.cityPairs.length}');

    // FIXED: Store the selection for this segment using the controller method
    airBlueController.handleMultiCityPackageSelection(
        selectedFareOption,
        segmentIndex
    );

    // Get.back(); // Close the package selection dialog

    // The rest of the logic is now handled in the controller
    // No need to duplicate the logic here
  }
  // NEW: Dedicated method to handle one-way or return flight selections
  void _handleOneWayOrReturnSelection(AirBlueFareOption selectedFareOption) {

    // Store the selected flight and package
    if (isReturnFlight) {
      airBlueController.selectedReturnFareOption = selectedFareOption;
    } else {
      airBlueController.selectedOutboundFareOption = selectedFareOption;
    }
    Get.back(); // Close the package selection dialog

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

    // FIXED: Use a small delay to ensure the dialog is fully closed before navigation
    Future.delayed(Duration(milliseconds: 300), () {
      Get.to(() => AirBlueReviewTripPage(
        flight: flight,
        isReturn: isReturnFlight,
      ));
    });
  }

  // NEW: Dedicated method to handle round trip selections
  void _handleRoundTripSelection(AirBlueFareOption selectedFareOption) {

    print('DEBUG: Return flight selected - ${flight.legSchedules.first['departure']['airport']} -> ${flight.legSchedules.last['arrival']['airport']}');


    Get.back(); // Close the package selection dialog

    // Store the selected outbound flight and package
    airBlueController.selectedOutboundFlight = flight;
    airBlueController.selectedOutboundFareOption = selectedFareOption;

    // Show return flights
    _showReturnFlights();
  }

  // NEW: Method to proceed to multi-city review
  void _proceedToMultiCityReview() {
    // You can create a dedicated multi-city review page or
    // modify the existing review page to handle multi-city
    Get.snackbar(
      'Multi-City Review',
      'This will navigate to multi-city review page',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
    );

    // TODO: Navigate to multi-city review page
    Get.to(() => AirBlueReviewTripPage(
      flight: airBlueController.selectedMultiCityFlights.where((f) => f != null).cast<AirBlueFlight>().toList().first,
      multicityFlights: airBlueController.selectedMultiCityFlights.where((f) => f != null).cast<AirBlueFlight>().toList(),
      isMulticity: true,
      multicityFareOptions: airBlueController.selectedMultiCityFareOptions,
    ));
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

  // Helper function to format condition text in a user-friendly way
  String _formatConditionText(String condition) {
    switch (condition.toLowerCase()) {
      case '<0':
        return 'Time is <0 hour(s)';
      case '<48':
        return 'Time is <48 hour(s)';
      case '>48':
        return 'Time is >48 hour(s)';
      default:
        if (condition.contains('<')) {
          final hours = condition.replaceAll('<', '').trim();
          return 'Time is <$hours hour(s)';
        } else if (condition.contains('>')) {
          final hours = condition.replaceAll('>', '').trim();
          return 'Time is >$hours hour(s)';
        }
        return condition;
    }
  }

  void _showReturnFlights() {
    final returnFlights = airBlueController.getReturnFlights();

    if (returnFlights.isEmpty) {
      Get.snackbar(
        'No Return Flights',
        'No suitable return flights were found.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );

      // Debug information
      final bookingController = Get.find<FlightBookingController>();
      print('DEBUG: No return flights found for trip type: ${bookingController.tripType.value}');
      print('DEBUG: Available segments: ${airBlueController.flightsBySegment.keys.toList()}');
      print('DEBUG: Available fare keys: ${airBlueController.fareOptionsByRPH.keys.toList()}');
      return;
    }

    // Navigate to a new screen showing return flights
    Get.to(
          () => AirblueReturnFlightsPage(returnFlights: returnFlights),
      transition: Transition.rightToLeft,
    );
  }
}