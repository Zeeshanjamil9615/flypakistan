// airarabia_booking_flight.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:country_picker/country_picker.dart';
import 'package:ready_flights/services/api_service_airarabia.dart';
import 'package:ready_flights/views/flight/booking_flight/common_flight_voucher_adapter.dart';
import 'package:ready_flights/views/flight/form/flight_booking_controller.dart';
import 'package:ready_flights/views/flight/search_flights/airarabia/validation_data/validation_controller.dart';

import '../../../../../utility/colors.dart';
import '../../../../../widgets/travelers_selection_bottom_sheet.dart';
import '../../search_flights/airarabia/airarabia_flight_controller.dart';
import '../../search_flights/airarabia/airarabia_flight_model.dart';
import '../booking_flight_controller.dart';

class AirArabiaBookingFlight extends StatefulWidget {
  final AirArabiaFlight flight;
  final AirArabiaPackage selectedPackage;
  final double totalPrice;
  final String currency;
  final Map<String, dynamic>? extrasData; 

  const AirArabiaBookingFlight({
    super.key,
    required this.flight,
    required this.selectedPackage,
    required this.totalPrice,
    required this.currency,
    this.extrasData,
  });

  @override
  State<AirArabiaBookingFlight> createState() => _AirArabiaBookingFlightState();
}

class _AirArabiaBookingFlightState extends State<AirArabiaBookingFlight> {
  final _formKey = GlobalKey<FormState>();
  final BookingFlightController bookingController = Get.put(
    BookingFlightController(),
    permanent: true,
  );
  final TravelersController travelersController = Get.put(
    TravelersController(),
  );
  final AirArabiaFlightController flightController =
  Get.find<AirArabiaFlightController>();

  bool termsAccepted = false;

