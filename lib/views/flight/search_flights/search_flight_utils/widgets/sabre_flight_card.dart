import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../../services/api_service_sabre.dart';

import '../../../../../utility/colors.dart';
import '../../../form/flight_booking_controller.dart';
import '../../pia/pia_flight_controller.dart';
import '../../sabre/sabre_flight_controller.dart';
import '../../sabre/sabre_flight_models.dart';
import '../helper_functions.dart';

class FlightCard extends StatefulWidget {
  final SabreFlight flight;
  final bool showReturnFlight;
  final bool isShowBookButton;

  const FlightCard({
    super.key,
    required this.flight,
    this.showReturnFlight = true,
    this.isShowBookButton = true,
  });



  @override
  State<FlightCard> createState() => _FlightCardState();
}

class _FlightCardState extends State<FlightCard>
    with SingleTickerProviderStateMixin {
  bool isExpanded = false;

  final Rx<Map<String, dynamic>> marginData = Rx<Map<String, dynamic>>({});
  final RxDouble finalPrice = 0.0.obs;

  final flightController = Get.find<SabreFlightController>();
  @override
  void initState() {
    super.initState();


    // Fetch margin data when widget initializes
    _fetchMarginData();
  }

  // Add this method to fetch margin data
  Future<void> _fetchMarginData() async {
    try {
      final apiService = Get.find<ApiServiceSabre>();
      final data = await apiService.getMargin(widget.flight.airlineCode, widget.flight.airline);
      marginData.value = data;

      // Calculate final price with margin
      finalPrice.value = apiService.calculatePriceWithMargin(
        widget.flight.price,
        data,
      );
    } catch (e) {
      // If margin fetch fails, use original price
      finalPrice.value = widget.flight.price;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Add this utility function to translate cabin codes
  String getCabinClassName(String cabinCode) {
    switch (cabinCode) {
      case 'F':
        return 'First Class';
      case 'C':
        return 'Business Class';
      case 'Y':
        return 'Economy Class';
      case 'W':
        return 'Premium Economy';
      default:
        return 'Economy Class';
    }
  }

  // Add this utility function for meal codes
  String getMealInfo(String mealCode) {
    switch (mealCode.toUpperCase()) {
      case 'P':
        return 'Alcoholic beverages for purchase';
      case 'C':
        return 'Complimentary alcoholic beverages';
      case 'B':
        return 'Breakfast';
      case 'K':
        return 'Continental breakfast';
      case 'D':
        return 'Dinner';
      case 'F':
        return 'Food for purchase';
      case 'G':
        return 'Food/Beverages for purchase';
      case 'M':
        return 'Meal';
      case 'N':
        return 'No meal service';
      case 'R':
        return 'Complimentary refreshments';
      case 'V':
        return 'Refreshments for purchase';
      case 'S':
        return 'Snack';
      default:
        return 'No Meal';
    }
  }

  // Format baggage information
  String formatBaggageInfo() {
    if (widget.flight.baggageAllowance.pieces > 0) {
      return '${widget.flight.baggageAllowance.pieces} piece(s) included';
    } else if (widget.flight.baggageAllowance.weight > 0) {
      return '${widget.flight.baggageAllowance.weight} ${widget.flight.baggageAllowance.unit} included';
    }
    return widget.flight.baggageAllowance.type;
  }

  // Add these utility methods for date formatting
  String formatTimeFromDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return DateFormat('hh:mm a').format(dateTime);
    } catch (e) {
      return 'N/A';
    }
  }

  String formatFullDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return DateFormat('E, d MMM yyyy').format(dateTime);
    } catch (e) {
      return 'N/A';
    }
  }

  String formatTime(String time) {
    if (time.isEmpty) return 'N/A';
    try {
      // Parse time as HH:mm
      final timeParts = time.split(':').sublist(0, 2);
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      // Create a DateTime object with current date for formatting
      final now = DateTime.now();
      final dateTime = DateTime(now.year, now.month, now.day, hour, minute);
      
      return DateFormat('hh:mm a').format(dateTime);
    } catch (e) {
      return 'N/A';
    }
  }

  String getFlightDuration(dynamic legSchedule) {
    final elapsedTime = legSchedule['elapsedTime'] ?? 0;
    final hours = elapsedTime ~/ 60;
    final minutes = elapsedTime % 60;
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  String _getStopText(dynamic legSchedule) {
    final stops = legSchedule['stops'] ?? [];
    if (stops.isEmpty) {
      return 'Nonstop';
    } else if (stops.length == 1) {
      return '1 stop';
    } else {
      return '${stops.length} stops';
    }
  }

  void _showFlightDetailsDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) => _buildFlightDetailsDialog(),
    );
  }

  Widget _buildFlightDetailsDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 50),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: TColors.primary.withOpacity(0.1),
              blurRadius: 40,
              spreadRadius: 0,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dialog Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    TColors.primary,
                    TColors.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.flight_takeoff,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Flight Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Flight Segments
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.flight.stopSchedules.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        return _buildFlightSegment(
                          widget.flight.stopSchedules[index],
                          index,
                          widget.flight.stopSchedules.length,
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Baggage Information
                    _buildSectionCard(
                      title: 'Baggage Allowance',
                      content: formatBaggageInfo(),
                      icon: Icons.luggage,
                    ),

                    const SizedBox(height: 16),

                    // Fare Rules
                    _buildSectionCard(
                      title: 'Policy',
                      content: _buildFareRules(),
                      icon: Icons.rule,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    Get.put(FlightBookingController());

    // Get first leg schedule for main display
    final firstLeg = widget.flight.legSchedules.isNotEmpty ? widget.flight.legSchedules.first : null;
    final ApiServiceSabre apiService = Get.find<ApiServiceSabre>();
    final airlineMap = apiService.getAirlineMap();
    final airlineInfo = firstLeg != null ? getAirlineInfo(firstLeg['airlineCode'] ?? 'XX', airlineMap) : null;

    return InkWell(
      onTap: widget.isShowBookButton ? () {
        flightController.handleFlightSelection(widget.flight);
      } : _showFlightDetailsDialog,
      borderRadius: BorderRadius.circular(12),
      child: Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top section with airline logo, name, duration and info icon
          Row(
            children: [
              // Airline logo
              if (firstLeg != null && airlineInfo != null)
                CachedNetworkImage(
                  imageUrl: firstLeg['airlineImg'],
                  height: 32,
                  width: 32,
                  placeholder: (context, url) => const SizedBox(
                    height: 32,
                    width: 32,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.flight,
                    size: 32,
                    color: Colors.blue,
                  ),
                  fit: BoxFit.contain,
                ),
              const SizedBox(width: 8),
              // Airline name
              Expanded(
                child: Text(
                  firstLeg?['airlineName'] ?? 'Airline',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              // Info icon button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showFlightDetailsDialog(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

                    // Flight routes (middle section with departure and arrival)
          ...widget.flight.legSchedules.map((legSchedule) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Departure
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatTime(legSchedule['departure']['time'].toString()),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        legSchedule['departure']['airport'] ?? legSchedule['departure']['code'] ?? 'DEP',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Flight duration line
                Expanded(
                  child: Column(
                    children: [
                      // Duration above line
                      Text(
                        getFlightDuration(legSchedule),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Line
                      Container(
                        height: 1,
                        color: const Color(0xFFBB0103),
                      ),
                      const SizedBox(height: 4),
                      // Stop indicator below line
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBB0103).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getStopText(legSchedule),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFBB0103),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrival
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatTime(legSchedule['arrival']['time'].toString()),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        legSchedule['arrival']['airport'] ?? legSchedule['arrival']['code'] ?? 'ARR',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),

          const SizedBox(height: 16),
          Container(height: 1, color: Colors.grey.shade200),

          // Bottom section with price
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 60,
                // height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFBB0103),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.flight.isNDC?'Sabre NDC':"Sabre",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(),
              if (widget.isShowBookButton)
                GetX<SabreFlightController>(
                  builder: (controller) => Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${controller.selectedCurrency.value} ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            color: Colors.black54,
                          ),
                        ),
                        TextSpan(
                          text: NumberFormat('#,###').format(finalPrice.value),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ));
  }

  Widget _buildFlightSegment(
      Map<String, dynamic> schedule,
      int index,
      int totalSegments,
      ) {
    // Get flight number and carrier from the schedule

    final carrier = schedule['carrier'] ?? {};
    final flightNumber =
        '${carrier['marketing'] ?? 'XX'}-${carrier['marketingFlightNumber'] ?? '000'}';
    final marketingCarrier = carrier['marketing'] ?? 'Unknown';
    final ApiServiceSabre apiService = Get.find<ApiServiceSabre>();
    final airlineMap = apiService.getAirlineMap();
    final airlineInfo = getAirlineInfo(marketingCarrier, airlineMap);
    FlightSegmentInfo? segmentInfo;
    if (index < widget.flight.segmentInfo.length) {
      segmentInfo = widget.flight.segmentInfo[index];
    }

    // Calculate layover time for segments within the same leg
    String? layoverTime;

    // Update the departure and arrival time display
    final departureDateTime = schedule['departure']['dateTime'];
    final arrivalDateTime = schedule['arrival']['dateTime'];

    // Find which leg this schedule belongs to
    for (var legSchedule in widget.flight.legSchedules) {
      final schedules = legSchedule['schedules'] as List;
      final currentScheduleIndex = schedules.indexWhere(
            (s) =>
        s['departure']['time'] == schedule['departure']['time'] &&
            s['arrival']['time'] == schedule['arrival']['time'],
      );

      // If found and not the last schedule in this leg
      if (currentScheduleIndex != -1 &&
          currentScheduleIndex < schedules.length - 1) {
        // Get arrival time of current flight
        final currentArrivalTime = schedule['arrival']['time'].toString();

        // Get departure time of next flight in the same leg
        final nextSchedule = schedules[currentScheduleIndex + 1];
        final nextDepartureTime = nextSchedule['departure']['time'].toString();

        // Parse times with a fixed date to handle day changes
        final arrival = DateTime.parse("2024-01-01T$currentArrivalTime");
        DateTime departure = DateTime.parse("2024-01-01T$nextDepartureTime");

        // If departure is before arrival, it means it's next day
        if (departure.isBefore(arrival)) {
          departure = departure.add(const Duration(days: 1));
        }

        // Calculate difference in minutes
        final difference = departure.difference(arrival);
        final totalMinutes = difference.inMinutes;

        if (totalMinutes > 0) {
          final hours = totalMinutes ~/ 60;
          final minutes = totalMinutes % 60;
          layoverTime = '${hours}h ${minutes}m';
        }
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
            index < totalSegments - 1
                ? Colors.grey[300]!
                : Colors.transparent,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flight number and carrier info
          Row(
            children: [
              const Icon(
                Icons.flight_takeoff,
                size: 16,
                color: TColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                ' Segment ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: TColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              getCabinClassName(segmentInfo?.cabinCode ?? 'Y'),
              style: const TextStyle(
                color: TColors.primary,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              CachedNetworkImage(
                imageUrl: airlineInfo.logoPath,
                height: 24,
                width: 24,
                placeholder:
                    (context, url) => const SizedBox(
                  height: 24,
                  width: 24,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget:
                    (context, url, error) => CachedNetworkImage(
                  imageUrl:
                  'https://cdn-icons-png.flaticon.com/128/15700/15700374.png',
                  height: 24,
                  width: 24,
                  errorWidget:
                      (context, url, error) =>
                  const Icon(Icons.flight, size: 24),
                ),
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              Text(
                '${airlineInfo.name} $flightNumber',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cabin Class information
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule['departure']['airport'] ?? "UNK",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Terminal ${schedule['departure']['terminal'] ?? "Main"}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      formatTimeFromDateTime(departureDateTime),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      formatFullDateTime(departureDateTime),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  const Icon(Icons.flight, color: TColors.primary),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.restaurant_menu,
                          size: 12,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          carrier=="OD"? getMealInfo(widget.flight.mealCode):"MEAL YES",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      schedule['arrival']['airport'] ?? "UNK",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Terminal ${schedule['arrival']['terminal'] ?? "Main"}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      formatTimeFromDateTime(arrivalDateTime),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      formatFullDateTime(arrivalDateTime),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Show layover time if it exists
          if (layoverTime != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Layover: $layoverTime',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: TColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _buildFareRules() {
    return '''
• ${widget.flight.isRefundable ? 'Refundable' : 'Non-refundable'} ticket
• Date change permitted with fee
• Standard meal included
• Free seat selection
• Cabin baggage allowed
• Check-in baggage as per policy''';
  }
}