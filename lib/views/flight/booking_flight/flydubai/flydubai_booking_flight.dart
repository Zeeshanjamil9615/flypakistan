// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:country_picker/country_picker.dart';
import 'package:ready_flights/views/flight/form/flight_booking_controller.dart';
import '../../../../services/api_service_flydubai.dart';
import '../../../../utility/colors.dart';
import '../../../../widgets/travelers_selection_bottom_sheet.dart';
import '../../search_flights/flydubai/flydubai_controller.dart';
import '../../search_flights/flydubai/flydubai_extras_controller.dart';
import '../../search_flights/flydubai/flydubai_model.dart';
import '../booking_flight_controller.dart';
import 'flydubai_print_voucher.dart';

class FlyDubaiBookingFlight extends StatefulWidget {
  final FlydubaiFlight flight;
  final FlydubaiFlight? returnFlight;
  final List<FlydubaiFlight>? multicityFlights;

  final FlydubaiFlightFare? outboundFareOption;
  final FlydubaiFlightFare? returnFareOption;
  final List<FlydubaiFlightFare?>? multicityFareOptions;

  const FlyDubaiBookingFlight({
    super.key,
    required this.flight,
    this.returnFlight,
    this.multicityFlights,

    this.outboundFareOption,
    this.returnFareOption,
    this.multicityFareOptions,
  });

  @override
  State<FlyDubaiBookingFlight> createState() => _FlyDubaiBookingFlightState();
}

class _FlyDubaiBookingFlightState extends State<FlyDubaiBookingFlight> {
  final _formKey = GlobalKey<FormState>();
  final BookingFlightController bookingController = Get.put(
    BookingFlightController(),
  );
  final TravelersController travelersController = Get.put(
    TravelersController(),
  );
  final FlydubaiFlightController flightController =
  Get.find<FlydubaiFlightController>();

  bool termsAccepted = false;

