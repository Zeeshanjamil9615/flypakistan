import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../services/api_service_pia.dart';
import '../../../../utility/colors.dart';
import '../../../../widgets/travelers_selection_bottom_sheet.dart';
import '../search_flights/pia/pia_flight_model.dart';
import '../search_flights/search_flight_utils/widgets/pia_flight_card.dart';
import 'booking_flight_controller2.dart';

class PIAFlightBookingForm extends StatefulWidget {
  final PIAFlight flight;
  final PIAFlight? returnFlight;
  final double totalPrice;
  final String currency;

  const PIAFlightBookingForm({
    super.key,
    required this.flight,
    this.returnFlight,
    required this.totalPrice,
    required this.currency,
  });

  @override
  State<PIAFlightBookingForm> createState() => _PIAFlightBookingFormState();
}

class _PIAFlightBookingFormState extends State<PIAFlightBookingForm> {
  final _formKey = GlobalKey<FormState>();
  final BookingFlightController bookingController = Get.put(BookingFlightController(), permanent: true);
  final TravelersController travelersController = Get.find();
  bool termsAccepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColors.background,
      appBar: AppBar(
        title: Text(widget.returnFlight != null
            ? 'Review Round Trip'
            : 'Review One Way Trip'),
        backgroundColor: TColors.background,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _buildFlightDetails(),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildTravelersForm(),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildBookerDetails(),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildTermsAndConditions(),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  @override
  void dispose() {
    bookingController.resetForm();
    super.dispose();
  }

  Widget _buildTermsAndConditions() {
    return Card(
      color: TColors.background,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: CheckboxListTile(
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'I accept the ',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              TextSpan(
                text: 'terms and conditions',
                style: TextStyle(
                  fontSize: 14,
                  color: TColors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
        value: termsAccepted,
        onChanged: (value) {
          setState(() {
            termsAccepted = value ?? false;
          });
        },
        activeColor: TColors.primary,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildFlightDetails() {
    return Column(
      children: [
        if (widget.returnFlight != null) ...[
          const Padding(
            padding: EdgeInsets.only(left: 16.0, top: 8.0),
            child: Text(
              'Outbound Flight',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          PIAFlightCard(flight: widget.flight),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 16.0, top: 8.0),
            child: Text(
              'Return Flight',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          PIAFlightCard(
            flight: widget.returnFlight!,
          ),
        ] else ...[
          PIAFlightCard(flight: widget.flight),
        ],
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

    return Card(
      color: TColors.background,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: TColors.primary.withOpacity(0.2)),
      ),
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TColors.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Icon(_getTravelerIcon(type), color: TColors.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: TColors.primary,
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
                if (type == 'adult') ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          hint: 'Gender',
                          items: ['Male', 'Female'],
                          controller: travelerInfo.genderController,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          hint: 'Title',
                          items: ['Mr', 'Mrs', 'Ms'],
                          controller: travelerInfo.titleController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    hint: 'Given Name',
                    prefixIcon: Icons.person_outline,
                    controller: travelerInfo.firstNameController,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    hint: 'Surname',
                    prefixIcon: Icons.person_outline,
                    controller: travelerInfo.lastNameController,
                  ),
                  const SizedBox(height: 16),
                  _buildDateField(
                    hint: 'Date of Birth',
                    controller: travelerInfo.dateOfBirthController,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    hint: 'Phone',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    controller: travelerInfo.phoneController,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    hint: 'Email',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    controller: travelerInfo.emailController,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    hint: 'Nationality',
                    prefixIcon: Icons.flag_outlined,
                    controller: travelerInfo.nationalityController,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    hint: 'Passport Number',
                    prefixIcon: Icons.document_scanner_outlined,
                    controller: travelerInfo.passportController,
                  ),
                  const SizedBox(height: 16),
                  _buildDateField(
                    hint: 'Passport Expiry',
                    controller: travelerInfo.passportExpiryController,
                  ),
                ],
                if (type == 'child') ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          hint: 'Gender',
                          items: ['Male', 'Female'],
                          controller: travelerInfo.genderController,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          hint: 'Title',
                          items: ['Mstr', 'Miss'],
                          controller: travelerInfo.titleController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    hint: 'Given Name',
                    prefixIcon: Icons.person_outline,
                    controller: travelerInfo.firstNameController,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    hint: 'Surname',
                    prefixIcon: Icons.person_outline,
                    controller: travelerInfo.lastNameController,
                  ),
                  const SizedBox(height: 16),
                  _buildDateField(
                    hint: 'Date of Birth',
                    controller: travelerInfo.dateOfBirthController,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    hint: 'Nationality',
                    prefixIcon: Icons.flag_outlined,
                    controller: travelerInfo.nationalityController,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    hint: 'Passport Number',
                    prefixIcon: Icons.document_scanner_outlined,
                    controller: travelerInfo.passportController,
                  ),
                  const SizedBox(height: 16),
                  _buildDateField(
                    hint: 'Passport Expiry',
                    controller: travelerInfo.passportExpiryController,
                  ),
                ],
                if (type == 'infant') ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          hint: 'Gender',
                          items: ['Male', 'Female'],
                          controller: travelerInfo.genderController,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          hint: 'Title',
                          items: ['Inf'],
                          controller: travelerInfo.titleController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    hint: 'Given Name',
                    prefixIcon: Icons.person_outline,
                    controller: travelerInfo.firstNameController,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    hint: 'Surname',
                    prefixIcon: Icons.person_outline,
                    controller: travelerInfo.lastNameController,
                  ),
                  const SizedBox(height: 16),
                  _buildDateField(
                    hint: 'Date of Birth',
                    controller: travelerInfo.dateOfBirthController,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    hint: 'Nationality',
                    prefixIcon: Icons.flag_outlined,
                    controller: travelerInfo.nationalityController,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    hint: 'Passport Number',
                    prefixIcon: Icons.document_scanner_outlined,
                    controller: travelerInfo.passportController,
                  ),
                  const SizedBox(height: 16),
                  _buildDateField(
                    hint: 'Passport Expiry',
                    controller: travelerInfo.passportExpiryController,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String hint,
    required TextEditingController controller,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.calendar_today, color: TColors.primary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        readOnly: true,
        onTap: () async {
          final DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime(2100),
          );
          if (pickedDate != null) {
            controller.text = "${pickedDate.toLocal()}".split(' ')[0];
          }
        },
      ),
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

  Widget _buildBookerDetails() {
    return Card(
      color: TColors.background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Booker Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              hint: 'First Name',
              prefixIcon: Icons.person_outline,
              controller: bookingController.firstNameController,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              hint: 'Last Name',
              prefixIcon: Icons.person_outline,
              controller: bookingController.lastNameController,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              hint: 'Email',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              controller: bookingController.emailController,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              hint: 'Phone',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              controller: bookingController.phoneController,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              hint: 'Address',
              prefixIcon: Icons.location_on_outlined,
              controller: bookingController.addressController,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              hint: 'City',
              prefixIcon: Icons.location_city_outlined,
              controller: bookingController.cityController,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String hint,
    required List<String> items,
    required TextEditingController controller,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        hint: Text(hint),
        items: items.map((String value) {
          return DropdownMenuItem<String>(value: value, child: Text(value));
        }).toList(),
        onChanged: (value) {
          controller.text = value ?? '';
        },
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required IconData prefixIcon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(prefixIcon, color: TColors.primary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
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
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total Amount'),
              Text(
                '${widget.currency} ${widget.totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // In pia_booking_flight.dart
          ElevatedButton(
            onPressed: () async {

              if (_formKey.currentState!.validate() && termsAccepted) {

                if (true) {
                  try {
                    // First save the booking
                    final response = await PIAFlightApiService().savePIABooking(
                      bookingController: bookingController,
                      flight: widget.flight,
                      returnFlight: widget.returnFlight,
                      token: "Your_AuTh_Token",
                    );

                    // If booking is successful, create PNR
                    if (response['status'] == 200) {
                      final pnrResponse = await PIAFlightApiService().createPIAPNR(
                        bookingController: bookingController,
                        flight: widget.flight,
                        returnFlight: widget.returnFlight,
                      );

                      if (pnrResponse['S:Envelope']?['S:Body']?['ns2:CreateBookingResponse'] != null ||
                          pnrResponse['soapenv:Envelope']?['soapenv:Body']?['impl:CreateBookingResponse'] != null) {
                        Get.snackbar(
                          'Success',
                          'Booking and PNR created successfully',
                          backgroundColor: Colors.green,
                          colorText: Colors.white,
                        );
                        // Get.to(() => const FlightBookingDetailsScreen());
                      } else {
                        Get.snackbar(
                          'Partial Success',
                          'Booking saved but PNR creation failed',
                          backgroundColor: Colors.orange,
                          colorText: Colors.white,
                        );
                      }
                    }
                  } catch (e) {
                    Get.snackbar(
                      'Error',
                      'An error occurred: $e',
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  }
                }
              }
            },
            child: const Text('Create Booking'),
          )
        ],
      ),
    );
  }
}