import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:country_picker/country_picker.dart';
import 'package:ready_flights/services/api_service_sabre.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../utility/colors.dart';
import '../../../../../widgets/travelers_selection_bottom_sheet.dart';
import '../../search_flights/sabre/sabre_flight_models.dart';
import '../../search_flights/search_flight_utils/widgets/sabre_flight_card.dart';
import '../booking_flight_controller.dart';
import '../common_flight_voucher_adapter.dart';

class SabreBookingForm extends StatefulWidget {
  final SabreFlight flight;
  Map<String, dynamic>? revalidatePricing;
  SabreBookingForm({super.key, required this.flight, this.revalidatePricing});

  @override
  State<SabreBookingForm> createState() => _SabreBookingFormState();
}

class _SabreBookingFormState extends State<SabreBookingForm> {
  final _formKey = GlobalKey<FormState>();
  final BookingFlightController bookingController = Get.put(
    BookingFlightController(),
    permanent: true,
  );
  final TravelersController travelersController = Get.put(
    TravelersController(),
  );

  bool termsAccepted = false;
  bool isLoading = false; // Add loading state


  // Auto-fill function for testing
  void _fillDummyData() {
    // Fill booker information
    bookingController.firstNameController.text = "John";
    bookingController.lastNameController.text = "Doe";
    bookingController.emailController.text = "ahmadtechdev@gmail.com";
    bookingController.phoneController.text = "1234567890";
    bookingController.remarksController.text = "Test booking";
    bookingController.bookerPhoneCountry.value = Country.parse('PK');

    // Fill adult travelers
    for (int i = 0; i < bookingController.adults.length; i++) {
      final adult = bookingController.adults[i];
      adult.titleController.text = i % 2 == 0 ? "Mr" : "Mrs";
      adult.firstNameController.text = "Ahmad";
      adult.lastNameController.text = "Raza";
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
      adult.emailController.text = "ahmadtechdev@gmail.com";
    }

    // Fill child travelers
    for (int i = 0; i < bookingController.children.length; i++) {
      final child = bookingController.children[i];
      child.titleController.text = i % 2 == 0 ? "Mstr" : "Miss";
      child.firstNameController.text = "Child${i + 1}";
      child.lastNameController.text = "Traveler";
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
      infant.lastNameController.text = "Traveler";
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
            'Booking Details',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Stack( // Add Stack to show overlay loader
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFlightDetails(),
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
          if (isLoading) // Show overlay when loading
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(TColors.primary),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildFlightDetails() {
    return FlightCard(
      flight: widget.flight,
      showReturnFlight: false,
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

// Updated _buildTravelerSection method with dropdown implementation
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
                      label: bookingController.isDomesticFlight
                          ? 'CNIC Number*'
                          : 'Passport Number*',
                      controller: travelerInfo.passportCnicController,
                      isRequired: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Passport Expiry
                _buildDateField(
                  label: bookingController.isDomesticFlight
                      ? 'CNIC Expire'
                      : 'Passport Expire',
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
                      // Show both country name and code for clarity
                      country != null
                          ? '${country.displayNameNoCountryCode} (${country.countryCode})'
                          : 'Select Nationality',
                      style: TextStyle(
                        fontSize: 14,
                        color: country != null ? Colors.black87 : Colors.grey[600],
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
                Text(
                  'PKR ${widget.flight.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: TColors.primary,
                  ),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null // Disable button when loading
                  : () async {
                if (_formKey.currentState!.validate() && termsAccepted) {
                  setState(() {
                    isLoading = true; // Start loading
                  });

                  try {
                    // Call the PNR request function
                    final apiService = ApiServiceSabre();
                    final pnrResponse = await apiService.createPNRRequest(
                      flight: widget.flight,
                      adults: bookingController.adults.toList(),
                      children: bookingController.children.toList(),
                      infants: bookingController.infants.toList(),
                      bookerEmail: bookingController.emailController.text,
                      bookerPhone: bookingController.getFormattedBookerPhoneNumber(),
                      revalidatePricing: widget.revalidatePricing,
                    );

                    setState(() {
                      isLoading = false; // Stop loading
                    });

                    Get.to(() => createSabreVoucher(
                      flight: widget.flight,
                      pnrResponse: pnrResponse,
                    ));

                    Get.snackbar(
                      'Success',
                      'Booking created successfully',
                      backgroundColor: Colors.green,
                      colorText: Colors.white,
                      snackPosition: SnackPosition.TOP,
                    );
                  } catch (e) {
                    setState(() {
                      isLoading = false; // Stop loading on error
                    });

                    Get.snackbar(
                      'Booking Saved',
                      'Flight details saved. PNR creation may have issues.',
                      backgroundColor: Colors.orange,
                      colorText: Colors.white,
                      snackPosition: SnackPosition.TOP,
                    );

                    // Still navigate to common flight booking voucher
                    Get.to(() => createSabreVoucher(
                      flight: widget.flight,
                      pnrResponse: null,
                    ));
                  }
                } else if (!termsAccepted) {
                  Get.snackbar(
                    'Error',
                    'Please accept terms and conditions',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                    snackPosition: SnackPosition.TOP,
                  );
                } else {
                  Get.snackbar(
                    'Error',
                    'Please fill all required fields',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                    snackPosition: SnackPosition.TOP,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TColors.primary, // Change color when loading
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
              child: isLoading
                  ? CircularProgressIndicator(
                    strokeWidth: 2,
                  )
                  : const Text(
                'Create Booking',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    bookingController.resetForm();
    super.dispose();
  }
}