  // Auto-fill function for testing
  void _fillDummyData() {
    // Check if widget is still mounted before accessing controllers
    if (!mounted) return;
    
    try {
      // Fill booker information
      if (bookingController.firstNameController.text.isEmpty) {
        bookingController.firstNameController.text = "shani";
      }
      if (bookingController.lastNameController.text.isEmpty) {
        bookingController.lastNameController.text = "shani";
      }
      if (bookingController.emailController.text.isEmpty) {
        bookingController.emailController.text = "ahmadtechdev@gmail.com";
      }
      if (bookingController.phoneController.text.isEmpty) {
        bookingController.phoneController.text = "1234567890";
      }
      if (bookingController.remarksController.text.isEmpty) {
        bookingController.remarksController.text = "Test booking";
      }
      bookingController.bookerPhoneCountry.value = Country.parse('PK');
      // Fill adult travelers with safety checks
      for (int i = 0; i < bookingController.adults.length; i++) {
        if (!mounted) return; // Check if still mounted during loop
        
        final adult = bookingController.adults[i];
        if (adult.titleController.text.isEmpty) {
          adult.titleController.text = i % 2 == 0 ? "Mr" : "Mrs";
        }
        if (adult.firstNameController.text.isEmpty) {
          adult.firstNameController.text = "ahmad${i + 1}";
        }
        if (adult.lastNameController.text.isEmpty) {
          adult.lastNameController.text = "Traveler";
        }
        if (adult.passportCnicController.text.isEmpty) {
          adult.passportCnicController.text = bookingController.isDomesticFlight
              ? "1234567890123"
              : "AB123456${i + 1}";
        }
        if (adult.nationalityController.text.isEmpty) {
          adult.nationalityController.text = "Pakistan";
        }
        adult.nationalityCountry.value = Country.parse('PK');
        if (adult.dateOfBirthController.text.isEmpty) {
          adult.dateOfBirthController.text = "1990-0${(i % 9) + 1}-15";
        }
        if (adult.passportExpiryController.text.isEmpty) {
          adult.passportExpiryController.text = "2030-12-31";
        }
        if (adult.genderController.text.isEmpty) {
          adult.genderController.text = i % 2 == 0 ? "Male" : "Female";
        }
        if (adult.phoneController.text.isEmpty) {
          adult.phoneController.text = "300123456${i + 1}";
        }
        adult.phoneCountry.value = Country.parse('PK');
        if (adult.emailController.text.isEmpty) {
          adult.emailController.text = "adult${i + 1}@example.com";
        }
      }

      // Fill child travelers with safety checks
      for (int i = 0; i < bookingController.children.length; i++) {
        if (!mounted) return;
        
        final child = bookingController.children[i];
        if (child.titleController.text.isEmpty) {
          child.titleController.text = i % 2 == 0 ? "Mstr" : "Miss";
        }
        if (child.firstNameController.text.isEmpty) {
          child.firstNameController.text = "Child${i + 1}";
        }
        if (child.lastNameController.text.isEmpty) {
          child.lastNameController.text = "Traveler";
        }
        if (child.passportCnicController.text.isEmpty) {
          child.passportCnicController.text = bookingController.isDomesticFlight
              ? "1234567890${100 + i}"
              : "CD123456${i + 1}";
        }
        if (child.nationalityController.text.isEmpty) {
          child.nationalityController.text = "Pakistan";
        }
        child.nationalityCountry.value = Country.parse('PK');
        if (child.dateOfBirthController.text.isEmpty) {
          child.dateOfBirthController.text = "2015-0${(i % 9) + 1}-15";
        }
        if (child.passportExpiryController.text.isEmpty) {
          child.passportExpiryController.text = "2030-12-31";
        }
        if (child.genderController.text.isEmpty) {
          child.genderController.text = i % 2 == 0 ? "Male" : "Female";
        }
      }

      // Fill infant travelers with safety checks
      for (int i = 0; i < bookingController.infants.length; i++) {
        if (!mounted) return;
        
        final infant = bookingController.infants[i];
        if (infant.titleController.text.isEmpty) {
          infant.titleController.text = "Inf";
        }
        if (infant.firstNameController.text.isEmpty) {
          infant.firstNameController.text = "Infant${i + 1}";
        }
        if (infant.lastNameController.text.isEmpty) {
          infant.lastNameController.text = "Traveler";
        }
        if (infant.nationalityController.text.isEmpty) {
          infant.nationalityController.text = "Pakistan";
        }
        infant.nationalityCountry.value = Country.parse('PK');
        if (infant.dateOfBirthController.text.isEmpty) {
          infant.dateOfBirthController.text = "2023-0${(i % 9) + 1}-15";
        }
        if (infant.genderController.text.isEmpty) {
          infant.genderController.text = i % 2 == 0 ? "Male" : "Female";
        }
      }

      // Accept terms and conditions
      if (mounted) {
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
    } catch (e) {
      print('Error in _fillDummyData: $e');
      if (mounted) {
        Get.snackbar(
          'Error',
          'Failed to fill dummy data: ${e.toString()}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
      }
    }
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
            'Booking Details - Air Arabia',
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
                    if (mounted) {
                      bookingController.showPhoneCountryPicker(
                        context,
                        travelerInfo,
                      );
                    }
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
                    if (mounted) {
                      bookingController.showBookerPhoneCountryPicker(context);
                    }
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
              if (mounted) {
                bookingController.showNationalityPicker(context, travelerInfo);
              }
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
              if (mounted) {
                setState(() {
                  termsAccepted = value ?? false;
                });
              }
            },
            activeColor: TColors.primary,
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (mounted) {
                  setState(() {
                    termsAccepted = !termsAccepted;
                  });
                }
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
            validator:
            isRequired
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
              if (!mounted) return;
              
              final DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
              );
              if (pickedDate != null && mounted) {
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
              if (newValue != null && mounted) {
                try {
                  controller.text = newValue;
                  // Trigger setState to update the UI immediately
                  setState(() {});
                } catch (e) {
                  print('Error updating controller: $e');
                }
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
                '${widget.currency} ${widget.totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: TColors.primary,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () => _handleBookNow(),
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

// Updated _handleBookNow method with safety checks
Future<void> _handleBookNow() async {
  // Check if widget is still mounted before proceeding
  if (!mounted) return;
  
  if (_formKey.currentState!.validate() && termsAccepted) {
    try {
      // Show loading
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(TColors.primary),
          ),
        ),
        barrierDismissible: false,
      );

      // Call Air Arabia booking API
      final response = await _createAirArabiaBooking();
      
      // Check if still mounted before proceeding
      if (!mounted) return;
      
      Get.back(); // Remove loading

      if (response != null && response['status'] == 200) {
        // Print successful response for debugging
        print('🎉 Booking Success Response:');
        print('Status: ${response['status']}');
        print('Message: ${response['message'] ?? 'Booking created successfully'}');
        print('Data: ${response['data']}');
        
        // Show success snackbar
        if (mounted) {
          Get.snackbar(
            'Success',
            'Booking created successfully!',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 2),
          );

          // Navigate to common flight booking voucher
          Get.off(() => createAirArabiaVoucher(
            flight: widget.flight,
            selectedPackage: widget.selectedPackage,
            bookingResponse: response,
            totalPrice: widget.totalPrice,
            currency: widget.currency,
          ));
        }
        
      } else {
        // Handle API error response
        print('❌ Booking Error Response:');
        print('Full Response: $response');
        
        final errorMessage = response?['message'] ?? 'Unknown error occurred';
        if (mounted) {
          Get.snackbar(
            'Booking Failed',
            errorMessage,
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 4),
          );
        }
      }

    } catch (e, stackTrace) {
      if (mounted) {
        Get.back(); // Remove loading
        
        print('❌ Booking Exception:');
        print('Error: $e');
        print('Stack Trace: $stackTrace');
        
        Get.snackbar(
          'Error',
          'Failed to create booking: ${e.toString()}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4),
        );
      }
    }
  } else if (!termsAccepted) {
    if (mounted) {
      Get.snackbar(
        'Error',
        'Please accept terms and conditions',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
      );
    }
  } else {
    if (mounted) {
      Get.snackbar(
        'Error',
        'Please fill all required fields',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
      );
    }
  }
}