  // Auto-fill function for testing
  void _fillDummyData() {
    // Fill booker information
    bookingController.firstNameController.text = "John";
    bookingController.lastNameController.text = "Doe";
    bookingController.emailController.text = "johndoe@example.com";
    bookingController.phoneController.text = "1234567890";
    bookingController.remarksController.text = "Test booking for FlyDubai";
    bookingController.bookerPhoneCountry.value = Country.parse('PK');

    // Fill adult travelers
    for (int i = 0; i < bookingController.adults.length; i++) {
      final adult = bookingController.adults[i];
      adult.titleController.text = i % 2 == 0 ? "Mr" : "Mrs";
      adult.firstNameController.text = "Traveler${i + 1}";
      adult.lastNameController.text = "Test";
      adult.passportCnicController.text = bookingController.isDomesticFlight
          ? "1234567890123"
          : "AB123456${i + 1}";
      adult.nationalityController.text = "Pakistan";
      adult.nationalityCountry.value = Country.parse('PK');
      adult.dateOfBirthController.text = "1990-0${(i % 9) + 1}-15";
      adult.passportExpiryController.text = "2030-12-31";
      adult.genderController.text = i % 2 == 0 ? "Male" : "Female";
      adult.phoneController.text = "300123456${i + 1}";
      adult.phoneCountry.value = Country.parse('PK');
      adult.emailController.text = "traveler${i + 1}@example.com";
    }

    // Fill child travelers
    for (int i = 0; i < bookingController.children.length; i++) {
      final child = bookingController.children[i];
      child.titleController.text = i % 2 == 0 ? "Mstr" : "Miss";
      child.firstNameController.text = "Child${i + 1}";
      child.lastNameController.text = "Test";
      child.passportCnicController.text = bookingController.isDomesticFlight
          ? "1234567890${100 + i}"
          : "CD123456${i + 1}";
      child.nationalityController.text = "Pakistan";
      child.nationalityCountry.value = Country.parse('PK');
      child.dateOfBirthController.text = "2015-0${(i % 9) + 1}-15";
      child.passportExpiryController.text = "2030-12-31";
      child.genderController.text = i % 2 == 0 ? "Male" : "Female";
      child.phoneController.text = "";
      child.emailController.text = "";
    }

    // Fill infant travelers
    for (int i = 0; i < bookingController.infants.length; i++) {
      final infant = bookingController.infants[i];
      infant.titleController.text = "Inf";
      infant.firstNameController.text = "Infant${i + 1}";
      infant.lastNameController.text = "Test";
      infant.nationalityController.text = "Pakistan";
      infant.nationalityCountry.value = Country.parse('PK');
      infant.dateOfBirthController.text = "2023-0${(i % 9) + 1}-15";
      infant.genderController.text = i % 2 == 0 ? "Male" : "Female";
    }

    // Accept terms and conditions
    setState(() {
      termsAccepted = true;
    });

    // Show success message
    Get.snackbar(
      'Success',
      'Form filled with dummy data for testing',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
            'FlyDubai Booking Details',
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
                _buildFlightSummary(),
                const SizedBox(height: 24),
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
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildFlightSummary() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TColors.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Image.network(
                  widget.flight.airlineImg,
                  height: 24,
                  width: 24,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.flight, color: Colors.white, size: 24);
                  },
                ),
                const SizedBox(width: 12),
                Text(
                  '${widget.flight.airlineName} Flight Summary',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildFlightDetails(widget.flight, 'Outbound Flight'),
                if (widget.returnFlight != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildFlightDetails(widget.returnFlight!, 'Return Flight'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlightDetails(FlydubaiFlight flight, String title) {
    final departure = flight.legSchedules.first['departure'];
    final arrival = flight.legSchedules.first['arrival'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: TColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    departure['airport'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    departure['city'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateTime.parse(departure['time']).toString().substring(11, 16),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    DateTime.parse(departure['time']).toString().substring(0, 10),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Icon(Icons.flight_takeoff, color: Colors.grey[600]),
                const SizedBox(height: 4),
                Text(
                  flight.flightSegment.flightNumber,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    arrival['airport'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    arrival['city'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateTime.parse(arrival['time']).toString().substring(11, 16),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    DateTime.parse(arrival['time']).toString().substring(0, 10),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
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

      return Column(children: [...adults, ...children, ...infants]);
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TColors.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(_getTravelerIcon(type), color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Gender Row - Now using dropdowns
                _buildDropdownField(
                  label: 'Title',
                  options: isInfant
                      ? ['Inf']
                      : (type == 'child'
                      ? ['Mstr', 'Miss']
                      : ['Mr', 'Mrs', 'Ms']),
                  controller: travelerInfo.titleController,
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  label: 'Gender',
                  options: ['Male', 'Female'],
                  controller: travelerInfo.genderController,
                ),
                const SizedBox(height: 16),

                // Name Fields Row
                Column(
                  children: [
                    _buildTextField(
                      label: 'Given Name*',
                      controller: travelerInfo.firstNameController,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Surname*',
                      controller: travelerInfo.lastNameController,
                      isRequired: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Date of Birth
                _buildDateField(
                  label: 'Date of Birth*',
                  controller: travelerInfo.dateOfBirthController,
                ),

                if (type == 'adult') ...[
                  const SizedBox(height: 16),
                  // Phone and Email Row
                  Column(
                    children: [
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
                  ),
                  const SizedBox(height: 16),
                ],

                // Nationality and Passport Row
                Column(
                  children: [
                    _buildNationalityPickerField(
                      label: 'Nationality*',
                      travelerInfo: travelerInfo,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Passport Number*',
                      controller: travelerInfo.passportCnicController,
                      isRequired: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Passport Expiry
                _buildDateField(
                  label: 'Passport Expire*',
                  controller: travelerInfo.passportExpiryController,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookerDetails() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TColors.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Text(
              'Booker Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: 'First Name*',
                        controller: bookingController.firstNameController,
                        isRequired: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        label: 'Last Name*',
                        controller: bookingController.lastNameController,
                        isRequired: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  children: [
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
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  label: 'Remarks',
                  controller: bookingController.remarksController,
                  maxLines: 3,
                ),
              ],
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
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Country Code Picker
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
                        right: BorderSide(color: Colors.grey[300]!),
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
              // Phone Number Field
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter phone number';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
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
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Country Code Picker
              Obx(() {
                final country = bookingController.bookerPhoneCountry.value;
                return InkWell(
                  onTap: () {
                    bookingController.showBookerPhoneCountryPicker(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Colors.grey[300]!),
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
              // Phone Number Field
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter phone number';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
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
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Obx(() {
          final country = travelerInfo.nationalityCountry.value;
          return InkWell(
            onTap: () {
              bookingController.showNationalityPicker(context, travelerInfo);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
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
                      style: TextStyle(
                        fontSize: 14,
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            validator: isRequired
                ? (value) {
              if (value == null || value.isEmpty) {
                return 'Please fill in this field.';
              }
              return null;
            }
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextFormField(
            controller: controller,
            readOnly: true,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              suffixIcon: Icon(Icons.calendar_month, color: Colors.grey),
            ),
            onTap: () async {
              final DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
              );
              if (pickedDate != null) {
                controller.text =
                "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select date';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

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
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonFormField<String>(
            value: controller.text.isNotEmpty && options.contains(controller.text)
                ? controller.text
                : null,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            hint: Text(
              'Select $label',
              style: TextStyle(color: Colors.grey[600]),
            ),
            items: options.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                controller.text = newValue;
                // Trigger setState to update the UI immediately
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
        ),
      ],
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

// Update the _buildBottomBar method in flydubai_booking_flight.dart
// Update the _buildBottomBar method
  Widget _buildBottomBar() {
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Obx(() {
                  // Get the base flight price
                  final flightPrice = widget.flight.price;

                  // Get extras price from extras controller
                  final extrasController = Get.put(FlydubaiExtrasController());
                  final extrasPrice = extrasController.totalExtrasPrice.value;

                  // Calculate total
                  final totalPrice = flightPrice + extrasPrice;
                  final currency = widget.flight.currency;

                  return Text(
                    '$currency ${_formatPrice(totalPrice)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: TColors.primary,
                    ),
                  );
                }),
              ],
            ),
            ElevatedButton(
              onPressed: () async {
                // Validate form first
                if (_formKey.currentState?.validate() ?? false) {
                  if (termsAccepted) {
                    // Show loading
                    Get.dialog(
                      const Center(child: CircularProgressIndicator()),
                      barrierDismissible: false,
                    );

                    try {
                      print('=== STARTING FLYDUBAI BOOKING PROCESS ===');

                      // Get controller instances
                      final apiService = Get.find<ApiServiceFlyDubai>();
                      final flydubaiController = Get.find<FlydubaiFlightController>();
                      
                      // Get extras controller (try to find existing or create new)
                      final extrasController = Get.isRegistered<FlydubaiExtrasController>()
                          ? Get.find<FlydubaiExtrasController>()
                          : Get.put(FlydubaiExtrasController());

                      // Prepare traveler data
                      final adults = bookingController.adults;
                      final children = bookingController.children;
                      final infants = bookingController.infants;

                      print('Travelers: ${adults.length} adults, ${children.length} children, ${infants.length} infants');

                      // Get combined cart data (includes both outbound and return)
                      final cartData = flydubaiController.cartData ??
                          flydubaiController.outboundCartData ??
                          flydubaiController.returnCartData;
                      if (cartData == null) {
                        throw Exception('No cart data available. Please add flights to cart first.');
                      }

                      // Build segment array
                      final segmentArray = flydubaiController.buildSegmentArray(extrasController: extrasController);
                      print('Segment array: ${segmentArray.length} items');

                      // Get city from booking controller or use default
                      final city = 'Islamabad'; // You can get this from user input

                      // Get SIM code (you might need to generate or get this)
                      final simCode = '123'; // Example SIM code


                      print('Segment array with extras: $segmentArray');


                      // Call createPNR API
                     // In the _buildBottomBar method, update the booking process:
                     final FlightBookingController flightBookingController = Get.find<FlightBookingController>();
final pnrResult = await apiService.createPNR(
  adults: adults,
  children: children,
  infants: infants,
  clientEmail: bookingController.emailController.text,
  clientPhone: bookingController.phoneController.text.trim(),
  countryCode: bookingController.bookerPhoneCountry.value?.phoneCode ?? '92',
  simCode: simCode,
  city: city,
  flightType: flightBookingController.tripType.value == TripType.roundTrip ? 'roundtrip' : 'oneway',
  segmentArray: segmentArray,
  cartData: cartData!,
);

                      // Close loading dialog
                      Get.back();

                      if (pnrResult['success'] == true) {
                        print('✅ PNR created successfully: ${pnrResult['confirmationNumber']}');

                        // Navigate to print voucher screen
                        Get.to(() => FlyDubaiBookingDetailsScreen(
                          outboundFlight: widget.flight,
                          returnFlight: widget.returnFlight,
                          multicityFlights: widget.multicityFlights,
                          outboundFareOption: widget.outboundFareOption,
                          returnFareOption: widget.returnFareOption,
                          multicityFareOptions: widget.multicityFareOptions,
                          pnrResponse: pnrResult,
                        ));
                      } else {
                        print('❌ PNR creation failed: ${pnrResult['error']}');
                        Get.snackbar(
                          'Booking Failed',
                          pnrResult['error']?.toString() ?? 'Unknown error occurred',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                      }
                    } catch (e, stackTrace) {
                      // Close loading dialog
                      Get.back();

                      print('❌ Booking error: $e');
                      print('Stack trace: $stackTrace');

                      Get.snackbar(
                        'Booking Error',
                        'An error occurred during booking: $e',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                      );
                    }
                  } else {
                    Get.snackbar(
                      'Terms Required',
                      'Please accept the terms and conditions',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.orange,
                      colorText: Colors.white,
                    );
                  }
                } else {
                  Get.snackbar(
                    'Validation Error',
                    'Please fill all required fields correctly',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.orange,
                    colorText: Colors.white,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Book Now',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // Add this helper method to format the price
  String _formatPrice(double price) {
    final parts = price.toStringAsFixed(0).split('.');
    final integerPart = parts[0];

    final formattedInteger = integerPart.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );

    return formattedInteger;
  }

  @override
  void dispose() {
    // Don't dispose the controllers here as they are managed by BookingFlightController
    super.dispose();
  }
}