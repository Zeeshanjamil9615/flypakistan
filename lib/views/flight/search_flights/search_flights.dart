import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ready_flights/views/flight/search_flights/emirates_ndc/emirates_flight_controller.dart';
import 'package:ready_flights/views/flight/search_flights/flydubai/flydubai_controller.dart';
import 'package:ready_flights/views/flight/search_flights/search_flight_utils/widgets/emirates_ndc_card.dart';
import 'package:ready_flights/views/flight/search_flights/search_flight_utils/widgets/flydubai_flight_card.dart';
import 'package:ready_flights/views/home/home_screen.dart';
import '../../../utility/colors.dart';
import 'airarabia/airarabia_flight_controller.dart';
import 'airblue/airblue_flight_controller.dart';
import 'filters/flight_filter_service.dart';
import 'pia/pia_flight_controller.dart';
import 'sabre/sabre_flight_controller.dart';
import 'search_flight_utils/widgets/airarabia_flight_card.dart';
import 'search_flight_utils/widgets/airblue_flight_card.dart';
import 'search_flight_utils/widgets/currency_dialog.dart';
import 'filters/flight_bottom_sheet.dart';
import 'search_flight_utils/widgets/pia_flight_card.dart';
import 'search_flight_utils/widgets/sabre_flight_card.dart';
import '../form/flight_booking_controller.dart';

enum FlightScenario { oneWay, returnFlight, multiCity }

class FlightBookingPage extends StatelessWidget {
  final FlightScenario scenario;
  final SabreFlightController controller = Get.put(SabreFlightController());
  final AirBlueFlightController airBlueController = Get.find<AirBlueFlightController>();
  final PIAFlightController piaController = Get.put(PIAFlightController());
  final AirArabiaFlightController airArabiaController = Get.put(AirArabiaFlightController());
  final FlydubaiFlightController flyDubaiController = Get.put(FlydubaiFlightController());
  final FilterController filterController = Get.put(FilterController());
   final EmiratesFlightController emiratesController = Get.put(EmiratesFlightController()); 

