import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../login/login_api_service/login_api.dart';
import '../login/login.dart';
import '../../home/home_screen.dart';

class OtpVerificationController extends GetxController {
  final AuthController authController = Get.find<AuthController>();

  // Observable variables
  final RxString email = ''.obs;
  final RxString password = ''.obs;
  final RxString otp = ''.obs;
  final RxInt remainingTime = 900.obs; // 15 minutes in seconds
  final RxInt attemptsRemaining = 3.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isOtpExpired = false.obs;
  final RxBool isMaxAttemptsReached = false.obs;
  final RxInt otpLength = 0.obs; // Track OTP length for button state

  // OTP text controllers (6 fields)
  final List<TextEditingController> otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );

  // Focus nodes for OTP fields
  final List<FocusNode> otpFocusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    // Get email (and optionally password) from arguments
    if (Get.arguments != null && Get.arguments is String) {
      email.value = Get.arguments as String;
    } else if (Get.arguments != null && Get.arguments is Map) {
      final args = Get.arguments as Map;
      email.value = args['email'] ?? '';
      password.value = args['password'] ?? '';
    }

    // Add listeners to OTP controllers to update reactive length
    for (var controller in otpControllers) {
      controller.addListener(updateOtpLength);
    }

    // Start the countdown timer
    startTimer();
  }

  @override
  void onClose() {
    _timer?.cancel();
    for (var controller in otpControllers) {
      controller.dispose();
    }
    for (var focusNode in otpFocusNodes) {
      focusNode.dispose();
    }
    super.onClose();
  }

  // Start countdown timer
  void startTimer() {
    remainingTime.value = 900; // 15 minutes
    isOtpExpired.value = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingTime.value > 0) {
        remainingTime.value--;
      } else {
        timer.cancel();
        isOtpExpired.value = true;
        errorMessage.value = 'OTP has expired. Please register again.';
      }
    });
  }

  // Format time as MM:SS
  String getFormattedTime() {
    final minutes = remainingTime.value ~/ 60;
    final seconds = remainingTime.value % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Get OTP from text fields
  String getOtpFromFields() {
    return otpControllers.map((controller) => controller.text).join();
  }

  // Update OTP length reactively
  void updateOtpLength() {
    final length = getOtpFromFields().length;
    otpLength.value = length;
  }

  // Clear all OTP fields
  void clearOtpFields() {
    for (var controller in otpControllers) {
      controller.clear();
    }
    otpLength.value = 0;
    otpFocusNodes[0].requestFocus();
  }

  // Verify OTP
  Future<void> verifyOtp() async {
    // Clear focus to hide keyboard
    FocusManager.instance.primaryFocus?.unfocus();

    // Reset error message
    errorMessage.value = '';

    // Check if OTP is expired
    if (isOtpExpired.value) {
      errorMessage.value = 'OTP has expired. Please register again.';
      return;
    }

    // Check if max attempts reached
    if (isMaxAttemptsReached.value) {
      errorMessage.value = 'Maximum attempts reached. Please register again.';
      return;
    }

    // Get OTP from fields
    final enteredOtp = getOtpFromFields();

    // Validate OTP length
    if (enteredOtp.length != 6) {
      errorMessage.value = 'Please enter complete 6-digit OTP';
      return;
    }

    // Validate OTP format (only digits)
    if (!RegExp(r'^\d{6}$').hasMatch(enteredOtp)) {
      errorMessage.value = 'OTP must contain only numbers';
      return;
    }

    try {
      isLoading.value = true;

      // Call the API to verify OTP
      final response = await authController.registerVerify(
        email: email.value,
        otp: enteredOtp,
      );

      if (response['success']) {
        // Stop timer
        _timer?.cancel();

        // Show success message
        Get.snackbar(
          'Success',
          response['message'] ?? 'Registration completed successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(10),
          duration: const Duration(seconds: 2),
        );

        // If we have a stored password, login automatically; otherwise go to Login screen
        if (password.value.isNotEmpty) {
          final loginResult = await authController.login(
            email: email.value,
            password: password.value,
          );

          if (loginResult['success'] == true) {
            Get.offAll(() => HomeScreen());
          } else {
            Get.offAll(() => Login());
            Get.snackbar(
              'Login Failed',
              loginResult['message'] ?? 'Unable to login automatically. Please login manually.',
              backgroundColor: Colors.red,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM,
              margin: const EdgeInsets.all(10),
              duration: const Duration(seconds: 3),
            );
          }
        } else {
          Get.offAll(() => Login());
        }
      } else {
        // Decrement attempts
        attemptsRemaining.value--;

        // Check if max attempts reached
        if (attemptsRemaining.value <= 0) {
          isMaxAttemptsReached.value = true;
          errorMessage.value =
              'Maximum attempts reached. Please register again.';
          _timer?.cancel();

          // Navigate back to register screen after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            Get.back();
          });
        } else {
          // Clear OTP fields
          clearOtpFields();

          // Show error message
          final statusCode = response['statusCode'];
          if (statusCode == 410) {
            // OTP expired
            isOtpExpired.value = true;
            errorMessage.value = 'OTP has expired. Please register again.';
            _timer?.cancel();
          } else {
            // OTP mismatch
            errorMessage.value =
                '${response['message'] ?? 'Invalid OTP'}. ${attemptsRemaining.value} attempt(s) remaining.';
          }
        }
      }
    } catch (e) {
      errorMessage.value = 'Verification failed: ${e.toString()}';
    } finally {
      isLoading.value = false;
    }
  }

  // Handle back button - navigate to register screen
  void goBackToRegister() {
    _timer?.cancel();
    Get.back();
  }
}

