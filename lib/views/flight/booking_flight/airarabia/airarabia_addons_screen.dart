import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../utility/app_constants.dart';
import '../../../../utility/colors.dart';
import '../../../../widgets/travelers_selection_bottom_sheet.dart';
import '../../search_flights/airarabia/airarabia_flight_model.dart';
import '../../search_flights/airarabia/validation_data/validation_controller.dart';
import '../../search_flights/airarabia/validation_data/validation_model.dart';
import '../booking_flight_controller.dart';
import 'airarabia_payment_screen.dart';

class AirArabiaAddOnsScreen extends StatefulWidget {
  final AirArabiaFlight flight;
  final AirArabiaPackage selectedPackage;
  final BookingFlightController bookingController;
  final TravelersController travelersController;
  final double totalPrice;
  final String currency;
  final int initialSecondsLeft;
  final Future<Map<String, dynamic>?> Function() onProceedToPayment;
  final AirArabiaRevalidationController extrasController;

  const AirArabiaAddOnsScreen({
    super.key,
    required this.flight,
    required this.selectedPackage,
    required this.bookingController,
    required this.travelersController,
    required this.totalPrice,
    required this.currency,
    required this.initialSecondsLeft,
    required this.onProceedToPayment,
    required this.extrasController,
  });

  @override
  State<AirArabiaAddOnsScreen> createState() => _AirArabiaAddOnsScreenState();
}

