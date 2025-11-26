import 'package:get/get.dart';

import '../airarabia/airarabia_flight_controller.dart';
import '../airblue/airblue_flight_controller.dart';
import '../pia/pia_flight_controller.dart';
import '../sabre/sabre_flight_controller.dart';
import '../flydubai/flydubai_controller.dart';
import '../emirates_ndc/emirates_flight_controller.dart';
import 'filter_flight_model.dart';


class FilterController extends GetxController {
  // Sort filters
  var sortType = 'Suggested'.obs;

  // Airlines filters
  var allAirlines = true.obs;
  var airlineFilters = <String, bool>{}.obs;

  // Stop filters
  var allStops = true.obs;
  var nonStops = false.obs;
  var oneStop = false.obs;
  var twoStop = false.obs;
  var threeStop = false.obs;

  // Available airlines list
  var availableAirlines = <FilterAirline>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadAvailableAirlines();
  }

  void loadAvailableAirlines() {
    List<FilterAirline> allAirlines = [];

    // Get airlines from the sabre controller
    try {
      final sabreController = Get.find<SabreFlightController>();
      allAirlines.addAll(sabreController.getAvailableAirlines());
    } catch (e) {
      // Controller not found
    }

    // Get airlines from Air Arabia controller
    try {
      final airArabiaController = Get.find<AirArabiaFlightController>();
      allAirlines.addAll(airArabiaController.getAvailableAirlines());
    } catch (e) {
      // Controller not found
    }
    // Get airlines from Air Arabia controller
    try {
      final airBlueController = Get.find<AirBlueFlightController>();
      allAirlines.addAll(airBlueController.getAvailableAirlines());
    } catch (e) {
      // Controller not found
    }
    // Get airlines from Air Arabia controller
    try {
      final piaController = Get.find<PIAFlightController>();
      allAirlines.addAll(piaController.getAvailableAirlines());
    } catch (e) {
      // Controller not found
    }

    // Get airlines from other controllers when available
    // Add similar blocks for AirBlue and PIA when they have the methods

    // Remove duplicates based on airline code
    final uniqueAirlines = <String, FilterAirline>{};
    for (var airline in allAirlines) {
      uniqueAirlines[airline.code] = airline;
    }

    availableAirlines.value = uniqueAirlines.values.toList();

    // Initialize airline filters
    airlineFilters.clear();
    for (var airline in availableAirlines) {
      airlineFilters[airline.code] = false;
    }
  }

  // Sort methods
  void updateSortType(String newSortType) {
    sortType.value = newSortType;
    applyFilters();
  }

  void setSuggested() {
    sortType.value = 'Suggested';
    applyFilters();
  }

  void setCheapest() {
    sortType.value = 'Cheapest';
    applyFilters();
  }

  void setFastest() {
    sortType.value = 'Fastest';
    applyFilters();
  }

  // Airline filter methods
  void toggleAllAirlines(bool value) {
    allAirlines.value = value;
    if (value) {
      // Reset individual airline filters when "All Airlines" is selected
      for (var key in airlineFilters.keys) {
        airlineFilters[key] = false;
      }
    }
  }

  void toggleAirlineFilter(String airlineCode, bool value) {
    airlineFilters[airlineCode] = value;
    if (value) {
      // If any individual airline is selected, uncheck "All Airlines"
      allAirlines.value = false;
    } else {
      // If no individual airlines are selected, check "All Airlines"
      bool hasAnySelected = airlineFilters.values.any((selected) => selected);
      if (!hasAnySelected) {
        allAirlines.value = true;
      }
    }
  }

  // Stop filter methods
  void toggleAllStops(bool value) {
    allStops.value = value;
    if (value) {
      nonStops.value = false;
      oneStop.value = false;
      twoStop.value = false;
      threeStop.value = false;
    }
  }

  void toggleNonStops(bool value) {
    nonStops.value = value;
    if (value) allStops.value = false;
  }

  void toggleOneStop(bool value) {
    oneStop.value = value;
    if (value) allStops.value = false;
  }

  void toggleTwoStop(bool value) {
    twoStop.value = value;
    if (value) allStops.value = false;
  }

  void toggleThreeStop(bool value) {
    threeStop.value = value;
    if (value) allStops.value = false;
  }

  // Reset all filters
  void resetFilters() {
    sortType.value = 'Suggested';
    allAirlines.value = true;
    allStops.value = true;
    nonStops.value = false;
    oneStop.value = false;
    twoStop.value = false;
    threeStop.value = false;

    // Reset individual airline filters
    for (var key in airlineFilters.keys) {
      airlineFilters[key] = false;
    }

    applyFilters();
  }

  // Apply filters to all controllers
  void applyFilters() {
    // Prepare airline filters
    List<String> selectedAirlines = [];
    if (allAirlines.value) {
      selectedAirlines = ['all'];
    } else {
      selectedAirlines = airlineFilters.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
    }

    // Prepare stop filters
    List<String> selectedStops = [];
    if (allStops.value) {
      selectedStops = ['all'];
    } else {
      if (nonStops.value) selectedStops.add('nonstop');
      if (oneStop.value) selectedStops.add('1stop');
      if (twoStop.value) selectedStops.add('2stop');
      if (threeStop.value) selectedStops.add('3stop');
    }

    // Apply to Sabre controller
    try {
      final sabreController = Get.find<SabreFlightController>();
      sabreController.applyFilters(
        airlines: selectedAirlines,
        stops: selectedStops,
        sortType: sortType.value,
      );
    } catch (e) {
      // Controller not found or method not available
    }

    // Apply to Air Arabia controller
    try {
      final airArabiaController = Get.find<AirArabiaFlightController>();
      airArabiaController.applyFilters(
        airlines: selectedAirlines,
        stops: selectedStops,
        sortType: sortType.value,
      );
    } catch (e) {
      // Controller not found or method not available
    }

    // Apply to other controllers when they have the methods
    try {
      final airBlueController = Get.find<AirBlueFlightController>();
      airBlueController.applyFilters(
        airlines: selectedAirlines,
        stops: selectedStops,
        sortType: sortType.value,
      );
    } catch (e) {
      // Controller not found or method not available
    }

    try {
      final piaController = Get.find<PIAFlightController>();
      piaController.applyFilters(
        airlines: selectedAirlines,
        stops: selectedStops,
        sortType: sortType.value,
      );
    } catch (e) {
      // Controller not found or method not available
    }

    try {
      final flydubaiController = Get.find<FlydubaiFlightController>();
      flydubaiController.applyFilters(
        airlines: selectedAirlines,
        stops: selectedStops,
        sortType: sortType.value,
      );
    } catch (e) {
      // Controller not found or method not available
    }

    try {
      final emiratesController = Get.find<EmiratesFlightController>();
      emiratesController.applyFilters(
        airlines: selectedAirlines,
        stops: selectedStops,
        sortType: sortType.value,
      );
    } catch (e) {
      // Controller not found or method not available
    }
  }
}

