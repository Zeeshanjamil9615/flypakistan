import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ready_flights/utility/colors.dart';
import 'package:ready_flights/views/flight/search_flights/emirates_ndc/emirates_flight_controller.dart';
import 'package:ready_flights/views/flight/search_flights/emirates_ndc/emirates_model.dart';
import 'package:ready_flights/views/flight/search_flights/search_flight_utils/widgets/emirates_ndc_card.dart';

class EmiratesReturnFlightsPage extends StatelessWidget {
  EmiratesReturnFlightsPage({super.key, this.returnFlights});

  final List<EmiratesFlight>? returnFlights;
  final EmiratesFlightController emiratesController = Get.find<EmiratesFlightController>();

  @override
  Widget build(BuildContext context) {
    final safeFlights = returnFlights ?? emiratesController.getReturnFlightOptions();

    return Scaffold(
      backgroundColor: TColors.background,
      appBar: AppBar(
        backgroundColor: TColors.background,
        surfaceTintColor: TColors.background,
        title: const Text('Select Return Flight'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: safeFlights.isEmpty ? _buildNoFlightsState() : _buildFlightList(safeFlights),
    );
  }

  Widget _buildFlightList(List<EmiratesFlight> flights) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: flights.length,
      itemBuilder: (context, index) {
        final flight = flights[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: EmiratesFlightCard(
            flight: flight,
            onSelect: () => emiratesController.handleReturnFlightSelection(flight),
          ),
        );
      },
    );
  }

  Widget _buildNoFlightsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flight_land_outlined,
            size: 64,
            color: TColors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Return Flights Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'We could not find any return flights for your selected route. Please adjust your dates or search criteria.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: TColors.grey,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Get.back(),
            style: ElevatedButton.styleFrom(
              backgroundColor: TColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Modify Search'),
          ),
        ],
      ),
    );
  }
}




