import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ready_flights/views/hotel/search_hotels/booking_hotel/booking_controller.dart';
import 'package:ready_flights/views/hotel/search_hotels/booking_hotel/booking_voucher/booking_voucher.dart';
import 'package:ready_flights/views/hotel/search_hotels/booking_hotel/payment_hotel/payment_controller.dart';
import 'package:ready_flights/views/hotel/search_hotels/booking_hotel/payment_hotel/payment_method.dart';
import 'package:ready_flights/widgets/colors.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AbhipayWebView extends StatefulWidget {
  final String paymentUrl;
  final String? orderId;
  final String transactionId;
  final String? callbackUrl;
  final Function(bool success)? onPaymentComplete;

  const AbhipayWebView({
    Key? key,
    required this.paymentUrl,
    this.orderId,
    required this.transactionId,
    this.callbackUrl,
    this.onPaymentComplete,
  }) : super(key: key);

  @override
  State<AbhipayWebView> createState() => _AbhipayWebViewState();
}

class _AbhipayWebViewState extends State<AbhipayWebView> {
  late final WebViewController controller;
  bool _completionHandled = false;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('Navigation URL: ${request.url}');

            if (_completionHandled || _verifying) {
              return NavigationDecision.prevent;
            }

            final uri = Uri.parse(request.url);
            final params = uri.queryParameters;
            debugPrint('URL Parameters: $params');

            // App callback is the strongest success signal in this integration.
            if (_matchesConfiguredCallback(request.url)) {
              _completionHandled = true;
              _handlePaymentSucceeded(request.url);
              return NavigationDecision.prevent;
            }

            if (_isFailureUrl(request.url) || _hasFailureParameters(params)) {
              debugPrint('Failure-like callback detected, verifying with API before failing.');
              _verifying = true;
              _verifyWithAbhipayThenFinish(
                request.url,
                strongSuccessSignal: false,
              );
              return NavigationDecision.prevent;
            }

