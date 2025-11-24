import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';

import '../../../../utility/colors.dart';
import '../../../../widgets/travelers_selection_bottom_sheet.dart';
import '../../booking_flight/airblue/airblue_booking_flight.dart';
import '../airarabia/airarabia_flight_model.dart';
import '../airarabia/airarabia_flight_controller.dart';
import '../airarabia/validation_data/validation_controller.dart';
import '../search_flight_utils/widgets/airarabia_flight_card.dart';

class AirArabiaReviewTripPage extends StatefulWidget {
  final AirArabiaFlight flight;
  final AirArabiaPackage selectedPackage;
  final bool isReturn;

  const AirArabiaReviewTripPage({
    super.key,
    required this.flight,
    required this.selectedPackage,
    this.isReturn = false,
  });

  @override
  AirArabiaReviewTripPageState createState() => AirArabiaReviewTripPageState();
}

class AirArabiaReviewTripPageState extends State<AirArabiaReviewTripPage> {
  List<BoxShadow> _animatedShadow = [
    BoxShadow(
      color: TColors.primary.withOpacity(0.4),
      blurRadius: 5,
      spreadRadius: 8,
      offset: const Offset(0, 0),
    ),
  ];
  late Timer _shadowTimer;

  final travelersController = Get.find<TravelersController>();
  final airArabiaController = Get.find<AirArabiaFlightController>();
  final revalidationController = Get.find<AirArabiaRevalidationController>();

  late double flightPrice;
  late double packagePrice;
  late double extrasPrice;
  late double totalPrice;
  String currency = 'PKR';

  @override
  void initState() {
    super.initState();
    _startShadowAnimation();
    _calculatePrices();
  }

