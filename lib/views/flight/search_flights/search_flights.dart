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
import 'airarabia/airarabia_flight_model.dart';
import 'airblue/airblue_flight_controller.dart';
import 'airblue/airblue_flight_model.dart';
import 'filters/flight_filter_service.dart';
import 'pia/pia_flight_controller.dart';
import 'pia/pia_flight_model.dart';
import 'sabre/sabre_flight_controller.dart';
import 'sabre/sabre_flight_models.dart';
import 'search_flight_utils/widgets/airarabia_flight_card.dart';
import 'search_flight_utils/widgets/airblue_flight_card.dart';
import 'search_flight_utils/widgets/currency_dialog.dart';
import 'filters/flight_bottom_sheet.dart';
import 'search_flight_utils/widgets/pia_flight_card.dart';
import 'search_flight_utils/widgets/sabre_flight_card.dart';
import 'flydubai/flydubai_model.dart';
import '../form/flight_booking_controller.dart';
import 'emirates_ndc/emirates_model.dart';
import '../../../widgets/city_selection_bottom_sheet.dart';

enum FlightScenario { oneWay, returnFlight, multiCity }

class FlightBookingPage extends StatefulWidget {
  final FlightScenario scenario;

  const FlightBookingPage({super.key, required this.scenario});

  @override
  State<FlightBookingPage> createState() => _FlightBookingPageState();
}

class _FlightBookingPageState extends State<FlightBookingPage> {
  final SabreFlightController controller = Get.put(SabreFlightController());
  final AirBlueFlightController airBlueController = Get.find<AirBlueFlightController>();
  final PIAFlightController piaController = Get.put(PIAFlightController());
  final AirArabiaFlightController airArabiaController = Get.put(AirArabiaFlightController());
  final FlydubaiFlightController flyDubaiController = Get.put(FlydubaiFlightController());
  final FilterController filterController = Get.put(FilterController());
  final EmiratesFlightController emiratesController = Get.put(EmiratesFlightController());
  late final AirportController airportController;

  @override
  void initState() {
    super.initState();
    controller.setScenario(widget.scenario);
    
    // Initialize AirportController and ensure airports are loaded
    airportController = Get.isRegistered<AirportController>()
        ? Get.find<AirportController>()
        : Get.put(AirportController());
    
    // Fetch airports if not already loaded
    if (!airportController.isAirportsLoaded.value) {
      airportController.fetchAirports();
    }

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
        // actions: [
        //   GetX<SabreFlightController>(
        //     builder: (controller) => TextButton(
        //       onPressed: () {
        //         showDialog(
        //           context: context,
        //           builder: (context) => CurrencyDialog(controller: controller),
        //         );
        //       },
        //       child: Text(
        //         controller.selectedCurrency.value,
        //         style: const TextStyle(
        //           color: TColors.primary,
        //           fontWeight: FontWeight.bold,
        //         ),
        //       ),
        //     ),
        //   ),
        //   const SizedBox(width: 8),
        // ],
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
  return Expanded(
    child: Obx(() {
      final isAnyLoading = airBlueController.isLoading.value ||
          flyDubaiController.isLoading.value ||
          controller.isLoading.value ||
          piaController.isLoading.value ||
          airArabiaController.isLoading.value ||
          emiratesController.isLoading.value;
      
      // Wait for airports to be loaded before showing flight cards
      final airportsLoading = airportController.isLoading.value;
      final airportsLoaded = airportController.isAirportsLoaded.value;

      final combinedFlights = _buildUnifiedFlightItems();

      // Show loading if airports are still loading (even if flights are ready)
      if (airportsLoading || (!airportsLoaded && combinedFlights.isNotEmpty)) {
        return _buildInitialLoadingState(context);
      }

      if (combinedFlights.isEmpty && isAnyLoading) {
        return _buildInitialLoadingState(context);
      }

      if (combinedFlights.isEmpty) {
        return _buildNoFlightsState();
      }

        return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            // Animated Progress Bar - Shows progress of remaining API calls
            if (isAnyLoading)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: _calculateLoadProgress()),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  builder: (context, value, _) => Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Searching more flights...',
                            style: TextStyle(
                              fontSize: 11,
                              color: TColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${(value * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: TColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: value,
                        backgroundColor: TColors.grey.withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation(TColors.primary),
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  ),
                ),
              ),

          _buildTotalFlightsCount(
            totalFlights: combinedFlights.length,
            isLoading: isAnyLoading,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 36),
              physics: const BouncingScrollPhysics(),
              itemCount: combinedFlights.length,
              itemBuilder: (context, index) {
                return combinedFlights[index].buildCard();
              },
            ),
          ),
        ],
      );
    }),
  );
}