  FlightBookingPage({super.key, required this.scenario}) {
    controller.setScenario(scenario);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColors.background,
      appBar: AppBar(
        surfaceTintColor: TColors.background,
        backgroundColor: TColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Get.offAll(() => HomeScreen()); // Replace with the page you want
          },
        ),
        title: Obx(() {
          final flightBookingController = Get.find<FlightBookingController>();
          
          // Get flight search details
          String origin = '';
          String destination = '';
          String date = '';
          String travelClass = flightBookingController.travelClass.value;
          int travelers = flightBookingController.travellersCount.value;
          
          if (flightBookingController.tripType.value == TripType.multiCity) {
            if (flightBookingController.cityPairs.isNotEmpty) {
              origin = flightBookingController.cityPairs.first.fromCityName.value;
              destination = flightBookingController.cityPairs.last.toCityName.value;
              date = flightBookingController.cityPairs.first.departureDate.value;
            }
          } else {
            origin = flightBookingController.fromCityName.value;
            destination = flightBookingController.toCityName.value;
            date = flightBookingController.departureDate.value;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    origin,
                    style: const TextStyle(
                      fontSize: 12,
                      color: TColors.text,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.swap_horiz,
                    size: 12,
                    color: TColors.text,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    destination,
                    style: const TextStyle(
                      fontSize: 12,
                      color: TColors.text,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: TColors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 12,
                      color: TColors.text,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    travelClass,
                    style: const TextStyle(
                      fontSize: 12,
                      color: TColors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '|',
                    style: TextStyle(
                      fontSize: 12,
                      color: TColors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$travelers ${travelers == 1 ? 'Traveller' : 'Travellers'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: TColors.grey,
                    ),
                  ),
                ],
              ),
            ],
          );
        }),
        actions: [
          GetX<SabreFlightController>(
            builder: (controller) => TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => CurrencyDialog(controller: controller),
                );
              },
              child: Text(
                controller.selectedCurrency.value,
                style: const TextStyle(
                  color: TColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(context),
          _buildFlightList(context),
        ],
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: TColors.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: TColors.secondary.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Obx(() => _filterButton(
                'Suggested',
                filterController.sortType.value == 'Suggested',
                    () => filterController.setSuggested()
            )),
            Obx(() => _filterButton(
                'Cheapest',
                filterController.sortType.value == 'Cheapest',
                    () => filterController.setCheapest()
            )),
            Obx(() => _filterButton(
                'Fastest',
                filterController.sortType.value == 'Fastest',
                    () => filterController.setFastest()
            )),
            OutlinedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const FlightFilterBottomSheet(),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: TColors.grey,
                side: BorderSide(color: TColors.grey.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'Filters',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// Update the _buildFlightList method to include Emirates

Widget _buildFlightList(BuildContext context) {
  final airBlueController = Get.find<AirBlueFlightController>();
  final piaController = Get.put(PIAFlightController());
  final flightController = Get.find<SabreFlightController>();
  final emiratesController = Get.find<EmiratesFlightController>(); // Add this

  return Expanded(
    child: Obx(() {
      // Check if any controller is loading
      final isAnyLoading = airBlueController.isLoading.value ||
          flyDubaiController.isLoading.value ||
          flightController.isLoading.value ||
          piaController.isLoading.value ||
          airArabiaController.isLoading.value ||
          emiratesController.isLoading.value; // Add this

      // Check if all controllers have finished loading and have no flights
      final hasNoFlights = !isAnyLoading &&
          airBlueController.filteredFlights.isEmpty &&
          flyDubaiController.filteredOutboundFlights.isEmpty &&
          flightController.filteredFlights.isEmpty &&
          piaController.filteredFlights.isEmpty &&
          airArabiaController.filteredFlights.isEmpty &&
          emiratesController.filteredFlights.isEmpty; // Add this

      final hasFlights =
          airBlueController.filteredFlights.isNotEmpty ||
              flyDubaiController.filteredOutboundFlights.isNotEmpty ||
              flightController.filteredFlights.isNotEmpty ||
              piaController.filteredFlights.isNotEmpty ||
              airArabiaController.filteredFlights.isNotEmpty ||
              emiratesController.filteredFlights.isNotEmpty;

      if (!hasFlights && isAnyLoading) {
        return _buildInitialLoadingState(context);
      }

      // Show main loading indicator when all controllers are loading and no flights are available
      if (hasNoFlights) {
        return _buildNoFlightsState();
      }

      return SingleChildScrollView(
        child: Column(
          children: [
            // Total flights count
            _buildTotalFlightsCount(),

            const SizedBox(height: 6),


            // AirBlue flights section
            _buildAirBlueSection(),

            // FlyDubai flights section
            _buildFlyDubaiSection(),

            // Sabre flights section
            _buildSabreSection(),

            // PIA flights section
            _buildPIASection(),

            // Air Arabia flights section
            _buildAirArabiaSection(),

            // Emirates flights section
            _buildEmiratesSection(), // Add this


            const SizedBox(height: 36),
          ],
        ),
      );
    }),
  );
}
// Add this to the FlightBookingPage class

Widget _buildTotalFlightsCount() {
  return Obx(() {
    // Get total flight count including all airlines
    final totalFlights = controller.filteredFlights.length +
        airBlueController.flights.length +
        piaController.filteredFlights.length +
        airArabiaController.flights.length +
        flyDubaiController.filteredOutboundFlights.length +
        emiratesController.filteredFlights.length;

    final isLoading = controller.isLoading.value ||
        airBlueController.isLoading.value ||
        piaController.isLoading.value ||
        airArabiaController.isLoading.value ||
        flyDubaiController.isLoading.value ||
        emiratesController.isLoading.value;

    if (isLoading) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'We found $totalFlights ${totalFlights == 1 ? 'flight' : 'flights'} for you',
        style: const TextStyle(
          fontSize: 12,
          color: TColors.text,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  });
}

Widget _buildNoFlightsState() {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.flight_takeoff,
            size: 48,
            color: TColors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No flights available right now.',
            style: TextStyle(
              fontSize: 16,
              color: TColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Try adjusting your filters or search criteria.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: TColors.grey,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildInitialLoadingState(BuildContext context) {
  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkeletonBar(widthFactor: 0.6),
          const SizedBox(height: 12),
          _buildSkeletonBar(widthFactor: 0.45),
          const SizedBox(height: 24),
          _buildLoadingInfoCard(context),
          const SizedBox(height: 24),
          ...List.generate(3, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildSkeletonCard(),
            );
          }),
        ],
      ),
    ),
  );
}

