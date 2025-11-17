import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../utility/colors.dart';
import '../../../../utility/app_constants.dart';
import '../login/login.dart';
import 'rejistration_controller.dart';

class RegisterAccount extends StatelessWidget {
  final RegisterController controller = Get.put(RegisterController());

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData prefixIcon,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppConstants.fieldLabelStyle.copyWith(
        color: TColors.text.withOpacity(0.7),
      ),
      errorText: errorText,
      prefixIcon: Icon(prefixIcon, color: TColors.primary),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: TColors.grey.withOpacity(0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: TColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: TColors.third),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: TColors.third),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Obx(() => Stack(
          children: [
            SingleChildScrollView(
              child: Container(
                width: double.infinity,
                color: TColors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Header
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 14,
                        left: 16,
                        right: 16,
                        bottom: 30,
                      ),
                      child: Text(
                        'Create a new account',
                        style: AppConstants.sectionTitleStyle.copyWith(
                          color: TColors.text,
                        ),
                      ),
                    ),

                    // "Already have an account? Log in" text
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 20),
                      child: Row(
                        children: [
                          Text(
                            'Already have an account? ',
                            style: AppConstants.fieldLabelStyle.copyWith(
                              color: TColors.text.withOpacity(0.7),
                            ),
                          ),
                          GestureDetector(
                            onTap: (){
                              Get.to(()=>Login());
                            },
                            child: Text(
                              'Log in',
                              style: AppConstants.fieldValueStyle.copyWith(
                                color: TColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Display API error message if any
                    if (controller.apiErrorMessage.value.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: TColors.third.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: TColors.third),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.error_outline, color: TColors.third),
                                  SizedBox(width: 8),
                                  Text(
                                    'Registration Error',
                                    style: AppConstants.fieldValueStyle.copyWith(
                                      color: TColors.third,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                controller.apiErrorMessage.value,
                                style: AppConstants.fieldLabelStyle.copyWith(
                                  color: TColors.third,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Agency Name field
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: TextField(
                        controller: controller.agencyNameController,
                        style: AppConstants.fieldValueStyle.copyWith(
                          color: TColors.text,
                        ),
                        decoration: _buildInputDecoration(
                          label: 'Agency Name',
                          prefixIcon: Icons.business,
                          errorText: controller.getErrorText(
                            controller.agencyNameError,
                          ),
                        ),
                      ),
                    ),

                    // Contact Name field
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: TextField(
                        controller: controller.contactNameController,
                        style: AppConstants.fieldValueStyle.copyWith(
                          color: TColors.text,
                        ),
                        decoration: _buildInputDecoration(
                          label: 'Contact Name',
                          prefixIcon: Icons.person,
                          errorText: controller.getErrorText(
                            controller.contactNameError,
                          ),
                        ),
                      ),
                    ),

                    // Email field
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: TextField(
                        controller: controller.emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: AppConstants.fieldValueStyle.copyWith(
                          color: TColors.text,
                        ),
                        decoration: _buildInputDecoration(
                          label: 'Email',
                          prefixIcon: Icons.email,
                          errorText: controller.getErrorText(
                            controller.emailError,
                          ),
                        ),
                      ),
                    ),

                    // Country Code and Cell
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Country Code dropdown
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    border: Border.all(
                                      color:
                                      controller.countryCodeError.value.isNotEmpty
                                          ? TColors.third
                                          : TColors.grey.withOpacity(0.3),
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Row(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(left: 12),
                                        child: Icon(Icons.flag, color: TColors.primary),
                                      ),
                                      Expanded(
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: controller.selectedCountryCode.value.isEmpty
                                                ? null
                                                : controller.selectedCountryCode.value,
                                            dropdownColor: Colors.white,
                                            icon: Icon(
                                              Icons.arrow_drop_down,
                                              color: TColors.text,
                                            ),
                                            style: AppConstants.fieldValueStyle.copyWith(
                                              color: TColors.text,
                                            ),
                                            isExpanded: true,
                                            hint: Padding(
                                              padding: const EdgeInsets.only(left: 8),
                                              child: Text(
                                                'Code',
                                                style: AppConstants.fieldLabelStyle.copyWith(
                                                  color: TColors.text.withOpacity(0.7),
                                                ),
                                              ),
                                            ),
                                            items: controller.countryCodes.map((String code) {
                                              return DropdownMenuItem<String>(
                                                value: code,
                                                child: Padding(
                                                  padding: const EdgeInsets.only(left: 8),
                                                  child: Text(code),
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: controller.updateCountryCode,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (controller.countryCodeError.value.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 12,
                                      top: 6,
                                    ),
                                    child: Text(
                                      controller.countryCodeError.value,
                                      style: AppConstants.fieldLabelStyle.copyWith(
                                        color: TColors.third,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(width: 10),
                          // Cell field
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: controller.cellController,
                              keyboardType: TextInputType.phone,
                              style: AppConstants.fieldValueStyle.copyWith(
                                color: TColors.text,
                              ),
                              decoration: _buildInputDecoration(
                                label: 'Cell Number',
                                prefixIcon: Icons.phone,
                                errorText: controller.getErrorText(
                                  controller.cellError,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Address field
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: TextField(
                        controller: controller.addressController,
                        style: AppConstants.fieldValueStyle.copyWith(
                          color: TColors.text,
                        ),
                        decoration: _buildInputDecoration(
                          label: 'Address',
                          prefixIcon: Icons.location_on,
                          errorText: controller.getErrorText(
                            controller.addressError,
                          ),
                        ),
                      ),
                    ),

                    // City Name field
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: TextField(
                        controller: controller.cityNameController,
                        style: AppConstants.fieldValueStyle.copyWith(
                          color: TColors.text,
                        ),
                        decoration: _buildInputDecoration(
                          label: 'City Name',
                          prefixIcon: Icons.location_city,
                          errorText: controller.getErrorText(
                            controller.cityNameError,
                          ),
                        ),
                      ),
                    ),

                    // Register button
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Column(
                        children: [
                          ElevatedButton(
                            onPressed: controller.isLoading.value ? null : controller.register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TColors.secondary,
                              disabledBackgroundColor: TColors.secondary.withOpacity(0.5),
                              minimumSize: Size(double.infinity, 55),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: controller.isLoading.value
                                ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: TColors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : Text(
                              'Register',
                              style: AppConstants.fieldValueStyle.copyWith(
                                color: TColors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Get.to(() => const Login()),
                            child: Text(
                              'Login',
                              style: AppConstants.fieldValueStyle.copyWith(
                                color: TColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 30),
                  ],
                ),
              ),
            ),

            // Loading overlay
            if (controller.isLoading.value)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.all(24),
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
                          CircularProgressIndicator(color: TColors.primary),
                          SizedBox(height: 16),
                          Text(
                            'Creating your account...',
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
    );
  }
}