  void _startShadowAnimation() {
    _shadowTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      setState(() {
        _animatedShadow =
            _animatedShadow[0].offset.dy == 2
                ? [
                  BoxShadow(
                    color: TColors.primary.withOpacity(0.4),
                    blurRadius: 2,
                    spreadRadius: 15,
                    offset: const Offset(0, 0),
                  ),
                ]
                : [
                  BoxShadow(
                    color: TColors.primary.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 2),
                  ),
                ];
      });
    });
  }

  @override
  void dispose() {
    _shadowTimer.cancel();
    super.dispose();
  }

  String _formatPrice(double price) {
    final parts = price.toStringAsFixed(0).split('.');
    final integerPart = parts[0];

    final formattedInteger = integerPart.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );

    return formattedInteger;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColors.background,
      appBar: AppBar(
        backgroundColor: TColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        title: Text(
          widget.isReturn ? 'Review Round Trip' : 'Review One Way Trip',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Flight Information Section
            const Padding(
              padding: EdgeInsets.only(left: 16.0, top: 8.0),
              child: Text(
                'Flight Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: TColors.primary,
                ),
              ),
            ),

            // Add proper flight card that shows backend data
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              child: AirArabiaFlightCard(
                flight: widget.flight,
                showReturnFlight: false,
                isShowBookButton:
                    false, // This will hide the book button and show proper layout
              ),
            ), // Flight Card - Using AirArabiaFlightCard if available, otherwise create custom

            // Selected Extras Section
            Obx(() {
              if (revalidationController.totalExtrasPrice.value > 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 16.0, top: 8.0),
                      child: Text(
                        'Selected Extras',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: TColors.primary,
                        ),
                      ),
                    ),

                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: TColors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: TColors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Selected Baggage for all passengers
                          if (revalidationController.selectedBaggage.isNotEmpty)
                            ..._buildBaggageExtras(),

                          // Selected Meals for all passengers
                          if (revalidationController.selectedMeals.isNotEmpty)
                            ..._buildMealExtras(),

                          // Selected Seats for all passengers
                          if (revalidationController.selectedSeats.isNotEmpty)
                            ..._buildSeatExtras(),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            }), // Price Breakdown Section
            const Padding(
              padding: EdgeInsets.only(left: 16.0, top: 8.0),
              child: Text(
                'Price Breakdown',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: TColors.primary,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: TColors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _animatedShadow,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildPriceRow(
                      'Base Flight Price',
                      '$currency ${_formatPrice(flightPrice)}',
                    ),
                    const SizedBox(height: 8),
                    _buildPriceRow(
                      'Package (${widget.selectedPackage.packageName})',
                      packagePrice > 0
                          ? '$currency ${_formatPrice(packagePrice)}'
                          : 'Included',
                    ),
                    Obx(() {
                      if (revalidationController.totalExtrasPrice.value > 0) {
                        return Column(
                          children: [
                            const SizedBox(height: 8),
                            _buildPriceRow(
                              'Extras',
                              '$currency ${_formatPrice(revalidationController.totalExtrasPrice.value)}',
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Obx(
                      () => _buildPriceRow(
                        'Total Amount',
                        '$currency ${_formatPrice(flightPrice + packagePrice + revalidationController.totalExtrasPrice.value)}',
                        isTotal: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isReturn ? 'Round Trip Total' : 'One Way Total',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: TColors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Obx(() {
                      final totalAmount =
                          flightPrice +
                          packagePrice +
                          revalidationController.totalExtrasPrice.value;
                      return Text(
                        '$currency ${_formatPrice(totalAmount)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: TColors.primary,
                        ),
                      );
                    }),
                  ],
                ),
                SizedBox(
                  width: 200,
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate to AirArabiaBookingFlight with all selected data
                      final totalAmount =
                          flightPrice +
                          packagePrice +
                          revalidationController.totalExtrasPrice.value;
                      final revalidationArgs =
                          revalidationController.lastRevalidationArgs;
                      if (revalidationArgs == null) {
                        Get.snackbar(
                          'Error',
                          'Unable to continue: revalidation data missing.',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.TOP,
                        );
                        return;
                      }
                      Get.to(
                        () => AirBlueBookingFlight.forAirArabia(
                          flight: widget.flight,
                          selectedPackage: widget.selectedPackage,
                          totalPrice: totalAmount,
                          currency: currency,
                          extrasData:
                              revalidationController.getBookingSummary(),
                          revalidationArgs: revalidationArgs,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TColors.primary,
                      foregroundColor: TColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(48),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Book Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPackageDetail(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: TColors.primary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, color: TColors.grey),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: TColors.text,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBaggageExtras() {
    List<Widget> baggageWidgets = [];

    revalidationController.selectedBaggage.entries.forEach((entry) {
      final passengerId = entry.key;
      final baggage = entry.value;
      final passengerIndex = revalidationController.passengerIds.indexOf(
        passengerId,
      );
      final passengerName = revalidationController.getPassengerDisplayName(
        passengerIndex,
      );

      // Only show non-default baggage (exclude "No Bag" options)
      if (!baggage.baggageCode.toLowerCase().contains('no bag') &&
          !baggage.baggageCode.toLowerCase().contains('nobag') &&
          double.parse(baggage.baggageCharge) > 0) {
        baggageWidgets.add(
          _buildExtrasItem(
            Icons.luggage,
            'Extra Baggage - $passengerName',
            baggage.baggageDescription,
            double.parse(baggage.baggageCharge),
          ),
        );
      }
    });

    return baggageWidgets;
  }

  List<Widget> _buildMealExtras() {
    List<Widget> mealWidgets = [];

    revalidationController.selectedMeals.entries.forEach((passengerEntry) {
      final passengerId = passengerEntry.key;
      final passengerMeals = passengerEntry.value;
      final passengerIndex = revalidationController.passengerIds.indexOf(
        passengerId,
      );
      final passengerName = revalidationController.getPassengerDisplayName(
        passengerIndex,
      );

      passengerMeals.entries.forEach((segmentEntry) {
        final segmentCode = segmentEntry.key;
        final meals = segmentEntry.value;

        meals.forEach((meal) {
          mealWidgets.add(
            _buildExtrasItem(
              Icons.restaurant,
              'Meal - $passengerName',
              '${meal.mealName} (${_getSegmentRoute(segmentCode)})',
              double.parse(meal.mealCharge),
            ),
          );
        });
      });
    });

    return mealWidgets;
  }

  List<Widget> _buildSeatExtras() {
    List<Widget> seatWidgets = [];

    revalidationController.selectedSeats.entries.forEach((passengerEntry) {
      final passengerId = passengerEntry.key;
      final passengerSeats = passengerEntry.value;
      final passengerIndex = revalidationController.passengerIds.indexOf(
        passengerId,
      );
      final passengerName = revalidationController.getPassengerDisplayName(
        passengerIndex,
      );

      passengerSeats.entries.forEach((segmentEntry) {
        final segmentCode = segmentEntry.key;
        final seat = segmentEntry.value;

        if (seat.seatNumber.isNotEmpty && seat.seatCharge > 0) {
          seatWidgets.add(
            _buildExtrasItem(
              Icons.airline_seat_recline_normal,
              'Seat ${seat.seatNumber} - $passengerName',
              'Premium seat selection (${_getSegmentRoute(segmentCode)})',
              seat.seatCharge,
            ),
          );
        }
      });
    });

    return seatWidgets;
  }

  String _getSegmentRoute(String segmentCode) {
    try {
      final segments = revalidationController.getFlightSegments();
      final segment = segments.firstWhere(
        (s) => s.attributes['SegmentCode']?.toString() == segmentCode,
        orElse: () => segments.first,
      );

      final departure = segment.departureAirport['LocationCode'] ?? '';
      final arrival = segment.arrivalAirport['LocationCode'] ?? '';
      return '$departure → $arrival';
    } catch (e) {
      return segmentCode;
    }
  }

  // Also update your _calculatePrices method to use the observable value:
  // Update _calculatePrices method:
  void _calculatePrices() {
    // Get prices from controller
    flightPrice = revalidationController.flightPrice.value;
    packagePrice = revalidationController.packagePrice.value;

    // Currency from flight or controller
    currency = widget.flight.currency;

    // Note: extras price is already reactive via revalidationController.totalExtrasPrice
  }

  Widget _buildExtrasItem(
    IconData icon,
    String title,
    String subtitle,
    double price,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: TColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: TColors.primary,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: TColors.grey),
                  ),
              ],
            ),
          ),
          Text(
            '$currency ${_formatPrice(price)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: TColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? TColors.primary : TColors.grey,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: isTotal ? TColors.primary : TColors.text,
          ),
        ),
      ],
    );
  }

  Color _getPackageColor(String packageType) {
    switch (packageType.toLowerCase()) {
      case 'basic':
        return TColors.primary;
      case 'value':
        return Colors.blue;
      case 'ultimate':
        return Colors.purple;
      default:
        return TColors.primary;
    }
  }

  String _formatDateTime(String dateTime) {
    try {
      final dt = DateTime.parse(dateTime);
      return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime;
    }
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }
}
