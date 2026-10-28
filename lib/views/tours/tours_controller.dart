import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/api_service_tours.dart';
import 'tour_model.dart';
import 'tour_whatsapp.dart';

enum TourSort { recommended, priceLowToHigh, priceHighToLow }

extension TourSortLabel on TourSort {
  String get label {
    switch (this) {
      case TourSort.recommended:
        return 'Sort by default';
      case TourSort.priceLowToHigh:
        return 'Price: low to high';
      case TourSort.priceHighToLow:
        return 'Price: high to low';
    }
  }
}

class ToursController extends GetxController {
  final ApiServiceTours _api = ApiServiceTours();

  final RxList<TourModel> tours = <TourModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  final RxString searchQuery = ''.obs;
  final Rx<TourSort> sort = TourSort.recommended.obs;

  /// Id of the tour whose WhatsApp enquiry is being prepared ('' when idle).
  final RxString sharingTourId = ''.obs;

  /// Shared instance for the home Tours tab and the full tours screen.
  static ToursController get instance => Get.isRegistered<ToursController>()
      ? Get.find<ToursController>()
      : Get.put(ToursController());

  Future<void> fetchTours() async {
    if (isLoading.value) return;
    isLoading.value = true;
    errorMessage.value = '';
    try {
      tours.value = await _api.fetchTours();
    } on ToursApiException catch (e) {
      // Keep any tours already on screen; the error only shows when empty.
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  /// Tours after the search box and sort menu are applied.
  List<TourModel> get visibleTours {
    final String query = searchQuery.value.trim().toLowerCase();
    final List<TourModel> result = query.isEmpty
        ? tours.toList()
        : tours
            .where(
              (tour) =>
                  tour.name.toLowerCase().contains(query) ||
                  tour.country.toLowerCase().contains(query) ||
                  tour.description.toLowerCase().contains(query),
            )
            .toList();

    if (sort.value != TourSort.recommended) {
      final bool ascending = sort.value == TourSort.priceLowToHigh;
      // Price-on-call tours have no amount to compare, so they always go last.
      result.sort((a, b) {
        if (a.hasPrice != b.hasPrice) return a.hasPrice ? -1 : 1;
        if (!a.hasPrice) return 0;
        return ascending
            ? a.price!.compareTo(b.price!)
            : b.price!.compareTo(a.price!);
      });
    }
    return result;
  }

  Future<void> bookViaWhatsApp(TourModel tour) async {
    if (sharingTourId.value.isNotEmpty) return;
    sharingTourId.value = tour.id;
    try {
      final bool opened = await TourWhatsApp.send(tour);
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
      sharingTourId.value = '';
    }
  }
}
