import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../utility/app_constants.dart';
import '../../../../utility/colors.dart';
import '../../../../widgets/travelers_selection_bottom_sheet.dart';
import '../../search_flights/emirates_ndc/emirates_flight_controller.dart';
import '../../search_flights/emirates_ndc/emirates_model.dart';
import '../booking_flight_controller.dart';
import 'emirates_card_payment_details_screen.dart';
import 'emirates_print_voucher.dart';

class EmiratesPaymentScreen extends StatefulWidget {
  final EmiratesFlight flight;
  final EmiratesFlight? returnFlight;
  final EmiratesFarePackage outboundPackage;
  final EmiratesFarePackage? returnPackage;
  final BookingFlightController bookingController;
  final TravelersController travelersController;
  final double totalPrice;
  final String currency;
  final int initialSecondsLeft;
  final Map<String, dynamic> pnrResponse;

  const EmiratesPaymentScreen({
    super.key,
    required this.flight,
    this.returnFlight,
    required this.outboundPackage,
    this.returnPackage,
    required this.bookingController,
    required this.travelersController,
    required this.totalPrice,
    required this.currency,
    required this.initialSecondsLeft,
    required this.pnrResponse,
  });

  @override
  State<EmiratesPaymentScreen> createState() => _EmiratesPaymentScreenState();
}

class _EmiratesPaymentScreenState extends State<EmiratesPaymentScreen> {
  String? _selectedPaymentMethod;
  late final RxInt _secondsLeft = widget.initialSecondsLeft.obs;
  Timer? _countdownTimer;

