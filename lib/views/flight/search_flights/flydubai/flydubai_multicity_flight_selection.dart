import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ready_flights/views/flight/search_flights/flydubai/flydubai_controller.dart';
import '../../../../utility/colors.dart';
import '../../form/flight_booking_controller.dart';
import '../search_flight_utils/widgets/flydubai_flight_card.dart';
import 'flydubai_model.dart';

class FlyDubaiMultiCityFlightPage extends StatefulWidget {
  final int currentSegment;
  final List<FlydubaiFlight>? availableFlights;

  const FlyDubaiMultiCityFlightPage({
    super.key,
    required this.currentSegment,
    this.availableFlights,
  });

  @override
  State<FlyDubaiMultiCityFlightPage> createState() =>
      _FlyDubaiMultiCityFlightPageState();
}

class _FlyDubaiMultiCityFlightPageState
    extends State<FlyDubaiMultiCityFlightPage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final flyDubaiController = Get.find<FlydubaiFlightController>();
      print('DEBUG: FlyDubai multi-city flight page opened for segment ${widget.currentSegment}');
      print('DEBUG: Available flights: ${_getSafeFlights().length}');
    });
  }

  List<FlydubaiFlight> _getSafeFlights() {
    return widget.availableFlights ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final bookingController = Get.find<FlightBookingController>();
    final flyDubaiController = Get.find<FlydubaiFlightController>();

    if (widget.currentSegment >= bookingController.cityPairs.length) {
      return _buildErrorScaffold('Invalid segment');
    }

    final cityPair = bookingController.cityPairs[widget.currentSegment];
    final flights = _getSafeFlights();

    return WillPopScope(
      onWillPop: () async {
        // Clear any selections for this segment if going back
        if (widget.currentSegment <
            flyDubaiController.selectedMultiCityFlights.length) {
          flyDubaiController.selectedMultiCityFlights[widget.currentSegment] =
              null;
        }
        if (widget.currentSegment <
            flyDubaiController.selectedMultiCityFareOptions.length) {
          flyDubaiController
              .selectedMultiCityFareOptions[widget.currentSegment] = null;
        }
        return true;
      },
      child: Scaffold(
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
            onPressed: () {
              print('DEBUG: Manual back navigation from segment ${widget.currentSegment}');
              Get.back();
            },
          ),
        ),
        body: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(bookingController, flyDubaiController),
            const SizedBox(height: 8),
            
            // Flight list
            Expanded(
              child: flights.isEmpty
                  ? _buildEmptyState(cityPair)
                  : _buildFlightList(flights, flyDubaiController),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(
    FlightBookingController bookingController,
    FlydubaiFlightController flyDubaiController,
  ) {
    final totalSegments = bookingController.cityPairs.length;
    final completedSegments = flyDubaiController.selectedMultiCityFlights
        .where((f) => f != null)
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Multi-City Trip Progress',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: TColors.text,
                ),
              ),
              Text(
                '$completedSegments / $totalSegments',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: TColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(totalSegments, (index) {
              final isCompleted = index <
                      flyDubaiController.selectedMultiCityFlights.length &&
                  flyDubaiController.selectedMultiCityFlights[index] != null &&
                  index <
                      flyDubaiController.selectedMultiCityFareOptions.length &&
                  flyDubaiController
                      .selectedMultiCityFareOptions[index] != null;
              final isCurrent = index == widget.currentSegment;

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    right: index < totalSegments - 1 ? 4 : 0,
                  ),
                  height: 4,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? TColors.primary
                        : isCurrent
                            ? TColors.primary.withOpacity(0.5)
                            : TColors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(dynamic cityPair) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flight_takeoff,
              size: 64,
              color: TColors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No flights available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: TColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No flights found for ${cityPair.fromCity.value} → ${cityPair.toCity.value}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: TColors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Get.back(),
              style: ElevatedButton.styleFrom(
                backgroundColor: TColors.primary,
                foregroundColor: TColors.white,
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlightList(
    List<FlydubaiFlight> flights,
    FlydubaiFlightController flyDubaiController,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: flights.length,
      itemBuilder: (context, index) {
        final flight = flights[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () {
              flyDubaiController.handleMultiCityFlightSelection(
                flight,
                widget.currentSegment,
              );
            },
            child: FlyDubaiFlightCard(
              flight: flight,
              showReturnFlight: false,
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorScaffold(String message) {
    return Scaffold(
      backgroundColor: TColors.background,
      appBar: AppBar(
        backgroundColor: TColors.background,
        title: const Text('Error'),
      ),
      body: Center(
        child: Text(
          message,
          style: TextStyle(color: TColors.text),
        ),
      ),
    );
  }
}

