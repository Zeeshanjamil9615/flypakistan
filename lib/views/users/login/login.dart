// ignore_for_file: library_private_types_in_public_api

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:ready_flights/views/users/login/login_controller.dart';
import 'package:ready_flights/views/users/rejistration/register.dart';

import '../../../sizes_helpers.dart';
import '../../../utility/colors.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final LoginController controller = Get.put(LoginController());
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final textScaleFactor = size.width / 375;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              // Modern Header with gradient overlay
              Container(
                width: double.infinity,
                height: size.height * 0.35,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/lywing-slash-screen.png'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.5),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: <Widget>[
                      // Back button
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Material(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              child: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Login title
                      Positioned(
                        bottom: 32,
                        left: 0,
                        right: 0,
                        child: Column(
                          children: [
                            Text(
                              "Welcome Back",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Login to continue",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Form content with modern design
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Error message with modern design
                      Obx(
                        () => controller.errorMessage.value.isNotEmpty
                            ? Container(
                                margin: const EdgeInsets.only(bottom: 24),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        controller.errorMessage.value,
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                      // Email input field - Modern design
                      _buildModernTextField(
                        label: 'Email',
                        hint: 'Enter your email',
                        controller: controller.emailController,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        textScaleFactor: textScaleFactor,
                        onChanged: (_) => controller.resetError(),
                      ),

                      const SizedBox(height: 20),

                      // Password input field - Modern design
                      _buildModernPasswordField(
                        label: 'Password',
                        hint: 'Enter your password',
                        controller: controller.passwordController,
                        textScaleFactor: textScaleFactor,
                        onChanged: (_) => controller.resetError(),
                      ),

                      const SizedBox(height: 32),

                      // Login button - Modern gradient design
                      Obx(
                        () => Container(
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: TColors.secondary.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: controller.isLoading.value ? null : controller.login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TColors.primary,
                              disabledBackgroundColor: TColors.secondary.withOpacity(0.6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: controller.isLoading.value
                                ? SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    "Login",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      // const SizedBox(height: 32),
                      //
                      // // Divider with "OR"
                      // Row(
                      //   children: [
                      //     Expanded(child: Divider(color: Colors.grey.shade300)),
                      //     Padding(
                      //       padding: const EdgeInsets.symmetric(horizontal: 16),
                      //       child: Text(
                      //         "OR",
                      //         style: TextStyle(
                      //           color: Colors.grey.shade600,
                      //           fontSize: 14,
                      //           fontWeight: FontWeight.w500,
                      //         ),
                      //       ),
                      //     ),
                      //     Expanded(child: Divider(color: Colors.grey.shade300)),
                      //   ],
                      // ),

                      // const SizedBox(height: 32),
                      //
                      // // Social login buttons - Modern design
                      // Row(
                      //   children: [
                      //     Expanded(
                      //       child: _buildSocialButton(
                      //         icon: 'assets/images/google.svg',
                      //         label: 'Google',
                      //         textScaleFactor: textScaleFactor,
                      //         onTap: () {},
                      //       ),
                      //     ),
                      //     const SizedBox(width: 12),
                      //     Expanded(
                      //       child: _buildSocialButton(
                      //         icon: 'assets/images/facebook.svg',
                      //         label: 'Facebook',
                      //         textScaleFactor: textScaleFactor,
                      //         onTap: () {},
                      //       ),
                      //     ),
                      //   ],
                      // ),

                      const SizedBox(height: 32),

                      // Register link - Modern design
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RegisterAccount(),
                                  ),
                                );
                              },
                              child: Text(
                                "Sign Up",
                                style: TextStyle(
                                  color: TColors.secondary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: TColors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    required double textScaleFactor,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade900,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 16,
              ),
              prefixIcon: Icon(prefixIcon, color: TColors.secondary, size: 22),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildModernPasswordField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required double textScaleFactor,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: _obscurePassword,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade900,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 16,
              ),
              prefixIcon: Icon(Icons.lock_outline, color: TColors.secondary, size: 22),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey.shade600,
                  size: 22,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required String icon,
    required String label,
    required double textScaleFactor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                icon,
                width: 20,
                height: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
