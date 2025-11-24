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
import 'flydubai_payment_screen.dart';

class FlyDubaiAddOnsScreen extends StatefulWidget {
  final FlydubaiFlight flight;
  final FlydubaiFlight? returnFlight;
  final FlydubaiFlightFare outboundFare;
  final FlydubaiFlightFare? returnFare;
  final BookingFlightController bookingController;
  final TravelersController travelersController;
  final double totalPrice;
  final String currency;
  final int initialSecondsLeft;
  final Future<Map<String, dynamic>?> Function() onProceedToPayment;
  final FlydubaiExtrasController extrasController;

  const FlyDubaiAddOnsScreen({
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
    required this.onProceedToPayment,
    required this.extrasController,
  });

  @override
  State<FlyDubaiAddOnsScreen> createState() => _FlyDubaiAddOnsScreenState();
}

class _FlyDubaiAddOnsScreenState extends State<FlyDubaiAddOnsScreen> {
  late final FlydubaiExtrasController extrasController;
  late final RxInt _secondsLeft = widget.initialSecondsLeft.obs;
  Timer? _countdownTimer;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    extrasController = widget.extrasController;
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Add-ons',
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
            const SizedBox(height: 16),
            Text(
              'Enhance your FlyDubai trip',
              style: AppConstants.sectionTitleStyle.copyWith(
                fontSize: 20,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildAddOnTile(
              title: 'Choose your seats',
              subtitle: _seatSummary(),
              icon: Icons.event_seat,
              actionLabel: 'Select',
              onTap: _openSeatSelector,
            ),
            const SizedBox(height: 12),
            _buildAddOnTile(
              title: 'Choose your baggage',
              subtitle: _baggageSummary(),
              icon: Icons.luggage,
              actionLabel: 'Select',
              onTap: _openBaggageSelector,
            ),
            const SizedBox(height: 12),
            _buildAddOnTile(
              title: 'Choose your meal',
              subtitle: _mealSummary(),
              icon: Icons.restaurant,
              actionLabel: 'Select',
              onTap: _openMealSelector,
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: TColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppConstants.fieldValueStyle.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppConstants.fieldLabelStyle.copyWith(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              actionLabel,
              style: AppConstants.fieldValueStyle.copyWith(
                fontSize: 13,
                color: TColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF0B5ED7)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Obx(() {
      final totalAmount =
          widget.totalPrice + extrasController.totalExtrasPrice.value;
      final formattedTotal =
          NumberFormat('#,##0').format(totalAmount.toDouble());
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
                          '${widget.currency} $formattedTotal',
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
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.info_outline, size: 14),
                            onPressed: _showPriceBreakdown,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isProcessing ? null : _handleContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    });
  }

  String _seatSummary() {
    final selectedCount = extrasController.selectedSeats.length;
    if (selectedCount == 0) {
      return 'No seats selected';
    }
    return '$selectedCount seat${selectedCount > 1 ? 's' : ''} selected';
  }

  String _baggageSummary() {
    final selectedCount = extrasController.selectedBaggage.length;
    if (selectedCount == 0) {
      return 'No baggage selected';
    }
    return '$selectedCount baggage selected';
  }

  String _mealSummary() {
    final selectedCount = extrasController.selectedMeals.length;
    if (selectedCount == 0) {
      return 'No meals selected';
    }
    return '$selectedCount meal${selectedCount > 1 ? 's' : ''} selected';
  }

  void _openSeatSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FlyDubaiSeatSelector(
        controller: extrasController,
      ),
    );
  }

