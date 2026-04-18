import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:country_picker/country_picker.dart';
import '../../../utility/colors.dart';
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
  final TextEditingController contactFirstNameController = TextEditingController();
  final TextEditingController contactLastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController cellController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController cityNameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();


  // Observable variables
  var selectedCountry = Country.parse('PK').obs; // Default to Pakistan
  var isLoading = false.obs;
  var apiErrorMessage = ''.obs; // Added for detailed API error messages

  // Form validation variables
  var agencyNameError = ''.obs;
  var contactFirstNameError = ''.obs;
  var contactLastNameError = ''.obs;
  var emailError = ''.obs;
  var countryCodeError = ''.obs;
  var cellError = ''.obs;
  var addressError = ''.obs;
  var cityNameError = ''.obs;
  var passwordError = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // Add listeners to clear errors when text changes
    agencyNameController.addListener(() => agencyNameError.value = '');
    contactFirstNameController.addListener(() => contactFirstNameError.value = '');
    contactLastNameController.addListener(() => contactLastNameError.value = '');
    emailController.addListener(() => emailError.value = '');
    cellController.addListener(() => cellError.value = '');
    addressController.addListener(() => addressError.value = '');
    cityNameController.addListener(() => cityNameError.value = '');
    passwordController.addListener(() => passwordError.value = '');
  }

  @override
  void onClose() {
    // Dispose all controllers
    agencyNameController.dispose();
    contactFirstNameController.dispose();
    contactLastNameController.dispose();
    emailController.dispose();
    cellController.dispose();
    addressController.dispose();
    cityNameController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  // Navigation to login screen

  // Reset all form errors
  void resetErrors() {
    agencyNameError.value = '';
    contactFirstNameError.value = '';
    contactLastNameError.value = '';
    emailError.value = '';
    countryCodeError.value = '';
    cellError.value = '';
    addressError.value = '';
    cityNameError.value = '';
    apiErrorMessage.value = '';
    passwordError.value = '';
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

    // Validate First Name
    if (contactFirstNameController.text.trim().isEmpty) {
      contactFirstNameError.value = 'First name is required';
      isValid = false;
    }

    // Validate Last Name
    if (contactLastNameController.text.trim().isEmpty) {
      contactLastNameError.value = 'Last name is required';
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

    // Validate Address
    if (addressController.text.trim().isEmpty) {
      addressError.value = 'Address is required';
      isValid = false;
    }

    // Validate Password
    final password = passwordController.text.trim();
    if (password.isEmpty) {
      passwordError.value = 'Password is required';
      isValid = false;
    } else if (password.length < 6) {
      passwordError.value = 'Password must be at least 6 characters';
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

      // Backend expects agency_name; per requirement, send it from First + Last name.
      agencyNameController.text =
          '${contactFirstNameController.text.trim()} ${contactLastNameController.text.trim()}'
              .trim();

      // Call the API service for registration request
      final response = await authController.registerRequest(
        agencyName: agencyNameController.text.trim(),
        firstName: contactFirstNameController.text.trim(),
        lastName: contactLastNameController.text.trim(),
        email: emailController.text.trim(),
        countryCode: '+${selectedCountry.value.phoneCode}',
        cellNumber: cellController.text.trim(),
        address: addressController.text.trim(),
        city: cityNameController.text.trim(),
        password: passwordController.text.trim(),

      );

      if (response['success']) {
        // Get email from response or use the entered email
        final email = response['email'] ?? emailController.text.trim();
        final password = passwordController.text.trim();

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

        // Navigate to OTP verification screen with email and password
        Get.to(
          () => OtpVerificationScreen(),
          arguments: {
            'email': email,
            'password': password,
          },
        );
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