double _calculateLoadProgress() {
    int total = 6;
    final flightBookingController = Get.find<FlightBookingController>();
    
    // Adjust total based on active APIs
    if (flightBookingController.tripType.value == TripType.multiCity) {
      total = 5; // Emirates is skipped for multi-city
    }
    
    int loadingCount = 0;
    if (controller.isLoading.value) loadingCount++;
    if (airBlueController.isLoading.value) loadingCount++;
    if (piaController.isLoading.value) loadingCount++;
    if (airArabiaController.isLoading.value) loadingCount++;
    if (flyDubaiController.isLoading.value) loadingCount++;
    
    // Emirates only counts if included
    if (flightBookingController.tripType.value != TripType.multiCity) {
       if (emiratesController.isLoading.value) loadingCount++;
    }
    
    int completed = total - loadingCount;
    // Return at least a small value so the bar starts visible (optional) or starts at 0
    return completed / total;
  }
// Add this to the FlightBookingPage class

Widget _buildTotalFlightsCount({
  required int totalFlights,
  required bool isLoading,
}) {
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

  List<_UnifiedFlightItem> _buildUnifiedFlightItems() {
    final List<_UnifiedFlightItem> items = [];

    void addFlight({
      required dynamic flight,
      required Widget Function() builder,
    }) {
      items.add(
        _UnifiedFlightItem(
          price: _extractFlightPrice(flight),
          durationMinutes: _extractFlightDurationMinutes(flight),
          buildCard: builder,
        ),
      );
    }

    for (final SabreFlight flight in controller.filteredFlights) {
      addFlight(
        flight: flight,
        builder: () => FlightCard(flight: flight),
      );
    }

    for (final AirBlueFlight flight in airBlueController.filteredFlights) {
      addFlight(
        flight: flight,
        builder: () => AirBlueFlightCard(flight: flight),
      );
    }

    // Handle FlyDubai flights - check if multi-city
    final flightBookingController = Get.find<FlightBookingController>();
    final isMultiCity = flightBookingController.tripType.value == TripType.multiCity;
    
    if (isMultiCity) {
      // For multi-city, show flights for the current segment (segment 0 initially)
      final currentSegment = flyDubaiController.currentMultiCitySegment.value;
      print('🔍 Building unified flight items - Multi-city mode');
      print('  Current segment: $currentSegment');
      print('  Total city pairs: ${flightBookingController.cityPairs.length}');
      
      final segmentFlights = flyDubaiController.getFlightsForSegment(currentSegment);
      print('  Flights returned for segment $currentSegment: ${segmentFlights.length}');
      
      if (segmentFlights.isEmpty) {
        print('  ⚠️ No FlyDubai flights found for segment $currentSegment');
      } else {
        print('  ✅ Adding ${segmentFlights.length} FlyDubai flights to unified list');
      }
      
      for (final FlydubaiFlight flight in segmentFlights) {
        addFlight(
          flight: flight,
          builder: () => FlyDubaiFlightCard(flight: flight, showReturnFlight: false),
        );
      }
    } else {
      // For one-way and return, use existing logic
      print('🔍 Building unified flight items - One-way/Return mode');
      print('  FlyDubai outbound flights: ${flyDubaiController.filteredOutboundFlights.length}');
      for (final FlydubaiFlight flight in flyDubaiController.filteredOutboundFlights) {
        addFlight(
          flight: flight,
          builder: () => FlyDubaiFlightCard(flight: flight, showReturnFlight: false),
        );
      }
    }

    for (final PIAFlight flight in piaController.filteredFlights) {
      addFlight(
        flight: flight,
        builder: () => GestureDetector(
          onTap: () => piaController.handlePIAFlightSelection(flight),
          child: PIAFlightCard(flight: flight),
        ),
      );
    }

    for (final AirArabiaFlight flight in airArabiaController.filteredFlights) {
      addFlight(
        flight: flight,
        builder: () => GestureDetector(
          onTap: () => airArabiaController.handleAirArabiaFlightSelection(flight),
          child: AirArabiaFlightCard(flight: flight),
        ),
      );
    }

    for (final EmiratesFlight flight in emiratesController.filteredFlights) {
      addFlight(
        flight: flight,
        builder: () => EmiratesFlightCard(flight: flight),
      );
    }

    final sortType = filterController.sortType.value;
    if (sortType == 'Fastest') {
      items.sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
    } else {
      items.sort((a, b) => a.price.compareTo(b.price));
    }

    return items;
  }

double _extractFlightPrice(dynamic flight) {
  if (flight is SabreFlight) return flight.price;
  if (flight is AirBlueFlight) return flight.price;
  if (flight is FlydubaiFlight) return flight.price;
  if (flight is PIAFlight) return flight.price;
  if (flight is AirArabiaFlight) return flight.price;
  if (flight is EmiratesFlight) return flight.price;
  return double.infinity;
}

int _extractFlightDurationMinutes(dynamic flight) {
  if (flight is SabreFlight) {
    final elapsed = flight.legElapsedTime ?? 0;
    if (elapsed > 0) return elapsed;
    return _sumLegElapsedTime(flight.legSchedules);
  }
  if (flight is AirBlueFlight) {
    return _sumLegElapsedTime(flight.legSchedules);
  }
  if (flight is FlydubaiFlight) {
    final duration = flight.flightSegment.arrivalDateTime
        .difference(flight.flightSegment.departureDateTime)
        .inMinutes;
    if (duration > 0) return duration;
    return _sumLegElapsedTime(flight.legSchedules);
  }
  if (flight is PIAFlight) {
    final elapsed = flight.legElapsedTime ?? _parseDurationString(flight.duration);
    if (elapsed > 0) return elapsed;
    return _sumLegElapsedTime(flight.legSchedules);
  }
  if (flight is AirArabiaFlight) {
    if (flight.totalDuration > 0) return flight.totalDuration;
    return _sumLegElapsedTime(flight.flightSegments);
  }
  if (flight is EmiratesFlight) {
    final elapsed = _sumLegElapsedTime(flight.legSchedules);
    if (elapsed > 0) return elapsed;
  }
  return 1 << 20;
}

int _sumLegElapsedTime(dynamic legSchedules) {
  if (legSchedules is! List || legSchedules.isEmpty) {
    return 0;
  }

  int totalMinutes = 0;
  for (final leg in legSchedules) {
    int legMinutes = 0;
    if (leg is Map<String, dynamic>) {
      legMinutes = _parseInt(leg['elapsedTime']);
      if (legMinutes == 0) {
        final departure = _parseDateTime(leg['departure']?['dateTime']);
        final arrival = _parseDateTime(leg['arrival']?['dateTime']);
        if (departure != null && arrival != null) {
          legMinutes = arrival.difference(departure).inMinutes;
        }
      }
    }
    if (legMinutes > 0) {
      totalMinutes += legMinutes;
    }
  }
  return totalMinutes;
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _parseDateTime(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

int _parseDurationString(String? duration) {
  if (duration == null || duration.isEmpty) return 0;

  final isoMatch = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?').firstMatch(duration);
  if (isoMatch != null) {
    final hours = int.tryParse(isoMatch.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(isoMatch.group(2) ?? '') ?? 0;
    return hours * 60 + minutes;
  }

  final hoursMatch = RegExp(r'(\d+)\s*h').firstMatch(duration);
  final minutesMatch = RegExp(r'(\d+)\s*m').firstMatch(duration);
  final hours = hoursMatch != null ? int.tryParse(hoursMatch.group(1)!) ?? 0 : 0;
  final minutes = minutesMatch != null ? int.tryParse(minutesMatch.group(1)!) ?? 0 : 0;

  return hours * 60 + minutes;
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

class _UnifiedFlightItem {
  _UnifiedFlightItem({
    required this.price,
    required this.durationMinutes,
    required this.buildCard,
  });

  final double price;
  final int durationMinutes;
  final Widget Function() buildCard;
}