import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../../utility/app_constants.dart';
import '../../../../../utility/colors.dart';
import '../../../../widgets/travelers_selection_bottom_sheet.dart';
import '../../search_flights/sabre/sabre_flight_models.dart';
import '../../../hotel/search_hotels/booking_hotel/payment_hotel/payment_controller.dart';
import '../booking_flight_controller.dart';

class SabreCardPaymentDetailsScreen extends StatelessWidget {
  final SabreFlight flight;
  final Map<String, dynamic> pnrResponse;
  final int totalPassengers;
  final double totalPrice;
  final String currency;
  final BookingFlightController bookingController;
  final TravelersController travelersController;

  const SabreCardPaymentDetailsScreen({
    super.key,
    required this.flight,
    required this.pnrResponse,
    required this.totalPassengers,
    required this.totalPrice,
    required this.currency,
    required this.bookingController,
    required this.travelersController,
  });

  @override
  Widget build(BuildContext context) {
    final firstLeg = flight.legSchedules.first;
    final departureDateTime = DateTime.parse(firstLeg['departure']['dateTime']);
    final formattedDate = DateFormat('EEE, dd MMM yyyy').format(departureDateTime);

    final creditCardFee = totalPrice * 0.03;
    final netTotal = totalPrice + creditCardFee;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Pay with Credit / Debit Card',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/abhipay.png',
                        height: 32,
                        errorBuilder: (_, __, ___) {
                          return Text(
                            'abhipay',
                            style: AppConstants.sectionTitleStyle.copyWith(
                              color: TColors.primary,
                            ),
                          );
                        },
                      ),
                      const Spacer(),
                      Text(
                        'Secure Payment',
                        style: AppConstants.fieldLabelStyle.copyWith(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _detailRow('Departure Date', formattedDate),
                  const SizedBox(height: 12),
                  _detailRow('Number of PX', '$totalPassengers'),
                  const Divider(height: 32),
                  Text(
                    'Amount Details',
                    style: AppConstants.sectionTitleStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    'Total Amount',
                    '$currency ${NumberFormat('#,##0.00').format(totalPrice)}',
                    valueColor: const Color(0xFF0B5ED7),
                  ),
                  const SizedBox(height: 8),
                  _detailRow(
                    'Credit Card (3%)',
                    '$currency ${NumberFormat('#,##0.00').format(creditCardFee)}',
                    valueColor: Colors.redAccent,
                  ),
                  const Divider(height: 24),
                  _detailRow(
                    'Net Total',
                    '$currency ${NumberFormat('#,##0.00').format(netTotal)}',
                    isBold: true,
                  ),
                ],
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: Get.back,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Back',
                      style: AppConstants.fieldValueStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleCardPayment(netTotal),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B5ED7),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
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
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppConstants.fieldValueStyle.copyWith(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: AppConstants.fieldValueStyle.copyWith(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Future<void> _handleCardPayment(double netTotal) async {
    final paymentController = Get.put(PaymentController());
    final transactionId = 'FK_SABRE_${DateTime.now().millisecondsSinceEpoch}';
    const callbackUrl = 'readyflights://payment-success';
    final description = 'Flight Booking - Sabre - $transactionId';

    // Store Sabre flight data for navigation after payment
    Get.put(
      SabreFlightPaymentData(
        flight: flight,
        pnrResponse: pnrResponse,
        bookingController: bookingController,
        travelersController: travelersController,
      ),
      permanent: false,
    );

    final success = await paymentController.processAbhipayPaymentForFlight(
      amount: netTotal,
      description: description,
      clientTransactionId: transactionId,
      callbackUrl: callbackUrl,
      currency: currency,
      language: 'EN',
    );

    if (!success) {
      Get.snackbar(
        'Payment Error',
        'Failed to initiate payment. Please try again.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }
}

// Sabre-specific payment data class
class SabreFlightPaymentData {
  final SabreFlight flight;
  final Map<String, dynamic> pnrResponse;
  final BookingFlightController bookingController;
  final TravelersController travelersController;

  SabreFlightPaymentData({
    required this.flight,
    required this.pnrResponse,
    required this.bookingController,
    required this.travelersController,
  });
}

