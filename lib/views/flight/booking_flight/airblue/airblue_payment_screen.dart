import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../../utility/app_constants.dart';
import '../../../../../utility/colors.dart';
import '../../../../widgets/travelers_selection_bottom_sheet.dart';
import '../../search_flights/airblue/airblue_flight_model.dart';
import '../booking_flight_controller.dart';
import 'flight_print_voucher.dart';
import 'card_payment_details_screen.dart';

class AirBluePaymentScreen extends StatefulWidget {
  final Map<String, dynamic> pnrResponse;
  final int totalPassengers;
  final AirBlueFlight outboundFlight;
  final AirBlueFlight? returnFlight;
  final List<AirBlueFlight>? multicityFlights;
  final AirBlueFareOption? outboundFareOption;
  final AirBlueFareOption? returnFareOption;
  final List<AirBlueFareOption?>? multicityFareOptions;
  final BookingFlightController bookingController;
  final TravelersController travelersController;
  final double totalPrice;
  final String currency;
  final int initialSecondsLeft;
  final Map<int, String>? selectedSeats;

  const AirBluePaymentScreen({
    super.key,
    required this.pnrResponse,
    required this.totalPassengers,
    required this.outboundFlight,
    this.returnFlight,
    this.multicityFlights,
    this.outboundFareOption,
    this.returnFareOption,
    this.multicityFareOptions,
    required this.bookingController,
    required this.travelersController,
    required this.totalPrice,
    required this.currency,
    required this.initialSecondsLeft,
    this.selectedSeats,
  });

  @override
  State<AirBluePaymentScreen> createState() => _AirBluePaymentScreenState();
}

