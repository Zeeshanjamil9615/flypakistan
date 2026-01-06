import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:country_picker/country_picker.dart';
import '../../../b2b/agent_dashboard/agent_dashboard.dart';
import '../../../utility/colors.dart';
import '../login/login.dart';
import '../login/login_api_service/login_api.dart';
import 'otp_verification_screen.dart';

class RegistrationModel {
  String agencyName;
  String contactName;
  String email;
  String countryCode;
  String cellNumber;
  String address;
  String cityName;

  RegistrationModel({
    required this.agencyName,
    required this.contactName,
    required this.email,
    required this.countryCode,
    required this.cellNumber,
    required this.address,
    required this.cityName,
  });

  Map<String, dynamic> toJson() {
    return {
      'agencyName': agencyName,
      'contactName': contactName,
      'email': email,
      'countryCode': countryCode,
      'cellNumber': cellNumber,
      'address': address,
      'cityName': cityName,
    };
  }

  factory RegistrationModel.fromJson(Map<String, dynamic> json) {
    return RegistrationModel(
      agencyName: json['agencyName'] ?? '',
      contactName: json['contactName'] ?? '',
      email: json['email'] ?? '',
      countryCode: json['countryCode'] ?? '',
      cellNumber: json['cellNumber'] ?? '',
      address: json['address'] ?? '',
      cityName: json['cityName'] ?? '',
    );
  }
}

class RegisterController extends GetxController {
  final authController = Get.find<AuthController>();

  // Text controllers for form fields
  final TextEditingController agencyNameController = TextEditingController();
  final TextEditingController contactNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController cellController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController cityNameController = TextEditingController();

  // Observable variables
  var selectedCountry = Country.parse('PK').obs; // Default to Pakistan
  var isLoading = false.obs;
  var apiErrorMessage = ''.obs; // Added for detailed API error messages

  // Form validation variables
  var agencyNameError = ''.obs;
  var contactNameError = ''.obs;
  var emailError = ''.obs;
  var countryCodeError = ''.obs;
  var cellError = ''.obs;
  var addressError = ''.obs;
  var cityNameError = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // Add listeners to clear errors when text changes
    agencyNameController.addListener(() => agencyNameError.value = '');
    contactNameController.addListener(() => contactNameError.value = '');
    emailController.addListener(() => emailError.value = '');
    cellController.addListener(() => cellError.value = '');
    addressController.addListener(() => addressError.value = '');
    cityNameController.addListener(() => cityNameError.value = '');
  }

  @override
  void onClose() {
    // Dispose all controllers
    agencyNameController.dispose();
    contactNameController.dispose();
    emailController.dispose();
    cellController.dispose();
    addressController.dispose();
    cityNameController.dispose();
    super.onClose();
  }

  // Navigation to login screen

  // Reset all form errors
  void resetErrors() {
    agencyNameError.value = '';
    contactNameError.value = '';
    emailError.value = '';
    countryCodeError.value = '';
    cellError.value = '';
    addressError.value = '';
    cityNameError.value = '';
    apiErrorMessage.value = '';
  }

  // Validate email format
  bool isEmailValid(String email) {
    final emailRegExp = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegExp.hasMatch(email);
  }

  // Validate phone number format
  bool isPhoneValid(String phone) {
    final phoneRegExp = RegExp(r'^\d{6,15}$');
    return phoneRegExp.hasMatch(phone);
  }

  // Validate all fields
  bool validateFields() {
    resetErrors();
    bool isValid = true;

    // Validate Agency Name
    if (agencyNameController.text.trim().isEmpty) {
      agencyNameError.value = 'Agency name is required';
      isValid = false;
    }

    // Validate Contact Name
    if (contactNameController.text.trim().isEmpty) {
      contactNameError.value = 'Contact name is required';
      isValid = false;
    }

    // Validate Email
    if (emailController.text.trim().isEmpty) {
      emailError.value = 'Email is required';
      isValid = false;
    } else if (!isEmailValid(emailController.text.trim())) {
      emailError.value = 'Please enter a valid email';
      isValid = false;
    }

    // Validate Country Code (country is always selected as it has default)
    // This validation is kept for consistency but should always pass

    // Validate Cell Number
    if (cellController.text.trim().isEmpty) {
      cellError.value = 'Cell number is required';
      isValid = false;
    } else if (!isPhoneValid(cellController.text.trim())) {
      cellError.value = 'Please enter a valid phone number (6-15 digits)';
      isValid = false;
    }



    // Validate City Name
    if (cityNameController.text.trim().isEmpty) {
      cityNameError.value = 'City name is required';
      isValid = false;
    }

    return isValid;
  }

  // Register method - now sends registration request and navigates to OTP screen
  void register() async {
    // Clear focus to hide keyboard
    FocusManager.instance.primaryFocus?.unfocus();

    // Reset API error message
    apiErrorMessage.value = '';

    // Validate fields
    if (!validateFields()) {
      Get.snackbar(
        'Validation Error',
        'Please correct the errors in the form',
        backgroundColor: TColors.third,
        colorText: TColors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(10),
      );
      return;
    }

    try {
      // Show loading indicator
      isLoading.value = true;

      // Call the API service for registration request
      final response = await authController.registerRequest(
        agencyName: agencyNameController.text.trim(),
        contactName: contactNameController.text.trim(),
        email: emailController.text.trim(),
        countryCode: '+${selectedCountry.value.phoneCode}',
        cellNumber: cellController.text.trim(),
        address: "",
        city: cityNameController.text.trim(),
      );

      if (response['success']) {
        // Get email from response or use the entered email
        final email = response['email'] ?? emailController.text.trim();

        // Show success message
        Get.snackbar(
          'OTP Sent',
          response['message'] ?? 'OTP has been sent to your email',
          backgroundColor: Colors.green,
          colorText: TColors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.all(10),
          duration: Duration(seconds: 2),
        );

        // Navigate to OTP verification screen with email
        Get.to(() => OtpVerificationScreen(), arguments: email);
      } else {
        // Store API error message
        apiErrorMessage.value = response['message'] ?? 'Registration request failed';

        // Show error message
        Get.snackbar(
          'Registration Failed',
          apiErrorMessage.value,
          backgroundColor: TColors.third,
          colorText: TColors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.all(10),
          duration: Duration(seconds: 5),
        );

        // Log error details
        print('Registration request API error: ${response['message']}');
      }
    } catch (e) {
      // Handle exception
      apiErrorMessage.value = 'Registration failed: ${e.toString()}';

      Get.snackbar(
        'Error',
        'Registration failed. Please try again later.',
        backgroundColor: TColors.third,
        colorText: TColors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(10),
      );

      print('Registration exception: $e');
    } finally {
      // Hide loading indicator
      isLoading.value = false;
    }
  }

  // Method to get error text for form fields
  String? getErrorText(RxString errorValue) {
    return errorValue.value.isEmpty ? null : errorValue.value;
  }

  // Method to show country picker
  void showPhoneCountryPicker(BuildContext buildContext) {
    showCountryPicker(
      context: buildContext,
      showPhoneCode: true,
      onSelect: (Country country) {
        selectedCountry.value = country;
        countryCodeError.value = '';
      },
      countryListTheme: CountryListThemeData(
        flagSize: 25,
        backgroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 16, color: Colors.blueGrey),
        bottomSheetHeight: MediaQuery.of(buildContext).size.height * 0.8,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
        inputDecoration: InputDecoration(
          labelText: 'Search',
          hintText: 'Start typing to search',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: const Color(0xFF8C98A8).withOpacity(0.2),
            ),
          ),
        ),
      ),
    );
  }
}
