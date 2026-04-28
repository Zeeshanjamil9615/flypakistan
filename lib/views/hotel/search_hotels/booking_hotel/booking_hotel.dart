import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:country_picker/country_picker.dart';
import 'package:ready_flights/views/hotel/search_hotels/booking_hotel/payment_hotel/payment_method.dart';
import 'package:ready_flights/views/hotel/search_hotels/select_room/controller/select_room_controller.dart';
import 'package:ready_flights/views/users/login/login_api_service/login_api.dart';
import 'package:ready_flights/views/users/rejistration/register.dart';
import '../../../../utility/colors.dart';
import '../../../../widgets/snackbar.dart';
import '../../hotel/guests/guests_controller.dart';
import 'booking_controller.dart';
import 'payment_hotel/important_booking_details_card.dart';

class BookingHotelScreen extends StatefulWidget {
  const BookingHotelScreen({super.key});

  @override
  State<BookingHotelScreen> createState() => _BookingHotelScreenState();
}

class _BookingHotelScreenState extends State<BookingHotelScreen> {
  final BookingController bookingController = Get.put(BookingController());
  final GuestsController guestsController = Get.find<GuestsController>();

  bool _promoDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowLoginPromoDialog();
    });
  }

  Future<void> _maybeShowLoginPromoDialog() async {
    if (!mounted || _promoDialogShown) return;

    final authController =
        Get.isRegistered<AuthController>() ? Get.find<AuthController>() : Get.put(AuthController());

    final isLoggedIn = await authController.isLoggedIn();
    if (!mounted) return;

    if (!isLoggedIn) {
      _promoDialogShown = true;
      _showLoginPromoDialog();
    }
  }

  void _showLoginPromoDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/images/logo1.png',
                        height: 48,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 14),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          height: 1.35,
                        ),
                        children: const [
                          TextSpan(text: 'Promo code '),
                          TextSpan(
                            text: 'WELCOME',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: '. Get PKR 500 off.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create an account and use promo code WELCOME and enjoy PKR 500 off on your first booking.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: const Text(
                              'Close',
                              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              Get.to(() => RegisterAccount());
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Sign up & continue',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close, size: 20, color: Colors.black54),
                  splashRadius: 20,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColors.background,
      appBar: AppBar(
        surfaceTintColor: TColors.background,
        backgroundColor: TColors.background,
        elevation: 0,
        title: const Text(
          "Complete Your Booking",
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
      ),
      body: SafeArea(
        top: false,
        child: Obx(
          () => Stack(
            children: [
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ImportantBookingDetailsCard(),
                      const SizedBox(height: 16),
                      _buildRoomCards(),
                      const SizedBox(height: 16),
                      _buildBookerInfoCard(),
                      const SizedBox(height: 16),
                      _buildSpecialRequestsCard(),
                      const SizedBox(height: 16),
                      _buildTermsAndConditions(),
                      const SizedBox(height: 24),
                      _buildSubmitButton(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              if (bookingController.isLoading.value)
                const Center(
                  child: CircularProgressIndicator(color: TColors.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomCards() {
    return Column(
      children: List.generate(
        bookingController.roomGuests.length,
        (roomIndex) => _buildRoomCard(roomIndex),
      ),
    );
  }

  Widget _buildRoomCard(int roomIndex) {
    final roomGuests = bookingController.roomGuests[roomIndex];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Room ${roomIndex + 1}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                _buildBadge("Refundable"),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(
              roomGuests.adults.length,
              (adultIndex) => _buildGuestField(
                guestInfo: roomGuests.adults[adultIndex],
                index: adultIndex,
                isAdult: true,
              ),
            ),
            ...List.generate(
              roomGuests.children.length,
              (childIndex) => _buildGuestField(
                guestInfo: roomGuests.children[childIndex],
                index: childIndex,
                isAdult: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestField({
    required HotelGuestInfo guestInfo,
    required int index,
    required bool isAdult,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAdult ? "Adult ${index + 1}" : "Child ${index + 1}",
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            controller: guestInfo.titleController,
            hint: 'Title',
            items: isAdult ? ['Mr.', 'Mrs.', 'Ms.'] : ['Mstr.', 'Miss.'],
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: guestInfo.firstNameController,
            hint: 'First Name',
            prefixIcon: Icons.person_outline,
            iconColor: TColors.iconclr,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: guestInfo.lastNameController,
            hint: 'Last Name',
            prefixIcon: Icons.person_outline,
            iconColor: TColors.iconclr,
          ),
        ],
      ),
    );
  }

  Widget _buildBookerInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          const Text(
            'Booker Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildDropdown(
            controller: bookingController.titleController,
            hint: 'Title',
            items: ['Mr.', 'Mrs.', 'Ms.'],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: bookingController.firstNameController,
            hint: 'First Name',
            prefixIcon: Icons.person_outline,
            iconColor: TColors.iconclr,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: bookingController.lastNameController,
            hint: 'Last Name',
            prefixIcon: Icons.person_outline,
            iconColor: TColors.iconclr,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: bookingController.emailController,
            hint: 'Email',
            prefixIcon: Icons.email_outlined,
            iconColor: TColors.iconclr,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _buildPhoneFieldWithCountryPicker(),
        ],
      ),
    );
  }

  Widget _buildPhoneFieldWithCountryPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
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
          child: Row(
            children: [
              // Country Code Picker
              Obx(() {
                return InkWell(
                  onTap: () {
                    showCountryPicker(
                      context: Get.context!,
                      showPhoneCode: true,
                      searchAutofocus: true,
                      showSearch: true,
                      exclude: <String>['KN', 'MF'], // Optional: exclude specific countries
                      favorite: <String>['PK', 'US', 'GB', 'IN', 'SA', 'AE'], // Optional: show favorite countries at top
                      countryListTheme: CountryListThemeData(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(40.0),
                          topRight: Radius.circular(40.0),
                        ),
                        inputDecoration: InputDecoration(
                          labelText: 'Search',
                          hintText: 'Start typing to search',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: const Color(0xFF8C98A8).withOpacity(0.2),
                            ),
                          ),
                        ),
                        searchTextStyle: const TextStyle(
                          color: Colors.blue,
                          fontSize: 18,
                        ),
                      ),
                      onSelect: (Country country) {
                        bookingController.selectedCountry.value = country;
                      },
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          bookingController.selectedCountry.value.flagEmoji,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '+${bookingController.selectedCountry.value.phoneCode}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 20),
                      ],
                    ),
                  ),
                );
              }),
              // Phone Number Field
              Expanded(
                child: TextField(
                  controller: bookingController.phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    hintText: 'Phone Number',
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialRequestsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          const Text(
            'Special Requests',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: bookingController.specialRequestsController,
            hint: 'Enter any special requests',
            prefixIcon: Icons.note_add_outlined,
            iconColor: TColors.iconclr,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Obx(
            () => Column(
              children: [
                _buildCheckboxTile(
                  'Ground Floor',
                  bookingController.isGroundFloor.value,
                  (value) => bookingController.isGroundFloor.value = value!,
                ),
                _buildCheckboxTile(
                  'High Floor',
                  bookingController.isHighFloor.value,
                  (value) => bookingController.isHighFloor.value = value!,
                ),
                _buildCheckboxTile(
                  'Late Checkout',
                  bookingController.isLateCheckout.value,
                  (value) => bookingController.isLateCheckout.value = value!,
                ),
                _buildCheckboxTile(
                  'Early Checkin',
                  bookingController.isEarlyCheckin.value,
                  (value) => bookingController.isEarlyCheckin.value = value!,
                ),
                _buildCheckboxTile(
                  'Twin Bed',
                  bookingController.isTwinBed.value,
                  (value) => bookingController.isTwinBed.value = value!,
                ),
                _buildCheckboxTile(
                  'Smoking Room',
                  bookingController.isSmoking.value,
                  (value) => bookingController.isSmoking.value = value!,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsAndConditions() {
    return Obx(
      () => CheckboxListTile(
        title: const Text(
          'I accept the terms and conditions',
          style: TextStyle(fontSize: 14, color: Colors.black87),
        ),
        value: bookingController.acceptedTerms.value,
        onChanged: (value) => bookingController.acceptedTerms.value = value!,
        activeColor: TColors.primary,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildTextField({
    TextEditingController? controller,
    required String hint,
    required IconData prefixIcon,
    required Color iconColor,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
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
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: Icon(prefixIcon, color: iconColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required TextEditingController controller,
    required String hint,
    required List<String> items,
  }) {
    return Container(
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
      child: DropdownButtonFormField<String>(
        value: controller.text.isEmpty ? null : controller.text,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        hint: Text(
          hint,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        items: items.map((String value) {
          return DropdownMenuItem<String>(value: value, child: Text(value));
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            controller.text = value;
          }
        },
      ),
    );
  }

  Widget _buildCheckboxTile(
    String title,
    bool value,
    Function(bool?) onChanged,
  ) {
    return CheckboxListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade700,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: TColors.primary,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: () {
          _handleSubmit();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: TColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: const Text(
          'Complete Booking',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

 void _handleSubmit() async {
  try {
    bookingController.isLoading.value = true;

    String? validationError = bookingController.getValidationError();
    if (validationError != null) {
      CustomSnackBar(
        message: validationError,
        backgroundColor: Colors.red,
      ).show();
      return;
    }

    final bool success = await bookingController.saveHotelBookingToDB();

    if (success) {
      // Get the selected rooms from SelectRoomController
      final SelectRoomController selectRoomController = Get.find<SelectRoomController>();
      selectRoomController.debugPrintRoomData();
      
      // Create a map of selected room data
      Map<int, Map<String, dynamic>> selectedRoomsData = {};
      
      for (int i = 0; i < selectRoomController.roomNames.length; i++) {
        if (selectRoomController.roomNames.containsKey(i)) {
          selectedRoomsData[i] = {
            'roomName': selectRoomController.getRoomName(i),
            'meal': selectRoomController.getRoomMeal(i),
            'rateType': selectRoomController.getRateType(i),
            'price': selectRoomController.getRoomPrice(i),
          };
        }
      }

      Get.to(() => const HotelPaymentScreen(), 
        arguments: {
          'selectedRooms': selectedRoomsData,
        }
      );
      
      CustomSnackBar(
        message: "Booking Confirmed Successfully!",
        backgroundColor: Colors.green,
      ).show();
    } else {
      CustomSnackBar(
        message: "Booking failed. Please try again.",
        backgroundColor: Colors.red,
      ).show();
    }
  } catch (e) {
    CustomSnackBar(
      message: "An error occurred. Please try again.",
      backgroundColor: Colors.red,
    ).show();
  } finally {
    bookingController.isLoading.value = false;
  }
} Widget _buildBadge(String text) {
    final isRefundable = text.toLowerCase() == 'refundable';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isRefundable ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isRefundable ? Colors.green.shade700 : Colors.red.shade700,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}