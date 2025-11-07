import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:ready_flights/views/home/home_screen.dart';
import '../../../b2b/agent_dashboard/agent_dashboard.dart';
import 'login_api_service/login_api.dart';
            
class LoginController extends GetxController {
  final authController = Get.find<AuthController>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final isLoading = false.obs;
  final errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    final isLoggedIn = await authController.isLoggedIn();
    if (isLoggedIn) {
      print("User is already logged in");
      Get.off(() => AgentDashboard());
    }
  }

  void resetError() {
    errorMessage.value = '';
  }

  Future<void> login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      errorMessage.value = 'Email and password are required';
      return;
    }

    isLoading.value = true;

    try {
      final result = await authController.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );



      isLoading.value = false;

      if (result['success']) {
        Get.off(() => HomeScreen());
      } else {
        errorMessage.value = result['message'];
      }
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = 'An unexpected error occurred';
    }
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