class _AirArabiaAddOnsScreenState extends State<AirArabiaAddOnsScreen> {
  late final AirArabiaRevalidationController extrasController;
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
              'Enhance your Air Arabia trip',
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
                  onPressed: _isProcessing ? null : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B5ED7),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Continue',
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
    });
  }

  Future<void> _handleContinue() async {
    setState(() {
      _isProcessing = true;
    });
    try {
      final response = await widget.onProceedToPayment();
      if (response == null || response['status'] != 200) {
        Get.snackbar(
          'Error',
          response?['message'] ?? 'Failed to create booking',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
        return;
      }

      Get.to(
        () => AirArabiaPaymentScreen(
          bookingResponse: response,
          flight: widget.flight,
          selectedPackage: widget.selectedPackage,
          bookingController: widget.bookingController,
          travelersController: widget.travelersController,
          totalPrice: widget.totalPrice,
          currency: widget.currency,
          initialSecondsLeft: _secondsLeft.value,
        ),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to continue: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  String _baggageSummary() {
    final entries = extrasController.selectedBaggage.entries.where(
      (entry) => double.tryParse(entry.value.baggageCharge) != null &&
          double.parse(entry.value.baggageCharge) > 0,
    );
    if (entries.isEmpty) return 'No extra baggage selected';
    return '${entries.length} baggage options selected';
  }

  String _mealSummary() {
    int count = 0;
    for (final passengerMeals in extrasController.selectedMeals.values) {
      for (final mealList in passengerMeals.values) {
        count += mealList.length;
      }
    }
    if (count == 0) return 'No meals selected';
    return '$count meal(s) selected';
  }

  String _seatSummary() {
    int count = 0;
    for (final passengerSeats in extrasController.selectedSeats.values) {
      count += passengerSeats.values.where((seat) => seat.seatNumber.isNotEmpty).length;
    }
    if (count == 0) return 'No seats selected';
    return '$count seat(s) selected';
  }

  void _openBaggageSelector() {
    Get.bottomSheet(
      AirArabiaBaggageSelector(controller: extrasController),
      isScrollControlled: true,
      backgroundColor: Colors.white,
    ).whenComplete(() => setState(() {}));
  }

  void _openMealSelector() {
    Get.bottomSheet(
      AirArabiaMealSelector(controller: extrasController),
      isScrollControlled: true,
      backgroundColor: Colors.white,
    ).whenComplete(() => setState(() {}));
  }

  void _openSeatSelector() {
    Get.bottomSheet(
      AirArabiaSeatSelector(controller: extrasController),
      isScrollControlled: true,
      backgroundColor: Colors.white,
    ).whenComplete(() => setState(() {}));
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

class AirArabiaBaggageSelector extends StatefulWidget {
  final AirArabiaRevalidationController controller;

  const AirArabiaBaggageSelector({super.key, required this.controller});

  @override
  State<AirArabiaBaggageSelector> createState() =>
      _AirArabiaBaggageSelectorState();
}

class _AirArabiaBaggageSelectorState extends State<AirArabiaBaggageSelector>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedPassengerIndex = 0;
  late List<String> _segmentCodes;

  @override
  void initState() {
    super.initState();
    final segments = widget.controller.getFlightSegments();
    _segmentCodes = segments.map((segment) {
      return segment.attributes['SegmentCode']?.toString() ??
          segment.attributes['RPH']?.toString() ??
          'segment_${segments.indexOf(segment)}';
    }).toList();
    _tabController = TabController(length: _segmentCodes.length, vsync: this);
    // Ensure selected passenger index is within bounds
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
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: TColors.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: TColors.primary,
              tabs: _segmentCodes.map((code) {
                final parts = code.split('/');
                return Tab(text: parts.length > 1 ? '${parts.first} → ${parts.last}' : code);
              }).toList(),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _segmentCodes.map((segmentCode) {
                  final baggageOptions =
                      widget.controller.getBaggageForSegment(segmentCode);
                  // Ensure passenger index is valid
                  if (widget.controller.passengerIds.isEmpty ||
                      _selectedPassengerIndex < 0 ||
                      _selectedPassengerIndex >= widget.controller.passengerIds.length) {
                    return const Center(
                      child: Text('No passengers available'),
                    );
                  }
                  final passengerId =
                      widget.controller.passengerIds[_selectedPassengerIndex];
                  final selectedBaggage = widget.controller
                      .getBaggageForPassenger(passengerId, segmentCode: segmentCode);
                  
                  // Get segment info for display
                  final segments = widget.controller.getFlightSegments();
                  FlightSegmentInfo? segment;
                  try {
                    segment = segments.firstWhere(
                      (s) {
                        final code = s.attributes['SegmentCode']?.toString() ??
                            s.attributes['RPH']?.toString() ??
                            '';
                        return code == segmentCode;
                      },
                    );
                  } catch (e) {
                    segment = segments.isNotEmpty ? segments.first : null;
                  }
                  
                  String destination = '';
                  if (segment != null) {
                    final segmentCodeStr = segment.attributes['SegmentCode']?.toString() ?? '';
                    if (segmentCodeStr.contains('/')) {
                      final parts = segmentCodeStr.split('/');
                      destination = parts.length > 1 ? parts.last : '';
                    }
                  }
                  
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Flight information box
                        if (segment != null) _buildFlightInfoBox(segmentCode, destination),
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
                        // Baggage options
                        ...baggageOptions.where((bag) {
                          // Filter out "No Bag" option from the list (it's shown in included section)
                          return !bag.baggageCode.toLowerCase().contains('no bag') &&
                                 !bag.baggageDescription.toLowerCase().contains('no bag');
                        }).map((baggage) {
                          final selected = selectedBaggage?.baggageCode == baggage.baggageCode;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildBaggageOptionCard(
                              baggage: baggage,
                              isSelected: selected,
                              onTap: () {
                                widget.controller.selectBaggage(
                                  passengerId,
                                  baggage,
                                  segmentCode: segmentCode,
                                );
                                setState(() {});
                              },
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            _buildCloseButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppConstants.sectionTitleStyle.copyWith(fontSize: 18),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // Use Navigator.pop for more reliable dismissal in release mode
                try {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Get.back();
                  }
                } catch (e) {
                  // Fallback to Get.back() if Navigator fails
                  Get.back();
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.close, size: 24),
              ),
            ),
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

  Widget _buildFlightInfoBox(String segmentCode, String destination) {
    final parts = segmentCode.split('/');
    final origin = parts.isNotEmpty ? parts.first : '';
    final dest = destination.isNotEmpty ? destination : (parts.length > 1 ? parts.last : '');
    
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
            origin.isNotEmpty && dest.isNotEmpty ? '$origin-$dest' : segmentCode,
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
          padding: const EdgeInsets.symmetric(horizontal: 16,vertical: 8),
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
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '0 KG',
                      style: AppConstants.sectionTitleStyle.copyWith(
                        fontSize: 14,
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
    required BaggageOption baggage,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // Extract weight from description (e.g., "20 kg", "30 kg", "40 kg")
    final weightMatch = RegExp(r'(\d+)\s*kg', caseSensitive: false).firstMatch(baggage.baggageDescription);
    final weight = weightMatch?.group(1) ?? '';
    final is40kg = weight == '40';
    
    // Get icon URL based on weight
    final iconUrl = is40kg
        ? 'https://cdn-icons-png.flaticon.com/128/1663/1663017.png'
        : 'https://cdn-icons-png.flaticon.com/128/2350/2350789.png';
    
    final charge = double.tryParse(baggage.baggageCharge) ?? 0.0;
    final formattedPrice = NumberFormat('#,##0').format(charge);
    
    // Format description - show weight allowance (e.g., "20 kg Baggage Allowance")
    final description = baggage.baggageDescription;
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
}

class AirArabiaMealSelector extends StatefulWidget {
  final AirArabiaRevalidationController controller;

  const AirArabiaMealSelector({super.key, required this.controller});

  @override
  State<AirArabiaMealSelector> createState() => _AirArabiaMealSelectorState();
}

class _AirArabiaMealSelectorState extends State<AirArabiaMealSelector>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedPassengerIndex = 0;
  late List<String> _segmentCodes;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, String> _searchQueries = {};

  @override
  void initState() {
    super.initState();
    final segments = widget.controller.getFlightSegments();
    _segmentCodes = segments.map((segment) {
      return segment.attributes['SegmentCode']?.toString() ??
          segment.attributes['RPH']?.toString() ??
          'segment_${segments.indexOf(segment)}';
    }).toList();
    _tabController = TabController(length: _segmentCodes.length, vsync: this);
    // Initialize search queries for each segment
    for (final code in _segmentCodes) {
      _searchQueries[code] = '';
    }
    // Ensure selected passenger index is within bounds
    if (widget.controller.passengerIds.isNotEmpty) {
      _selectedPassengerIndex = 0;
    } else {
      _selectedPassengerIndex = -1;
    }
    
    // Listen to tab changes to update search controller
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final currentSegment = _segmentCodes[_tabController.index];
        _searchController.text = _searchQueries[currentSegment] ?? '';
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
              child: TabBarView(
                controller: _tabController,
                children: _segmentCodes.map((segmentCode) {
                  return _buildMealListForSegment(segmentCode);
                }).toList(),
              ),
            ),
            _buildContinueButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildMealListForSegment(String segmentCode) {
    final meals = widget.controller.getMealsForSegment(segmentCode);
    final searchQuery = _searchQueries[segmentCode] ?? '';
    final filteredMeals = searchQuery.isEmpty
        ? meals
        : meals.where((meal) {
            return meal.mealName.toLowerCase().contains(searchQuery.toLowerCase()) ||
                meal.mealDescription.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();

    // Ensure passenger index is valid
    if (widget.controller.passengerIds.isEmpty ||
        _selectedPassengerIndex < 0 ||
        _selectedPassengerIndex >= widget.controller.passengerIds.length) {
      return const Center(
        child: Text('No passengers available'),
      );
    }
    final passengerId = widget.controller.passengerIds[_selectedPassengerIndex];

    // Get segment info for display
    final segments = widget.controller.getFlightSegments();
    FlightSegmentInfo? segment;
    try {
      segment = segments.firstWhere(
        (s) {
          final code = s.attributes['SegmentCode']?.toString() ??
              s.attributes['RPH']?.toString() ??
              '';
          return code == segmentCode;
        },
      );
    } catch (e) {
      segment = segments.isNotEmpty ? segments.first : null;
    }

    String origin = '';
    String destination = '';
    if (segment != null) {
      final segmentCodeStr = segment.attributes['SegmentCode']?.toString() ?? '';
      if (segmentCodeStr.contains('/')) {
        final parts = segmentCodeStr.split('/');
        origin = parts.isNotEmpty ? parts.first : '';
        destination = parts.length > 1 ? parts.last : '';
      }
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

          const SizedBox(height: 8 ),
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
                        _searchQueries[segmentCode] = '';
                        setState(() {});
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
              _searchQueries[segmentCode] = value;
              setState(() {});
            },
          ),
          const SizedBox(height: 20),
          // Meal cards
          ...filteredMeals.map((meal) {
            final isSelected = widget.controller.isMealSelected(
                segmentCode, passengerId, meal);
            return _buildMealCard(
              meal: meal,
              isSelected: isSelected,
              onAdd: () {
                widget.controller.toggleMeal(segmentCode, passengerId, meal);
                setState(() {});
              },
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) => Padding(
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

  Widget _buildSegmentSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: _segmentCodes.asMap().entries.map((entry) {
          final index = entry.key;
          final segmentCode = entry.value;
          final isSelected = _tabController.index == index;
          
          final segments = widget.controller.getFlightSegments();
          FlightSegmentInfo? segment;
          try {
            segment = segments.firstWhere(
              (s) {
                final code = s.attributes['SegmentCode']?.toString() ??
                    s.attributes['RPH']?.toString() ??
                    '';
                return code == segmentCode;
              },
            );
          } catch (e) {
            segment = segments.isNotEmpty ? segments.first : null;
          }
          
          String origin = '';
          String destination = '';
          if (segment != null) {
            final segmentCodeStr = segment.attributes['SegmentCode']?.toString() ?? '';
            if (segmentCodeStr.contains('/')) {
              final parts = segmentCodeStr.split('/');
              origin = parts.isNotEmpty ? parts.first : '';
              destination = parts.length > 1 ? parts.last : '';
            }
          }
          
          final displayText = origin.isNotEmpty && destination.isNotEmpty
              ? '$origin-$destination\nDeparting'
              : segmentCode;
          
          return Expanded(
            child: GestureDetector(
              onTap: () {
                _tabController.animateTo(index);
                setState(() {});
              },
              child: Container(
                margin: EdgeInsets.only(right: index < _segmentCodes.length - 1 ? 8 : 0),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? TColors.primary.withOpacity(0.1) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? TColors.primary : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  displayText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? TColors.primary : Colors.grey[700],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMealCard({
    required MealOption meal,
    required bool isSelected,
    required VoidCallback onAdd,
  }) {
    final charge = double.tryParse(meal.mealCharge) ?? 0.0;
    final isFree = charge == 0.0;
    final formattedPrice = isFree
        ? 'Free'
        : NumberFormat('#,##0').format(charge);
    
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
              if (meal.mealImageLink.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  child: Image.network(
                    meal.mealImageLink,
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
                        meal.mealName,
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

class AirArabiaSeatSelector extends StatefulWidget {
  final AirArabiaRevalidationController controller;

  const AirArabiaSeatSelector({super.key, required this.controller});

  @override
  State<AirArabiaSeatSelector> createState() => _AirArabiaSeatSelectorState();
}

class _AirArabiaSeatSelectorState extends State<AirArabiaSeatSelector>
    with SingleTickerProviderStateMixin {
  final List<String> seatLetters = ['A', 'B', 'C', 'D', 'E', 'F'];
  late TabController _tabController;
  int _selectedPassengerIndex = 0;
  late List<String> _segmentCodes;

  @override
  void initState() {
    super.initState();
    final segments = widget.controller.getFlightSegments();
    _segmentCodes = segments.map((segment) {
      return segment.attributes['SegmentCode']?.toString() ??
          segment.attributes['RPH']?.toString() ??
          'segment_${segments.indexOf(segment)}';
    }).toList();
    _tabController = TabController(length: _segmentCodes.length, vsync: this);
    // Ensure selected passenger index is within bounds
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
            _buildHeader('Select Seats'),
            _buildPassengerChips(),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: TColors.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: TColors.primary,
              tabs: _segmentCodes.map((code) {
                final parts = code.split('/');
                return Tab(text: parts.length > 1 ? '${parts.first} → ${parts.last}' : code);
              }).toList(),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _segmentCodes.map((segmentCode) {
                  // Ensure passenger index is valid
                  if (widget.controller.passengerIds.isEmpty ||
                      _selectedPassengerIndex < 0 ||
                      _selectedPassengerIndex >= widget.controller.passengerIds.length) {
                    return const Center(
                      child: Text('No passengers available'),
                    );
                  }
                  final passengerId =
                      widget.controller.passengerIds[_selectedPassengerIndex];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildLegend(),
                        const SizedBox(height: 20),
                        _buildAirplaneFront(),
                        const SizedBox(height: 20),
                        _buildSeatMap(segmentCode, passengerId),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            _buildCloseButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
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

  Widget _buildCloseButton() => Padding(
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
          child: const Text('Done', style: TextStyle(color: Colors.white)),
        ),
      );

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem(Colors.green[400]!, 'Available'),
          _buildLegendItem(Colors.grey[400]!, 'Occupied'),
          _buildLegendItem(TColors.primary, 'Selected'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildAirplaneFront() {
    return SizedBox(
      height: 40,
      child: CustomPaint(
        size: const Size(double.infinity, 40),
        painter: AirplaneFrontPainter(),
      ),
    );
  }

  Widget _buildSeatMap(String segmentCode, String passengerId) {
    final seats = widget.controller.getSeatsForSegment(segmentCode);
    final selectedSeat = widget.controller.getSelectedSeat(segmentCode, passengerId);
    
    // Debug: Log seat data
    debugPrint('🔍 Seat Selector - Segment: $segmentCode');
    debugPrint('🔍 Total seats from API: ${seats.length}');
    if (seats.isNotEmpty) {
      debugPrint('🔍 First seat: ${seats.first.seatNumber}, Availability: ${seats.first.seatAvailability}, Charge: ${seats.first.seatCharge}');
    }
    
    // Group seats by row number
    final Map<int, List<SeatOption>> seatsByRow = {};
    for (final seat in seats) {
      final rowNumber = _extractRowNumber(seat.seatNumber);
      if (rowNumber != null) {
        seatsByRow.putIfAbsent(rowNumber, () => []).add(seat);
      }
    }
    
    final totalRows = seatsByRow.keys.isEmpty ? 38 : seatsByRow.keys.reduce((a, b) => a > b ? a : b);
    
    return Column(
      children: List.generate(totalRows, (index) {
        final rowNumber = index + 1;
        return _buildSeatRow(
          rowNumber.toString(),
          seatLetters,
          seatsByRow[rowNumber] ?? [],
          segmentCode,
          passengerId,
          selectedSeat,
        );
      }),
    );
  }

  int? _extractRowNumber(String seatNumber) {
    // Extract row number from seat number (e.g., "12A" -> 12)
    final match = RegExp(r'^(\d+)').firstMatch(seatNumber);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  String _extractSeatLetter(String seatNumber) {
    // Extract letter from seat number (e.g., "12A" -> "A")
    final match = RegExp(r'([A-F])$').firstMatch(seatNumber);
    return match?.group(1) ?? '';
  }

  Widget _buildSeatRow(
    String rowNumber,
    List<String> seatLetters,
    List<SeatOption> availableSeats,
    String segmentCode,
    String passengerId,
    SeatOption? selectedSeat,
  ) {
    // Create a map for quick lookup
    final seatsMap = {for (var seat in availableSeats) seat.seatNumber: seat};
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Left side seats (A, B, C)
          ...seatLetters.sublist(0, 3).map((letter) {
            final seatNumber = '$rowNumber$letter';
            final seat = seatsMap[seatNumber] ?? SeatOption(
              seatNumber: seatNumber,
              seatCharge: 0,
              currencyCode: 'PKR',
              seatAvailability: 'Occupied',
            );
            return _buildSeat(seat, segmentCode, passengerId, selectedSeat, seatsMap.containsKey(seatNumber));
          }),
          // Row number in center
          Container(
            width: 36,
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              rowNumber,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ),
          // Right side seats (D, E, F)
          ...seatLetters.sublist(3).map((letter) {
            final seatNumber = '$rowNumber$letter';
            final seat = seatsMap[seatNumber] ?? SeatOption(
              seatNumber: seatNumber,
              seatCharge: 0,
              currencyCode: 'PKR',
              seatAvailability: 'Occupied',
            );
            return _buildSeat(seat, segmentCode, passengerId, selectedSeat, seatsMap.containsKey(seatNumber));
          }),
        ],
      ),
    );
  }

  Widget _buildSeat(
    SeatOption seat,
    String segmentCode,
    String passengerId,
    SeatOption? selectedSeat,
    bool existsInApi,
  ) {
    final isSelected = selectedSeat?.seatNumber == seat.seatNumber;
    // If seat exists in API response, it's available (controller only adds available/VAC seats)
    // If seat doesn't exist in API, it's occupied
    final isOccupied = !existsInApi;
    final isOccupiedByOther = widget.controller.isSeatOccupiedByOtherPassenger(
      segmentCode,
      passengerId,
      seat,
    );
    final isAvailable = existsInApi && !isOccupiedByOther;
    
    final seatLetter = _extractSeatLetter(seat.seatNumber);
    final price = seat.seatCharge;
    
    final String priceLabel;
    if (isAvailable) {
      priceLabel = price > 0 ? price.toStringAsFixed(0) : 'Free';
    } else if (isOccupied) {
      priceLabel = '';
    } else {
      priceLabel = '—';
    }
    
    return SizedBox(
      width: 44,
      child: Column(
        children: [
          GestureDetector(
            onTap: isAvailable
                ? () {
                    widget.controller.selectSeat(segmentCode, passengerId, seat);
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
                    : isOccupiedByOther
                        ? TColors.primary.withOpacity(0.6)
                        : isAvailable
                            ? const Color(0xFFBFA4FF) // Same purple color as AirBlue
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
                child: isOccupied && !existsInApi
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
}

class AirplaneFrontPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width * 0.5, 0);
    path.lineTo(size.width * 0.42, size.height * 0.8);
    path.lineTo(size.width * 0.58, size.height * 0.8);
    path.close();

    canvas.drawPath(path, paint);

    final windowPaint = Paint()
      ..color = Colors.blue[200]!
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.3),
      8,
      windowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