Widget _buildLoadingInfoCard(BuildContext context) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 20,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/images/flight-search.svg',
          height: 160,
        ),
        const SizedBox(height: 24),
        const Text(
          'Please wait, we are searching best flight deals for you.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: TColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Our payment plans are flexible—you can pay cash, bank transfer, or choose to pay by credit card.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: TColors.grey,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ],
    ),
  );
}

Widget _buildSkeletonBar({required double widthFactor}) {
  return FractionallySizedBox(
    widthFactor: widthFactor,
    child: Container(
      height: 14,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade200,
            Colors.grey.shade100,
            Colors.grey.shade200,
          ],
        ),
      ),
    ),
  );
}

Widget _buildSkeletonCard() {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSkeletonLine(widthFactor: 0.5),
        const SizedBox(height: 12),
        _buildSkeletonLine(widthFactor: 0.8),
        const SizedBox(height: 12),
        _buildSkeletonLine(widthFactor: 0.65),
      ],
    ),
  );
}

Widget _buildSkeletonLine({required double widthFactor}) {
  return FractionallySizedBox(
    widthFactor: widthFactor,
    child: Container(
      height: 12,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade200,
      ),
    ),
  );
}

Widget _buildEmiratesSection() {
  return Obx(() {
    if (emiratesController.filteredFlights.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: emiratesController.filteredFlights.map((flight) {
        return EmiratesFlightCard(flight: flight);
      }).toList(),
    );
  });
}
  Widget _buildAirBlueSection() {
    return Obx(() {
      if (airBlueController.filteredFlights.isEmpty) {
        return const SizedBox.shrink();
      }

      return Column(
        children: airBlueController.filteredFlights.map((flight) {
          return AirBlueFlightCard(flight: flight);
        }).toList(),
      );
    });
  }

  Widget _buildFlyDubaiSection() {
    return Obx(() {
      if (flyDubaiController.filteredOutboundFlights.isEmpty) {
        return const SizedBox.shrink();
      }

      return Column(
        children: flyDubaiController.filteredOutboundFlights.map((flight) {
          return FlyDubaiFlightCard(flight: flight, showReturnFlight: false);
        }).toList(),
      );
    });
  }

  Widget _buildSabreSection() {
    return Obx(() {
      if (controller.filteredFlights.isEmpty) {
        return const SizedBox.shrink();
      }

      return Column(
        children: controller.filteredFlights.map((flight) {
          return FlightCard(flight: flight);
        }).toList(),
      );
    });
  }

  Widget _buildPIASection() {
    return Obx(() {
      if (piaController.filteredFlights.isEmpty) {
        return const SizedBox.shrink();
      }

      return Column(
        children: piaController.filteredFlights.map((flight) {
          return GestureDetector(
            onTap: () => piaController.handlePIAFlightSelection(flight),
            child: PIAFlightCard(flight: flight),
          );
        }).toList(),
      );
    });
  }

  Widget _buildAirArabiaSection() {
    return Obx(() {
      if (airArabiaController.filteredFlights.isEmpty) {
        return const SizedBox.shrink();
      }

      return Column(
        children: airArabiaController.filteredFlights.map((flight) {
          return GestureDetector(
            onTap: () => airArabiaController.handleAirArabiaFlightSelection(flight),
            child: AirArabiaFlightCard(flight: flight),
          );
        }).toList(),
      );
    });
  }

  Widget _filterButton(String text, bool isSelected, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: isSelected ? TColors.primary : TColors.grey,
        backgroundColor: isSelected ? TColors.primary.withOpacity(0.1) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}