import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:ready_flights/views/hotel/search_hotels/booking_hotel/booking_controller.dart';
import 'package:ready_flights/views/hotel/search_hotels/booking_hotel/booking_voucher/booking_voucher.dart';
import 'package:ready_flights/views/hotel/search_hotels/booking_hotel/payment_hotel/abi_webview.dart';
import 'package:ready_flights/views/flight/booking_flight/airblue/flight_print_voucher.dart';
import 'package:ready_flights/views/flight/search_flights/airblue/airblue_flight_model.dart';
import 'package:ready_flights/views/flight/booking_flight/booking_flight_controller.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class PaymentController extends GetxController {
        final BookingController bookingController = Get.put(BookingController());

  var selectedTab = 0.obs;
  var selectedBank = ''.obs;
  var isProcessingPayment = false.obs;

  
  final List<String> banks = [
    'HBL Bank',
    'UBL Bank',
    'Allied Bank',
    'MCB Bank',
    'NBP Bank',
    'Standard Chartered',
    'Askari Bank',
    'Bank Alfalah',
    'Faysal Bank',
    'JS Bank',
  ];

  // Abhipay Configuration
  static const String abhipayBaseUrl = 'https://api.abhipay.com.pk/api/v3';
  static const String authToken = '35117073706643A79CEDB8B192E87F0E';
  
  Timer? _paymentPollingTimer;

  // Flight payment with Abhipay - navigates to FlightBookingDetailsScreen
  Future<bool> processAbhipayPaymentForFlight({
    required double amount,
    required String description,
    required String clientTransactionId,
    required String callbackUrl,
    String currency = 'PKR',
    String language = 'EN',
  }) async {
    try {
      isProcessingPayment.value = true;

      final requestData = {
        "amount": "5",
        // "amount": amount.toStringAsFixed(2),
        "language": language,
        "currency": currency,
        "description": description,
        "clientTransactionId": clientTransactionId,
        "callbackUrl": callbackUrl,
        "cardSave": false,
        "operation": "PURCHASE"
      };

      print('Abhipay Flight Request: ${json.encode(requestData)}');

      final response = await http.post(
        Uri.parse('$abhipayBaseUrl/orders'),
        headers: {
          'Authorization': authToken,
          'Content-Type': 'application/json',
        },
        body: json.encode(requestData),
      );

      print('Abhipay Flight Response Status: ${response.statusCode}');
      print('Abhipay Flight Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (responseData['code'] == '00000') {
          final paymentUrl = responseData['payload']?['paymentUrl'];
          final orderId = responseData['payload']?['orderId'];

          if (paymentUrl != null && paymentUrl.toString().isNotEmpty) {
            _startPaymentPollingForFlight(orderId);
            Get.to(
              () => AbhipayWebView(
                paymentUrl: paymentUrl,
                transactionId: clientTransactionId,
                onPaymentComplete: _stopPollingAndNavigateForFlight,
              ),
            );
            return true;
          } else {
            print('Flight Payment Error: Missing payment URL');
            return false;
          }
        } else {
          print(
            'Flight Payment API error: ${responseData['code']} - ${responseData['message']}',
          );
          return false;
        }
      } else {
        print('Flight Payment HTTP error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Flight Payment Exception: $e');
      return false;
    } finally {
      isProcessingPayment.value = false;
    }
  }

  // Process Abhipay Payment - Fixed version
  Future<bool> processAbhipayPayment({
    required double amount,
    required String description,
    required String clientTransactionId,
    required String callbackUrl,
    String currency = 'PKR',
    String language = 'EN',
  }) async {
    try {
      isProcessingPayment.value = true;
      
      final requestData = {
        "amount": "5",
        // "amount": amount.toStringAsFixed(2),
        "language": language,
        "currency": currency,
        "description": description,
        "clientTransactionId": clientTransactionId,
        "callbackUrl": callbackUrl,
        "cardSave": false,
        "operation": "PURCHASE"
      };

      print('Abhipay Request: ${json.encode(requestData)}');

      final response = await http.post(
        Uri.parse('$abhipayBaseUrl/orders'),
        headers: {
          'Authorization': authToken,
          'Content-Type': 'application/json',
        },
        body: json.encode(requestData),
      );

      print('Abhipay Response Status: ${response.statusCode}');
      print('Abhipay Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        
        // Check if the response is successful
        if (responseData['code'] == '00000') {
          final paymentUrl = responseData['payload']?['paymentUrl'];
          final orderId = responseData['payload']?['orderId'];

          print('Payment URL: $paymentUrl');
          print('Order ID: $orderId');

          if (paymentUrl != null && paymentUrl.toString().isNotEmpty) {
            // Start background polling with orderId
            _startPaymentPolling(orderId);
            
            Get.to(() => AbhipayWebView(
              paymentUrl: paymentUrl,
              transactionId: clientTransactionId,
              onPaymentComplete: _stopPollingAndNavigate,
            ));

            return true;
          } else {
            print('Error: No payment URL in response');
            return false;
          }
        } else {
          print('Error: API returned error code: ${responseData['code']} - ${responseData['message']}');
          return false;
        }
      } else {
        print('Error: HTTP ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Payment Error: $e');
      return false;
    } finally {
      isProcessingPayment.value = false;
    }
  }

  // Fixed polling - use orderId instead of clientTransactionId
  void _startPaymentPolling(String orderId) {
    print('Starting payment polling for Order ID: $orderId');
    
    _paymentPollingTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      try {
        final status = await _getPaymentStatus(orderId);
        print('Polling status for $orderId: $status');
        
        if (status != null) {
          if (status == 'APPROVED' || status == 'COMPLETED') {
            // FIX: Update payment status IMMEDIATELY when approved
       bookingController.payment_status.value = "APPROVED";
            bookingController.payment_status.refresh(); // Force UI update
            
            print('✅ PAYMENT SUCCESS: Order ID = $orderId, Status = $status');
            print('✅ Payment status updated to: ${bookingController.payment_status.value}');
            
            timer.cancel();
            _navigateToSuccess(orderId);
          } else if (status == 'DECLINED' || status == 'FAILED' || status == 'CANCELLED') {
            // Update status for failed payments too
            bookingController.payment_status.value = "FAILED";
            bookingController.payment_status.refresh(); // Force UI update
            
            print('❌ PAYMENT FAILED: Order ID = $orderId, Status = $status');
            timer.cancel();
            _navigateToFailure();
          } else {
            // Update status for pending states
            bookingController.payment_status.value= status ?? "PENDING";
            bookingController.payment_status.refresh(); // Force UI update
            print('🔄 Payment still processing: $status');
          }
          // Continue polling for CREATED, PENDING, or other statuses
        }
      } catch (e) {
        print('Polling error: $e');
        // Continue polling on error
      }
    });

    // Stop polling after 10 minutes (increased timeout)
    Timer(Duration(minutes: 10), () {
      if (_paymentPollingTimer?.isActive == true) {
        print('Payment polling timeout for $orderId');
        _paymentPollingTimer?.cancel();
      }
    });
  }

  // Get payment status from API - use orderId
  Future<String?> _getPaymentStatus(String orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$abhipayBaseUrl/orders/$orderId'),
        headers: {
          'Authorization': authToken,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Status check response: ${response.body}');
        
        if (responseData['code'] == '00000') {
          return responseData['payload']?['paymentStatus'];
        } else {
          print('Status check error: ${responseData['message']}');
          return null;
        }
      } else {
        print('Status check HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Status check exception: $e');
      return null;
    }
  }

  // Stop polling and handle navigation - UPDATED
  void _stopPollingAndNavigate(bool success) {
    print('Stopping polling, success: $success');
    _paymentPollingTimer?.cancel();
    
    if (success) {
      // FIX: Also update status when WebView reports success
      bookingController.payment_status.value = "APPROVED";
      bookingController.payment_status.refresh(); // Force UI update
      print('✅ Payment completed successfully via WebView - Status: ${bookingController.payment_status.value}');
    } else {
      bookingController.payment_status.value = "FAILED";
      bookingController.payment_status.refresh(); // Force UI update
      print('❌ Payment failed via WebView - Status: ${bookingController.payment_status.value}');
    }
  }

  void _navigateToSuccess(String orderId) {
    if (!Get.currentRoute.contains('HotelBookingThankYouScreen')) {
      print('Navigating to success screen for Order ID: $orderId');
      Get.offAll(() => HotelBookingThankYouScreen(), arguments: {
        'paymentMethod': 'Card Payment (Abhipay)',
        'transactionId': orderId,
        'paymentStatus': 'Success',
      });
    }
  }

  void _navigateToFailure() {
    if (Get.currentRoute.contains('AbhipayWebView')) {
      Get.back();
      Get.snackbar(
        'Payment Failed',
        'Payment was not successful. Please try again.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 5),
      );
    }
  }

  // Flight payment helpers ---------------------------------------------------
  void _startPaymentPollingForFlight(String orderId) {
    print('Starting flight payment polling for $orderId');

    _paymentPollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final status = await _getPaymentStatus(orderId);
        print('Flight payment status ($orderId): $status');

        if (status != null) {
          if (status == 'APPROVED' || status == 'COMPLETED') {
            timer.cancel();
            _navigateToFlightSuccess(orderId);
          } else if (status == 'DECLINED' || status == 'FAILED' || status == 'CANCELLED') {
            timer.cancel();
            _navigateToFlightFailure();
          }
        }
      } catch (e) {
        print('Flight polling error: $e');
      }
    });

    Timer(const Duration(minutes: 10), () {
      if (_paymentPollingTimer?.isActive == true) {
        print('Flight payment polling timeout for $orderId');
        _paymentPollingTimer?.cancel();
      }
    });
  }

  void _navigateToFlightSuccess(String orderId) {
    try {
      final flightData = Get.find<FlightPaymentData>();

      List<AirBlueFareOption>? cleanedMulticity;
      if (flightData.multicityFareOptions != null) {
        cleanedMulticity =
            flightData.multicityFareOptions!.whereType<AirBlueFareOption>().toList();
      }

      // Try to get existing booking controller to preserve passenger data
      BookingFlightController? bookingController;
      try {
        bookingController = Get.find<BookingFlightController>();
      } catch (e) {
        // Controller not found, will create new one in FlightBookingDetailsScreen
        bookingController = null;
      }

      Get.offAll(
        () => FlightBookingDetailsScreen(
          outboundFlight: flightData.outboundFlight,
          returnFlight: flightData.returnFlight,
          multicityFlights: flightData.multicityFlights,
          outboundFareOption: flightData.outboundFareOption,
          returnFareOption: flightData.returnFareOption,
          multicityFareOptions: cleanedMulticity,
          pnrResponse: flightData.pnrResponse,
          selectedSeats: flightData.selectedSeats,
          bookingController: bookingController, // Pass controller if found
        ),
      );
    } catch (e) {
      print('Error navigating to flight success: $e');
    }
  }

  void _navigateToFlightFailure() {
    if (Get.currentRoute.contains('AbhipayWebView')) {
      Get.back();
      Get.snackbar(
        'Payment Failed',
        'Payment was not successful. Please try again.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _stopPollingAndNavigateForFlight(bool success) {
    print('Flight payment completion callback. success=$success');
    _paymentPollingTimer?.cancel();

    if (success) {
      _navigateToFlightSuccess('');
    } else {
      _navigateToFlightFailure();
    }
  }

  // Verify payment status (manual check) - use orderId
  Future<Map<String, dynamic>?> verifyPaymentStatus(String orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$abhipayBaseUrl/orders/$orderId'),
        headers: {
          'Authorization': authToken,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['code'] == '00000') {
          final status = data['payload']?['paymentStatus'];
          
          // Only print the essential success information
          if (status == 'APPROVED' || status == 'COMPLETED') {
            print('Payment Success - Order ID: $orderId - Status: $status');
          }
          
          return data;
        } else {
          print('Verify payment error: ${data['message']}');
          return null;
        }
      }
      return null;
    } catch (e) {
      print('Verify payment exception: $e');
      return null;
    }
  }

  // ADDED METHOD to manually refresh status
  void updatePaymentStatus(String newStatus) {
    bookingController.payment_status.value = newStatus;
    bookingController.payment_status..refresh();
    update(); // Force GetX controller update
    print('📱 Payment status manually updated to: $newStatus');
  }

  @override
  void onClose() {
    _paymentPollingTimer?.cancel();
    super.onClose();
  }

  Future<void> _launchPaymentUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'Could not launch payment URL';
      }
    } catch (e) {
      print('Error launching payment URL: $e');
      Get.snackbar(
        'Payment Error',
        'Could not open payment page',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    }
  }
}

class FlightPaymentData {
  final AirBlueFlight outboundFlight;
  final AirBlueFlight? returnFlight;
  final List<AirBlueFlight>? multicityFlights;
  final AirBlueFareOption? outboundFareOption;
  final AirBlueFareOption? returnFareOption;
  final List<AirBlueFareOption?>? multicityFareOptions;
  final Map<String, dynamic> pnrResponse;
  final Map<int, String>? selectedSeats;

  FlightPaymentData({
    required this.outboundFlight,
    this.returnFlight,
    this.multicityFlights,
    this.outboundFareOption,
    this.returnFareOption,
    this.multicityFareOptions,
    required this.pnrResponse,
    this.selectedSeats,
  });
}