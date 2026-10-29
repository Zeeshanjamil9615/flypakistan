import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service_cars.dart';
import '../tours/tour_whatsapp.dart';
import 'car_model.dart';

enum CarSort { recommended, priceLowToHigh, priceHighToLow }

extension CarSortLabel on CarSort {
  String get label {
    switch (this) {
      case CarSort.recommended:
        return 'Sort by default';
      case CarSort.priceLowToHigh:
        return 'Price: low to high';
      case CarSort.priceHighToLow:
        return 'Price: high to low';
    }
  }
}

class CarsController extends GetxController {
  final ApiServiceCars _api = ApiServiceCars();

  final RxList<CarModel> cars = <CarModel>[].obs;
  final RxList<String> cities = <String>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  /// City filter shared by the home Cars tab and the full list ('' = all).
  final RxString selectedCity = ''.obs;
  final RxString searchQuery = ''.obs;
  final Rx<CarSort> sort = CarSort.recommended.obs;

  /// Id of the car whose WhatsApp enquiry is being prepared ('' when idle).
  final RxString sharingCarId = ''.obs;

  /// Shared instance for the home Cars tab and the full cars screen.
  static CarsController get instance => Get.isRegistered<CarsController>()
      ? Get.find<CarsController>()
      : Get.put(CarsController());

  Future<void> fetchCars() async {
    if (isLoading.value) return;
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final CarsResponse response = await _api.fetchCars();
      cars.value = response.cars;
      cities.value = response.cities;
      if (!cities.contains(selectedCity.value)) selectedCity.value = '';
    } on CarsApiException catch (e) {
      // Keep any cars already on screen; the error only shows when empty.
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  /// Cars in the selected city, in the API's order.
  List<CarModel> get carsInCity => selectedCity.value.isEmpty
      ? cars.toList()
      : cars.where((car) => car.city == selectedCity.value).toList();

  /// [carsInCity] after the search box and sort menu are applied.
  List<CarModel> get visibleCars {
    final String query = searchQuery.value.trim().toLowerCase();
    final List<CarModel> result = query.isEmpty
        ? carsInCity
        : carsInCity
            .where(
              (car) =>
                  car.name.toLowerCase().contains(query) ||
                  car.city.toLowerCase().contains(query) ||
                  car.description.toLowerCase().contains(query),
            )
            .toList();

    if (sort.value != CarSort.recommended) {
      final bool ascending = sort.value == CarSort.priceLowToHigh;
      // Sorted by the within-city rate; cars without a rate always go last.
      result.sort((a, b) {
        if (a.hasRate != b.hasRate) return a.hasRate ? -1 : 1;
        if (!a.hasRate) return 0;
        return ascending
            ? a.rate!.compareTo(b.rate!)
            : b.rate!.compareTo(a.rate!);
      });
    }
    return result;
  }

  /// Same wording as the website's "Whatsapp Now" button, e.g. "Hello! I'm
  /// interested in renting the Yaris in Faisalabad. Can you please provide
  /// more details?"
  static String enquiryMessage(CarModel car) {
    final String city = car.city.isNotEmpty ? ' in ${car.city}' : '';
    return "Hello! I'm interested in renting the ${car.name}$city. "
        'Can you please provide more details?';
  }

  /// "+92 345 9668442" — calls go to the same number as WhatsApp.
  static String get displayPhone {
    const String phone = TourWhatsApp.phone;
    return '+${phone.substring(0, 2)} ${phone.substring(2, 5)} '
        '${phone.substring(5)}';
  }

  Future<void> callNow() async {
    bool opened = false;
    try {
      opened = await launchUrl(
        Uri(scheme: 'tel', path: '+${TourWhatsApp.phone}'),
      );
    } catch (e) {
      print('CarsController call error: $e');
    }
    if (!opened) {
      Get.snackbar(
        'Call',
        'Could not open the dialer. Please call us on $displayPhone.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.85),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
      );
    }
  }

  Future<void> bookViaWhatsApp(CarModel car) async {
    if (sharingCarId.value.isNotEmpty) return;
    sharingCarId.value = car.id;
    try {
      final bool opened = await TourWhatsApp.sendEnquiry(
        text: enquiryMessage(car),
        imageUrl: car.image,
        fileName: 'car_${car.id}',
      );
      if (!opened) {
        Get.snackbar(
          'WhatsApp',
          'Could not open WhatsApp. Please make sure WhatsApp is installed.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.85),
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
        );
      }
    } finally {
      sharingCarId.value = '';
    }
  }
}
