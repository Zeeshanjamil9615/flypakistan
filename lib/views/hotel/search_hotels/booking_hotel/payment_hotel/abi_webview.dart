import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ready_flights/views/hotel/search_hotels/booking_hotel/booking_controller.dart';
import 'package:ready_flights/views/hotel/search_hotels/booking_hotel/booking_voucher/booking_voucher.dart';
import 'package:ready_flights/views/hotel/search_hotels/booking_hotel/payment_hotel/payment_controller.dart';
import 'package:ready_flights/widgets/colors.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AbhipayWebView extends StatefulWidget {
  final String paymentUrl;
  final String transactionId;
  final Function(bool success)? onPaymentComplete;
  
  const AbhipayWebView({
    Key? key, 
    required this.paymentUrl, 
    required this.transactionId, 
    this.onPaymentComplete
  }) : super(key: key);

  @override
  State<AbhipayWebView> createState() => _AbhipayWebViewState();
}

class _AbhipayWebViewState extends State<AbhipayWebView> {
  late final WebViewController controller;
  bool _isPaymentProcessed = false;

  @override
  void initState() {
    super.initState();
    
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            // Log every URL to catch the success response
            debugPrint('Navigation URL: ${request.url}');
            
            // Prevent duplicate processing
            if (_isPaymentProcessed) return NavigationDecision.prevent;
            
            // Parse URL parameters
            final uri = Uri.parse(request.url);
            final params = uri.queryParameters;
            
            // Check all parameters for success indicators
            debugPrint('URL Parameters: $params');
            
            // Check for success redirect URL OR success parameters
            if (_isSuccessUrl(request.url) || _hasSuccessParameters(params)) {
              _isPaymentProcessed = true;
              _handlePaymentResult(request.url, true);
              return NavigationDecision.prevent;
            }
            
            // Check for failure indicators
            if (_isFailureUrl(request.url) || _hasFailureParameters(params)) {
              _isPaymentProcessed = true;
              _handlePaymentResult(request.url, false);
              return NavigationDecision.prevent;
            }
            
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Error: ${error.description}');
          },
          onPageFinished: (String url) {
            debugPrint('Page finished loading: $url');
            
            // Double-check for success/failure on page load
            if (!_isPaymentProcessed) {
              final uri = Uri.parse(url);
              final params = uri.queryParameters;
              
              if (_isSuccessUrl(url) || _hasSuccessParameters(params)) {
                _isPaymentProcessed = true;
                _handlePaymentResult(url, true);
              } else if (_isFailureUrl(url) || _hasFailureParameters(params)) {
                _isPaymentProcessed = true;
                _handlePaymentResult(url, false);
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  bool _isSuccessUrl(String url) {
    return url.contains('thankyousuccesshotel.php') || 
           url.contains('readyflights.pk') ||
           url.contains('payment-success') ||
           url.contains('/success') ||
           url.contains('/complete') ||
           url.contains('status=success') ||
           url.contains('payment_status=approved');
  }

  bool _isFailureUrl(String url) {
    return url.contains('payment-failed') ||
           url.contains('payment-error') ||
           url.contains('/failed') ||
           url.contains('/error') ||
           url.contains('status=failed') ||
           url.contains('payment_status=declined');
  }

  bool _hasSuccessParameters(Map<String, String> params) {
    // Check for success in any parameter
    return params['paymentok'] == '1' ||
           params['status']?.toLowerCase() == 'success' ||
           params['payment_status']?.toLowerCase() == 'approved' ||
           params['success'] == 'true' ||
           params['result']?.toLowerCase() == 'approved' ||
           params['transaction_status']?.toLowerCase() == 'approved';
  }

  bool _hasFailureParameters(Map<String, String> params) {
    // Check for failure in any parameter
    return params['paymentok'] == '0' ||
           params['status']?.toLowerCase() == 'failed' ||
           params['payment_status']?.toLowerCase() == 'declined' ||
           params['success'] == 'false' ||
           params['result']?.toLowerCase() == 'declined' ||
           params['transaction_status']?.toLowerCase() == 'failed';
  }

  // UPDATED METHOD with PaymentController status update
  void _handlePaymentResult(String url, bool isSuccess) {
    final uri = Uri.parse(url);
    final params = uri.queryParameters;
    
    // Extract useful information from URL
    final sessionId = params['s_id'] ?? params['session_id'] ?? params['sessionId'];
    final transactionId = params['transaction_id'] ?? params['transactionId'] ?? widget.transactionId;
    
    final isFlightPayment = transactionId.startsWith('FK_');
    
    if (isSuccess) {
      debugPrint('✅ PAYMENT SUCCESS: Transaction ID: $transactionId, Session ID: ${sessionId ?? 'N/A'}');
      
      if (isFlightPayment) {
        widget.onPaymentComplete?.call(true);
        return;
      }

      try {
        final BookingController bookingController = Get.put(BookingController());
        final PaymentController paymentController = Get.put(PaymentController());
        paymentController.updatePaymentStatus("APPROVED");
      } catch (e) {
        print('Could not update payment controller: $e');
      }
      
      widget.onPaymentComplete?.call(true);
      
      Get.offAll(() => HotelBookingThankYouScreen(), arguments: {
        'paymentMethod': 'Card Payment (Abhipay)',
        'transactionId': transactionId,
        'paymentStatus': 'Success',
        'sessionId': sessionId,
        'successUrl': url,
      });
    } else {
      debugPrint('❌ PAYMENT FAILED: Transaction ID: $transactionId');
      
      if (isFlightPayment) {
        widget.onPaymentComplete?.call(false);
        return;
      }
      
      try {
        final PaymentController paymentController = Get.find<PaymentController>();
        paymentController.updatePaymentStatus("FAILED");
      } catch (e) {
        print('Could not update payment controller: $e');
      }
      
      widget.onPaymentComplete?.call(false);
      
      Get.back();
      Get.snackbar(
        'Payment Failed',
        'Payment was not successful. Please try again.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        backgroundColor: TColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            widget.onPaymentComplete?.call(false);
            Get.back();
          },
        ),
      ),
      body: SafeArea(
        top: false,
        child: WebViewWidget(controller: controller),
      ),
    );
  }
}