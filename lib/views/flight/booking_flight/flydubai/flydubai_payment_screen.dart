import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../utility/app_constants.dart';
import '../../../../utility/colors.dart';
import '../../../../widgets/travelers_selection_bottom_sheet.dart';
import '../../search_flights/flydubai/flydubai_model.dart';
import '../../search_flights/flydubai/flydubai_extras_controller.dart';
import '../booking_flight_controller.dart';
import 'flydubai_card_payment_details_screen.dart';
import '../common_flight_voucher_adapter.dart';

class FlyDubaiPaymentScreen extends StatefulWidget {
  final FlydubaiFlight flight;
  final FlydubaiFlight? returnFlight;
  final FlydubaiFlightFare outboundFare;
  final FlydubaiFlightFare? returnFare;
  final BookingFlightController bookingController;
  final TravelersController travelersController;
  final double totalPrice;
  final String currency;
  final int initialSecondsLeft;
  final Map<String, dynamic>? pnrResponse;

  const FlyDubaiPaymentScreen({
    super.key,
    required this.flight,
    this.returnFlight,
    required this.outboundFare,
    this.returnFare,
    required this.bookingController,
    required this.travelersController,
    required this.totalPrice,
    required this.currency,
    required this.initialSecondsLeft,
    this.pnrResponse,
  });

  @override
  State<FlyDubaiPaymentScreen> createState() => _FlyDubaiPaymentScreenState();
}

class _FlyDubaiPaymentScreenState extends State<FlyDubaiPaymentScreen> {
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
    final departureTime = DateTime.parse(departure['time']);
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
            Icon(Icons.chevron_right, color: TColors.primary),
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
            color: TColors.text
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
                  if (widget.pnrResponse == null) {
                    Get.snackbar(
                      'Booking Not Ready',
                      'PNR response missing. Please try again.',
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                      snackPosition: SnackPosition.TOP,
                    );
                    return;
                  }