  void _openBaggageSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FlyDubaiBaggageSelector(
        controller: extrasController,
      ),
    );
  }

  void _openMealSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FlyDubaiMealSelector(
        controller: extrasController,
      ),
    );
  }

  void _showPriceBreakdown() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Price Breakdown',
                    style: AppConstants.sectionTitleStyle.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _PriceRow(
                        label: 'Base Flight Price',
                        value: '${widget.currency} ${NumberFormat('#,##0').format(widget.totalPrice)}',
                      ),
                      if (extrasController.totalExtrasPrice.value > 0) ...[
                        const SizedBox(height: 12),
                        _PriceRow(
                          label: 'Selected Extras',
                          value: '${widget.currency} ${NumberFormat('#,##0').format(extrasController.totalExtrasPrice.value)}',
                        ),
                      ],
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      _PriceRow(
                        label: 'Total Amount',
                        value: '${widget.currency} ${NumberFormat('#,##0').format(widget.totalPrice + extrasController.totalExtrasPrice.value)}',
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleContinue() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Call the PNR creation and DB save callback
      final pnrResponse = await widget.onProceedToPayment();

      if (mounted) {
        // Navigate to payment screen
        Get.to(
          () => FlyDubaiPaymentScreen(
            flight: widget.flight,
            returnFlight: widget.returnFlight,
            outboundFare: widget.outboundFare,
            returnFare: widget.returnFare,
            bookingController: widget.bookingController,
            travelersController: widget.travelersController,
            totalPrice: widget.totalPrice + extrasController.totalExtrasPrice.value,
            currency: widget.currency,
            initialSecondsLeft: _secondsLeft.value,
            pnrResponse: pnrResponse,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          'Error',
          'Failed to proceed: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStep(1, 'Booking', activeStep >= 1),
              _buildStepConnector(),
              _buildStep(2, 'Add-ons', activeStep >= 2),
              _buildStepConnector(),
              _buildStep(3, 'Payment', activeStep >= 3),
            ],
          ),
          const SizedBox(height: 12),
          Obx(() {
            final hours = secondsLeft.value ~/ 3600;
            final minutes = (secondsLeft.value % 3600) ~/ 60;
            final seconds = secondsLeft.value % 60;
            return Text(
              'Time left: ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: AppConstants.fieldLabelStyle.copyWith(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStep(int step, String label, bool isActive) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isActive ? TColors.primary : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step.toString(),
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isActive ? TColors.primary : Colors.grey[600],
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector() {
    return Container(
      height: 2,
      width: 20,
      color: Colors.grey[300],
      margin: const EdgeInsets.only(bottom: 20),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _PriceRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.normal,
            color: isTotal ? TColors.primary : Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: FontWeight.w700,
            color: isTotal ? TColors.primary : Colors.black87,
          ),
        ),
      ],
    );
  }
}

// FlyDubai Baggage Selector
class FlyDubaiBaggageSelector extends StatefulWidget {
  final FlydubaiExtrasController controller;

  const FlyDubaiBaggageSelector({super.key, required this.controller});

  @override
  State<FlyDubaiBaggageSelector> createState() => _FlyDubaiBaggageSelectorState();
}

class _FlyDubaiBaggageSelectorState extends State<FlyDubaiBaggageSelector> {
  int _selectedPassengerIndex = 0;
  late String _segmentCode;

  @override
  void initState() {
    super.initState();
    final segments = widget.controller.getSegmentCodes();
    _segmentCode = segments.isNotEmpty ? segments.first : '0';
    if (widget.controller.passengerIds.isNotEmpty) {
      _selectedPassengerIndex = 0;
    } else {
      _selectedPassengerIndex = -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.only(top: 16, bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            _buildHeader('Add Extra Baggage'),
            _buildPassengerChips(),
            Expanded(
              child: _buildBaggageList(),
            ),
            _buildCloseButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppConstants.sectionTitleStyle.copyWith(fontSize: 18),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Get.back(),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerChips() {
    if (widget.controller.passengerIds.length <= 1) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.controller.passengerIds.length,
        itemBuilder: (context, index) {
          final label = widget.controller.getPassengerDisplayName(index);
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              selected: _selectedPassengerIndex == index,
              onSelected: (_) {
                setState(() {
                  _selectedPassengerIndex = index;
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildBaggageList() {
    if (widget.controller.passengerIds.isEmpty ||
        _selectedPassengerIndex < 0 ||
        _selectedPassengerIndex >= widget.controller.passengerIds.length) {
      return const Center(
        child: Text('No passengers available'),
      );
    }

    final passengerId = widget.controller.passengerIds[_selectedPassengerIndex];
    final selectedBaggage = widget.controller.getSelectedBaggageForPassenger(
      _segmentCode,
      passengerId,
    );

    // Get flight info for display
    final flight = widget.controller.selectedFlight.value;
    String origin = '';
    String destination = '';
    if (flight != null && flight.legSchedules.isNotEmpty) {
      final firstLeg = flight.legSchedules.first;
      origin = firstLeg['departure']?['airport'] ?? '';
      final lastLeg = flight.legSchedules.last;
      destination = lastLeg['arrival']?['airport'] ?? '';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flight information box
          if (origin.isNotEmpty && destination.isNotEmpty)
            _buildFlightInfoBox(origin, destination),
          const SizedBox(height: 20),
          // Included in fare section
          _buildIncludedInFareSection(),
          const SizedBox(height: 24),
          // Select your baggage section
          Text(
            destination.isNotEmpty
                ? 'Select your baggage to $destination'
                : 'Select your baggage',
            style: AppConstants.sectionTitleStyle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          // Baggage options - filtered and sorted
          Obx(() {
            final filteredBaggage = widget.controller.getFilteredAndSortedBaggageOptions();
            
            if (filteredBaggage.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'No baggage options available',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }
            
            return Column(
              children: filteredBaggage.map((baggage) {
                final isSelected = selectedBaggage?['id'] == baggage['id'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildBaggageOptionCard(
                    baggage: baggage,
                    isSelected: isSelected,
                    onTap: () {
                      final key = 'seg$_segmentCode|$passengerId';
                      widget.controller.selectBaggage(key, baggage);
                      setState(() {});
                    },
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFlightInfoBox(String origin, String destination) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F0FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$origin-$destination',
            style: AppConstants.sectionTitleStyle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Departing',
            style: AppConstants.fieldLabelStyle.copyWith(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncludedInFareSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Included in fare',
          style: AppConstants.sectionTitleStyle.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(
                Icons.luggage,
                color: Colors.grey[700],
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check In Baggage',
                      style: AppConstants.fieldValueStyle.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '0 KG',
                      style: AppConstants.sectionTitleStyle.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBaggageOptionCard({
    required Map<String, dynamic> baggage,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // Extract weight from description (e.g., "20 kg", "30 kg", "40 kg")
    final description = (baggage['description'] ?? '').toString();
    final weightMatch = RegExp(r'(\d+)\s*kg', caseSensitive: false).firstMatch(description);
    final weight = weightMatch?.group(1) ?? '';
    final is40kg = weight == '40';
    
    // Get icon URL based on weight
    final iconUrl = is40kg
        ? 'https://cdn-icons-png.flaticon.com/128/1663/1663017.png'
        : 'https://cdn-icons-png.flaticon.com/128/2350/2350789.png';
    
    final charge = double.tryParse(baggage['charge']?.toString() ?? '0') ?? 0.0;
    final formattedPrice = NumberFormat('#,##0').format(charge);
    
    // Format description - show weight allowance
    final weightText = weight.isNotEmpty ? '$weight kg Baggage Allowance' : description;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? TColors.primary.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? TColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            SizedBox(
              width: 56,
              height: 56,
              child: Image.network(
                iconUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.luggage,
                    size: 48,
                    color: isSelected ? TColors.primary : Colors.grey[600],
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            // Baggage info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weightText,
                    style: AppConstants.fieldValueStyle.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'PKR $formattedPrice',
                    style: AppConstants.sectionTitleStyle.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? TColors.primary : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            // Selection indicator
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: TColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        onPressed: () => Get.back(),
        style: ElevatedButton.styleFrom(
          backgroundColor: TColors.primary,
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text('Continue', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// FlyDubai Meal Selector
class FlyDubaiMealSelector extends StatefulWidget {
  final FlydubaiExtrasController controller;

  const FlyDubaiMealSelector({super.key, required this.controller});

  @override
  State<FlyDubaiMealSelector> createState() => _FlyDubaiMealSelectorState();
}

class _FlyDubaiMealSelectorState extends State<FlyDubaiMealSelector> {
  int _selectedPassengerIndex = 0;
  late String _segmentCode;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final segments = widget.controller.getSegmentCodes();
    _segmentCode = segments.isNotEmpty ? segments.first : '0';
    if (widget.controller.passengerIds.isNotEmpty) {
      _selectedPassengerIndex = 0;
    } else {
      _selectedPassengerIndex = -1;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.only(top: 16, bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            _buildHeader('Add Meal'),
            _buildSegmentSelector(),
            Expanded(
              child: _buildMealList(),
            ),
            _buildContinueButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppConstants.sectionTitleStyle.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Get.back(),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentSelector() {
    final flight = widget.controller.selectedFlight.value;
    String origin = '';
    String destination = '';
    if (flight != null && flight.legSchedules.isNotEmpty) {
      final firstLeg = flight.legSchedules.first;
      origin = firstLeg['departure']?['airport'] ?? '';
      final lastLeg = flight.legSchedules.last;
      destination = lastLeg['arrival']?['airport'] ?? '';
    }

    final displayText = origin.isNotEmpty && destination.isNotEmpty
        ? '$origin-$destination\nDeparting'
        : 'Flight Segment';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: TColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: TColors.primary,
            width: 2,
          ),
        ),
        child: Text(
          displayText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: TColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildMealList() {
    if (widget.controller.passengerIds.isEmpty ||
        _selectedPassengerIndex < 0 ||
        _selectedPassengerIndex >= widget.controller.passengerIds.length) {
      return const Center(
        child: Text('No passengers available'),
      );
    }

    final passengerId = widget.controller.passengerIds[_selectedPassengerIndex];
    final selectedMeal = widget.controller.getSelectedMealForPassenger(
      _segmentCode,
      passengerId,
    );

    final flight = widget.controller.selectedFlight.value;
    String origin = '';
    String destination = '';
    if (flight != null && flight.legSchedules.isNotEmpty) {
      final firstLeg = flight.legSchedules.first;
      origin = firstLeg['departure']?['airport'] ?? '';
      final lastLeg = flight.legSchedules.last;
      destination = lastLeg['arrival']?['airport'] ?? '';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instructional text
          if (origin.isNotEmpty && destination.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Select your meal from $origin to $destination',
                style: AppConstants.fieldLabelStyle.copyWith(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ),
          // Back arrow and Free Meals header
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Get.back(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Text(
                'Free Meals',
                style: AppConstants.sectionTitleStyle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search for free meals',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 20),
          // Meal cards
          Obx(() {
            final meals = widget.controller.availableMeals;
            final filteredMeals = _searchQuery.isEmpty
                ? meals
                : meals.where((meal) {
                    final name = (meal['name'] ?? '').toString().toLowerCase();
                    final description = (meal['description'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery.toLowerCase()) ||
                        description.contains(_searchQuery.toLowerCase());
                  }).toList();
            
            return Column(
              children: filteredMeals.map((meal) {
                final isSelected = selectedMeal?['id'] == meal['id'];
                return _buildMealCard(
                  meal: meal,
                  isSelected: isSelected,
                  onAdd: () {
                    final key = 'seg$_segmentCode|$passengerId';
                    widget.controller.selectMeal(key, meal);
                    setState(() {});
                  },
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMealCard({
    required Map<String, dynamic> meal,
    required bool isSelected,
    required VoidCallback onAdd,
  }) {
    final charge = double.tryParse(meal['charge']?.toString() ?? '0') ?? 0.0;
    final isFree = charge == 0.0;
    final formattedPrice = isFree
        ? 'Free'
        : NumberFormat('#,##0').format(charge);
    
    final imageLink = meal['imageLink']?.toString() ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? TColors.primary : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meal image and info row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meal image
              if (imageLink.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  child: Image.network(
                    imageLink,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[200],
                        child: const Icon(Icons.restaurant, size: 40, color: Colors.grey),
                      );
                    },
                  ),
                )
              else
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.restaurant, size: 40, color: Colors.grey),
                ),
              // Meal details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal['name'] ?? 'Meal',
                        style: AppConstants.sectionTitleStyle.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Price or Free label
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isFree ? Colors.green[50] : Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isFree ? Colors.green : Colors.blue,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            formattedPrice,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isFree ? Colors.green[700] : Colors.blue[700],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Add button
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected
                      ? Colors.grey[400]
                      : const Color(0xFFE7F0FF),
                  foregroundColor: isSelected
                      ? Colors.white
                      : TColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  isSelected ? 'Added' : '+ Add',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        onPressed: () => Get.back(),
        style: ElevatedButton.styleFrom(
          backgroundColor: TColors.primary,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Continue',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// FlyDubai Seat Selector - matching AirArabia design
class FlyDubaiSeatSelector extends StatefulWidget {
  final FlydubaiExtrasController controller;

  const FlyDubaiSeatSelector({super.key, required this.controller});

  @override
  State<FlyDubaiSeatSelector> createState() => _FlyDubaiSeatSelectorState();
}

class _FlyDubaiSeatSelectorState extends State<FlyDubaiSeatSelector> {
  int _selectedPassengerIndex = 0;
  late String _segmentCode;

  @override
  void initState() {
    super.initState();
    final segments = widget.controller.getSegmentCodes();
    _segmentCode = segments.isNotEmpty ? segments.first : '0';
    if (widget.controller.passengerIds.isNotEmpty) {
      _selectedPassengerIndex = 0;
    } else {
      _selectedPassengerIndex = -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.only(top: 16, bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            _buildHeader('Select Seat'),
            _buildPassengerChips(),
            Expanded(
              child: _buildSeatMap(),
            ),
            _buildCloseButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppConstants.sectionTitleStyle.copyWith(fontSize: 18),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Get.back(),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerChips() {
    if (widget.controller.passengerIds.length <= 1) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.controller.passengerIds.length,
        itemBuilder: (context, index) {
          final label = widget.controller.getPassengerDisplayName(index);
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              selected: _selectedPassengerIndex == index,
              onSelected: (_) {
                setState(() {
                  _selectedPassengerIndex = index;
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSeatMap() {
    if (widget.controller.passengerIds.isEmpty ||
        _selectedPassengerIndex < 0 ||
        _selectedPassengerIndex >= widget.controller.passengerIds.length) {
      return const Center(
        child: Text('No passengers available'),
      );
    }

    final passengerId = widget.controller.passengerIds[_selectedPassengerIndex];
    final selectedSeat = widget.controller.getSelectedSeatForPassenger(
      _segmentCode,
      passengerId,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildLegend(),
          const SizedBox(height: 16),
          _buildAirplaneFront(),
          const SizedBox(height: 16),
          Obx(() => _buildSeatMapGrid(passengerId, selectedSeat)),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem(const Color(0xFFBFA4FF), 'Available'),
        _buildLegendItem(TColors.primary, 'Selected'),
        _buildLegendItem(Colors.grey[300]!, 'Occupied'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildAirplaneFront() {
    return CustomPaint(
      size: const Size(200, 40),
      painter: _AirplaneFrontPainter(),
    );
  }

  Widget _buildSeatMapGrid(String passengerId, Map<String, dynamic>? selectedSeat) {
    final availableSeats = widget.controller.availableSeats;
    
    // Determine total rows from available seats
    int maxRow = 0;
    for (final seat in availableSeats) {
      final seatNumber = seat['seatNumber']?.toString() ?? '';
      final rowMatch = RegExp(r'^(\d+)').firstMatch(seatNumber);
      if (rowMatch != null) {
        final row = int.tryParse(rowMatch.group(1) ?? '0') ?? 0;
        if (row > maxRow) maxRow = row;
      }
    }
    
    final totalRows = maxRow > 0 ? maxRow : 32; // Default to 32 if no seats found
    final columns = ['A', 'B', 'C', 'D', 'E', 'F'];

    return Column(
      children: List.generate(totalRows, (rowIndex) {
        final rowNumber = rowIndex + 1;
        return _buildSeatRow(rowNumber, columns, passengerId, selectedSeat, availableSeats);
      }),
    );
  }

  Widget _buildSeatRow(
    int rowNumber,
    List<String> columns,
    String passengerId,
    Map<String, dynamic>? selectedSeat,
    List<dynamic> availableSeats,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Row number
          SizedBox(
            width: 24,
            child: Text(
              '$rowNumber',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          // Left side seats (A, B, C)
          ...columns.take(3).map((column) {
            final seatNumber = '$rowNumber$column';
            return _buildSeat(seatNumber, passengerId, selectedSeat, availableSeats);
          }),
          // Aisle
          const SizedBox(width: 12),
          // Right side seats (D, E, F)
          ...columns.skip(3).map((column) {
            final seatNumber = '$rowNumber$column';
            return _buildSeat(seatNumber, passengerId, selectedSeat, availableSeats);
          }),
        ],
      ),
    );
  }

  Widget _buildSeat(
    String seatNumber,
    String passengerId,
    Map<String, dynamic>? selectedSeat,
    List<dynamic> availableSeats,
  ) {
    // Find seat in available seats
    final apiSeat = availableSeats.firstWhere(
      (seat) => seat['seatNumber']?.toString() == seatNumber,
      orElse: () => null,
    );

    final isSelected = selectedSeat?['seatNumber']?.toString() == seatNumber;
    final existsInApi = apiSeat != null;
    final isAvailable = existsInApi && (apiSeat['isAvailable'] == true);
    final isOccupied = !isAvailable || (apiSeat?['isAssigned'] == true) || (apiSeat?['isBlocked'] == true);

    final seatLetter = seatNumber.substring(seatNumber.length - 1);
    final price = existsInApi ? (double.tryParse(apiSeat['charge']?.toString() ?? '0') ?? 0.0) : 0.0;

    final String priceLabel;
    if (isAvailable) {
      priceLabel = price > 0 ? price.toStringAsFixed(0) : 'Free';
    } else {
      priceLabel = '';
    }

    return SizedBox(
      width: 44,
      child: Column(
        children: [
          GestureDetector(
            onTap: isAvailable
                ? () {
                    final key = 'seg$_segmentCode|$passengerId';
                    final seatToSelect = {
                      'id': apiSeat?['id'] ?? 'SEAT_$seatNumber',
                      'seatNumber': seatNumber,
                      'charge': price.toString(),
                      'serviceCode': apiSeat?['serviceCode'] ?? 'SEAT',
                      'rowNumber': seatNumber.substring(0, seatNumber.length - 1),
                      'description': 'Seat $seatNumber',
                      'type': 'seat',
                    };
                    widget.controller.selectSeat(key, seatToSelect);
                    setState(() {});
                  }
                : null,
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? TColors.primary
                    : isOccupied
                        ? Colors.grey[300]
                        : isAvailable
                            ? const Color(0xFFBFA4FF)
                            : Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? TColors.primary
                      : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: TColors.primary.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Center(
                child: !isAvailable && !existsInApi
                    ? const Icon(Icons.close, color: Colors.white, size: 16)
                    : Text(
                        seatLetter,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            priceLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isAvailable
                  ? Colors.black87
                  : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        onPressed: () => Get.back(),
        style: ElevatedButton.styleFrom(
          backgroundColor: TColors.primary,
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text('Continue', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _AirplaneFrontPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TColors.primary
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width * 0.3, size.height);
    path.lineTo(size.width * 0.7, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

