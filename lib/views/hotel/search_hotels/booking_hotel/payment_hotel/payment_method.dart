import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:ready_flights/utility/colors.dart';
import 'package:ready_flights/views/hotel/search_hotels/booking_hotel/booking_voucher/booking_voucher.dart';
import 'package:ready_flights/views/hotel/search_hotels/booking_hotel/payment_hotel/payment_controller.dart';
import 'package:ready_flights/views/hotel/search_hotels/search_hotel_controller.dart';
import 'package:ready_flights/views/hotel/search_hotels/select_room/controller/select_room_controller.dart';
import 'package:ready_flights/widgets/snackbar.dart';
import '../../../hotel/hotel_date_controller.dart';

class HotelPaymentScreen extends StatefulWidget {
  const HotelPaymentScreen({super.key});

  @override
  State<HotelPaymentScreen> createState() => _HotelPaymentScreenState();
}

class _HotelPaymentScreenState extends State<HotelPaymentScreen>
    with TickerProviderStateMixin {
  final PaymentController paymentController = Get.put(PaymentController());
  final HotelDateController dateController = Get.find<HotelDateController>();
  final SelectRoomController selectRoomController = Get.find<SelectRoomController>();
  final SearchHotelController searchHotelController = Get.find<SearchHotelController>();

  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1 - _fadeAnimation.value)),
                    child: Obx(() => _buildTabContent()),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      surfaceTintColor: TColors.background,
      backgroundColor: TColors.background,
      elevation: 0,
      title: const Text(
        "Payment Options",
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Get.back(),
      ),
      centerTitle: false,
    );
  }

  Widget _buildTabBar() {
  return Container(
    margin: const EdgeInsets.all(16),
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
    child: Obx(() => Row(
      children: [
        _buildModernTab(0, "Cash At Office", Icons.store_outlined),
        _buildModernTab(1, "Bank Transfer", Icons.account_balance),
        _buildModernTab(2, "Card Payment", 'assets/images/card.jpg'),
      ],
    )),
  );
}