// Add this method to create the booking API call
// Add this method to create the booking API call
// Updated _createAirArabiaBooking method
Future<Map<String, dynamic>?> _createAirArabiaBooking() async {
  try {
    // Get API service
    final apiService = Get.find<ApiServiceAirArabia>();  

    // Get revalidation controller and meta info
    final revalidationController = Get.find<AirArabiaRevalidationController>();
    final metaInfo = revalidationController.revalidationResponse.value?.data?.meta;
    
    if (metaInfo == null) {
      throw Exception('No revalidation data found. Please revalidate flight first.');
    }
    
    final controller = Get.find<AirArabiaFlightController>();
    final flightBookingController = Get.find<FlightBookingController>();

    // Get the selected package index from the controller
    final selectedPackageIndex = controller.selectedPackageIndex;
    print("Selected package index is $selectedPackageIndex");

    // Calculate number of flight segments
    final numberOfSegments = widget.flight.flightSegments.length;
    print("Number of flight segments: $numberOfSegments");

    // Get trip type from flight booking controller
    int tripType = 0; // Default to one way
    switch (flightBookingController.tripType.value) {
      case TripType.oneWay:
        tripType = 0;
        break;
      case TripType.roundTrip:
        tripType = 1;
        break;
      case TripType.multiCity:
        tripType = 2;
        break;
    }
    print("Trip type: $tripType");

    // Prepare final key - add !ret! for one-way flights if missing, keep as-is for return flights
    String finalKey = metaInfo.finalKey;
    
    // For one-way flights: add !ret! if it doesn't already exist
    // For return flights: send finalKey as it is (don't add !ret!)
    if (tripType == 0 && !finalKey.endsWith('!ret!')) {
      // One way flight - add !ret! if missing
      finalKey = "${finalKey}!ret!";
    }
    // For return flights (tripType == 1) or multi-city, keep finalKey as it is
    
    print("Final key: $finalKey (Trip Type: $tripType,");

    // Prepare bkIdArray and bkIdArray3
    String bkIdArray = '';
    String bkIdArray3 = '';
    
    if (numberOfSegments == 1) {
      // Direct flight
      bkIdArray = "${selectedPackageIndex}_0-";
      bkIdArray3 = "${selectedPackageIndex}!0_";
    } else {
      // Multi-segment flight
      List<String> bkIdArrayParts = [];
      List<String> bkIdArray3Parts = [];
      
      for (int i = 0; i < numberOfSegments; i++) {
        bkIdArrayParts.add("${selectedPackageIndex}_$i-");
        bkIdArray3Parts.add("${selectedPackageIndex}!${i}_");
      }
      
      bkIdArray = bkIdArrayParts.join("");
      bkIdArray3 = bkIdArray3Parts.join("");
    }

    print("Final bkIdArray: $bkIdArray");
    print("Final bkIdArray3: $bkIdArray3");

    // Calculate fares from revalidation data
    final revalidationData = revalidationController.revalidationResponse.value?.data;
    double basicFarePerAdult = 0.0;
    double taxPerAdult = 0.0;
    
    if (revalidationData != null) {
      for (final breakdown in revalidationData.pricing.ptcFareBreakdowns) {
        if (breakdown.passengerTypeQuantity?.attributes['Code'] == 'ADT') {
          final passengerFare = breakdown.passengerFare;
          if (passengerFare != null) {
            basicFarePerAdult = double.tryParse(passengerFare.baseFare?.attributes['Amount'] ?? '0') ?? 0.0;
            
            // Calculate total tax
            if (passengerFare.taxes != null) {
              for (final tax in passengerFare.taxes!.taxes) {
                taxPerAdult += double.tryParse(tax.attributes['Amount'] ?? '0') ?? 0.0;
              }
            }
            break;
          }
        }
      }
    }

    // Prepare passenger data
    final List<Map<String, dynamic>> adultPassengers = [];
    for (int i = 0; i < bookingController.adults.length; i++) {
      final adult = bookingController.adults[i];
      adultPassengers.add({
        'title': adult.titleController.text,
        'given_name': adult.firstNameController.text.toUpperCase(),
        'surname': adult.lastNameController.text.toUpperCase(),
        'dob': adult.dateOfBirthController.text,
        'nationality': '${adult.nationalityController.text}-${adult.nationalityCountry.value?.countryCode ?? 'PK'}',
        'passport_no': adult.passportCnicController.text,
        'passport_exp': adult.passportExpiryController.text,
        'basic_fare': basicFarePerAdult.toStringAsFixed(2),
        'tax': taxPerAdult.toStringAsFixed(2),
        'fees': '', // Empty for now
      });
    }

    // Child passengers (75% of adult fare)
    final List<Map<String, dynamic>> childPassengers = [];
    final basicFarePerChild = basicFarePerAdult * 0.75;
    final taxPerChild = taxPerAdult * 0.75;
    
    for (int i = 0; i < bookingController.children.length; i++) {
      final child = bookingController.children[i];
      childPassengers.add({
        'title': child.titleController.text,
        'given_name': child.firstNameController.text.toUpperCase(),
        'surname': child.lastNameController.text.toUpperCase(),
        'dob': child.dateOfBirthController.text,
        'nationality': '${child.nationalityController.text}-${child.nationalityCountry.value?.countryCode ?? 'PK'}',
        'passport_no': child.passportCnicController.text,
        'passport_exp': child.passportExpiryController.text,
        'basic_fare': basicFarePerChild.toStringAsFixed(2),
        'tax': taxPerChild.toStringAsFixed(2),
        'fees': '',
      });
    }

    // Infant passengers (10% of adult fare)
    final List<Map<String, dynamic>> infantPassengers = [];
    final basicFarePerInfant = basicFarePerAdult * 0.1;
    final taxPerInfant = taxPerAdult * 0.1;
    
    for (int i = 0; i < bookingController.infants.length; i++) {
      final infant = bookingController.infants[i];
      infantPassengers.add({
        'title': infant.titleController.text,
        'given_name': infant.firstNameController.text.toUpperCase(),
        'surname': infant.lastNameController.text.toUpperCase(),
        'dob': infant.dateOfBirthController.text,
        'nationality': '${infant.nationalityController.text}-${infant.nationalityCountry.value?.countryCode ?? 'PK'}',
        'basic_fare': basicFarePerInfant.toStringAsFixed(2),
        'passport_no': infant.passportCnicController.text,
        'passport_exp': infant.passportExpiryController.text,
        'tax': taxPerInfant.toStringAsFixed(2),
        'fees': '',
      });
    }

    // Prepare flight details
    final List<Map<String, dynamic>> flightDetails = [];
    for (int segmentIndex = 0; segmentIndex < widget.flight.flightSegments.length; segmentIndex++) {
      final segment = widget.flight.flightSegments[segmentIndex];
      final departureDateTime = DateTime.parse(segment['departure']['dateTime']);
      final arrivalDateTime = DateTime.parse(segment['arrival']['dateTime']);
      
      // Calculate flight duration
      final duration = arrivalDateTime.difference(departureDateTime);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      final flightDuration = '${hours}h ${minutes}m';
      
      // Calculate layover for next segment (if exists)
      String layover = '0h 0m';
      if (segmentIndex < widget.flight.flightSegments.length - 1) {
        final nextSegment = widget.flight.flightSegments[segmentIndex + 1];
        final nextDepartureDateTime = DateTime.parse(nextSegment['departure']['dateTime']);
        final layoverDuration = nextDepartureDateTime.difference(arrivalDateTime);
        final layoverHours = layoverDuration.inHours;
        final layoverMinutes = layoverDuration.inMinutes % 60;
        layover = '${layoverHours}h ${layoverMinutes}m';
      }
      
      flightDetails.add({
        'depart': segment['departure']['airport'],
        'depart_date': '${departureDateTime.year}-${departureDateTime.month.toString().padLeft(2, '0')}-${departureDateTime.day.toString().padLeft(2, '0')}',
        'depart_time': '${departureDateTime.hour.toString().padLeft(2, '0')}:${departureDateTime.minute.toString().padLeft(2, '0')}',
        'dep_terminal': segment['departure']['terminal'] ?? '',
        'arr': segment['arrival']['airport'],
        'arr_date': '${arrivalDateTime.year}-${arrivalDateTime.month.toString().padLeft(2, '0')}-${arrivalDateTime.day.toString().padLeft(2, '0')}',
        'arr_time': '${arrivalDateTime.hour.toString().padLeft(2, '0')}:${arrivalDateTime.minute.toString().padLeft(2, '0')}',
        'arr_terminal': segment['arrival']['terminal'] ?? '',
        'flight_no': segment['flightNumber'],
        'airline_code': segment['flightNumber'].substring(0, 2),
        'operating_flight_no': segment['flightNumber'],
        'operating_airline_code': segment['flightNumber'].substring(0, 2),
        'class_cabin': 'Economy',
        'sub_class': 'Y',
        'hand_baggage': '7KG',
        'check_baggage': '20KG',
        'meal': 'Available',
        'layover': layover,
        'flight_duration': flightDuration,
        'flight_type': numberOfSegments == 1 ? 'Direct' : 'Connect',
        'fare_name': widget.selectedPackage.packageName,
      });
    }

    // Prepare extras data
    final selectedBaggage = revalidationController.selectedBaggage.values.toList();
    final selectedMealsMap = revalidationController.selectedMeals;
    final selectedSeatsMap = revalidationController.selectedSeats;

    // Format baggage data
    List<List<String>> adultBaggage = [];
    for (int i = 0; i < bookingController.adults.length; i++) {
      if (i < selectedBaggage.length && selectedBaggage[i].baggageDescription.isNotEmpty) {
        adultBaggage.add([selectedBaggage[i].baggageDescription]);
      } else {
        adultBaggage.add(['No Bag']);
      }
    }

    // Format meal data
    List<List<List<String>>> adultMeal = [];
    for (int adultIndex = 0; adultIndex < bookingController.adults.length; adultIndex++) {
      List<List<String>> adultMealForAllSegments = [];
      
      final passengerId = 'passenger_$adultIndex';
      final passengerMeals = selectedMealsMap[passengerId];
      
      if (passengerMeals != null) {
        for (final segmentEntry in passengerMeals.entries) {
          List<String> segmentMeals = [];
          for (var meal in segmentEntry.value) {
            segmentMeals.add("${meal.mealCode}--${meal.mealDescription}");
          }
          if (segmentMeals.isNotEmpty) {
            adultMealForAllSegments.add(segmentMeals);
          }
        }
      }
      
      adultMeal.add(adultMealForAllSegments);
    }

    // Format seat data
    List<List<List<String>>> adultSeat = [];
    for (int adultIndex = 0; adultIndex < bookingController.adults.length; adultIndex++) {
      List<List<String>> adultSeatForAllSegments = [];
      
      final passengerId = 'passenger_$adultIndex';
      final passengerSeats = selectedSeatsMap[passengerId];
      
      if (passengerSeats != null) {
        for (final segmentEntry in passengerSeats.entries) {
          final seat = segmentEntry.value;
          if (seat.seatNumber.isNotEmpty) {
            adultSeatForAllSegments.add(["${seat.seatNumber}--${seat.seatNumber}"]);
          }
        }
      }
      
      adultSeat.add(adultSeatForAllSegments);
    }

    // Determine flight type and stops based on trip type
    String flightType;
    List<int> stopsSector;
    
    switch (tripType) {
      case 0: // One Way
        flightType = 'OneWay';
        stopsSector = [numberOfSegments - 1];
        break;
      case 1: // Round Trip
        flightType = 'Return';
        // For round trip, we need to handle both outbound and return segments
        if (widget.flight.isRoundTrip && 
            widget.flight.outboundFlight != null && 
            widget.flight.inboundFlight != null) {
          final outboundSegments = widget.flight.outboundFlight!['flightSegments'].length;
          final inboundSegments = widget.flight.inboundFlight!['flightSegments'].length;
          stopsSector = [outboundSegments - 1, inboundSegments - 1];
        } else {
          stopsSector = [numberOfSegments - 1];
        }
        break;
      case 2: // Multi City
        flightType = 'MultiCity';
        stopsSector = [numberOfSegments - 1];
        break;
      default:
        flightType = 'OneWay';
        stopsSector = [numberOfSegments - 1];
    }

    print('=== BOOKING PARAMETERS DEBUG ===');
    print('Trip Type: $tripType ($flightType)');
    print('Number of Segments: $numberOfSegments');
    print('Final Key: $finalKey');
    print('Selected Package Index: $selectedPackageIndex');
    print('bkIdArray: $bkIdArray');
    print('bkIdArray3: $bkIdArray3');
    print('Stops Sector: $stopsSector');
    print('Adult Passengers: ${adultPassengers.length}');
    print('Child Passengers: ${childPassengers.length}');
    print('Infant Passengers: ${infantPassengers.length}');
    // print('Is Return Flight: ${widget.isReturnFlight}');
    print('================================');

    final response = await apiService.createAirArabiaBooking(
      email: bookingController.emailController.text,
      finalKey: finalKey,
      echoToken: metaInfo.echoToken,
      transactionIdentifier: metaInfo.transactionId,
      jsession: metaInfo.jsession,
      adults: travelersController.adultCount.value,
      child: travelersController.childrenCount.value,
      infant: travelersController.infantCount.value,
      stopsSector: stopsSector,
      bkIdArray: bkIdArray,
      bkIdArray3: bkIdArray3,
      adultBaggage: adultBaggage,
      adultMeal: adultMeal,
      adultSeat: adultSeat,
      childBaggage: [],
      childMeal: [],
      childSeat: [],
      bookerName: '${bookingController.firstNameController.text} ${bookingController.lastNameController.text}',
      countryCode: bookingController.bookerPhoneCountry.value?.phoneCode ?? '92',
      simCode: bookingController.bookerPhoneCountry.value?.phoneCode ?? '92',
      city: 'Unknown',
      address: 'Unknown',
      phone: bookingController.phoneController.text,
      remarks: bookingController.remarksController.text,
      marginPer: 0.0,
      marginVal: 0.0,
      finalPrice: widget.totalPrice,
      totalPrice: widget.totalPrice,
      flightType: flightType,
      csId: 1,
      csName: 'Default Agent',
      adultPassengers: adultPassengers,
      childPassengers: childPassengers,
      infantPassengers: infantPassengers,
      flightDetails: flightDetails,
    );

    print('API Response received: $response');
    return response;
    
  } catch (e, stackTrace) {
    print('Error in _createAirArabiaBooking: $e');
    print('Stack Trace: $stackTrace');
    rethrow;
  }
}
  void dispose() {
    // Dispose controllers if they exist and haven't been disposed already
    try {
      // bookingController.dispose();
    } catch (e) {
      print('Error disposing booking controller: $e');
    }
    
    try {
      // travelersController.dispose();
    } catch (e) {
      print('Error disposing travelers controller: $e');
    }
    
    super.dispose();
  }
}