import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../services/api_service_hotel.dart';
import '../../../../widgets/loading_dailog.dart';
import '../../../widgets/date_range_slector.dart';
import '../../../widgets/hotel_custom_textfield.dart';
import '../search_hotels/search_hotel.dart';
import '../search_hotels/search_hotel_controller.dart';
import 'guests/guests_controller.dart';
import 'hotel_date_controller.dart';
import 'guests/guests_field.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Add this package for animations

import '../../../utility/colors.dart';
import '../../../utility/app_constants.dart';
import '../../../widgets/custom_date_picker_sheet.dart';

class HotelFormScreen extends StatelessWidget {
  const HotelFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
        children: [
          // Background with gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  TColors.primary.withOpacity(0.9),
                  TColors.secondary.withOpacity(0.9),
                ],
              ),
            ),
          ),

          // Curved white background
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: TColors.background,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 15,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
            ),
          ),

          // App Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              title: const Text(
                'Find Your Perfect Hotel',
                style: TextStyle(
                  color: TColors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 70),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: HotelForm(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class HotelForm extends StatefulWidget {
  HotelForm({super.key});

  @override
  State<HotelForm> createState() => _HotelFormState();
}

class _HotelFormState extends State<HotelForm> {
  // Persistent state
  final Rx<CityData?> selectedCity = Rx<CityData?>(null);
  late final TextEditingController cityController;

  @override
  void initState() {
    super.initState();
    // Initialize controllers
    Get.find<HotelDateController>();
    Get.find<SearchHotelController>();
    cityController = TextEditingController();
  }

  @override
  void dispose() {
    cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hotelDateController = Get.find<HotelDateController>();
    final searchHotelController = Get.find<SearchHotelController>();

    String _formatDate(DateTime date) {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDecorativeHeader()
              .animate()
              .fadeIn(duration: const Duration(milliseconds: 600))
              .slideY(
                begin: -0.2,
                end: 0,
                duration: const Duration(milliseconds: 600),
              ),

          const SizedBox(height: 16),

          _buildSectionTitle('Where would you like to go?', Icons.location_on)
              .animate()
              .fadeIn(delay: const Duration(milliseconds: 200))
              .slideX(begin: -0.1, end: 0),

          const SizedBox(height: 8),

          // City field: directly use CustomTextField so bottom sheet opens immediately
          _buildFormField(
            child: CustomTextField(
              hintText: 'Enter City Name',
              icon: Icons.location_on,
              controller: cityController,
              onCitySelected: (cityData) {
                selectedCity.value = cityData;
                cityController.text = cityData.displayName;
              },
            ),
          )
              .animate()
              .fadeIn(delay: const Duration(milliseconds: 300))
              .slideX(begin: 0.1, end: 0),

          const SizedBox(height: 16),

          _buildSectionTitle(
                'When are you planning to travel?',
                Icons.calendar_today,
              )
              .animate()
              .fadeIn(delay: const Duration(milliseconds: 400))
              .slideX(begin: -0.1, end: 0),

          const SizedBox(height: 8),

          // Date range selector using custom bottom sheet to match flights
          Obx(() => _buildFieldContainer(
                onTap: () async {
                  final result = await showCustomDateRangePicker(
                    context: context,
                    selectedDateRange: hotelDateController.dateRange.value,
                    title: 'Select Dates',
                    label: 'Select your stay',
                  );
                  if (result != null) {
                    hotelDateController.updateDateRange(result);
                  }
                },
                leadingIcon: Icons.calendar_today,
                placeholder: 'Select dates',
                valueText:
                    '${_formatDate(hotelDateController.dateRange.value.start)} - ${_formatDate(hotelDateController.dateRange.value.end)} (${hotelDateController.nights.value} night${hotelDateController.nights.value > 1 ? 's' : ''})',
              ))
              .animate()
              .fadeIn(delay: const Duration(milliseconds: 500))
              .slideX(begin: 0.1, end: 0),

          const SizedBox(height: 16),

          _buildSectionTitle('How many guests?', Icons.person)
              .animate()
              .fadeIn(delay: const Duration(milliseconds: 600))
              .slideX(begin: -0.1, end: 0),

          const SizedBox(height: 8),

          _buildFormField(child: const GuestsField())
              .animate()
              .fadeIn(delay: const Duration(milliseconds: 700))
              .slideX(begin: 0.1, end: 0),

          const SizedBox(height: 24),

          Center(
                child: SizedBox(
                  width: double.infinity,
                  height: AppConstants.buttonHeight + 8,
                  child: _buildSearchButton(context),
                ),
              )
              .animate()
              .fadeIn(delay: const Duration(milliseconds: 800))
              .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),

        ],
      ),
    );
  }

  // removed redundant city bottom sheet trigger; CustomTextField handles it directly

  Widget _buildDecorativeHeader() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: TColors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: TColors.primary.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hotel, color: TColors.iconclr, size: 30),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find Your Dream Stay',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: TColors.text,
                    ),
                  ),
                  Text(
                    'Best prices guaranteed',
                    style: TextStyle(fontSize: 12, color: TColors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 7,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              children: [
                Container(
                  width: 120,
                  height: 7,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [TColors.primary, TColors.third],
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: TColors.iconclr),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: TColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(color: AppConstants.fieldBorderColor),
        boxShadow: AppConstants.cardShadow,
      ),
      child: child,
    );
  }

  Widget _buildFieldContainer({
    required VoidCallback onTap,
    required IconData leadingIcon,
    required String placeholder,
    String? valueText,
  }) {
    final hasValue = (valueText != null && valueText.isNotEmpty);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: AppConstants.fieldHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(color: AppConstants.fieldBorderColor),
          boxShadow: AppConstants.cardShadow,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              leadingIcon,
              color: hasValue ? TColors.iconclr : AppConstants.tabInactiveColor,
              size: AppConstants.smallIconSize,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasValue ? valueText! : placeholder,
                style: hasValue ? AppConstants.fieldValueStyle : AppConstants.fieldLabelStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
          // Validate if a city is selected
          if (selectedCity.value == null) {
            Get.snackbar(
              'Missing Information',
              'Please select a city first',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.red.withOpacity(0.8),
              colorText: Colors.white,
            );
            return;
          }

          final hotelDateController = Get.find<HotelDateController>();
          final guestsController = Get.find<GuestsController>();

          // Get values from selected city
          String destinationCode = selectedCity.value!.value;
          String countryCode = selectedCity.value!.countryCode;

          // Default values
          String nationality = "PK"; // You might want to make this dynamic too
          String currency = "USD"; // You might want to make this dynamic too

          String checkInDate =
              hotelDateController.checkInDate.value.toIso8601String();
          String checkOutDate =
              hotelDateController.checkOutDate.value.toIso8601String();

          // Create rooms array with the new structure
          List<Map<String, dynamic>> rooms = List.generate(
            guestsController.roomCount.value,
            (index) => {
              "RoomIdentifier": index + 1,
              "Adult": guestsController.rooms[index].adults.value,
              "Children": guestsController.rooms[index].children.value,
              if (guestsController.rooms[index].children.value > 0)
                "ChildrenAges":
                    guestsController.rooms[index].childrenAges.toList(),
            },
          );

          // Navigate to the hotel listing screen immediately
          Get.to(() => const HotelScreen());

          try {
            // Call the API (this will update the loading state and hotels list)
            await ApiServiceHotel().fetchHotels(
              destinationCode: destinationCode,
              countryCode: countryCode,
              nationality: nationality,
              currency: currency,
              checkInDate: checkInDate,
              checkOutDate: checkOutDate,
              rooms: rooms,
              cityId: selectedCity.value!.cityId ?? '1',
            );
          } catch (e) {
            // Check if it's a network-related error
            String errorTitle = 'Something went wrong';
            String errorMessage = 'An unexpected error occurred. Please try again.';
            IconData errorIcon = Icons.error_outline;
            
            final errorString = e.toString().toLowerCase();
            if (errorString.contains('socketexception') ||
                errorString.contains('connection') ||
                errorString.contains('network is unreachable') ||
                errorString.contains('dioexception') ||
                errorString.contains('failed host lookup') ||
                errorString.contains('no internet') ||
                errorString.contains('errno = 101') ||
                errorString.contains('errno = 7')) {
              errorTitle = 'No Internet Connection';
              errorMessage = 'Please check your internet connection and try again.';
              errorIcon = Icons.wifi_off;
            } else if (errorString.contains('timeout')) {
              errorTitle = 'Connection Timeout';
              errorMessage = 'The server took too long to respond. Please try again later.';
              errorIcon = Icons.timer_off;
            }
            
            // Show error dialog
            Get.dialog(
              Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        errorIcon,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        errorTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage,
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Get.back(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TColors.primary,
                          minimumSize: const Size(200, 45),
                        ),
                        child: const Text(
                          'OK',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              barrierDismissible: false,
            );
          }
      },
      child: Container(
        height: AppConstants.buttonHeight,
        decoration: BoxDecoration(
          color: TColors.primary,
          borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
          boxShadow: [
            BoxShadow(
              color: TColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'SEARCH HOTELS',
                style: AppConstants.buttonTextStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