Widget _buildModernTab(int index, String title, dynamic iconOrImage) {
  final isSelected = paymentController.selectedTab.value == index;
  return Expanded(
    child: GestureDetector(
      onTap: () {
        paymentController.selectedTab.value = index;
        _animationController.reset();
        _animationController.forward();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [TColors.primary, TColors.primary.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: TColors.primary.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Check if it's an image path (String) or IconData
            if (iconOrImage is String)
              Image.asset(
                iconOrImage,
                width: 50,
                height: 20,
              )
            else
              Icon(
                iconOrImage as IconData,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 20,
              ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}Widget _buildTabContent() {
    switch (paymentController.selectedTab.value) {
      case 0:
        return _buildCashAtOfficeTab();
      case 1:
        return _buildBankTransferTab();
      case 2:
        return _buildCardPaymentTab();
      default:
        return _buildCashAtOfficeTab();
    }
  }

  Widget _buildCashAtOfficeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.blue[50]!.withOpacity(0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 25,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          TColors.primary.withOpacity(0.1),
                          TColors.primary.withOpacity(0.05),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: TColors.primary.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      size: 60,
                      color: TColors.primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Visit Our Office',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Complete your payment directly at our office location',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                   const Text(
                    'We will confirm your booking now if the booking is refundable and in case booking is nonrefundable, booking will be confirmed after we receive payment. In this payment option you may lose the selected price during the process of payment.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: TColors.primary.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: TColors.primary.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              color: TColors.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Office Address',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: TColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Travelocity, Majeed Plaza, Al Hamra Town, East Canal Road, Faisalabad, Pakistan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildActionButtons(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBankTransferTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 20),
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
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              TColors.primary.withOpacity(0.1),
                              TColors.primary.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.account_balance,
                          color: TColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Bank Transfer Payment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50]!.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Booking confirmed after payment verification',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'We will confirm your booking now if the booking is refundable and in case booking is nonrefundable, booking will be confirmed after we receive payment. In this payment option you may lose the selected price during the process of payment.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Select Your Bank',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Obx(() => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: paymentController.selectedBank.value.isEmpty 
                            ? null 
                            : paymentController.selectedBank.value,
                        hint: const Text(
                          'Choose your bank',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        items: paymentController.banks.map((String bank) {
                          return DropdownMenuItem<String>(
                            value: bank,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.account_balance, 
                                           color: TColors.primary, size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    bank,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? value) {
                          if (value != null) {
                            paymentController.selectedBank.value = value;
                          }
                        },
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ),
          _buildActionButtons(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCardPaymentTab() {
    final totalAmount = selectRoomController.totalPrice.value;
    final creditCardFee = totalAmount * 0.03;
    final netTotal = totalAmount + creditCardFee;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 20),
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
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pay with Credit Card / Debit Card',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // AbhiPay Logo Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue[50]!,
                          Colors.blue[100]!.withOpacity(0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[700],
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue[700]!.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.payment_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'abhipay',
                                style: TextStyle(
                                  color: Colors.blue[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              const Text(
                                'by payriff',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'SECURE',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Booking Details Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        _buildStyledPaymentRow(
                          'Check In',
                          DateFormat('EEE, dd MMM yyyy').format(dateController.checkInDate.value),
                          Icons.login_rounded,
                        ),
                        const SizedBox(height: 12),
                        _buildStyledPaymentRow(
                          'Check Out',
                          DateFormat('EEE, dd MMM yyyy').format(dateController.checkOutDate.value),
                          Icons.logout_rounded,
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white,
                                Colors.white,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _buildStyledPaymentRow(
                                'Total Amount',
                                'PKR ${totalAmount.toStringAsFixed(0)}',
                                Icons.receipt_long_rounded,
                                isBlue: true,
                              ),
                              const SizedBox(height: 8),
                              _buildStyledPaymentRow(
                                'Credit Card Fee (3%)',
                                'PKR ${creditCardFee.toStringAsFixed(0)}',
                                Icons.credit_card,
                                isRed: true,
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                height: 1,
                                color: Colors.orange[300],
                              ),
                              const SizedBox(height: 16),
                              _buildStyledPaymentRow(
                                'Net Total',
                                'PKR ${netTotal.toStringAsFixed(0)}',
                                Icons.account_balance_wallet_rounded,
                                isBold: true,
                                isLarge: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Payment Processing Indicator
                  Obx(() => paymentController.isProcessingPayment.value 
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Processing payment...',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink()
                  ),
                ],
              ),
            ),
          ),
          _buildActionButtons(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStyledPaymentRow(String label, String value, IconData icon, {
    bool isBlue = false,
    bool isRed = false,
    bool isBold = false,
    bool isLarge = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isBlue 
                ? Colors.blue[100] 
                : isRed 
                    ? Colors.red[100] 
                    : isBold 
                        ? TColors.primary.withOpacity(0.1)
                        : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: isLarge ? 20 : 16,
            color: isBlue 
                ? Colors.blue[700] 
                : isRed 
                    ? Colors.red[700] 
                    : isBold 
                        ? TColors.primary
                        : Colors.grey[600],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isLarge ? 16 : 14,
              color: Colors.grey[700],
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 18 : 14,
            color: isBlue 
                ? Colors.blue[700] 
                : isRed 
                    ? Colors.red[700] 
                    : isBold 
                        ? TColors.primary
                        : Colors.black87,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Obx(() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: paymentController.isProcessingPayment.value 
                      ? null 
                      : () => Get.back(),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_back_rounded, 
                          color: paymentController.isProcessingPayment.value 
                              ? Colors.grey[400] 
                              : Colors.grey
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Back',
                          style: TextStyle(
                            fontSize: 16,
                            color: paymentController.isProcessingPayment.value 
                                ? Colors.grey[400] 
                                : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: paymentController.isProcessingPayment.value
                    ? LinearGradient(
                        colors: [Colors.grey[400]!, Colors.grey[300]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [TColors.primary, TColors.primary.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: paymentController.isProcessingPayment.value
                    ? null
                    : [
                        BoxShadow(
                          color: TColors.primary.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: paymentController.isProcessingPayment.value 
                      ? null 
                      : _handleBookNow,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (paymentController.isProcessingPayment.value)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        else
                          const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          paymentController.isProcessingPayment.value 
                              ? 'Processing...' 
                              : 'Book Now',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ));
  }

  void _handleBookNow() async {
    // Validate inputs based on selected payment method
    if (paymentController.selectedTab.value == 1 && 
        paymentController.selectedBank.value.isEmpty) {
      CustomSnackBar(
        message: "Please select a bank",
        backgroundColor: Colors.red,
      ).show();
      return;
    }

    // Handle different payment methods
    if (paymentController.selectedTab.value == 2) {
      // Card Payment with Abhipay
     await _processAbhipayPayment();
    } else {
      // Cash at Office or Bank Transfer
      _navigateToThankYouPage();
    }
  }


Future<void> _processAbhipayPayment() async {
  final totalAmount = selectRoomController.totalPrice.value;
  final creditCardFee = totalAmount * 0.03;
  final netTotal = totalAmount + creditCardFee;
  
  // Generate a unique transaction ID using timestamp
  final transactionId = 'RFK-${DateTime.now().millisecondsSinceEpoch}';
  final hotelName = searchHotelController.hotelName.value;
  final description = 'Hotel Booking - $hotelName - $transactionId';

  // Use your app's custom scheme for callback
  const callbackUrl = 'readyflights://payment-success';
  
  try {
    final success = await paymentController.processAbhipayPayment(
      amount: netTotal,
      description: description,
      clientTransactionId: transactionId,
      callbackUrl: callbackUrl,
      currency: 'PKR',
      language: 'EN',
    );
    
    if (!success) {
      CustomSnackBar(
        message: "Failed to initiate payment",
        backgroundColor: Colors.red,
      ).show();
    }
  } catch (e) {
    CustomSnackBar(
      message: "Payment failed: ${e.toString()}",
      backgroundColor: Colors.red,
    ).show();
  }
}
void _showPaymentProcessDialog(String transactionId) {
  Get.dialog(
    AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[600]),
          const SizedBox(width: 12),
          const Text('Payment in Progress'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You will be redirected to the Abhipay payment gateway. Please complete your payment and return to the app.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Transaction ID: $transactionId',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Get.back();
            // Navigate to payment status page where user can check status
            // You need to pass orderId here, not transactionId
            // _navigateToPaymentStatusPage(orderId); 
            // Since we don't have orderId in this context, you might want to 
            // modify this approach or store orderId globally
          },
          child: const Text('Continue'),
        ),
      ],
    ),
    barrierDismissible: false,
  );
}

  void _navigateToPaymentStatusPage(String orderId) {
  Get.to(() => PaymentStatusPage(orderId: orderId));
}

  void _navigateToThankYouPage() {
    Get.to(() => HotelBookingThankYouScreen(), arguments: {
      'paymentMethod': _getPaymentMethodString(),
      'selectedBank': paymentController.selectedBank.value,
    });
    
    CustomSnackBar(
      message: "Booking Confirmed Successfully!",
      backgroundColor: Colors.green,
    ).show();
  }

  String _getPaymentMethodString() {
    switch (paymentController.selectedTab.value) {
      case 0:
        return 'Cash At Office';
      case 1:
        return 'Bank Transfer';
      case 2:
        return 'Card Payment (Abhipay)';
      default:
        return 'Cash At Office';
    }
  }
}

// Payment Status Page to handle payment verification
class PaymentStatusPage extends StatefulWidget {
  final String orderId; // Changed from transactionId to orderId
  
  const PaymentStatusPage({Key? key, required this.orderId}) : super(key: key);

  @override
  State<PaymentStatusPage> createState() => _PaymentStatusPageState();
}

class _PaymentStatusPageState extends State<PaymentStatusPage> {
  final PaymentController paymentController = Get.find<PaymentController>();
  bool isChecking = false;
  String? paymentStatus;

  @override
  void initState() {
    super.initState();
    _checkPaymentStatus();
  }

  Future<void> _checkPaymentStatus() async {
    setState(() {
      isChecking = true;
    });

    try {
      final result = await paymentController.verifyPaymentStatus(widget.orderId);
      
      if (result != null) {
        final status = result['payload']?['paymentStatus'];
        setState(() {
          paymentStatus = status ?? 'Unknown';
          isChecking = false;
        });

        // Handle different payment statuses
        if (status == 'APPROVED' || status == 'COMPLETED') {
          // Payment successful
          Get.offAll(() => HotelBookingThankYouScreen(), arguments: {
            'paymentMethod': 'Card Payment (Abhipay)',
            'transactionId': widget.orderId,
            'paymentStatus': 'Success',
          });
        } else if (status == 'DECLINED' || status == 'FAILED' || status == 'CANCELLED') {
          // Payment failed
          _showPaymentFailedDialog();
        }
      } else {
        setState(() {
          paymentStatus = 'Unable to verify';
          isChecking = false;
        });
      }
    } catch (e) {
      setState(() {
        paymentStatus = 'Error checking status';
        isChecking = false;
      });
    }
  }

  void _showPaymentFailedDialog() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[600]),
            const SizedBox(width: 12),
            const Text('Payment Failed'),
          ],
        ),
        content: const Text(
          'Your payment could not be processed. Please try again or choose a different payment method.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back(); // Close dialog
              Get.back(); // Go back to payment screen
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: TColors.background,
        backgroundColor: TColors.background,
        elevation: 0,
        title: const Text(
          'Payment Status',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isChecking) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                const Text(
                  'Checking payment status...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ] else ...[
                Icon(
                  paymentStatus == 'APPROVED' || paymentStatus == 'COMPLETED'
                      ? Icons.check_circle
                      : Icons.error,
                  size: 80,
                  color: paymentStatus == 'APPROVED' || paymentStatus == 'COMPLETED'
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(height: 24),
                Text(
                  'Payment Status: $paymentStatus',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Order ID',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.orderId,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _checkPaymentStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Refresh Status'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Back to Payment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}