class _AirBluePaymentScreenState extends State<AirBluePaymentScreen> {
  late final RxInt _secondsLeft = widget.initialSecondsLeft.obs;
  Timer? _countdownTimer;
  String? _selectedPaymentMethod;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft.value > 0) {
        _secondsLeft.value--;
      } else {
        timer.cancel();
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final hoursStr = hours.toString().padLeft(1, '0');
    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');
    return '$hoursStr:$minutesStr:$secondsStr';
  }

  @override
  Widget build(BuildContext context) {
    final formattedPrice =
        NumberFormat('#,##0').format(widget.totalPrice.toDouble());
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Payment',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BookingStepCard(
              activeStep: 2,
              secondsLeft: _secondsLeft,
            ),
            const SizedBox(height: 20),
            _buildFlightDetailsSection(),
            const SizedBox(height: 20),
            _buildTravellerDetailsButton(),
            const SizedBox(height: 24),
            _buildPaymentMethodsSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(formattedPrice),
    );
  }

  Widget _buildFlightDetailsSection() {
    final firstLeg = widget.outboundFlight.legSchedules.first;
    final lastLeg = widget.outboundFlight.legSchedules.last;
    final departureDateTime = DateTime.parse(firstLeg['departure']['dateTime']);
    final arrivalAirport = lastLeg['arrival']['airport'];
    final departureAirport = firstLeg['departure']['airport'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$departureAirport → $arrivalAirport',
                style: AppConstants.sectionTitleStyle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.flight_takeoff, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                'Depart: ${DateFormat('EEE, MMM dd, hh:mm a').format(departureDateTime)}',
                style: AppConstants.fieldValueStyle.copyWith(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showReviewDetailsBottomSheet,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, size: 16, color: TColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Details',
                  style: AppConstants.fieldValueStyle.copyWith(
                    fontSize: 14,
                    color: TColors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, size: 16, color: TColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTravellerDetailsButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Get.snackbar(
            'Traveller Details',
            'View traveller details functionality will be implemented',
            backgroundColor: Colors.blue,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0B5ED7),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          'View Traveller Details (${widget.totalPassengers})',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select a payment method',
          style: AppConstants.sectionTitleStyle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _selectedPaymentMethod != null
                  ? TColors.primary
                  : Colors.grey.shade300,
              width: _selectedPaymentMethod != null ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              _buildPaymentMethodItem(
                title: 'Pay at Office',
                icon: Icons.business,
                onTap: () {
                  setState(() {
                    _selectedPaymentMethod = 'Pay at Office';
                  });
                  _showPayAtOfficeBottomSheet();
                },
                isSelected: _selectedPaymentMethod == 'Pay at Office',
                showDivider: true,
              ),
              _buildPaymentMethodItem(
                title: 'Bank Transfer',
                icon: Icons.account_balance,
                onTap: () {
                  setState(() {
                    _selectedPaymentMethod = 'Bank Transfer';
                  });
                  Get.snackbar(
                    'Payment Method',
                    'Bank Transfer selected',
                    backgroundColor: Colors.blue,
                    colorText: Colors.white,
                    snackPosition: SnackPosition.TOP,
                  );
                },
                isSelected: _selectedPaymentMethod == 'Bank Transfer',
                showDivider: true,
              ),
              _buildPaymentMethodItem(
                title: 'Pay with Card',
                icon: Icons.credit_card,
                onTap: () {
                  setState(() {
                    _selectedPaymentMethod = 'Pay with Card';
                  });
                  Get.to(
                    () => CardPaymentDetailsScreen(
                      outboundFlight: widget.outboundFlight,
                      returnFlight: widget.returnFlight,
                      multicityFlights: widget.multicityFlights,
                      outboundFareOption: widget.outboundFareOption,
                      returnFareOption: widget.returnFareOption,
                      multicityFareOptions: widget.multicityFareOptions,
                      pnrResponse: widget.pnrResponse,
                      totalPassengers: widget.totalPassengers,
                      totalPrice: widget.totalPrice,
                      currency: widget.currency,
                      selectedSeats: widget.selectedSeats,
                    ),
                  );
                },
                isSelected: _selectedPaymentMethod == 'Pay with Card',
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required bool isSelected,
    required bool showDivider,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? TColors.primary.withOpacity(0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? TColors.primary : Colors.grey[600],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: AppConstants.fieldValueStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isSelected ? TColors.primary : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey.shade300,
          ),
      ],
    );
  }

  void _showPayAtOfficeBottomSheet() {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Heading
            Text(
              'Transfer the payment directly At Office.',
              style: AppConstants.sectionTitleStyle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            // Instructional paragraph
            Text(
              'We will confirm your booking now if the booking is refundable and in case booking is nonrefundable, booking will be confirmed after we receive payment.',
              style: AppConstants.fieldValueStyle.copyWith(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'In this payment option you may lose the selected price during the process of payment.',
              style: AppConstants.fieldValueStyle.copyWith(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'If You wish to lock the price now, Select payment by credit card.',
              style: AppConstants.fieldValueStyle.copyWith(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // Ready Flights title
            Center(
              child: Text(
                'Ready Flights',
                style: AppConstants.sectionTitleStyle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Contact information
            Row(
              children: [
                Text(
                  'For Flight # ',
                  style: AppConstants.fieldValueStyle.copyWith(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  '+92 321 9667908',
                  style: AppConstants.fieldValueStyle.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'For Hotel # ',
                  style: AppConstants.fieldValueStyle.copyWith(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  '+92 321 9667909',
                  style: AppConstants.fieldValueStyle.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Back',
                      style: AppConstants.fieldValueStyle.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Get.back();
                      _handleBookNow();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B5ED7),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Book Now',
                      style: AppConstants.fieldValueStyle.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void _handleBookNow() {
    List<AirBlueFareOption>? cleanedMulticityFareOptions;
    if (widget.multicityFareOptions != null) {
      cleanedMulticityFareOptions = widget.multicityFareOptions!
          .whereType<AirBlueFareOption>()
          .toList();
    }

    Get.offAll(
      () => FlightBookingDetailsScreen(
        outboundFlight: widget.outboundFlight,
        returnFlight: widget.returnFlight,
        multicityFlights: widget.multicityFlights,
        outboundFareOption: widget.outboundFareOption,
        returnFareOption: widget.returnFareOption,
        multicityFareOptions: cleanedMulticityFareOptions,
        pnrResponse: widget.pnrResponse,
        selectedSeats: widget.selectedSeats,
      ),
    );
  }

  Widget _buildBottomBar(String formattedPrice) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total price',
                    style: AppConstants.fieldLabelStyle.copyWith(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${widget.currency} $formattedPrice',
                        style: AppConstants.sectionTitleStyle.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          size: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReviewDetailsBottomSheet() {
    final flights = <_FlightReviewItem>[];

    flights.add(
      _FlightReviewItem(
        title: 'Departure',
        flight: widget.outboundFlight,
      ),
    );

    if (widget.returnFlight != null) {
      flights.add(
        _FlightReviewItem(
          title: 'Return',
          flight: widget.returnFlight!,
        ),
      );
    }

    if (widget.multicityFlights != null && widget.multicityFlights!.isNotEmpty) {
      for (var i = 0; i < widget.multicityFlights!.length; i++) {
        flights.add(
          _FlightReviewItem(
            title: 'Flight ${i + 1}',
            flight: widget.multicityFlights![i],
          ),
        );
      }
    }

    final priceRows = _buildPriceRows();

    Get.bottomSheet(
      DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.6,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SafeArea(
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Review Details',
                            style: AppConstants.sectionTitleStyle.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Get.back(),
                          icon: const Icon(Icons.close, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(child: const SizedBox(height: 12)),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = flights[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _FlightReviewCard(item: item),
                        );
                      },
                      childCount: flights.length,
                    ),
                  ),
                  if (priceRows.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            'Price Details',
                            style: AppConstants.sectionTitleStyle.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                ...priceRows.map(
                                  (row) => _PriceDetailRow(
                                    label: row.label,
                                    value: row.value,
                                    showDivider: row != priceRows.last,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Total price',
                                        style:
                                            AppConstants.fieldValueStyle.copyWith(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${widget.currency} ${NumberFormat('#,##0.##').format(widget.totalPrice)}',
                                        style:
                                            AppConstants.sectionTitleStyle.copyWith(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SliverToBoxAdapter(child: const SizedBox(height: 16)),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }



  List<_PriceRow> _buildPriceRows() {
    final rows = <_PriceRow>[];
    final adultCount = widget.bookingController.adults.length;
    final childCount = widget.bookingController.children.length;
    final infantCount = widget.bookingController.infants.length;

    if (adultCount > 0) {
      final price = _calculatePassengerPrice(
        'ADT',
        widget.outboundFlight,
        widget.outboundFareOption,
        widget.returnFlight,
        widget.returnFareOption,
        widget.multicityFlights,
        widget.multicityFareOptions,
      );
      final total = (price['total'] ?? 0) * adultCount;
      rows.add(
        _PriceRow(
          label: 'Adult (x$adultCount)',
          value:
              '${widget.currency} ${NumberFormat('#,##0.##').format(total)}',
          unitPrice: price['total'] ?? 0,
          count: adultCount,
        ),
      );
    }

    if (childCount > 0) {
      final price = _calculatePassengerPrice(
        'CHD',
        widget.outboundFlight,
        widget.outboundFareOption,
        widget.returnFlight,
        widget.returnFareOption,
        widget.multicityFlights,
        widget.multicityFareOptions,
      );
      final total = (price['total'] ?? 0) * childCount;
      rows.add(
        _PriceRow(
          label: 'Child (x$childCount)',
          value: '${widget.currency} ${NumberFormat('#,##0.##').format(total)}',
          unitPrice: price['total'] ?? 0,
          count: childCount,
        ),
      );
    }

    if (infantCount > 0) {
      final price = _calculatePassengerPrice(
        'INF',
        widget.outboundFlight,
        widget.outboundFareOption,
        widget.returnFlight,
        widget.returnFareOption,
        widget.multicityFlights,
        widget.multicityFareOptions,
      );
      final total = (price['total'] ?? 0) * infantCount;
      rows.add(
        _PriceRow(
          label: 'Infant (x$infantCount)',
          value: '${widget.currency} ${NumberFormat('#,##0.##').format(total)}',
          unitPrice: price['total'] ?? 0,
          count: infantCount,
        ),
      );
    }

    return rows;
  }
}

class _BookingStepCard extends StatelessWidget {
  final int activeStep;
  final RxInt secondsLeft;

  const _BookingStepCard({
    required this.activeStep,
    required this.secondsLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              _StepChip(
                label: 'Booking',
                index: 1,
                activeStep: activeStep,
                icon: Icons.check,
              ),
              _Connector(active: activeStep > 1),
              _StepChip(
                label: 'Payment',
                index: 2,
                activeStep: activeStep,
                icon: Icons.airplanemode_active,
              ),
              _Connector(active: activeStep > 2),
              _StepChip(
                label: 'E-ticket',
                index: 3,
                activeStep: activeStep,
                icon: Icons.receipt_long,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Obx(
          () => Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Finish booking in  ',
                style: AppConstants.fieldLabelStyle.copyWith(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                _formatDuration(secondsLeft.value),
                style: AppConstants.fieldValueStyle.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0B5ED7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final hoursStr = hours.toString().padLeft(1, '0');
    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');
    return '$hoursStr:$minutesStr:$secondsStr';
  }
}

class _Connector extends StatelessWidget {
  final bool active;

  const _Connector({required this.active});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        height: 2,
        color: active ? TColors.primary : Colors.grey[300],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  final String label;
  final int index;
  final int activeStep;
  final IconData icon;

  const _StepChip({
    required this.label,
    required this.index,
    required this.activeStep,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = index < activeStep;
    final bool isActive = index == activeStep;
    final Color borderColor =
        isActive || isCompleted ? TColors.primary : Colors.grey[300]!;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isCompleted
                  ? TColors.primary
                  : isActive
                      ? TColors.primary.withOpacity(0.1)
                      : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Icon(
                      icon,
                      size: 18,
                      color: isActive ? TColors.primary : Colors.grey[500],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppConstants.fieldValueStyle.copyWith(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? TColors.primary : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlightReviewItem {
  final String title;
  final AirBlueFlight flight;

  _FlightReviewItem({
    required this.title,
    required this.flight,
  });
}

Map<String, double> _calculatePassengerPrice(
  String passengerType,
  AirBlueFlight outboundFlight,
  AirBlueFareOption? outboundFareOption,
  AirBlueFlight? returnFlight,
  AirBlueFareOption? returnFareOption,
  List<AirBlueFlight>? multicityFlights,
  List<AirBlueFareOption?>? multicityFareOptions,
) {
  double base = 0;
  double tax = 0;
  double fee = 0;

  void accumulate(AirBlueFlight? flight) {
    if (flight?.pnrPricing == null) return;
    for (final pricing in flight!.pnrPricing!) {
      if (pricing.passengerType == passengerType) {
        base += pricing.baseFare;
        tax += pricing.totalTax;
        fee += pricing.totalFees;
        break;
      }
    }
  }

  accumulate(outboundFlight);
  accumulate(returnFlight);
  if (multicityFlights != null) {
    for (final flight in multicityFlights) {
      accumulate(flight);
    }
  }

  if (base == 0 && tax == 0 && fee == 0) {
    void accumulateFare(AirBlueFareOption? fare) {
      if (fare == null) return;
      base += fare.basePrice;
      tax += fare.taxAmount;
      fee += fare.feeAmount;
    }

    accumulateFare(outboundFareOption);
    accumulateFare(returnFareOption);
    if (multicityFareOptions != null) {
      for (final fare in multicityFareOptions) {
        accumulateFare(fare);
      }
    }
  }

  return {'base': base, 'tax': tax, 'fee': fee, 'total': base + tax + fee};
}

class _FlightReviewCard extends StatelessWidget {
  final _FlightReviewItem item;

  const _FlightReviewCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final firstLeg = item.flight.legSchedules.first;
    final lastLeg = item.flight.legSchedules.last;
    final departureDateTime = DateTime.parse(firstLeg['departure']['dateTime']);
    final arrivalDateTime = DateTime.parse(lastLeg['arrival']['dateTime']);
    final duration = arrivalDateTime.difference(departureDateTime);
    final durationText =
        '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    final airlineName = item.flight.airlineName;
    String flightNumber = '';
    final schedules = firstLeg['schedules'] as List<dynamic>?;
    if (schedules != null &&
        schedules.isNotEmpty &&
        schedules.first['carrier'] != null) {
      final carrier = schedules.first['carrier'] as Map<String, dynamic>;
      final marketing = carrier['marketing']?.toString() ?? '';
      final marketingNumber = carrier['marketingFlightNumber']?.toString() ?? '';
      flightNumber = '$marketing$marketingNumber'.trim();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: AppConstants.sectionTitleStyle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side - Timeline
              Column(
                children: [
                  // Top circle
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TColors.primary,
                      border: Border.all(color: TColors.primary, width: 2),
                    ),
                  ),
                  // Vertical line
                  Container(
                    width: 2,
                    height: 40,
                    color: Colors.grey.shade300,
                  ),
                  // Airplane icon in circle
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TColors.primary.withOpacity(0.1),
                    ),
                    child: Icon(
                      Icons.flight,
                      size: 18,
                      color: TColors.primary,
                    ),
                  ),
                  // Vertical line
                  Container(
                    width: 2,
                    height: 40,
                    color: Colors.grey.shade300,
                  ),
                  // Bottom circle
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TColors.primary,
                      border: Border.all(color: TColors.primary, width: 2),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Right side - Flight details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Departure info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('hh:mm a').format(departureDateTime),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('EEE, dd MMM').format(departureDateTime),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          firstLeg['departure']['airport'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    // Duration and airline info
                    Row(
                      children: [
                        Text(
                          durationText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade100,
                          ),
                          child: ClipOval(
                            child: Image.network(
                              'https://images.kiwi.com/airlines/64/PA.png',
                              width: 24,
                              height: 24,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.airplanemode_active,
                                  size: 14,
                                  color: TColors.primary,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$airlineName $flightNumber',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    // Arrival info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('hh:mm a').format(arrivalDateTime),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('EEE, dd MMM').format(arrivalDateTime),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          lastLeg['arrival']['airport'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationColumn extends StatelessWidget {
  final String time;
  final String date;
  final String city;
  final bool alignEnd;

  const _LocationColumn({
    required this.time,
    required this.date,
    required this.city,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          time,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          city,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          date,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

class _PriceDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool showDivider;

  const _PriceDetailRow({
    required this.label,
    required this.value,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppConstants.fieldValueStyle.copyWith(
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                value,
                style: AppConstants.fieldValueStyle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: Colors.grey.shade200,
          ),
      ],
    );
  }
}

class _PriceRow {
  final String label;
  final String value;
  final double unitPrice;
  final int count;

  _PriceRow({
    required this.label,
    required this.value,
    required this.unitPrice,
    required this.count,
  });
}

