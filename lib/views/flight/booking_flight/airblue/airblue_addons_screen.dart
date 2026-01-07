import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../../utility/app_constants.dart';
import '../../../../../utility/colors.dart';
import '../../../../widgets/travelers_selection_bottom_sheet.dart';
import '../../search_flights/airblue/airblue_flight_model.dart';
import '../booking_flight_controller.dart';
import 'select_seat.dart';
import 'airblue_payment_screen.dart';

class AirBlueAddOnsScreen extends StatefulWidget {
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

  const AirBlueAddOnsScreen({
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
  });

  @override
  State<AirBlueAddOnsScreen> createState() => _AirBlueAddOnsScreenState();
}

class _AirBlueAddOnsScreenState extends State<AirBlueAddOnsScreen> {
  late final RxInt _secondsLeft = widget.initialSecondsLeft.obs;
  Timer? _countdownTimer;

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

  @override
  Widget build(BuildContext context) {
    final formattedPrice =
        NumberFormat('#,##0').format(widget.totalPrice.toDouble());
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
            const SizedBox(height: 12),
            Text(
              'Enhance your trip with add-ons',
              style: AppConstants.sectionTitleStyle.copyWith(
                fontSize: 20,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildAddOnTile(
              title: 'Choose your seats',
              subtitle: 'Select preferred seats for every traveler.',
              icon: Icons.event_seat,
              actionLabel: 'Select',
              onTap: _openSeatSelectionSheet,
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(formattedPrice),
    );
  }

  Widget _buildAddOnTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Text(
              title,
              style: AppConstants.fieldValueStyle.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Color(0xFF0B5ED7)),
          ],
        ),
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Review Details',
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
                        child: const Icon(Icons.info_outline,
                            size: 12, color: Colors.grey),
                      ),
                    ],
                  ),

                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: _skipToPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B5ED7),
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'Skip To Payment',
                  style: TextStyle(
                    fontSize: 14,
                    color: TColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSeatSelectionSheet() {
    Get.bottomSheet(
      FractionallySizedBox(
        heightFactor: 0.95,
        child: SeatSelectionScreen(
          pnrResponse: widget.pnrResponse,
          totalPassengers: widget.totalPassengers,
          outboundFlight: widget.outboundFlight,
          returnFlight: widget.returnFlight,
          multicityFlights: widget.multicityFlights,
          outboundFareOption: widget.outboundFareOption,
          returnFareOption: widget.returnFareOption,
          multicityFareOptions: widget.multicityFareOptions,
          showAsSheet: true,
          bookingController: widget.bookingController,
          travelersController: widget.travelersController,
          totalPrice: widget.totalPrice,
          currency: widget.currency,
          initialSecondsLeft: _secondsLeft.value,
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void _skipToPayment() {
    List<AirBlueFareOption>? cleanedMulticityFareOptions;
    if (widget.multicityFareOptions != null) {
      cleanedMulticityFareOptions = widget.multicityFareOptions!
          .whereType<AirBlueFareOption>()
          .toList();
    }

    Get.to(
      () => AirBluePaymentScreen(
        pnrResponse: widget.pnrResponse,
        totalPassengers: widget.totalPassengers,
        outboundFlight: widget.outboundFlight,
        returnFlight: widget.returnFlight,
        multicityFlights: widget.multicityFlights,
        outboundFareOption: widget.outboundFareOption,
        returnFareOption: widget.returnFareOption,
        multicityFareOptions: widget.multicityFareOptions,
        bookingController: widget.bookingController,
        travelersController: widget.travelersController,
        totalPrice: widget.totalPrice,
        currency: widget.currency,
        initialSecondsLeft: _secondsLeft.value,
        selectedSeats: null,
      ),
    );
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
                label: 'Add-ons',
                index: 2,
                activeStep: activeStep,
                icon: Icons.airplanemode_active,
              ),
              _Connector(active: activeStep > 2),
              _StepChip(
                label: 'Payment',
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
    return '${hours.toString().padLeft(1, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
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
              border: Border.all(
                color:
                    isActive || isCompleted ? TColors.primary : Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Icon(
                      icon,
                      color: isActive ? TColors.primary : Colors.grey[500],
                      size: 18,
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