                  Get.to(
                    () => FlyDubaiCardPaymentDetailsScreen(
                      flight: widget.flight,
                      returnFlight: widget.returnFlight,
                      outboundFare: widget.outboundFare,
                      returnFare: widget.returnFare,
                      pnrResponse: widget.pnrResponse!,
                      totalPassengers: _totalPassengers,
                      totalPrice: widget.totalPrice,
                      currency: widget.currency,
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
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
                  widget.flight.flightSegment.flightNumber,
                  style: AppConstants.fieldValueStyle.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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

    final bookingResponse = widget.pnrResponse;
    if (bookingResponse == null) {
      Get.snackbar(
        'Booking Not Ready',
        'PNR response missing. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    try {
      // Get extras from controller if available
      Map<String, dynamic>? extrasData;
      try {
        final extrasController = Get.find<FlydubaiExtrasController>();
        print('🔍 DEBUG: Found FlydubaiExtrasController in payment screen');
        print('   - Baggage count: ${extrasController.selectedBaggage.length}');
        print('   - Meals count: ${extrasController.selectedMeals.length}');
        print('   - Seats count: ${extrasController.selectedSeats.length}');
        
        // Convert RxMap to regular Map
        final baggageMap = <String, dynamic>{};
        extrasController.selectedBaggage.forEach((key, value) {
          print('   📦 Baggage key: $key, value: $value (type: ${value.runtimeType})');
          // Ensure value is properly converted
          if (value is Map) {
            baggageMap[key] = Map<String, dynamic>.from(value);
          } else {
            baggageMap[key] = value;
          }
        });
        
        final mealsMap = <String, dynamic>{};
        extrasController.selectedMeals.forEach((key, value) {
          print('   🍽️ Meal key: $key, value: $value (type: ${value.runtimeType})');
          // Ensure value is properly converted
          if (value is Map) {
            mealsMap[key] = Map<String, dynamic>.from(value);
          } else {
            mealsMap[key] = value;
          }
        });
        
        final seatsMap = <String, dynamic>{};
        extrasController.selectedSeats.forEach((key, value) {
          print('   💺 Seat key: $key, value: $value (type: ${value.runtimeType})');
          // Ensure value is properly converted
          if (value is Map) {
            seatsMap[key] = Map<String, dynamic>.from(value);
          } else {
            seatsMap[key] = value;
          }
        });
        
        extrasData = {
          'selectedBaggage': baggageMap,
          'selectedMeals': mealsMap,
          'selectedSeats': seatsMap,
        };
        
        print('✅ DEBUG: Extras data prepared in payment screen:');
        print('   - Baggage: ${baggageMap.length} items');
        print('   - Meals: ${mealsMap.length} items');
        print('   - Seats: ${seatsMap.length} items');
      } catch (e, stackTrace) {
        print('❌ DEBUG: Error getting extras in payment screen: $e');
        print('   Stack trace: $stackTrace');
        // Extras controller not found, skip
      }

      Get.offAll(
        () => createFlyDubaiVoucher(
          outboundFlight: widget.flight,
          returnFlight: widget.returnFlight,
          outboundFareOption: widget.outboundFare,
          returnFareOption: widget.returnFare,
          pnrResponse: bookingResponse,
          totalPrice: widget.totalPrice,
          currency: widget.currency,
          extras: extrasData,
        ),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to proceed: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  void _showReviewDetailsBottomSheet() {
    final flights = <_FlightReviewItem>[];
    
    // Add outbound flight
    flights.add(
      _FlightReviewItem(
        title: 'Departure',
        flight: widget.flight,
        isReturn: false,
      ),
    );
    
    // Add return flight if exists
    if (widget.returnFlight != null) {
      flights.add(
        _FlightReviewItem(
          title: 'Return',
          flight: widget.returnFlight!,
          isReturn: true,
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
    );
  }

  List<_PriceRow> _buildPriceRows() {
    final rows = <_PriceRow>[];
    final adultCount = widget.bookingController.adults.length;
    final childCount = widget.bookingController.children.length;
    final infantCount = widget.bookingController.infants.length;

    // Calculate price per passenger type (simple split for now)
    final basePrice = widget.totalPrice / (adultCount + childCount * 0.75 + infantCount * 0.1);

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
  final FlydubaiFlight flight;
  final bool isReturn;

  _FlightReviewItem({
    required this.title,
    required this.flight,
    required this.isReturn,
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
    final departureTime = DateTime.parse(departure['time']);
    final departureAirport = departure['airport'] ?? '';
    
    final lastLeg = item.flight.legSchedules.last;
    final arrival = lastLeg['arrival'] as Map<String, dynamic>;
    final arrivalTime = DateTime.parse(arrival['time']);
    final arrivalAirport = arrival['airport'] ?? '';
    
    final duration = arrivalTime.difference(departureTime);
    final durationText = '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    final airlineName = item.flight.airlineName;
    final flightNumber = item.flight.flightSegment.flightNumber;

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
    final traveler = item.traveler;
    final title = traveler.titleController.text.trim();
    final first = traveler.firstNameController.text.trim();
    final last = traveler.lastNameController.text.trim();
    final fullName =
        [title, first, last].where((element) => element.isNotEmpty).join(' ');
    final documentLabel = isDomestic ? 'CNIC Number' : 'Passport Number';
    final documentExpiryLabel =
        isDomestic ? 'CNIC Expiry' : 'Passport Expiry';

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
          Row(
            children: [
              Expanded(
                child: Text(
                  fullName.isEmpty ? 'Traveller ${item.index}' : fullName,
                  style: AppConstants.sectionTitleStyle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: TColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.passengerType,
                  style: AppConstants.fieldValueStyle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: TColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TravellerInfoRow(
            label: 'Date of Birth',
            value: _formatTravellerDate(traveler.dateOfBirthController.text),
          ),
          const SizedBox(height: 8),
          _TravellerInfoRow(
            label: documentLabel,
            value: traveler.passportCnicController.text.trim().isEmpty
                ? '--'
                : traveler.passportCnicController.text.trim(),
          ),
          const SizedBox(height: 8),
          _TravellerInfoRow(
            label: documentExpiryLabel,
            value: _formatTravellerDate(
              traveler.passportExpiryController.text,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTravellerDate(String raw) {
    if (raw.trim().isEmpty) return '--';
    try {
      final parsed = DateTime.parse(raw);
      return DateFormat('dd.MM.yyyy').format(parsed);
    } catch (_) {
      final normalized = raw.replaceAll('/', '-');
      try {
        final parsed = DateFormat('dd-MM-yyyy').parse(normalized);
        return DateFormat('dd.MM.yyyy').format(parsed);
      } catch (_) {
        return raw;
      }
    }
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            '$label:',
            style: AppConstants.fieldValueStyle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: TColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: AppConstants.fieldValueStyle.copyWith(
              fontSize: 14,
              color: Colors.black87,
            ),
            textAlign: TextAlign.left,
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

