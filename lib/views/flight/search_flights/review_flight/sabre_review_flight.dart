import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';

import '../../../../utility/colors.dart';
import '../../../../widgets/travelers_selection_bottom_sheet.dart';
import '../../booking_flight/airblue/airblue_booking_flight.dart';
import '../sabre/sabre_flight_models.dart';
import '../search_flight_utils/widgets/sabre_flight_card.dart';

class ReviewTripPage extends StatefulWidget {
  final bool isMulti; // Indicates if it's a multi-city trip
  final SabreFlight flight; // Selected flight
  final Map<String, dynamic> pricingInformation; // Pricing information from API for the selected package
  final bool isNDC; // Flag to indicate if this is an NDC flight

  const ReviewTripPage({
    super.key,
    required this.isMulti,
    required this.flight,
    required this.pricingInformation,
    this.isNDC = false,
  });

  @override
  ReviewTripPageState createState() => ReviewTripPageState();
}

class ReviewTripPageState extends State<ReviewTripPage> {
  List<BoxShadow> _animatedShadow = [
    BoxShadow(
      color: TColors.primary.withOpacity(0.4),
      blurRadius: 5,
      spreadRadius: 8,
      offset: const Offset(0, 0),
    )
  ];
  late Timer _shadowTimer;

  // Get the travelers controller to access passenger counts
  final travelersController = Get.find<TravelersController>();

  // Variables to store calculated prices - initialized with defaults
  double adultPrice = 0.0;
  double childPrice = 0.0;
  double infantPrice = 0.0;
  double totalPrice = 0.0;
  String currency = 'PKR'; // Default currency

  @override
  void initState() {
    super.initState();
    _startShadowAnimation();
    _calculatePrices();
  }

  void _calculatePrices() {
    if (widget.isNDC) {
      _calculateNDCPrices();
    } else {
      _calculateStandardPrices();
    }

    // Ensure we have valid values
    adultPrice = adultPrice.isFinite ? adultPrice : 0.0;
    childPrice = childPrice.isFinite ? childPrice : 0.0;
    infantPrice = infantPrice.isFinite ? infantPrice : 0.0;
    totalPrice = totalPrice.isFinite ? totalPrice : 0.0;
    currency = currency.isNotEmpty ? currency : 'PKR';
  }