            if (_isProbablePaymentSuccess(request.url, params)) {
              final isStrongSuccessSignal =
                  _matchesConfiguredCallback(request.url) || _hasSuccessParameters(params);
              _verifying = true;
              _verifyWithAbhipayThenFinish(
                request.url,
                strongSuccessSignal: isStrongSuccessSignal,
              );
              if (_matchesConfiguredCallback(request.url) ||
                  _hasSuccessParameters(params)) {
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            }

            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Error: ${error.description}');
          },
          onPageFinished: (String url) {
            debugPrint('Page finished loading: $url');
            if (_completionHandled || _verifying) return;

            final uri = Uri.parse(url);
            final params = uri.queryParameters;

            if (_matchesConfiguredCallback(url)) {
              _completionHandled = true;
              _handlePaymentSucceeded(url);
              return;
            }

            if (_isFailureUrl(url) || _hasFailureParameters(params)) {
              debugPrint('Failure-like page detected, verifying with API before failing.');
              _verifying = true;
              _verifyWithAbhipayThenFinish(
                url,
                strongSuccessSignal: false,
              );
              return;
            }

            if (_isProbablePaymentSuccess(url, params)) {
              final isStrongSuccessSignal =
                  _matchesConfiguredCallback(url) || _hasSuccessParameters(params);
              _verifying = true;
              _verifyWithAbhipayThenFinish(
                url,
                strongSuccessSignal: isStrongSuccessSignal,
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  /// Only treat explicit success signals as candidates; confirm with AbhiPay API before completing.
  bool _isProbablePaymentSuccess(String url, Map<String, String> params) {
    if (_hasSuccessParameters(params)) return true;
    if (_matchesConfiguredCallback(url)) return true;
    final u = url.toLowerCase();
    return u.contains('thankyousuccesshotel.php') || u.contains('payment-success');
  }

  bool _matchesConfiguredCallback(String url) {
    final cb = widget.callbackUrl;
    if (cb == null || cb.isEmpty) return false;
    try {
      final configured = Uri.parse(cb);
      final current = Uri.parse(url);
      if (configured.scheme != current.scheme) return false;
      if (configured.host != current.host) return false;
      if (configured.path.isNotEmpty && configured.path != current.path) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isFailureUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('payment-failed') ||
        u.contains('payment-error') ||
        u.contains('status=failed') ||
        u.contains('payment_status=declined');
  }

  bool _hasSuccessParameters(Map<String, String> params) {
    return params['paymentok'] == '1' ||
        params['status']?.toLowerCase() == 'success' ||
        params['payment_status']?.toLowerCase() == 'approved' ||
        params['success'] == 'true' ||
        params['result']?.toLowerCase() == 'approved' ||
        params['transaction_status']?.toLowerCase() == 'approved';
  }

  bool _hasFailureParameters(Map<String, String> params) {
    return params['paymentok'] == '0' ||
        params['status']?.toLowerCase() == 'failed' ||
        params['payment_status']?.toLowerCase() == 'declined' ||
        params['success'] == 'false' ||
        params['result']?.toLowerCase() == 'declined' ||
        params['transaction_status']?.toLowerCase() == 'failed';
  }

  Future<void> _verifyWithAbhipayThenFinish(
    String url, {
    required bool strongSuccessSignal,
  }) async {
    try {
      final paymentController = Get.find<PaymentController>();
      final result = await paymentController.confirmAbhipayPaymentSettled(
        orderId: widget.orderId,
        clientTransactionId: widget.transactionId,
      );
      debugPrint('Abhipay verification result: $result for txn=${widget.transactionId}, order=${widget.orderId}');
      if (!mounted) return;
      _verifying = false;
      if (_completionHandled) return;
      if (result == AbhipayVerificationResult.success) {
        _completionHandled = true;
        _handlePaymentSucceeded(url);
      } else if (result == AbhipayVerificationResult.failed) {
        _completionHandled = true;
        _handlePaymentFailed();
      } else if (strongSuccessSignal) {
        // Gateway sometimes stays on CREATED even after callback success.
        // If we got our registered success callback, do not bounce user back.
        _completionHandled = true;
        debugPrint('Pending status with success callback; proceeding as success.');
        _handlePaymentSucceeded(url);
      } else {
        // Still pending on gateway side; keep polling in controller and don't mark failed.
        Get.snackbar(
          'Payment Processing',
          'Your payment is still processing. We will confirm shortly.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      debugPrint('Abhipay verify error: $e');
      if (!mounted) return;
      _verifying = false;
      if (_completionHandled) return;
      _completionHandled = true;
      _handlePaymentFailed();
    }
  }

  void _handlePaymentSucceeded(String url) {
    final uri = Uri.parse(url);
    final params = uri.queryParameters;
    final sessionId = params['s_id'] ?? params['session_id'] ?? params['sessionId'];
    final transactionId =
        params['transaction_id'] ?? params['transactionId'] ?? widget.transactionId;

    final isFlightPayment = transactionId.startsWith('FK_');

    debugPrint('✅ PAYMENT SUCCESS (verified): Transaction ID: $transactionId');

    if (isFlightPayment) {
      widget.onPaymentComplete?.call(true);
      return;
    }

    try {
      Get.put(BookingController());
      final paymentController = Get.find<PaymentController>();
      paymentController.updatePaymentStatus('APPROVED');
    } catch (e) {
      debugPrint('Could not update payment controller: $e');
    }

    widget.onPaymentComplete?.call(true);

    Get.offAll(() => HotelBookingThankYouScreen(), arguments: {
      'paymentMethod': 'Card Payment (Abhipay)',
      'transactionId': transactionId,
      'paymentStatus': 'Success',
      'sessionId': sessionId,
      'successUrl': url,
    });
  }

  void _handlePaymentFailed() {
    final transactionId = widget.transactionId;
    final isFlightPayment = transactionId.startsWith('FK_');

    debugPrint('❌ PAYMENT NOT COMPLETED: Transaction ID: $transactionId');

    if (isFlightPayment) {
      widget.onPaymentComplete?.call(false);
      return;
    }

    try {
      final paymentController = Get.find<PaymentController>();
      paymentController.updatePaymentStatus('FAILED');
    } catch (e) {
      debugPrint('Could not update payment controller: $e');
    }

    widget.onPaymentComplete?.call(false);

    Get.offAll(() => const HotelPaymentScreen());
    Get.snackbar(
      'Payment Failed',
      'Payment was not completed. Please try again.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
    );
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
            if (!_completionHandled) {
              _completionHandled = true;
              widget.onPaymentComplete?.call(false);
            }
            if (widget.transactionId.startsWith('FK_')) {
              Get.back();
              return;
            }
            Get.offAll(() => const HotelPaymentScreen());
          },
        ),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            WebViewWidget(controller: controller),
            if (_verifying)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66000000),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Verifying payment…'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
