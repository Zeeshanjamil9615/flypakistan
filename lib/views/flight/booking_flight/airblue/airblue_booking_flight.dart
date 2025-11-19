// ignore_for_file: unused_local_variable

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:country_picker/country_picker.dart';
import 'package:ready_flights/views/flight/booking_flight/airblue/select_seat.dart';
import 'package:ready_flights/views/flight/booking_flight/airblue/airblue_addons_screen.dart';
import '../../../../../services/api_service_airblue.dart';
import '../../../../../utility/colors.dart';
import '../../../../../utility/app_constants.dart';
import '../../../../../widgets/travelers_selection_bottom_sheet.dart';
import '../../search_flights/airblue/airblue_flight_controller.dart';
import '../../search_flights/airblue/airblue_flight_model.dart';
import '../../search_flights/airblue/airblue_pnr_pricing.dart';
import '../booking_flight_controller.dart';
import 'flight_print_voucher.dart';
import '../../../users/login/login.dart';
import '../../../users/rejistration/register.dart';
import '../../../users/login/login_api_service/login_api.dart';

class AirBlueBookingFlight extends StatefulWidget {
  final AirBlueFlight flight;
  final AirBlueFlight? returnFlight;
  final List<AirBlueFlight>? multicityFlights;
  final double totalPrice;
  final String currency;
  final AirBlueFareOption? outboundFareOption;
  final AirBlueFareOption? returnFareOption;
  final List<AirBlueFareOption?>? multicityFareOptions;


  const AirBlueBookingFlight({
    super.key,
    required this.flight,
    this.returnFlight,
    this.multicityFlights,
    required this.totalPrice,
    required this.currency,
    this.outboundFareOption,
    this.returnFareOption,
    this.multicityFareOptions,
  });

  @override
  State<AirBlueBookingFlight> createState() => _AirBlueBookingFlightState();
}

class _AirBlueBookingFlightState extends State<AirBlueBookingFlight> {
  final _formKey = GlobalKey<FormState>();
  final BookingFlightController bookingController = Get.put(
    BookingFlightController(),
  );
  final TravelersController travelersController = Get.put(
    TravelersController(),
  );
  final AirBlueFlightController flightController =
  Get.find<AirBlueFlightController>();
  final AuthController authController = Get.find<AuthController>();

