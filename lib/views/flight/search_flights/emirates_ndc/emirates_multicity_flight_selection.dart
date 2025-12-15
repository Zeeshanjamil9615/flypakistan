import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ready_flights/utility/colors.dart';
import 'package:ready_flights/views/flight/search_flights/emirates_ndc/emirates_flight_controller.dart';
import 'package:ready_flights/views/flight/search_flights/emirates_ndc/emirates_model.dart';

import '../../form/flight_booking_controller.dart';
import '../search_flight_utils/widgets/emirates_ndc_card.dart';

class EmiratesMultiCityFlightPage extends StatefulWidget {
  final int currentSegment;
  final List<EmiratesFlight>? availableFlights;

  const EmiratesMultiCityFlightPage({
    super.key,
    required this.currentSegment,
    this.availableFlights,
  });

  @override
  State<EmiratesMultiCityFlightPage> createState() => _EmiratesMultiCityFlightPageState();
}

class _EmiratesMultiCityFlightPageState extends State<EmiratesMultiCityFlightPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final emiratesController = Get.find<EmiratesFlightController>();
      debugPrint('DEBUG: Emirates multicity page opened for segment ${widget.currentSegment}');
      debugPrint('DEBUG: Available flights: ${_getSafeFlights().length}');
      emiratesController.debugPrintStoredFlights();
    });
  }

  List<EmiratesFlight> _getSafeFlights() {
    return widget.availableFlights ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final bookingController = Get.find<FlightBookingController>();
    final emiratesController = Get.find<EmiratesFlightController>();

    if (widget.currentSegment >= bookingController.cityPairs.length) {
      return _buildErrorScaffold('Invalid segment');
    }

    final cityPair = bookingController.cityPairs[widget.currentSegment];

    return Scaffold(
      backgroundColor: TColors.background,
      appBar: AppBar(
        backgroundColor: TColors.background,
        surfaceTintColor: TColors.background,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Flight: ${cityPair.fromCity.value} → ${cityPair.toCity.value}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Segment ${widget.currentSegment + 1} of ${bookingController.cityPairs.length}',
              style: TextStyle(
                fontSize: 12,
                color: TColors.grey,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: Column(
        children: [
          _buildProgressIndicator(bookingController, emiratesController),
          _buildSegmentInfoCard(cityPair),
          Expanded(child: _buildFlightList(emiratesController)),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(
    FlightBookingController bookingController,
    EmiratesFlightController emiratesController,
  ) {
    return Obx(() => Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: TColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.flight_takeoff, color: TColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Multi-City Trip Progress',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: TColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(
                        bookingController.cityPairs.length,
                        (index) {
                          final isCompleted = index < emiratesController.selectedMultiCityFlights.length &&
                              emiratesController.selectedMultiCityFlights[index] != null &&
                              index < emiratesController.selectedMultiCityPackages.length &&
                              emiratesController.selectedMultiCityPackages[index] != null;
                          final isCurrent = index == widget.currentSegment;
                          return Container(
                            margin: const EdgeInsets.only(right: 4),
                            height: 6,
                            width: 20,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? Colors.green
                                  : isCurrent
                                      ? TColors.primary
                                      : TColors.grey.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${widget.currentSegment + 1}/${bookingController.cityPairs.length}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: TColors.primary,
                ),
              ),
            ],
          ),
        ));
  }

  Widget _buildSegmentInfoCard(dynamic cityPair) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [TColors.primary, TColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: TColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('From', style: TextStyle(fontSize: 12, color: TColors.white.withOpacity(0.8))),
                Text(
                  cityPair.fromCity.value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: TColors.white),
                ),
                Text(
                  cityPair.fromCityName.value,
                  style: TextStyle(fontSize: 10, color: TColors.white.withOpacity(0.8)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TColors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.arrow_forward, color: TColors.white, size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('To', style: TextStyle(fontSize: 12, color: TColors.white.withOpacity(0.8))),
                Text(
                  cityPair.toCity.value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: TColors.white),
                ),
                Text(
                  cityPair.toCityName.value,
                  style: TextStyle(fontSize: 10, color: TColors.white.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlightList(EmiratesFlightController emiratesController) {
    final flights = _getSafeFlights();

    if (flights.isEmpty) {
      return _buildNoFlightsFound(emiratesController);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: flights.length,
      itemBuilder: (context, index) {
        final flight = flights[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TColors.grey.withOpacity(0.2), width: 1),
          ),
          child: EmiratesFlightCard(
            flight: flight,
            showReturnFlight: false,
            isMultiCity: true,
            currentSegment: widget.currentSegment,
          ),
        );
      },
    );
  }

  Widget _buildNoFlightsFound(EmiratesFlightController emiratesController) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flight_takeoff_outlined, size: 64, color: TColors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'No Flights Found for This Segment',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: TColors.text),
          ),
          const SizedBox(height: 8),
          const Text(
            'No flights available for this route. Please adjust your search.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: TColors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Future.delayed(const Duration(milliseconds: 300), () {
                emiratesController.proceedToNextMultiCitySegment();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text(
              'Skip This Segment',
              style: TextStyle(color: TColors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Scaffold _buildErrorScaffold(String errorMessage) {
    return Scaffold(
      backgroundColor: TColors.background,
      appBar: AppBar(
        backgroundColor: TColors.background,
        title: const Text('Error'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: TColors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: TColors.text),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Get.back(),
              style: ElevatedButton.styleFrom(
                backgroundColor: TColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text(
                'Go Back',
                style: TextStyle(color: TColors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

