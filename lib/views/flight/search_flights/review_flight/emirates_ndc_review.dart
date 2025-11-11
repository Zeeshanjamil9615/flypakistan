// views/flight/search_flights/emirates_ndc/emirates_review_trip.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:ready_flights/views/flight/booking_flight/emirates%20_ndc/emirates_ndc_booking_flight.dart';
import 'package:ready_flights/views/flight/search_flights/emirates_ndc/emirates_flight_controller.dart';
import 'package:ready_flights/views/flight/search_flights/emirates_ndc/emirates_model.dart';
import 'package:ready_flights/views/flight/search_flights/search_flight_utils/widgets/emirates_ndc_card.dart';
import '../../../../utility/colors.dart';
import '../../../../widgets/travelers_selection_bottom_sheet.dart';

class EmiratesReviewTripPage extends StatefulWidget {
  final EmiratesFlight outboundFlight;
  final EmiratesFarePackage outboundPackage;
  final EmiratesFlight? returnFlight;
  final EmiratesFarePackage? returnPackage;
  final bool isRoundTrip;

  const EmiratesReviewTripPage({
    super.key,
    required this.outboundFlight,
    required this.outboundPackage,
    this.returnFlight,
    this.returnPackage,
    this.isRoundTrip = false,
  });

  @override
  EmiratesReviewTripPageState createState() => EmiratesReviewTripPageState();
}

class EmiratesReviewTripPageState extends State<EmiratesReviewTripPage> {
  List<BoxShadow> _animatedShadow = [
    BoxShadow(
      color: TColors.primary.withOpacity(0.4),
      blurRadius: 5,
      spreadRadius: 8,
      offset: const Offset(0, 0),
    )
  ];
  late Timer _shadowTimer;

  final travelersController = Get.find<TravelersController>();
  final emiratesController = Get.find<EmiratesFlightController>();

  @override
  void initState() {
    super.initState();
    _startShadowAnimation();
  }

  void _startShadowAnimation() {
    _shadowTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      setState(() {
        _animatedShadow = _animatedShadow[0].offset.dy == 2
            ? [
                BoxShadow(
                  color: TColors.primary.withOpacity(0.4),
                  blurRadius: 2,
                  spreadRadius: 15,
                  offset: const Offset(0, 0),
                )
              ]
            : [
                BoxShadow(
                  color: TColors.primary.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 2),
                )
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
    final parts = price.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];

    final formattedInteger = integerPart.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );

    return '$formattedInteger.$decimalPart';
  }

  double get totalPrice {
    final adults = travelersController.adultCount.value;
    final children = travelersController.childrenCount.value;
    final infants = travelersController.infantCount.value;
    final passengerCount = adults + children + infants;
    if (passengerCount == 0) return 0;

    final outboundTotal = widget.outboundPackage.price * passengerCount;
    final returnTotal = widget.returnPackage != null
        ? widget.returnPackage!.price * passengerCount
        : 0;

    return outboundTotal + returnTotal;
  }

  bool get hasReturnSegment =>
      widget.isRoundTrip && widget.returnFlight != null && widget.returnPackage != null;

  String get primaryCurrency => widget.outboundPackage.currency;

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
        title: const Text(
          'Review Trip',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            
            _buildFlightSection('Outbound Flight', widget.outboundFlight),
            if (widget.isRoundTrip && widget.returnFlight != null)
              _buildFlightSection('Return Flight', widget.returnFlight!),
            
            _buildPackageInfo('Outbound Package', widget.outboundPackage),
            if (widget.isRoundTrip && widget.returnPackage != null)
              _buildPackageInfo('Return Package', widget.returnPackage!),
            
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
              child: Text(
                'Booking Amount',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            
            _buildPricingCard(
              'Outbound Fare (${widget.outboundPackage.name})',
              widget.outboundPackage,
            ),
            if (widget.isRoundTrip && widget.returnPackage != null)
              _buildPricingCard(
                'Return Fare (${widget.returnPackage!.name})',
                widget.returnPackage!,
              ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildFlightSection(String title, EmiratesFlight flight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 4),
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        EmiratesFlightCard(
          flight: flight,
          isShowBookButton: false,
        ),
      ],
    );
  }

  Widget _buildPackageInfo(String title, EmiratesFarePackage package) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _buildPackageDetail(Icons.luggage, 'Baggage', 
              '${package.checkedWeight.toStringAsFixed(0)} ${package.checkedUnit}'),
          const SizedBox(height: 8),
          _buildPackageDetail(Icons.restaurant, 'Meal', 'Included'),
          const SizedBox(height: 8),
          _buildPackageDetail(Icons.swap_horiz, 'Changes', 
              package.isRefundable ? 'Allowed' : 'Not Allowed'),
          const SizedBox(height: 8),
          _buildPackageDetail(Icons.money_off, 'Refund', 
              package.isRefundable ? 'Allowed' : 'Not Allowed'),
        ],
      ),
    );
  }

  Widget _buildPackageDetail(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: TColors.primary),
        const SizedBox(width: 8),
        Text(
          '$title: ',
          style: const TextStyle(fontSize: 14, color: TColors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildPricingCard(String title, EmiratesFarePackage package) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 1500),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: TColors.background,
          borderRadius: BorderRadius.circular(10),
          boxShadow: _animatedShadow,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: TColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            
            if (travelersController.adultCount.value > 0)
              _buildPriceRow(
                'Adult Price x ${travelersController.adultCount.value}',
                '${package.currency} ${_formatPrice(package.price * travelersController.adultCount.value)}',
              ),
            
            if (travelersController.childrenCount.value > 0) ...[
              const SizedBox(height: 8),
              _buildPriceRow(
                'Child Price x ${travelersController.childrenCount.value}',
                '${package.currency} ${_formatPrice(package.price * travelersController.childrenCount.value)}',
              ),
            ],
            
            if (travelersController.infantCount.value > 0) ...[
              const SizedBox(height: 8),
              _buildPriceRow(
                'Infant Price x ${travelersController.infantCount.value}',
                '${package.currency} ${_formatPrice(package.price * travelersController.infantCount.value)}',
              ),
            ],
            
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            
            _buildPriceRow(
              'Subtotal',
              '${package.currency} ${_formatPrice(package.price * (travelersController.adultCount.value + travelersController.childrenCount.value + travelersController.infantCount.value))}',
              isTotal: true,
            ),
          ],
        ),
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
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? TColors.primary : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Column(
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
                    hasReturnSegment ? 'Round Trip Total' : 'Total',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: TColors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$primaryCurrency ${_formatPrice(totalPrice)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: () {
                    Get.to(() => EmiratesNdcBookingFlight(
                      flight: widget.outboundFlight,
                      selectedPackage: widget.outboundPackage,
                      returnFlight: widget.returnFlight,
                      returnPackage: widget.returnPackage,
                      isRoundTrip: widget.isRoundTrip && hasReturnSegment,
                      totalPrice: totalPrice,
                      currency: primaryCurrency,
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TColors.primary,
                    foregroundColor: TColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(48),
                    ),
                  ),
                  child: const Text(
                    'Continue to Book',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
      ],
    );
  }

}