  bool termsAccepted = false;
  final Map<TextEditingController, _DateSelectionState> _dateSelections = {};
  final RxInt _secondsLeft = (4 * 60 * 60).obs;
  Timer? _countdownTimer;
  bool _loginDialogVisible = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginStatus();
    });
  }

  void _fillDummyData() {
    final bookerFirstName = TestDataPool.randomFirstName();
    final bookerLastName = TestDataPool.randomLastName();

    // Fill booker information with random data
    bookingController.firstNameController.text = bookerFirstName;
    bookingController.lastNameController.text = bookerLastName;
    bookingController.emailController.text = TestDataPool.randomEmail(bookerFirstName, bookerLastName);
    bookingController.phoneController.text = TestDataPool.randomPhone();
    bookingController.remarksController.text = "Test booking ${DateTime.now().millisecondsSinceEpoch}";
    bookingController.bookerPhoneCountry.value = Country.parse('PK');

    // Fill adult travelers with random data
    for (int i = 0; i < bookingController.adults.length; i++) {
      final adult = bookingController.adults[i];
      final gender = TestDataPool.randomGender();
      final firstName = TestDataPool.randomFirstName();
      final lastName = TestDataPool.randomLastName();

      adult.titleController.text = TestDataPool.randomTitle(gender);
      adult.firstNameController.text = firstName;
      adult.lastNameController.text = lastName;
      adult.passportCnicController.text = bookingController.isDomesticFlight
          ? TestDataPool.randomCNIC()
          : TestDataPool.randomPassport();
      adult.nationalityController.text = "Pakistan";
      adult.nationalityCountry.value = Country.parse('PK');
      adult.dateOfBirthController.text = TestDataPool.randomDate(18, 65);
      adult.passportExpiryController.text = "203${Random().nextInt(5) + 5}-12-31";
      adult.genderController.text = gender;
      adult.phoneController.text = TestDataPool.randomPhone();
      adult.phoneCountry.value = Country.parse('PK');
      adult.emailController.text = TestDataPool.randomEmail(firstName, lastName);
    }

    // Fill child travelers with random data
    for (int i = 0; i < bookingController.children.length; i++) {
      final child = bookingController.children[i];
      final gender = TestDataPool.randomGender();
      final firstName = TestDataPool.randomFirstName();
      final lastName = TestDataPool.randomLastName();

      child.titleController.text = TestDataPool.randomChildTitle(gender);
      child.firstNameController.text = firstName;
      child.lastNameController.text = lastName;
      child.passportCnicController.text = bookingController.isDomesticFlight
          ? TestDataPool.randomCNIC()
          : TestDataPool.randomPassport();
      child.nationalityController.text = "Pakistan";
      child.nationalityCountry.value = Country.parse('PK');
      child.dateOfBirthController.text = TestDataPool.randomDate(2, 12);
      child.passportExpiryController.text = "203${Random().nextInt(5) + 5}-12-31";
      child.genderController.text = gender;
      child.phoneController.text = "";
      child.emailController.text = "";
    }

    // Fill infant travelers with random data
    for (int i = 0; i < bookingController.infants.length; i++) {
      final infant = bookingController.infants[i];
      final gender = TestDataPool.randomGender();
      final firstName = TestDataPool.randomFirstName();
      final lastName = TestDataPool.randomLastName();

      infant.titleController.text = "Inf";
      infant.firstNameController.text = firstName;
      infant.lastNameController.text = lastName;
      infant.nationalityController.text = "Pakistan";
      infant.nationalityCountry.value = Country.parse('PK');
      infant.dateOfBirthController.text = TestDataPool.randomDate(0, 2);
      infant.genderController.text = gender;
    }

    // Accept terms and conditions
    setState(() {
      termsAccepted = true;
    });

    // Show success message
    Get.snackbar(
      'Success',
      'Form filled with randomized test data',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            // Single tap does nothing, preserving original behavior
          },
          onDoubleTap: () {
            // Double tap fills dummy data
            _fillDummyData();
          },
          child: const Text(
            'Booking Details',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepProgressCard(activeStep: 1),
                const SizedBox(height: 20),
                _buildTravelersForm(),
                const SizedBox(height: 24),
                _buildBookerDetails(),
                const SizedBox(height: 24),
                _buildTermsAndConditions(),
                const SizedBox(height: 100), // Space for bottom bar
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }


  Widget _buildTravelersForm() {
    return Obx(() {
      final adults = List.generate(
        travelersController.adultCount.value,
            (index) => _buildTravelerSection(
          title: 'Adult ${index + 1}',
          isInfant: false,
          type: 'adult',
          index: index,
        ),
      );

      final children = List.generate(
        travelersController.childrenCount.value,
            (index) => _buildTravelerSection(
          title: 'Child ${index + 1}',
          isInfant: false,
          type: 'child',
          index: index,
        ),
      );

      final infants = List.generate(
        travelersController.infantCount.value,
            (index) => _buildTravelerSection(
          title: 'Infant ${index + 1}',
          isInfant: true,
          type: 'infant',
          index: index,
        ),
      );

      return Container(
          margin: EdgeInsets.all(4),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [...adults, ...children, ...infants]));
    });
  }
  Widget _buildTravelerSection({
    required String title,
    required bool isInfant,
    required String type,
    required int index,
  }) {
    TravelerInfo travelerInfo;
    if (type == 'adult') {
      travelerInfo = bookingController.adults[index];
    } else if (type == 'child') {
      travelerInfo = bookingController.children[index];
    } else {
      travelerInfo = bookingController.infants[index];
    }

    final headingText = 'Traveler details for $title';

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getTravelerIcon(type),
                color: TColors.primary,
                size: AppConstants.iconSize,
              ),
              const SizedBox(width: 8),
              Text(
                headingText,
                style: AppConstants.sectionTitleStyle.copyWith(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTitleSelector(
            label: 'Title',
            options: isInfant
                ? ['Inf']
                : (type == 'child' ? ['Mstr', 'Miss'] : ['Mr', 'Mrs', 'Ms']),
            controller: travelerInfo.titleController,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Given Name*',
            controller: travelerInfo.firstNameController,
            isRequired: true,
            helperText:
            'Please ensure your name is as it appears on your Passport.',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Surname*',
            controller: travelerInfo.lastNameController,
            isRequired: true,
            helperText:
            'Please ensure your name is as it appears on your Passport.',
          ),
          const SizedBox(height: 16),
          // _buildDropdownField(
          //   label: 'Gender',
          //   options: ['Male', 'Female'],
          //   controller: travelerInfo.genderController,
          // ),
          // const SizedBox(height: 16),
          _buildDateDropdownField(
            label: 'Date of Birth*',
            controller: travelerInfo.dateOfBirthController,
            isDob: true,
          ),
          if (type == 'adult') ...[
            const SizedBox(height: 16),
            _buildPhoneFieldWithCountryPicker(
              label: 'Phone*',
              phoneController: travelerInfo.phoneController,
              travelerInfo: travelerInfo,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Passenger Email',
              controller: travelerInfo.emailController,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
          const SizedBox(height: 16),
          _buildTextField(
            label: bookingController.isDomesticFlight
                ? 'CNIC Number*'
                : 'Passport Number*',
            controller: travelerInfo.passportCnicController,
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildDateDropdownField(
            label: bookingController.isDomesticFlight
                ? 'CNIC Expiry*'
                : 'Passport Expiry*',
            controller: travelerInfo.passportExpiryController,
            isDob: false,
          ),
          const SizedBox(height: 16),
          _buildNationalityPickerField(
            label: 'Nationality*',
            travelerInfo: travelerInfo,
          ),
        ],
      ),
    );
  }
  Widget _buildBookerDetails() {
    return Container(
      margin: EdgeInsets.all(4),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.badge, color: TColors.primary, size: AppConstants.iconSize),
              const SizedBox(width: 8),
              Text(
                'Booker Information',
                style: AppConstants.sectionTitleStyle.copyWith(
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: 'Given Name*',
            controller: bookingController.firstNameController,
            isRequired: true,
            helperText:
            'Please ensure your name is as it appears on your Passport.',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Surname*',
            controller: bookingController.lastNameController,
            isRequired: true,
            helperText:
            'Please ensure your name is as it appears on your Passport.',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Email*',
            controller: bookingController.emailController,
            keyboardType: TextInputType.emailAddress,
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildBookerPhoneFieldWithCountryPicker(
            label: 'Phone*',
            phoneController: bookingController.phoneController,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Remarks',
            controller: bookingController.remarksController,
            maxLines: 3,
            helperText: 'Optional',
          ),
        ],
      ),
    );
  }

  Widget _buildStepProgressCard({required int activeStep}) {
    final steps = [
      {'label': 'Booking', 'icon': Icons.airplanemode_active},
      {'label': 'Add-ons', 'icon': Icons.event_seat},
      {'label': 'Payment', 'icon': Icons.credit_card},
    ];

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
              for (int i = 0; i < steps.length; i++) ...[
                _buildStepProgressChip(
                  label: steps[i]['label'] as String,
                  icon: steps[i]['icon'] as IconData,
                  index: i + 1,
                  activeStep: activeStep,
                ),
                if (i != steps.length - 1)
                  _buildStepConnector(active: activeStep > i + 1),
              ],
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
                _formatDuration(_secondsLeft.value),
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

  Widget _buildStepConnector({required bool active}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        height: 2,
        color: active ? TColors.primary : Colors.grey[300],
      ),
    );
  }

  Widget _buildStepProgressChip({
    required String label,
    required IconData icon,
    required int index,
    required int activeStep,
  }) {
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

  Widget _buildPhoneFieldWithCountryPicker({
    required String label,
    required TextEditingController phoneController,
    required TravelerInfo travelerInfo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppConstants.fieldValueStyle),
        const SizedBox(height: 6),
        FormField<String>(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) {
            if (phoneController.text.isEmpty) {
              return 'Please enter phone number';
            }
            return null;
          },
          builder: (fieldState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: fieldState.hasError
                          ? Colors.red
                          : AppConstants.fieldBorderColor,
                    ),
                    borderRadius: BorderRadius.circular(
                      AppConstants.borderRadius,
                    ),
                  ),
                  child: Row(
                    children: [
                      Obx(() {
                        final country = travelerInfo.phoneCountry.value;
                        return InkWell(
                          onTap: () {
                            bookingController.showPhoneCountryPicker(
                              context,
                              travelerInfo,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: fieldState.hasError
                                      ? Colors.red
                                      : AppConstants.fieldBorderColor,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  country?.flagEmoji ?? '🇵🇰',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '+${country?.phoneCode ?? '92'}',
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
                      Expanded(
                        child: TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            hintText: 'Phone Number',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (fieldState.hasError) ...[
                  const SizedBox(height: 4),
                  Text(
                    fieldState.errorText ?? '',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBookerPhoneFieldWithCountryPicker({
    required String label,
    required TextEditingController phoneController,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppConstants.fieldValueStyle),
        const SizedBox(height: 6),
        FormField<String>(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) {
            if (phoneController.text.isEmpty) {
              return 'Please enter phone number';
            }
            return null;
          },
          builder: (fieldState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: fieldState.hasError
                          ? Colors.red
                          : AppConstants.fieldBorderColor,
                    ),
                    borderRadius: BorderRadius.circular(
                      AppConstants.borderRadius,
                    ),
                  ),
                  child: Row(
                    children: [
                      Obx(() {
                        final country =
                        bookingController.bookerPhoneCountry.value;
                        return InkWell(
                          onTap: () {
                            bookingController
                                .showBookerPhoneCountryPicker(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: fieldState.hasError
                                      ? Colors.red
                                      : AppConstants.fieldBorderColor,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  country?.flagEmoji ?? '🇵🇰',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '+${country?.phoneCode ?? '92'}',
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
                      Expanded(
                        child: TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            hintText: 'Phone Number',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (fieldState.hasError) ...[
                  const SizedBox(height: 4),
                  Text(
                    fieldState.errorText ?? '',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildNationalityPickerField({
    required String label,
    required TravelerInfo travelerInfo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppConstants.fieldValueStyle),
        const SizedBox(height: 6),
        Obx(() {
          final country = travelerInfo.nationalityCountry.value;
          return InkWell(
            onTap: () {
              bookingController.showNationalityPicker(context, travelerInfo);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppConstants.fieldBorderColor),
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              child: Row(
                children: [
                  Text(
                    country?.flagEmoji ?? '🇵🇰',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      country?.displayNameNoCountryCode ?? 'Select Nationality',
                      style: AppConstants.fieldValueStyle.copyWith(
                        color:
                        country != null ? Colors.black87 : Colors.grey[600],
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTermsAndConditions() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: termsAccepted,
            onChanged: (value) {
              setState(() {
                termsAccepted = value ?? false;
              });
            },
            activeColor: TColors.primary,
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  termsAccepted = !termsAccepted;
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'I read and accept all ',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      TextSpan(
                        text: 'Terms and conditions',
                        style: TextStyle(
                          fontSize: 14,
                          color: TColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false,
    int maxLines = 1,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppConstants.fieldValueStyle),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: AppConstants.fieldValueStyle,
          decoration: _buildInputDecoration(),
          validator: isRequired
              ? (value) {
            if (value == null || value.isEmpty) {
              return _requiredFieldMessage(label);
            }
            return null;
          }
              : null,
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText,
            style: AppConstants.fieldLabelStyle.copyWith(
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  InputDecoration _buildInputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppConstants.fieldValueStyle.copyWith(
        color: Colors.grey[500],
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        borderSide: const BorderSide(color: AppConstants.fieldBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        borderSide: const BorderSide(color: TColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }

  String _requiredFieldMessage(String label) {
    final sanitized = label.replaceAll('*', '').trim();
    return 'Please enter $sanitized';
  }

  Widget _buildDateDropdownField({
    required String label,
    required TextEditingController controller,
    required bool isDob,
  }) {
    final selection = _syncDateSelection(controller);
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppConstants.fieldValueStyle),
        const SizedBox(height: 6),
        FormField<String>(
          validator: (_) {
            final parsedDate = _parseDate(controller.text);
            if (parsedDate == null) {
              return 'Please select $label';
            }
            if (isDob && parsedDate.isAfter(now)) {
              return 'Date cannot be in the future';
            }
            if (!isDob && parsedDate.isBefore(now)) {
              return 'Date cannot be in the past';
            }
            return null;
          },
          builder: (fieldState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    BorderRadius.circular(AppConstants.borderRadius),
                    border:
                    Border.all(color: AppConstants.fieldBorderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildDatePartSelector(
                          placeholder: 'Date',
                          value: selection.day?.toString().padLeft(2, '0'),
                          onTap: () async {
                            await _handleDateSelectionFlow(
                              selection: selection,
                              controller: controller,
                              fieldState: fieldState,
                              isDob: isDob,
                            );
                          },
                          addRightDivider: true,
                        ),
                      ),
                      Expanded(
                        child: _buildDatePartSelector(
                          placeholder: 'Month',
                          value: selection.month != null
                              ? DateFormat.MMM()
                              .format(DateTime(0, selection.month!))
                              : null,
                          onTap: () async {
                            final selected = await _showSelectionDialog<int>(
                              title: 'Select Month',
                              options: List.generate(12, (index) => index + 1),
                              displayBuilder: (value) =>
                                  DateFormat.MMMM().format(DateTime(0, value)),
                            );
                            if (selected != null) {
                              selection.month = selected;
                              _updateDateController(controller, selection);
                              fieldState.didChange(controller.text);
                            }
                          },
                          addRightDivider: true,
                        ),
                      ),
                      Expanded(
                        child: _buildDatePartSelector(
                          placeholder: 'Year',
                          value: selection.year?.toString(),
                          onTap: () async {
                            final years = isDob
                                ? List.generate(120, (index) => now.year - index)
                                : List.generate(30, (index) => now.year + index);
                            final selected = await _showSelectionDialog<int>(
                              title: 'Select Year',
                              options: years,
                              displayBuilder: (value) => value.toString(),
                            );
                            if (selected != null) {
                              selection.year = selected;
                              _updateDateController(controller, selection);
                              fieldState.didChange(controller.text);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (fieldState.hasError) ...[
                  const SizedBox(height: 6),
                  Text(
                    fieldState.errorText ?? '',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildDatePartSelector({
    required String placeholder,
    required Future<void> Function() onTap,
    String? value,
    bool addRightDivider = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: addRightDivider
                ? Border(
              right: BorderSide(color: AppConstants.fieldBorderColor),
            )
                : null,
          ),
          child: Row(
            children: [
              Text(
                value ?? placeholder,
                style: AppConstants.fieldValueStyle.copyWith(
                  fontSize: 12,
                  color: value == null ? Colors.grey[600] : Colors.black,
                ),
              ),
              const Spacer(),
              const Icon(Icons.expand_more, color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<T?> _showSelectionDialog<T>({
    required String title,
    required List<T> options,
    required String Function(T) displayBuilder,
  }) {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          elevation: 4,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: SizedBox(
            height: 550,
            width: double.infinity,
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: options.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Colors.grey.shade200,
              ),
              itemBuilder: (_, index) {
                final option = options[index];
                return InkWell(
                  onTap: () => Navigator.of(dialogContext).pop(option),
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: Text(
                        displayBuilder(option),
                        style: AppConstants.fieldValueStyle.copyWith(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleDateSelectionFlow({
    required _DateSelectionState selection,
    required TextEditingController controller,
    required FormFieldState<String> fieldState,
    required bool isDob,
  }) async {
    final date = await _showSelectionDialog<int>(
      title: 'Select Date',
      options: List.generate(31, (index) => index + 1),
      displayBuilder: (value) => value.toString().padLeft(2, '0'),
    );
    if (date == null) return;
    selection.day = date;
    _updateDateController(controller, selection);
    fieldState.didChange(controller.text);

    final month = await _showSelectionDialog<int>(
      title: 'Select Month',
      options: List.generate(12, (index) => index + 1),
      displayBuilder: (value) => DateFormat.MMMM().format(DateTime(0, value)),
    );
    if (month == null) return;
    selection.month = month;
    _updateDateController(controller, selection);
    fieldState.didChange(controller.text);

    final now = DateTime.now();
    final years = isDob
        ? List.generate(120, (index) => now.year - index)
        : List.generate(30, (index) => now.year + index);
    final year = await _showSelectionDialog<int>(
      title: 'Select Year',
      options: years,
      displayBuilder: (value) => value.toString(),
    );
    if (year == null) return;
    selection.year = year;
    _updateDateController(controller, selection);
    fieldState.didChange(controller.text);
  }

  _DateSelectionState _syncDateSelection(TextEditingController controller) {
    final selection = _dateSelections.putIfAbsent(
      controller,
          () => _DateSelectionState(),
    );
    if (controller.text.isNotEmpty) {
      final parsed = _parseDate(controller.text);
      if (parsed != null) {
        selection
          ..day = parsed.day
          ..month = parsed.month
          ..year = parsed.year;
      }
    }
    return selection;
  }

  void _updateDateController(
      TextEditingController controller, _DateSelectionState selection) {
    if (!selection.isComplete) {
      controller.text = '';
      setState(() {});
      return;
    }
    final day = selection.day!;
    final month = selection.month!;
    final year = selection.year!;
    final maxDay = DateUtils.getDaysInMonth(year, month);
    final safeDay = day > maxDay ? maxDay : day;
    final date = DateTime(year, month, safeDay);
    controller.text =
    "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    selection.day = safeDay;
    setState(() {});
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  // Replace the _buildCheckboxGroup method with this dropdown method
// Replace the _buildDropdownField method in your UI file with this updated version

  Widget _buildDropdownField({
    required String label,
    required List<String> options,
    required TextEditingController controller,
    bool isRequired = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppConstants.fieldLabelStyle),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value:
          controller.text.isNotEmpty && options.contains(controller.text)
              ? controller.text
              : null,
          decoration: _buildInputDecoration(hintText: 'Select $label'),
          icon: const Icon(Icons.arrow_drop_down),
          items: options
              .map(
                (value) => DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: AppConstants.fieldValueStyle,
              ),
            ),
          )
              .toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              controller.text = newValue;
              setState(() {});
            }
          },
          validator: isRequired
              ? (value) {
            if (value == null || value.isEmpty) {
              return 'Please select $label';
            }
            return null;
          }
              : null,
        ),
      ],
    );
  }
  Widget _buildTitleSelector({
    required String label,
    required List<String> options,
    required TextEditingController controller,
  }) {
    return FormField<String>(
      validator: (_) {
        if (controller.text.isEmpty) {
          return 'Please select $label';
        }
        return null;
      },
      builder: (fieldState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppConstants.fieldValueStyle),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                border: Border.all(
                  color:
                      fieldState.hasError ? Colors.red : AppConstants.fieldBorderColor,
                ),
              ),
              child: Row(
                children: List.generate(options.length, (index) {
                  final option = options[index];
                  final isSelected = controller.text == option;
                  return Expanded(
                    child: InkWell(
                      onTap: () {
                        controller.text = option;
                        setState(() {});
                        fieldState.didChange(option);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            right: index != options.length - 1
                                ? BorderSide(
                                    color: fieldState.hasError
                                        ? Colors.red
                                        : AppConstants.fieldBorderColor,
                                  )
                                : BorderSide.none,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 18,
                              color: isSelected ? TColors.primary : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              option,
                              style: AppConstants.fieldValueStyle.copyWith(
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            if (fieldState.hasError) ...[
              const SizedBox(height: 4),
              Text(
                fieldState.errorText ?? '',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        );
      },
    );
  }
  IconData _getTravelerIcon(String type) {
    switch (type) {
      case 'adult':
        return Icons.person;
      case 'child':
        return Icons.child_care;
      case 'infant':
        return Icons.baby_changing_station;
      default:
        return Icons.person;
    }
  }

  Widget _buildBottomBar(BuildContext context) {
    final formattedPrice =
        NumberFormat('#,##0').format(widget.totalPrice.toDouble());
    final buttonWidth =
        (MediaQuery.of(context).size.width * 0.35).clamp(140.0, 220.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        '${widget.currency} $formattedPrice',
                        style: AppConstants.sectionTitleStyle.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
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
                        child: const Icon(
                          Icons.info_outline,
                          size: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: buttonWidth,
              height: 44,
              child: ElevatedButton(
                onPressed: _handleContinuePressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B5ED7),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final hoursStr = hours.toString().padLeft(1, '0');
    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');
    return '$hoursStr:$minutesStr:$secondsStr';
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await authController.isLoggedIn();
    if (!isLoggedIn) {
      _showLoginRequiredDialog();
    }
  }

  void _showLoginRequiredDialog() {
    if (_loginDialogVisible) return;
    _loginDialogVisible = true;
    Get.dialog(
      Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row with logo centered and close button on right
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left spacer
                  const Expanded(child: SizedBox()),
                  // Centered Logo
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      // color: Color(0xFF0B5ED7),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/images/logo1.png',
                      height: 80,
                      width: 100,
                    ),
                  ),
                  // Right spacer with close button
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => Get.back(),
                        child: const Icon(
                          Icons.close,
                          color: TColors.black,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // const SizedBox(height: 20),

              // Title with promo code
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: 'Promo code '),
                    TextSpan(
                      text: 'WELCOME',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0B5ED7),
                      ),
                    ),
                    const TextSpan(text: ', Get PKR 500 off'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Description text
              const Text(
                'Create an account and use promo code WELCOME and enjoy PKR 500 off on your first booking.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF666666),
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: TColors.primary.withAlpha(50),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _navigateToRegister(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B5ED7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Sign up & conti...',
                        style: TextStyle(
                          fontSize: 14,
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
      ),
      barrierDismissible: false,
    ).whenComplete(() {
      _loginDialogVisible = false;
    });
  }

  Future<void> _navigateToLogin() async {
    Get.back();
    await Get.to(() => const Login());
    _checkLoginStatus();
  }

  Future<void> _navigateToRegister() async {
    Get.back();
    await Get.to(() => RegisterAccount());
    _checkLoginStatus();
  }

  Future<void> _handleContinuePressed() async {
    // final isLoggedIn = await authController.isLoggedIn();
    // if (!isLoggedIn) {
    //   _showLoginRequiredDialog();
    //   return;
    // }
    if (!(_formKey.currentState?.validate() ?? false)) {
      Get.snackbar(
        'Error',
        'Please fill all required fields',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }
    if (!termsAccepted) {
      Get.snackbar(
        'Error',
        'Please accept terms and conditions',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(TColors.primary),
          ),
        ),
        barrierDismissible: false,
      );

      Map<String, dynamic>? pnrResponse;
      AirBlueFlight? updatedOutboundFlight;
      AirBlueFlight? updatedReturnFlight;

      try {
        pnrResponse = await AirBlueFlightApiService().createAirBluePNR(
          flight: widget.flight,
          returnFlight: widget.returnFlight,
          multicityFlights: widget.multicityFlights,
          bookingController: bookingController,
          clientEmail: bookingController.emailController.text,
          clientPhone: bookingController.phoneController.text,
          isDomestic: bookingController.isDomesticFlight,
          multicityFareOptions: widget.multicityFareOptions,
          outboundFareOption: widget.outboundFareOption,
          returnFareOption: widget.returnFareOption,
        );

        if (pnrResponse != null) {
          updatedOutboundFlight = widget.flight.copyWithPNRPricing(
            pnrResponse['rawPricingObjects'] ?? [],
          );

          if (widget.returnFlight != null) {
            updatedReturnFlight = widget.returnFlight?.copyWithPNRPricing(
              pnrResponse['rawPricingObjects'] ?? [],
            );
          }

          Get.snackbar(
            'Success',
            'PNR created successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
          );
        }
      } catch (e) {
        Get.back();
        Get.snackbar(
          'Error',
          'PNR creation failed: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
        return;
      }

      try {
        final response = await AirBlueFlightApiService().saveAirBlueBooking(
          bookingController: bookingController,
          flight: widget.flight,
          returnFlight: widget.returnFlight,
          multicityFlights: widget.multicityFlights,
          token: 'your_auth_token_here',
          pnr: pnrResponse?['pnr'] ?? "",
          finalPrice: pnrResponse?['finalPrice'] ?? "",
          pnrStatus: pnrResponse?['status'] ?? 0,
        );

        Get.back();

        if (response['status'] == 200) {
          final totalPassengers = travelersController.adultCount.value +
              travelersController.childrenCount.value +
              travelersController.infantCount.value;

          Get.to(
            () => AirBlueAddOnsScreen(
              pnrResponse: pnrResponse!,
              totalPassengers: totalPassengers,
              outboundFlight: updatedOutboundFlight ?? widget.flight,
              returnFlight: updatedReturnFlight ?? widget.returnFlight,
              multicityFlights: widget.multicityFlights,
              outboundFareOption: widget.outboundFareOption,
              returnFareOption: widget.returnFareOption,
              multicityFareOptions: widget.multicityFareOptions,
              bookingController: bookingController,
              travelersController: travelersController,
              totalPrice: widget.totalPrice,
              currency: widget.currency,
              initialSecondsLeft: _secondsLeft.value,
            ),
          );
        } else {
          String errorMessage = response['message'] ?? 'Failed to save booking';
          if (response['errors'] != null) {
            errorMessage += '\n${(response['errors'] as Map).entries.map((e) {
              return '${e.key}: ${e.value}';
            }).join('\n')}';
          }
          Get.snackbar(
            'Error',
            errorMessage,
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
            snackPosition: SnackPosition.TOP,
          );
        }
      } catch (e) {
        Get.back();

        if (e is ApiException) {
          String errorMessage = e.message;
          if (e.errors.isNotEmpty) {
            errorMessage += '\n${e.errors.entries.map((e) {
              return '${e.key}: ${e.value}';
            }).join('\n')}';
          }
          Get.snackbar(
            'Error (${e.statusCode ?? 'Unknown'})',
            errorMessage,
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
            snackPosition: SnackPosition.TOP,
          );
        } else {
          Get.snackbar(
            'Error',
            'Failed to save booking: $e',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
            snackPosition: SnackPosition.TOP,
          );
        }
      }
    } catch (e) {
      Get.back();
      Get.snackbar(
        'Error',
        'An unexpected error occurred: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  @override
  void dispose() {
    bookingController.dispose();
    travelersController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }
}

class _DateSelectionState {
  int? day;
  int? month;
  int? year;

  bool get isComplete => day != null && month != null && year != null;
}

// Data pools for randomization
class TestDataPool {
  static final Random _random = Random();

  static final List<String> firstNames = [
    'Ahmad', 'Ali', 'Hassan', 'Usman', 'Bilal', 'Farhan', 'Imran', 'Kashif',
    'Sara', 'Ayesha', 'Fatima', 'Zainab', 'Mariam', 'Hira', 'Nida', 'Sana',
    'Omar', 'Hamza', 'Yousaf', 'Tariq', 'Nasir', 'Raza', 'Kamran', 'Salman'
  ];

  static final List<String> lastNames = [
    'Khan', 'Ahmed', 'Ali', 'Hussain', 'Shah', 'Malik', 'Iqbal', 'Raza',
    'Butt', 'Chaudhry', 'Siddiqui', 'Qureshi', 'Mirza', 'Bhatti', 'Javed',
    'Saeed', 'Nawaz', 'Ashraf', 'Aslam', 'Zaman'
  ];

  static final List<String> emailDomains = [
    'gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com'
  ];

  static final List<String> phonePrefixes = [
    '300', '301', '302', '303', '304', '305', '321', '322', '323', '333'
  ];

  static String randomFirstName() => firstNames[_random.nextInt(firstNames.length)];
  static String randomLastName() => lastNames[_random.nextInt(lastNames.length)];
  static String randomEmail(String firstName, String lastName) {
    final domain = emailDomains[_random.nextInt(emailDomains.length)];
    final suffix = _random.nextInt(999);
    return '${firstName.toLowerCase()}${lastName.toLowerCase()}$suffix@$domain';
  }

  static String randomPhone() {
    final prefix = phonePrefixes[_random.nextInt(phonePrefixes.length)];
    final number = _random.nextInt(9000000) + 1000000; // 7 digit number
    return '$prefix$number';
  }

  static String randomCNIC() {
    final part1 = _random.nextInt(90000) + 10000; // 5 digits
    final part2 = _random.nextInt(9000000) + 1000000; // 7 digits
    final part3 = _random.nextInt(9) + 1; // 1 digit
    return '$part1$part2$part3';
  }

  static String randomPassport() {
    final letters = String.fromCharCodes([
      65 + _random.nextInt(26), // A-Z
      65 + _random.nextInt(26)
    ]);
    final numbers = _random.nextInt(9000000) + 1000000;
    return '$letters$numbers';
  }

  static String randomDate(int minAge, int maxAge) {
    final now = DateTime.now();
    final year = now.year - (minAge + _random.nextInt(maxAge - minAge));
    final month = _random.nextInt(12) + 1;
    final day = _random.nextInt(28) + 1;
    return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  static String randomGender() => _random.nextBool() ? 'Male' : 'Female';

  static String randomTitle(String gender) {
    if (gender == 'Male') {
      return 'Mr';
    } else {
      return 'Mrs';
    }
  }

  static String randomChildTitle(String gender) {
    return gender == 'Male' ? 'Mstr' : 'Miss';
  }
}