  void _calculateNDCPrices() {
    try {
      // For NDC, the pricing information is already extracted correctly in the package selection
      // Extract total amount directly from the pricing information
      totalPrice = double.tryParse(widget.pricingInformation['totalAmount']?.toString() ?? '0') ?? 0.0;
      currency = widget.pricingInformation['totalCurrency']?.toString() ?? 'PKR';

      // Calculate individual passenger prices
      final totalPassengers = travelersController.adultCount.value +
          travelersController.childrenCount.value +
          travelersController.infantCount.value;

      if (totalPassengers > 0) {
        // For NDC, distribute the total price among all passengers
        // You might want to adjust this logic based on your airline's pricing structure
        adultPrice = travelersController.adultCount.value > 0
            ? totalPrice / totalPassengers * travelersController.adultCount.value / travelersController.adultCount.value
            : 0.0;

        childPrice = travelersController.childrenCount.value > 0
            ? totalPrice / totalPassengers * travelersController.childrenCount.value / travelersController.childrenCount.value
            : 0.0;

        infantPrice = travelersController.infantCount.value > 0
            ? totalPrice / totalPassengers * travelersController.infantCount.value / travelersController.infantCount.value
            : 0.0;
      } else {
        adultPrice = totalPrice; // Default to total price if no passengers specified
        childPrice = 0.0;
        infantPrice = 0.0;
      }

      print('NDC Pricing Debug:');
      print('Total Price: $totalPrice $currency');
      print('Adult Price: $adultPrice');
      print('Child Price: $childPrice');
      print('Infant Price: $infantPrice');

    } catch (e) {
      print('Error calculating NDC prices: $e');
      // Fallback values already set in declarations
      totalPrice = 0.0;
      adultPrice = 0.0;
      childPrice = 0.0;
      infantPrice = 0.0;
      currency = 'PKR';
    }
  }
  void _calculateStandardPrices() {
    try {
      // Check if this is a standard revalidation response
      if (widget.pricingInformation.containsKey('fare')) {
        final fareInfo = widget.pricingInformation['fare'];
        final passengerInfoList = fareInfo['passengerInfoList'] as List? ?? [];

        // Calculate prices based on passenger type
        for (var passengerInfo in passengerInfoList) {
          final passengerType = passengerInfo['passengerInfo']['passengerType'];
          final passengerTotalFare = passengerInfo['passengerInfo']['passengerTotalFare'];
          final price = double.tryParse(passengerTotalFare['totalFare'].toString()) ?? 0.0;

          if (passengerType == 'ADT') {
            adultPrice = price;
          } else if (passengerType == 'CHD') {
            childPrice = price;
          } else if (passengerType == 'INF') {
            infantPrice = price;
          }

          // Update total price
          totalPrice += price;
        }

        // If total price is not available, use the totalFare from the pricingInformation
        if (totalPrice == 0.0) {
          final totalFare = fareInfo['totalFare'];
          totalPrice = double.tryParse(totalFare['totalPrice'].toString()) ?? 0.0;
          currency = totalFare['currency']?.toString() ?? 'PKR';
        }
      } else {
        // Fallback for other response formats
        totalPrice = double.tryParse(widget.pricingInformation['totalAmount']?.toString() ?? '0') ?? 0.0;
        currency = widget.pricingInformation['totalCurrency']?.toString() ?? 'PKR';
        adultPrice = travelersController.adultCount.value > 0
            ? totalPrice / travelersController.adultCount.value
            : 0.0;
      }
    } catch (e) {
      // Fallback values already set in declarations
    }
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

  // Format price to show with commas and fixed decimal places
  String _formatPrice(double price) {
    return price.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColors.background,
      appBar: AppBar(
        backgroundColor: TColors.background,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
          ),
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
            FlightCard(
              flight: widget.flight,
              showReturnFlight: widget.isMulti,
                isShowBookButton:false
            ),
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
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: TColors.background,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _animatedShadow,
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show adult price if there are adults
                      if (travelersController.adultCount.value > 0)
                        _buildPriceRow(
                            'Adult Price x ${travelersController.adultCount.value}',
                            '$currency ${_formatPrice(adultPrice * travelersController.adultCount.value)}'),

                      // Show child price if there are children
                      if (travelersController.childrenCount.value > 0)
                        Column(
                          children: [
                            const SizedBox(height: 8),
                            _buildPriceRow(
                                'Child Price x ${travelersController.childrenCount.value}',
                                '$currency ${_formatPrice(childPrice * travelersController.childrenCount.value)}'),
                          ],
                        ),

                      // Show infant price if there are infants
                      if (travelersController.infantCount.value > 0)
                        Column(
                          children: [
                            const SizedBox(height: 8),
                            _buildPriceRow(
                                'Infant Price x ${travelersController.infantCount.value}',
                                '$currency ${_formatPrice(infantPrice * travelersController.infantCount.value)}'),
                          ],
                        ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(),
                      ),

                      // Show total amount
                      _buildPriceRow(
                        'Total Amount',
                        '$currency ${_formatPrice(totalPrice)}',
                        isTotal: true,
                      ),
                    ],
                  ),
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      const Text(
                        'Review Details',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: TColors.grey),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$currency ${_formatPrice(totalPrice)}',
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
                        Get.to(() => AirBlueBookingFlight.forSabre(
                          sabreFlight: widget.flight,
                          totalPrice: widget.flight.price,
                          currency: 'PKR',
                          revalidatePricing: widget.pricingInformation,
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
                        'Book',
                        style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
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
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? TColors.primary : Colors.black,
          ),
        ),
      ],
    );
  }
}