  int get _totalPassengers {
    return widget.bookingController.adults.length +
        widget.bookingController.children.length +
        widget.bookingController.infants.length;
  }

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
        actions: [
          IconButton(
            onPressed: _showReviewDetailsBottomSheet,
            icon: const Icon(Icons.info_outline),
            color: Colors.black87,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BookingStepCard(
              activeStep: 2,
              secondsLeft: _secondsLeft,
            ),
            const SizedBox(height: 16),
            _buildFlightDetailsSection(),
            const SizedBox(height: 12),
            _buildTravellerDetailsButton(),
            const SizedBox(height: 12),
            _buildPaymentMethodsSection(),
            const SizedBox(height: 12),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildFlightDetailsSection() {
    if (widget.flight.legSchedules.isEmpty) {
      return const SizedBox.shrink();
    }

    final firstLeg = widget.flight.legSchedules.first;
    final departure = firstLeg['departure'] as Map<String, dynamic>;
    final departureTime = DateTime.parse(departure['dateTime'] ?? departure['time']);
    final origin = departure['airport'] ?? '';

    final lastLeg = widget.flight.legSchedules.last;
    final arrival = lastLeg['arrival'] as Map<String, dynamic>;
    final destination = arrival['airport'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$origin → $destination',
          style: AppConstants.sectionTitleStyle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Depart: ${DateFormat('EEE, MMM dd, hh:mm a').format(departureTime)}',
          style: AppConstants.fieldValueStyle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _showReviewDetailsBottomSheet,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Details',
                style: AppConstants.fieldValueStyle.copyWith(
                  fontSize: 14,
                  color: TColors.primary,
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 16, color: TColors.primary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTravellerDetailsButton() {
    final totalPassengers = widget.travelersController.adultCount.value +
        widget.travelersController.childrenCount.value +
        widget.travelersController.infantCount.value;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _showTravellerDetailsBottomSheet,
        style: OutlinedButton.styleFrom(
          backgroundColor: TColors.primary.withOpacity(0.05),
          side: BorderSide(color: TColors.primary.withOpacity(0.3)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: TColors.primary, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Traveller Details ($totalPassengers)',
                  style: AppConstants.fieldValueStyle.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const Icon(Icons.chevron_right, color: TColors.primary),
          ],
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
            color: TColors.text,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _selectedPaymentMethod != null ? TColors.primary : Colors.grey.shade300,
              width: _selectedPaymentMethod != null ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              _buildPaymentMethodItem(
                title: 'Pay with Card',
                icon: Icons.credit_card,
                onTap: () {
                  setState(() {
                    _selectedPaymentMethod = 'Pay with Card';
                  });
                  Get.to(
                    () => EmiratesCardPaymentDetailsScreen(
                      flight: widget.flight,
                      returnFlight: widget.returnFlight,
                      outboundPackage: widget.outboundPackage,
                      returnPackage: widget.returnPackage,
                      totalPassengers: _totalPassengers,
                      totalPrice: widget.totalPrice,
                      currency: widget.currency,
                      pnrResponse: widget.pnrResponse,
                    ),
                  );
                },
                isSelected: _selectedPaymentMethod == 'Pay with Card',
                showDivider: true,
                trailing: const _CardBrandRow(),
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
                    'Bank Transfer option will be available soon',
                    backgroundColor: Colors.blue,
                    colorText: Colors.white,
                    snackPosition: SnackPosition.TOP,
                  );
                },
                isSelected: _selectedPaymentMethod == 'Bank Transfer',
                showDivider: true,
              ),
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
    Widget? trailing,
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
                    color: TColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: TColors.primary,
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
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ] else
                  Icon(
                    Icons.chevron_right,
                    color: TColors.primary,
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

  void _showTravellerDetailsBottomSheet() {
    final travelers = <_TravelerDisplayItem>[];

    void addTravelers(List<TravelerInfo> list, String type) {
      for (var i = 0; i < list.length; i++) {
        travelers.add(
          _TravelerDisplayItem(
            traveler: list[i],
            passengerType: type,
            index: i + 1,
          ),
        );
      }
    }

    addTravelers(widget.bookingController.adults, 'Adult');
    addTravelers(widget.bookingController.children, 'Child');
    addTravelers(widget.bookingController.infants, 'Infant');

    if (travelers.isEmpty) {
      Get.snackbar(
        'No travellers',
        'Traveller details are not available.',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    final isDomestic = widget.bookingController.isDomesticFlight;

    Get.bottomSheet(
      DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, controller) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Traveller Details',
                            style: AppConstants.sectionTitleStyle.copyWith(
                              fontSize: 18,
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
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      itemCount: travelers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = travelers[index];
                        return _TravellerDetailCard(
                          item: item,
                          isDomestic: isDomestic,
                        );
                      },
                    ),
                  ),
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
            Text(
              'Transfer the payment directly At Office.',
              style: AppConstants.sectionTitleStyle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
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
                  widget.flight.flightNumber,
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
                  'Call ',
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
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Back',
                        style: AppConstants.fieldValueStyle.copyWith(
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Book Now',
                        style: AppConstants.fieldValueStyle.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildBottomBar() {
    final formattedPrice =
        NumberFormat('#,##0').format(widget.totalPrice.toDouble());
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

  Future<void> _handleBookNow() async {
    if (_selectedPaymentMethod != 'Pay at Office') {
      Get.snackbar(
        'Select Pay at Office',
        'Please choose Pay at Office to continue with this option.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    Get.offAll(
      () => EmiratesBookingDetailsScreen(
        flight: widget.flight,
        selectedPackage: widget.outboundPackage,
        pnrResponse: widget.pnrResponse,
      ),
    );
  }

  void _showReviewDetailsBottomSheet() {
    final flights = <_FlightReviewItem>[];

    flights.add(
      _FlightReviewItem(
        title: 'Departure',
        flight: widget.flight,
        package: widget.outboundPackage,
      ),
    );

    if (widget.returnFlight != null && widget.returnPackage != null) {
      flights.add(
        _FlightReviewItem(
          title: 'Return',
          flight: widget.returnFlight!,
          package: widget.returnPackage!,
        ),
      );
    }

    final priceRows = _buildPriceRows();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
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
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _FlightReviewCard(item: flights[index]),
                      ),
                      childCount: flights.length,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          'Price Summary',
                          style: AppConstants.sectionTitleStyle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...priceRows.map(
                          (row) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PriceRow(
                              label: row.label,
                              value: row.value,
                              unitPrice: row.unitPrice,
                              count: row.count,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 12),
                        _PriceRow(
                          label: 'Total',
                          value:
                              '${widget.currency} ${NumberFormat('#,##0.##').format(widget.totalPrice)}',
                          unitPrice: widget.totalPrice,
                          count: 1,
                          isTotal: true,
                        ),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(child: const SizedBox(height: 16)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<_PriceRow> _buildPriceRows() {
    final rows = <_PriceRow>[];
    final adultCount = widget.bookingController.adults.length;
    final childCount = widget.bookingController.children.length;
    final infantCount = widget.bookingController.infants.length;

    final weight = adultCount + childCount * 0.75 + infantCount * 0.1;
    if (weight == 0) {
      return rows;
    }

    final basePrice = widget.totalPrice / weight;

    if (adultCount > 0) {
      final total = basePrice * adultCount;
      rows.add(
        _PriceRow(
          label: 'Adult (x$adultCount)',
          value: '${widget.currency} ${NumberFormat('#,##0.##').format(total)}',
          unitPrice: basePrice,
          count: adultCount,
        ),
      );
    }

    if (childCount > 0) {
      final childPrice = basePrice * 0.75;
      final total = childPrice * childCount;
      rows.add(
        _PriceRow(
          label: 'Child (x$childCount)',
          value: '${widget.currency} ${NumberFormat('#,##0.##').format(total)}',
          unitPrice: childPrice,
          count: childCount,
        ),
      );
    }

    if (infantCount > 0) {
      final infantPrice = basePrice * 0.1;
      final total = infantPrice * infantCount;
      rows.add(
        _PriceRow(
          label: 'Infant (x$infantCount)',
          value: '${widget.currency} ${NumberFormat('#,##0.##').format(total)}',
          unitPrice: infantPrice,
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
    return '${hours.toString().padLeft(1, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _Connector extends StatelessWidget {
  final bool active;

  const _Connector({required this.active});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: active ? TColors.primary : Colors.grey[200],
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

    return Column(
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
    );
  }
}

class _FlightReviewItem {
  final String title;
  final EmiratesFlight flight;
  final EmiratesFarePackage package;

  _FlightReviewItem({
    required this.title,
    required this.flight,
    required this.package,
  });
}

class _FlightReviewCard extends StatelessWidget {
  final _FlightReviewItem item;

  const _FlightReviewCard({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.flight.legSchedules.isEmpty) {
      return const SizedBox.shrink();
    }

    final firstLeg = item.flight.legSchedules.first;
    final departure = firstLeg['departure'] as Map<String, dynamic>;
    final departureTime = DateTime.parse(departure['dateTime'] ?? departure['time']);
    final departureAirport = departure['airport'] ?? '';

    final lastLeg = item.flight.legSchedules.last;
    final arrival = lastLeg['arrival'] as Map<String, dynamic>;
    final arrivalTime = DateTime.parse(arrival['dateTime'] ?? arrival['time']);
    final arrivalAirport = arrival['airport'] ?? '';

    final duration = arrivalTime.difference(departureTime);
    final durationText = '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    final airlineName = item.flight.airlineName;
    final flightNumber = item.flight.flightNumber;

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
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TColors.primary,
                      border: Border.all(color: TColors.primary, width: 2),
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 40,
                    color: Colors.grey.shade300,
                  ),
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
                  Container(
                    width: 2,
                    height: 40,
                    color: Colors.grey.shade300,
                  ),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('hh:mm a').format(departureTime),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('EEE, dd MMM').format(departureTime),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          departureAirport,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                              item.flight.airlineImg,
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
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('hh:mm a').format(arrivalTime),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('EEE, dd MMM').format(arrivalTime),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          arrivalAirport,
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

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final double unitPrice;
  final int count;
  final bool isTotal;

  const _PriceRow({
    required this.label,
    required this.value,
    required this.unitPrice,
    required this.count,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isTotal ? Colors.black : Colors.grey[600],
              ),
            ),
            Text(
              '${NumberFormat('#,##0.##').format(unitPrice)} each',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? TColors.primary : Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _CardBrandRow extends StatelessWidget {
  final List<String> _logos = const [
    'https://upload.wikimedia.org/wikipedia/commons/thumb/4/41/Visa_Logo.png/240px-Visa_Logo.png',
    'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/Mastercard-logo.svg/320px-Mastercard-logo.svg.png',
    'https://cdn-icons-png.flaticon.com/128/349/349228.png',
  ];

  const _CardBrandRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _logos
          .map(
            (url) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: SizedBox(
                width: 28,
                height: 20,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 28,
                      height: 20,
                      color: Colors.grey[200],
                    );
                  },
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _TravelerDisplayItem {
  final TravelerInfo traveler;
  final String passengerType;
  final int index;

  _TravelerDisplayItem({
    required this.traveler,
    required this.passengerType,
    required this.index,
  });
}

class _TravellerDetailCard extends StatelessWidget {
  final _TravelerDisplayItem item;
  final bool isDomestic;

  const _TravellerDetailCard({
    required this.item,
    required this.isDomestic,
  });

  @override
  Widget build(BuildContext context) {
    final passportLabel = isDomestic ? 'CNIC' : 'Passport';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: TColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    item.index.toString(),
                    style: const TextStyle(
                      color: TColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.traveler.firstNameController.text} ${item.traveler.lastNameController.text}',
                    style: AppConstants.sectionTitleStyle.copyWith(fontSize: 16),
                  ),
                  Text(
                    item.passengerType,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TravellerInfoRow(
            label: passportLabel,
            value: item.traveler.passportCnicController.text,
          ),
          const SizedBox(height: 8),
          _TravellerInfoRow(
            label: 'Date of Birth',
            value: item.traveler.dateOfBirthController.text,
          ),
          const SizedBox(height: 8),
          _TravellerInfoRow(
            label: 'Gender',
            value: item.traveler.genderController.text,
          ),
        ],
      ),
    );
  }
}

class _TravellerInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _TravellerInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        Text(
          value.isNotEmpty ? value : '--',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

