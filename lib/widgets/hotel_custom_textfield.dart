import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/api_service_hotel.dart';
import '../utility/app_constants.dart';
import '../utility/colors.dart';

class CityData {
  final String value;
  final String countryCode;
  final String zone;
  final String label;

  CityData({
    required this.value,
    required this.countryCode,
    required this.zone,
    required this.label,
  });

  factory CityData.fromJson(Map<String, dynamic> json) {
    return CityData(
      value: json['value']?.toString() ?? '',
      countryCode: json['country_code']?.toString() ?? '',
      zone: json['zone']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }

  String get displayName {
    return label;
  }

  // You may need these getters for backward compatibility with existing code
  String get cityStateCode => value;
  String get cityStateName => zone;
  String get countryName => label.split(', ').last;
  String get zoneName => zone;
  String get zoneCode => value.split('-').first;
}

class CityController extends GetxController {
  final ApiServiceHotel _apiService = Get.put(ApiServiceHotel());

  var cities = <CityData>[].obs;
  var isLoading = false.obs;
  var searchQuery = ''.obs;

  Worker? _debounceWorker;

  @override
  void onInit() {
    super.onInit();
    _debounceWorker = debounce(
      searchQuery,
          (value) => _searchCities(value),
      time: const Duration(milliseconds: 500),
    );
  }

  @override
  void onClose() {
    _debounceWorker?.dispose();
    super.onClose();
  }

  void updateSearchQuery(String query) {
    searchQuery.value = query;
  }

  // New method to fetch default cities
  Future<void> fetchDefaultCities() async {
    isLoading.value = true;
    cities.value = [];

    try {

      // Fetch cities with a common keyword or empty to get default cities
      final response = await _apiService.fetchCities(''); // or use a default keyword like 'a'

      if (response != null && response.isNotEmpty) {
        final cityList = response.map<CityData>((cityJson) {
          if (cityJson is Map<String, dynamic>) {
            return CityData.fromJson(cityJson);
          } else {
            throw FormatException("Invalid city data format");
          }
        }).toList();

        cities.value = cityList;
      }
    } catch (e) {
      print("Error fetching default cities: $e");
      cities.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _searchCities(String query) async {
    if (query.isEmpty) {
      // Instead of clearing, fetch default cities
      await fetchDefaultCities();
      return;
    }

    isLoading.value = true;

    try {
      final response = await _apiService.fetchCities(query);
      print("API Response: $response");

      if (response != null && response.isNotEmpty) {
        try {
          final cityList = response.map<CityData>((cityJson) {
            print("Processing city item: $cityJson");
            if (cityJson is Map<String, dynamic>) {
              return CityData.fromJson(cityJson);
            } else {
              print("Invalid city item format: $cityJson");
              throw FormatException("Invalid city data format");
            }
          }).toList();

          cities.value = cityList;
        } catch (parseError) {
          print("Error parsing city data: $parseError");
          cities.clear();
          Get.snackbar(
            'Error',
            'Error processing city data. Please try again.',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      } else {
        cities.clear();
        Get.snackbar(
          'Info',
          'No cities found for your search',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      print("Error in city search: $e");
      cities.clear();
      Get.snackbar(
        'Error',
        'Failed to fetch cities. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
class CustomTextField extends StatefulWidget {
  final String hintText;
  final IconData icon;
  final TextEditingController controller;
  final String? label;
  final Function(CityData)? onCitySelected;

  CustomTextField({
    Key? key,
    required this.hintText,
    required this.icon,
    required this.controller,
    this.label,
    this.onCitySelected,
  }) : super(key: key);

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cityController = Get.put(CityController());

    return GestureDetector(
      onTap: () => _showCitySuggestions(context, cityController),
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
              widget.icon,
              color: widget.controller.text.isNotEmpty ? TColors.primary : AppConstants.tabInactiveColor,
              size: AppConstants.smallIconSize,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.controller.text.isNotEmpty ? widget.controller.text : widget.hintText,
                style: widget.controller.text.isNotEmpty
                    ? AppConstants.fieldValueStyle
                    : AppConstants.fieldLabelStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCitySuggestions(
      BuildContext context,
      CityController cityController,
      ) {
    // Initialize with default cities instead of clearing
    cityController.fetchDefaultCities();
    cityController.searchQuery.value = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: TColors.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select City',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ],
                ),
              ),

              // Search field
              Padding(
                padding: const EdgeInsets.all(AppConstants.screenPadding),
                child: Container(
                  height: AppConstants.fieldHeight,
                  decoration: BoxDecoration(
                    color: AppConstants.fieldBackgroundColor,
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    border: Border.all(color: AppConstants.fieldBorderColor),
                    boxShadow: AppConstants.cardShadow,
                  ),
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search for a city',
                      hintStyle: AppConstants.fieldLabelStyle,
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppConstants.tabInactiveColor,
                        size: AppConstants.smallIconSize,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) => cityController.updateSearchQuery(value),
                  ),
                ),
              ),

              Obx(() {
                if (cityController.isLoading.value) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return const SizedBox.shrink();
              }),

              Expanded(
                child: Obx(() {
                  if (cityController.cities.isEmpty) {
                    if (cityController.searchQuery.value.length >= 2 &&
                        !cityController.isLoading.value) {
                      return const Center(
                        child: Text(
                          'No cities found. Try a different search term.',
                        ),
                      );
                    }
                    if (cityController.isLoading.value) {
                      return const SizedBox.shrink();
                    }
                    return const Center(
                      child: Text('Loading cities...'),
                    );
                  }

                  return ListView.builder(
                    itemCount: cityController.cities.length,
                    itemBuilder: (context, index) {
                      final city = cityController.cities[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppConstants.screenPadding,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                          border: Border.all(color: AppConstants.fieldBorderColor),
                          boxShadow: AppConstants.cardShadow,
                        ),
                        child: ListTile(
                          onTap: () {
                            widget.controller.text = city.displayName;
                            if (widget.onCitySelected != null) {
                              widget.onCitySelected!(city);
                            }
                            Navigator.pop(context);
                          },
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      city.zone,
                                      style: AppConstants.fieldValueStyle,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      city.label,
                                      style: AppConstants.fieldLabelStyle,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: TColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                                ),
                                child: Text(
                                  city.countryCode,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: TColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}