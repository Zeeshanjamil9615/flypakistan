import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ready_flights/services/api_service_airblue.dart';
import 'package:ready_flights/utility/app_constants.dart';
import 'package:ready_flights/utility/colors.dart';
import 'package:ready_flights/views/flight/booking_flight/airblue/airblue_payment_screen.dart';
import 'package:ready_flights/views/flight/booking_flight/booking_flight_controller.dart';
import 'package:ready_flights/views/flight/search_flights/airblue/airblue_flight_model.dart';
import 'package:ready_flights/widgets/travelers_selection_bottom_sheet.dart';

class SeatSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> pnrResponse;
  final int totalPassengers;
  final AirBlueFlight outboundFlight;
  final AirBlueFlight? returnFlight;
  final List<AirBlueFlight>? multicityFlights;
  final AirBlueFareOption? outboundFareOption;
  final AirBlueFareOption? returnFareOption;
  final List<AirBlueFareOption?>? multicityFareOptions;
  final bool showAsSheet;
  final VoidCallback? onClose;
  final BookingFlightController bookingController;
  final TravelersController travelersController;
  final double totalPrice;
  final String currency;
  final int initialSecondsLeft;

  const SeatSelectionScreen({
    super.key,
    required this.pnrResponse,
    required this.totalPassengers,
    required this.outboundFlight,
    this.returnFlight,
    this.multicityFlights,
    this.outboundFareOption,
    this.returnFareOption,
    this.multicityFareOptions,
    this.showAsSheet = false,
    this.onClose,
    required this.bookingController,
    required this.travelersController,
    required this.totalPrice,
    required this.currency,
    required this.initialSecondsLeft,
  });

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  // Flight selection for multi-segment trips
  int selectedFlightIndex = 0;
  List<Map<String, dynamic>?> flightSeatMaps = [];
  
  // Store selected seats for each flight segment
  // Structure: flightIndex -> passengerIndex -> seatNumber
  Map<int, Map<int, String>> selectedSeatsPerFlight = {};
  Map<int, Map<int, String>> selectedSeatRowsPerFlight = {};
  Map<int, Map<int, double>> selectedSeatPricesPerFlight = {};
  
  bool isLoading = true;
  int selectedPassengerIndex = 0;
  bool isPriceBoxExpanded = false;

  final List<String> seatLetters = ['A', 'B', 'C', 'D', 'E', 'F'];
  final int totalRows = 38;

  int get totalFlightSegments {
    if (widget.multicityFlights != null && widget.multicityFlights!.isNotEmpty) {
      return widget.multicityFlights!.length;
    } else if (widget.returnFlight != null) {
      return 2; // Outbound + Return
    } else {
      return 1; // One-way only
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeSeatMaps();
    _loadAllSeatMaps();
  }

  void _initializeSeatMaps() {
    flightSeatMaps = List.generate(totalFlightSegments, (_) => null);
    
    for (int i = 0; i < totalFlightSegments; i++) {
      selectedSeatsPerFlight[i] = {};
      selectedSeatRowsPerFlight[i] = {};
      selectedSeatPricesPerFlight[i] = {};
    }
  }

  Future<void> _loadAllSeatMaps() async {
    try {
      final futures = <Future>[];
      
      // Load outbound or multicity flights
      if (widget.multicityFlights != null && widget.multicityFlights!.isNotEmpty) {
        // For multicity flights, load seat maps for all flights
        for (int i = 0; i < widget.multicityFlights!.length; i++) {
          futures.add(_loadSeatMapForFlight(i, widget.multicityFlights![i]));
        }
      } else {
        // For one-way or round trip
        futures.add(_loadSeatMapForFlight(0, widget.outboundFlight));
        
        // Load return flight if exists
        if (widget.returnFlight != null) {
          futures.add(_loadSeatMapForFlight(1, widget.returnFlight!));
        }
      }

      await Future.wait(futures);
      
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorDialog('Failed to load seat maps: $e');
    }
  }

  Future<void> _loadSeatMapForFlight(int flightIndex, AirBlueFlight flight) async {
    try {
      final firstLeg = flight.legSchedules.first;
      final departureDateTime = firstLeg['departure']['dateTime'];
      final flightNumber = flight.id.split('-').first;

      final response = await AirBlueFlightApiService().getAirBlueSeatMap(
        departureDateTime: departureDateTime,
        flightNumber: flightNumber,
        departureAirport: firstLeg['departure']['airport'],
        arrivalAirport: firstLeg['arrival']['airport'],
        operatingAirlineCode: flight.airlineCode,
        pnr: widget.pnrResponse['pnr'],
        instance: widget.pnrResponse['Instance'],
        fareType: 'EV',
        resBookDesigCode: 'H',
        cabinClass: 'Y',
      );

      setState(() {
        flightSeatMaps[flightIndex] = response;
      });
    } catch (e) {
      debugPrint('Error loading seat map for flight $flightIndex: $e');
      // Don't throw - allow other seat maps to load
    }
  }

  void _selectSeat(String seatNumber, String rowNumber, double price) {
    setState(() {
      final currentFlightSeats = selectedSeatsPerFlight[selectedFlightIndex]!;
      
      // Check if seat is already selected by another passenger in this flight
      if (currentFlightSeats.values.contains(seatNumber)) {
        Get.snackbar(
          'Error',
          'This seat is already selected for another passenger',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
        return;
      }

      selectedSeatsPerFlight[selectedFlightIndex]![selectedPassengerIndex] = seatNumber;
      selectedSeatRowsPerFlight[selectedFlightIndex]![selectedPassengerIndex] = rowNumber;
      selectedSeatPricesPerFlight[selectedFlightIndex]![selectedPassengerIndex] = price;

      // Auto-advance to next passenger
      if (selectedPassengerIndex < widget.totalPassengers - 1) {
        selectedPassengerIndex++;
      }
    });
  }

  Future<void> _confirmSeats() async {
    // Check if all passengers have seats for all flights
    for (int flightIndex = 0; flightIndex < totalFlightSegments; flightIndex++) {
      if (selectedSeatsPerFlight[flightIndex]!.length != widget.totalPassengers) {
        final flightTitle = _getFlightTitle(flightIndex);
        Get.snackbar(
          'Error',
          'Please select seats for all passengers on $flightTitle',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
    }

    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(TColors.primary),
          ),
        ),
        barrierDismissible: false,
      );

      final pnr = widget.pnrResponse['pnr'];
      final instance = widget.pnrResponse['Instance'];

      // Update seats for each flight
      for (int flightIndex = 0; flightIndex < totalFlightSegments; flightIndex++) {
        final seatRequests = selectedSeatsPerFlight[flightIndex]!.entries.map((entry) {
          return {
            'flightRefNumber': (flightIndex + 1).toString(),
            'travelerRefNumber': (entry.key + 1).toString(),
            'seatNumber': entry.value,
            'rowNumber': selectedSeatRowsPerFlight[flightIndex]![entry.key]!,
          };
        }).toList();

        await AirBlueFlightApiService().updateAirBlueSeats(
          pnr: pnr,
          instance: instance,
          seatRequests: seatRequests,
          pnrResponse: widget.pnrResponse, // Pass PNR response to extract RPH tokens
        );
      }

      Get.back(); // Close loading

      Get.snackbar(
        'Success',
        widget.multicityFlights != null && widget.multicityFlights!.isNotEmpty
            ? 'Seats updated successfully for all ${totalFlightSegments} multicity flights'
            : 'Seats updated successfully for all flights',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );

      // Combine all selected seats from ALL flights into a single map for display
      final Map<int, String> allSelectedSeats = {};
      // Calculate total seat price from all flights
      double totalSeatPrice = 0.0;
      final Map<int, double> seatPricesByPassenger = {};
      
      // For round trip or multi-city, combine seats from all flight segments
      for (int flightIndex = 0; flightIndex < totalFlightSegments; flightIndex++) {
        selectedSeatsPerFlight[flightIndex]!.forEach((passengerIndex, seat) {
          // For first flight, use seat as is
          // For subsequent flights, append flight info to differentiate
          if (flightIndex == 0) {
            allSelectedSeats[passengerIndex] = seat;
          } else {
            // Combine outbound and return seats with separator
            if (allSelectedSeats.containsKey(passengerIndex)) {
              allSelectedSeats[passengerIndex] = 
                  '${allSelectedSeats[passengerIndex]} | $seat';
            } else {
              allSelectedSeats[passengerIndex] = seat;
            }
          }
          
          // Sum up seat prices
          final seatPrice = selectedSeatPricesPerFlight[flightIndex]?[passengerIndex] ?? 0.0;
          if (seatPrice > 0) {
            if (seatPricesByPassenger.containsKey(passengerIndex)) {
              seatPricesByPassenger[passengerIndex] = seatPricesByPassenger[passengerIndex]! + seatPrice;
            } else {
              seatPricesByPassenger[passengerIndex] = seatPrice;
            }
          }
        });
      }
      
      // Calculate total seat price
      totalSeatPrice = seatPricesByPassenger.values.fold<double>(0.0, (sum, price) => sum + price);
      
      print('📋 Total seat price: $totalSeatPrice');
      print('📋 Seat prices by passenger: $seatPricesByPassenger');

      List<AirBlueFareOption>? cleanedMulticityFareOptions;
      if (widget.multicityFareOptions != null) {
        cleanedMulticityFareOptions = widget.multicityFareOptions!
            .whereType<AirBlueFareOption>()
            .toList();
      }

      Get.offAll(
        () => AirBluePaymentScreen(
          pnrResponse: widget.pnrResponse,
          totalPassengers: widget.totalPassengers,
          outboundFlight: widget.outboundFlight,
          returnFlight: widget.returnFlight,
          multicityFlights: widget.multicityFlights,
          outboundFareOption: widget.outboundFareOption,
          returnFareOption: widget.returnFareOption,
          multicityFareOptions: cleanedMulticityFareOptions,
          bookingController: widget.bookingController,
          travelersController: widget.travelersController,
          totalPrice: widget.totalPrice + totalSeatPrice, // Add seat prices to total
          currency: widget.currency,
          initialSecondsLeft: widget.initialSecondsLeft,
          selectedSeats: allSelectedSeats,
          seatPrices: seatPricesByPassenger, // Pass seat prices
          totalSeatPrice: totalSeatPrice, // Pass total seat price
        ),
      );
    } catch (e) {
      Get.back();
      Get.snackbar(
        'Error',
        'Failed to update seats: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  void _skipSeatSelection() {
    // Show confirmation dialog before skipping
    Get.dialog(
      AlertDialog(
        title: const Text('Skip Seat Selection?'),
        content: const Text(
          'Are you sure you want to skip seat selection? You can select seats later by contacting customer support.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back(); // Close dialog
              
              // Filter out null values from multicityFareOptions if it exists
              List<AirBlueFareOption>? cleanedMulticityFareOptions;
              if (widget.multicityFareOptions != null) {
                cleanedMulticityFareOptions = widget.multicityFareOptions!
                    .whereType<AirBlueFareOption>()
                    .toList();
              }
              
              Get.offAll(
                () => AirBluePaymentScreen(
                  pnrResponse: widget.pnrResponse,
                  totalPassengers: widget.totalPassengers,
                  outboundFlight: widget.outboundFlight,
                  returnFlight: widget.returnFlight,
                  multicityFlights: widget.multicityFlights,
                  outboundFareOption: widget.outboundFareOption,
                  returnFareOption: widget.returnFareOption,
                  multicityFareOptions: cleanedMulticityFareOptions,
                  bookingController: widget.bookingController,
                  travelersController: widget.travelersController,
                  totalPrice: widget.totalPrice,
                  currency: widget.currency,
                  initialSecondsLeft: widget.initialSecondsLeft,
                  selectedSeats: null,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TColors.primary,
            ),
            child: const Text('Skip'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  void _showErrorDialog(String message) {
    Get.dialog(
      AlertDialog(
        title: const Text('Seat Map Not Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            const Text(
              'You can skip seat selection and proceed with your booking.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              Get.back();
            },
            child: const Text('Go Back'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              
              // Filter out null values from multicityFareOptions if it exists
              List<AirBlueFareOption>? cleanedMulticityFareOptions;
              if (widget.multicityFareOptions != null) {
                cleanedMulticityFareOptions = widget.multicityFareOptions!
                    .whereType<AirBlueFareOption>()
                    .toList();
              }
              
              _skipSeatSelection();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TColors.primary,
            ),
            child: const Text('Skip Seat Selection'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Map<String, dynamic>? _getSeatData(String rowNumber, String seatLetter) {
    final currentSeatMap = flightSeatMaps[selectedFlightIndex];
    if (currentSeatMap == null) return null;

    try {
      final seatMapResponse = currentSeatMap['soap\$Envelope']['soap\$Body']
          ['AirSeatMapResponse']['AirSeatMapResult']['SeatMapResponses']
          ['SeatMapResponse'];

      final cabinClass = seatMapResponse['SeatMapDetails']['CabinClass'];
      final rows = cabinClass['RowInfo'] as List;

      for (var row in rows) {
        if (row['RowNumber'] == rowNumber) {
          final seats = row['SeatInfo'] as List;
          for (var seat in seats) {
            final seatNum = seat['Summary']['SeatNumber']?.toString().trim();
            if (seatNum == seatLetter) {
              return seat;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting seat data: $e');
    }
    return null;
  }

  String _getFlightTitle(int index) {
    if (widget.multicityFlights != null && widget.multicityFlights!.isNotEmpty) {
      final flight = widget.multicityFlights![index];
      final firstLeg = flight.legSchedules.first;
      final lastLeg = flight.legSchedules.last;
      return 'Flight ${index + 1}: ${firstLeg['departure']['airport']} → ${lastLeg['arrival']['airport']}';
    } else if (index == 0) {
      final firstLeg = widget.outboundFlight.legSchedules.first;
      final lastLeg = widget.outboundFlight.legSchedules.last;
      return 'Outbound: ${firstLeg['departure']['airport']} → ${lastLeg['arrival']['airport']}';
    } else {
      final firstLeg = widget.returnFlight!.legSchedules.first;
      final lastLeg = widget.returnFlight!.legSchedules.last;
      return 'Return: ${firstLeg['departure']['airport']} → ${lastLeg['arrival']['airport']}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = isLoading
        ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(TColors.primary),
            ),
          )
        : Column(
            children: [
              if (totalFlightSegments > 1) _buildFlightSelector(),
              _buildPassengerSelector(),
              Expanded(child: _buildSeatMap()),
              _buildBottomBar(),
            ],
          );

    if (widget.showAsSheet) {
      return Material(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _buildSheetHeader(),
                Expanded(child: bodyContent),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Select Seats',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: TColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _skipSeatSelection,
            icon: const Icon(Icons.skip_next, color: Colors.white),
            label: const Text(
              'Skip',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildSheetHeader() {
    final routeLabel = _getFlightTitle(selectedFlightIndex);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F0FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              routeLabel.replaceFirst('Flight', '').trim(),
              style: TextStyle(
                color: TColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select your seat (Optional)',
                  style: AppConstants.sectionTitleStyle.copyWith(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All prices are in PKR',
                  style: AppConstants.fieldLabelStyle.copyWith(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                widget.onClose?.call();
                // Use Navigator.pop for more reliable dismissal in release mode
                try {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Get.back();
                  }
                } catch (e) {
                  // Fallback to Get.back() if Navigator fails
                  Get.back();
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.close, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlightSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.multicityFlights != null && widget.multicityFlights!.isNotEmpty
                ? 'Select multicity flight:'
                : 'Select flight:',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: totalFlightSegments,
              itemBuilder: (context, index) {
                final isSelected = selectedFlightIndex == index;
                final hasAllSeats = selectedSeatsPerFlight[index]!.length == widget.totalPassengers;

                return GestureDetector(
                  onTap: () => setState(() => selectedFlightIndex = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? TColors.primary : Colors.grey[100],
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: hasAllSeats
                            ? (isSelected ? Colors.white : Colors.green)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getFlightTitle(index),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (hasAllSeats) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.check_circle,
                            color: isSelected ? Colors.white : Colors.green,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerSelector() {
    final currentFlightSeats = selectedSeatsPerFlight[selectedFlightIndex]!;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select passenger:',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.totalPassengers,
              itemBuilder: (context, index) {
                final isSelected = selectedPassengerIndex == index;
                final hasSeat = currentFlightSeats.containsKey(index);

                return GestureDetector(
                  onTap: () => setState(() => selectedPassengerIndex = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? TColors.primary : Colors.grey[100],
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: hasSeat
                            ? (isSelected ? Colors.white : Colors.green)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'P${index + 1}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (hasSeat) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.check_circle,
                            color: isSelected ? Colors.white : Colors.green,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (currentFlightSeats.containsKey(selectedPassengerIndex))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.airline_seat_recline_normal,
                        color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Seat ${currentFlightSeats[selectedPassengerIndex]}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (selectedSeatPricesPerFlight[selectedFlightIndex]![selectedPassengerIndex] != null &&
                        selectedSeatPricesPerFlight[selectedFlightIndex]![selectedPassengerIndex]! > 0)
                      Text(
                        ' • PKR ${selectedSeatPricesPerFlight[selectedFlightIndex]![selectedPassengerIndex]!.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSeatMap() {
    if (flightSeatMaps[selectedFlightIndex] == null) {
      return const Center(
        child: Text(
          'No seat map available for this flight',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // // Current flight indicator
          // Container(
          //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          //   decoration: BoxDecoration(
          //     color: TColors.primary.withOpacity(0.1),
          //     borderRadius: BorderRadius.circular(8),
          //     border: Border.all(color: TColors.primary.withOpacity(0.3)),
          //   ),
          //   child: Row(
          //     mainAxisAlignment: MainAxisAlignment.center,
          //     children: [
          //       Icon(Icons.flight, color: TColors.primary, size: 16),
          //       const SizedBox(width: 8),
          //       Text(
          //         'Currently selecting seats for: ${_getFlightTitle(selectedFlightIndex)}',
          //         style: TextStyle(
          //           color: TColors.primary,
          //           fontWeight: FontWeight.w600,
          //           fontSize: 13,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
          // const SizedBox(height: 16),
          _buildLegend(),
          const SizedBox(height: 20),
          _buildAirplaneFront(),
          const SizedBox(height: 20),
          ...List.generate(totalRows, (index) {
            final rowNumber = (index + 1).toString();
            return _buildSeatRow(rowNumber);
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem(Colors.green[400]!, 'Available'),
          _buildLegendItem(Colors.grey[400]!, 'Occupied'),
          _buildLegendItem(TColors.primary, 'Selected'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildAirplaneFront() {
    return SizedBox(
      height: 40,
      child: CustomPaint(
        size: const Size(double.infinity, 40),
        painter: AirplaneFrontPainter(),
      ),
    );
  }

  Widget _buildSeatRow(String rowNumber) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...seatLetters.sublist(0, 3).map((letter) {
            return _buildSeat(rowNumber, letter);
          }),
          Container(
            width: 36,
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              rowNumber,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ),
          ...seatLetters.sublist(3).map((letter) {
            return _buildSeat(rowNumber, letter);
          }),
        ],
      ),
    );
  }

  Widget _buildSeat(String rowNumber, String seatLetter) {
    final seatData = _getSeatData(rowNumber, seatLetter);
    final seatNumber = '$rowNumber$seatLetter';

    bool isAvailable = false;
    bool isOccupied = true;
    double price = 0;

    if (seatData != null) {
      isAvailable = seatData['Summary']['AvailableInd'] == 'true';
      isOccupied = seatData['Summary']['OccupiedInd'] == 'true';

      try {
        final service = seatData['Service'];
        if (service != null && service['Fee'] != null) {
          price = double.parse(service['Fee']['Amount'].toString());
        }
      } catch (e) {
        // Price not available
      }
    }

    final currentFlightSeats = selectedSeatsPerFlight[selectedFlightIndex]!;
    final isSelectedByCurrent = currentFlightSeats[selectedPassengerIndex] == seatNumber;
    final isSelectedByOther = currentFlightSeats.values.contains(seatNumber) && !isSelectedByCurrent;

    final String priceLabel;
    if (isAvailable && !isOccupied) {
      priceLabel = price > 0 ? price.toStringAsFixed(0) : 'Free';
    } else if (seatData == null) {
      priceLabel = '';
    } else {
      priceLabel = '—';
    }

    return SizedBox(
      width: 44,
      child: Column(
        children: [
          GestureDetector(
            onTap: (isAvailable && !isOccupied && !isSelectedByOther)
                ? () => _selectSeat(seatNumber, rowNumber, price)
                : null,
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isSelectedByCurrent
                    ? TColors.primary
                    : isSelectedByOther
                        ? TColors.primary.withOpacity(0.6)
                        : (isAvailable && !isOccupied)
                            ? const Color(0xFFBFA4FF)
                            : Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelectedByCurrent
                      ? TColors.primary
                      : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: [
                  if (isSelectedByCurrent)
                    BoxShadow(
                      color: TColors.primary.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Center(
                child: seatData == null
                    ? const Icon(Icons.close, color: Colors.white, size: 16)
                    : Text(
                        seatLetter,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            priceLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isAvailable && !isOccupied
                  ? Colors.black87
                  : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final currentFlightSeats = selectedSeatsPerFlight[selectedFlightIndex]!;
    final totalPrice = selectedSeatPricesPerFlight[selectedFlightIndex]!.values.fold<double>(0, (sum, price) => sum + price);

    // Calculate overall progress for multicity flights
    int totalCompletedFlights = 0;
    if (widget.multicityFlights != null && widget.multicityFlights!.isNotEmpty) {
      for (int i = 0; i < totalFlightSegments; i++) {
        if (selectedSeatsPerFlight[i]!.length == widget.totalPassengers) {
          totalCompletedFlights++;
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (totalPrice > 0 || currentFlightSeats.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => isPriceBoxExpanded = !isPriceBoxExpanded),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isPriceBoxExpanded ? Icons.expand_more : Icons.chevron_right,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${_getFlightTitle(selectedFlightIndex)})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      if (totalPrice > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: TColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'PKR ${totalPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: TColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (isPriceBoxExpanded && currentFlightSeats.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Column(
                  children: currentFlightSeats.entries.map((entry) {
                    final passengerNum = entry.key + 1;
                    final seat = entry.value;
                    final price = selectedSeatPricesPerFlight[selectedFlightIndex]![entry.key] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: TColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    'P$passengerNum',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: TColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Seat $seat',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            price > 0 ? 'PKR ${price.toStringAsFixed(0)}' : 'Free',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: price > 0 ? Colors.grey[700] : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // // Show multicity progress if applicable
                  // if (widget.multicityFlights != null && widget.multicityFlights!.isNotEmpty)
                  //   Container(
                  //     margin: const EdgeInsets.only(bottom: 12),
                  //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  //     decoration: BoxDecoration(
                  //       color: Colors.blue[50],
                  //       borderRadius: BorderRadius.circular(8),
                  //       border: Border.all(color: Colors.blue[200]!),
                  //     ),
                  //     child: Row(
                  //       children: [
                  //         Icon(Icons.flight, color: Colors.blue[600], size: 16),
                  //         const SizedBox(width: 8),
                  //         Text(
                  //           'Multicity Progress: $totalCompletedFlights of $totalFlightSegments flights completed',
                  //           style: TextStyle(
                  //             fontSize: 12,
                  //             color: Colors.blue[700],
                  //             fontWeight: FontWeight.w600,
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${currentFlightSeats.length} of ${widget.totalPassengers} selected',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (currentFlightSeats.length < widget.totalPassengers)
                              Text(
                                'Select ${widget.totalPassengers - currentFlightSeats.length} more for ${_getFlightTitle(selectedFlightIndex)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange[700],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _confirmSeats,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
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

class AirplaneFrontPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width * 0.5, 0);
    path.lineTo(size.width * 0.42, size.height * 0.8);
    path.lineTo(size.width * 0.58, size.height * 0.8);
    path.close();

    canvas.drawPath(path, paint);

    final windowPaint = Paint()
      ..color = Colors.blue[200]!
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.3),
      8,
      windowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
