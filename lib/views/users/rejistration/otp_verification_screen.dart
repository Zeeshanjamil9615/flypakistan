import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../utility/colors.dart';
import 'otp_verification_controller.dart';

class OtpVerificationScreen extends StatelessWidget {
  final OtpVerificationController controller =
      Get.put(OtpVerificationController());

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        controller.goBackToRegister();
        return true;
      },
      child: Scaffold(
        backgroundColor: TColors.white,
        appBar: AppBar(
          backgroundColor: TColors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: TColors.text),
            onPressed: () => controller.goBackToRegister(),
          ),
        ),
        body: SafeArea(
          child: Obx(() => Stack(
                children: [
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),

                          // Header Icon
                          Center(
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: TColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.email_outlined,
                                size: 50,
                                color: TColors.primary,
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Title
                          Center(
                            child: Text(
                              'Verify Your Email',
                              style: TextStyle(
                                color: TColors.text,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Description
                          Center(
                            child: Text(
                              'We\'ve sent a 6-digit OTP to',
                              style: TextStyle(
                                color: TColors.text.withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                          ),

                          const SizedBox(height: 4),

                          // Email display
                          Text(
                            controller.email.value,
                            style: TextStyle(
                              color: TColors.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 40),

                          // OTP Input Fields
                          _buildOtpInputFields(context),

                          const SizedBox(height: 24),

                          // Timer and Resend Section
                          _buildTimerSection(),

                          const SizedBox(height: 24),

                          // Error Message
                          if (controller.errorMessage.value.isNotEmpty)
                            _buildErrorMessage(),

                          const SizedBox(height: 32),

                          // Verify Button
                          _buildVerifyButton(),

                          const SizedBox(height: 20),

                          // Info Text
                          Center(
                            child: Text(
                              'Didn\'t receive the code? Please check your spam folder or register again.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: TColors.text.withOpacity(0.6),
                                fontSize: 13,
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),

                  // Loading Overlay
                  if (controller.isLoading.value)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.5),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  color: TColors.primary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Verifying OTP...',
                                  style: TextStyle(
                                    color: TColors.text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              )),
        ),
      ),
    );
  }

  Widget _buildOtpInputFields(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        return Container(
          width: 50,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: controller.errorMessage.value.isNotEmpty &&
                      !controller.otpFocusNodes[index].hasFocus
                  ? TColors.third
                  : controller.otpFocusNodes[index].hasFocus
                      ? TColors.primary
                      : TColors.grey.withOpacity(0.3),
              width: controller.otpFocusNodes[index].hasFocus ? 2 : 1,
            ),
          ),
          child: TextField(
            controller: controller.otpControllers[index],
            focusNode: controller.otpFocusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: TextStyle(
              color: TColors.text,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              counterText: '',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (value) {
              // Update OTP length reactively
              controller.updateOtpLength();
              
              if (value.isNotEmpty && index < 5) {
                // Move to next field
                FocusScope.of(context)
                    .requestFocus(controller.otpFocusNodes[index + 1]);
              } else if (value.isEmpty && index > 0) {
                // Move to previous field on backspace
                FocusScope.of(context)
                    .requestFocus(controller.otpFocusNodes[index - 1]);
              }
              // Clear error when user starts typing
              if (controller.errorMessage.value.isNotEmpty) {
                controller.errorMessage.value = '';
              }
            },
            onTap: () {
              // Clear error when user taps on field
              if (controller.errorMessage.value.isNotEmpty) {
                controller.errorMessage.value = '';
              }
            },
          ),
        );
      }),
    );
  }

  Widget _buildTimerSection() {
    return Obx(() {
      if (controller.isOtpExpired.value || controller.isMaxAttemptsReached.value) {
        return Center(
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                color: TColors.third,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                controller.isOtpExpired.value
                    ? 'OTP Expired'
                    : 'Maximum Attempts Reached',
                style: TextStyle(
                  color: TColors.third,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please go back and register again',
                style: TextStyle(
                  color: TColors.text.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }

      return Column(
        children: [
          // Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer_outlined,
                color: controller.remainingTime.value < 60
                    ? TColors.orange
                    : TColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'OTP expires in ${controller.getFormattedTime()}',
                style: TextStyle(
                  color: controller.remainingTime.value < 60
                      ? TColors.orange
                      : TColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Attempts remaining
          Text(
            '${controller.attemptsRemaining.value} attempt(s) remaining',
            style: TextStyle(
              color: TColors.text.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TColors.third.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TColors.third),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: TColors.third, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              controller.errorMessage.value,
              style: TextStyle(
                color: TColors.third,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyButton() {
    return Obx(() {
      final isEnabled = !controller.isLoading.value &&
          !controller.isOtpExpired.value &&
          !controller.isMaxAttemptsReached.value &&
          controller.otpLength.value == 6;

      return SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: isEnabled ? () => controller.verifyOtp() : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: TColors.secondary,
            disabledBackgroundColor: TColors.secondary.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 0,
          ),
          child: Text(
            'Verify OTP',
            style: TextStyle(
              color: TColors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    });
  }
}

