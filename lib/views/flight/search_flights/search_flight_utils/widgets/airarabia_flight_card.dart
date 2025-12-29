import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../../utility/colors.dart';
import '../../../form/flight_booking_controller.dart';
import '../../airarabia/airarabia_flight_controller.dart';
import '../../airarabia/airarabia_flight_model.dart';
import '../helper_functions.dart';

class AirArabiaFlightCard extends StatefulWidget {
  final AirArabiaFlight flight;
  final bool showReturnFlight;
  final bool isShowBookButton;
  final bool isMultiCity;
  final int currentSegment;
                                                                                                                                                                                                                               
  const AirArabiaFlightCard({
    super.key,
    required this.flight,
    this.showReturnFlight = false,
    this.isMultiCity = false,
    this.currentSegment = 0,
    this.isShowBookButton = true,
  });

  @override
  State<AirArabiaFlightCard> createState() => _AirArabiaFlightCardState();
}

class _AirArabiaFlightCardState extends State<AirArabiaFlightCard>
    with SingleTickerProviderStateMixin {
  bool isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  String _formatLocation(Map<String, dynamic>? location,
      {String? fallbackCode}) {
    final city = location?['city']?.toString();
    final code = location?['airport']?.toString() ??
        location?['code']?.toString() ??
        fallbackCode;
    return formatCityLabel(cityName: city, code: code);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String formatTimeFromDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'N/A';

    try {
      final dateTime = DateTime.parse(dateTimeString);
      return DateFormat('hh:mm a').format(dateTime);
    } catch (e) {
      return 'N/A';
    }
  }

  String formatFullDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'N/A';

    try {
      final dateTime = DateTime.parse(dateTimeString);
      return DateFormat('E, d MMM yyyy').format(dateTime);
    } catch (e) {
      return 'N/A';
    }
  }

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

  // NEW: Group segments into legs for multi-city display
  List<Map<String, dynamic>> getLegSchedules() {
    if (widget.flight.flightSegments.isEmpty) {
      return [];
    }

    // For round trip flights
    if (widget.flight.isRoundTrip && 
        widget.flight.outboundFlight != null && 
        widget.flight.inboundFlight != null) {
      return _groupRoundTripLegs();
    }

    // For multi-city or one-way flights
    return _groupMultiCityLegs();
  }

  List<Map<String, dynamic>> _groupRoundTripLegs() {
    final outboundSegments = <Map<String, dynamic>>[];
    final inboundSegments = <Map<String, dynamic>>[];

    // Separate segments based on isOutbound flag if available
    for (var segment in widget.flight.flightSegments) {
      // Try to determine if segment is outbound or inbound
      bool isOutbound = segment['isOutbound'] ?? true;
      
      if (isOutbound) {
        outboundSegments.add(segment);
      } else {
        inboundSegments.add(segment);
      }
    }

    // If we couldn't separate properly, split in half
    if (inboundSegments.isEmpty && widget.flight.flightSegments.length > 1) {
      final midpoint = (widget.flight.flightSegments.length / 2).ceil();
      outboundSegments.clear();
      outboundSegments.addAll(widget.flight.flightSegments.sublist(0, midpoint));
      inboundSegments.addAll(widget.flight.flightSegments.sublist(midpoint));
    }

    final legs = <Map<String, dynamic>>[];

    // Add outbound leg
    if (outboundSegments.isNotEmpty) {
      legs.add(_createLegFromSegments(outboundSegments));
    }

    // Add inbound leg
    if (inboundSegments.isNotEmpty) {
      legs.add(_createLegFromSegments(inboundSegments));
    }

    return legs;
  }

  List<Map<String, dynamic>> _groupMultiCityLegs() {
    final legs = <Map<String, dynamic>>[];
    final segments = widget.flight.flightSegments;

    if (segments.isEmpty) return legs;

    // Check if this is multicity by getting booking controller
    try {
      final bookingController = Get.find<FlightBookingController>();
      final isMultiCity = bookingController.tripType.value == TripType.multiCity;
      
      if (isMultiCity && bookingController.cityPairs.length > 1) {
        // For multicity, segments are already ordered correctly by the controller
        // Each segment represents a different cityPair, so create a leg for each segment
        // Only group segments if they are connecting (same airport)
        List<Map<String, dynamic>> currentLegSegments = [segments[0]];

        for (int i = 1; i < segments.length; i++) {
          final previousArrival = segments[i - 1]['arrival']?['airport']?.toString().toUpperCase() ?? '';
          final currentDeparture = segments[i]['departure']?['airport']?.toString().toUpperCase() ?? '';

          // If airports match, it's a connecting flight in the same leg
          if (previousArrival == currentDeparture && previousArrival.isNotEmpty) {
            currentLegSegments.add(segments[i]);
          } else {
            // Different leg - save current and start new one
            legs.add(_createLegFromSegments(currentLegSegments));
            currentLegSegments = [segments[i]];
          }
        }

        // Add the last leg
        if (currentLegSegments.isNotEmpty) {
          legs.add(_createLegFromSegments(currentLegSegments));
        }

        return legs;
      }
    } catch (e) {
      // If we can't get booking controller, fall through to original logic
    }

    // Original logic for non-multicity or fallback
    // Group segments by checking if arrival airport of one segment 
    // matches departure airport of next segment
    List<Map<String, dynamic>> currentLegSegments = [segments[0]];

    for (int i = 1; i < segments.length; i++) {
      final previousArrival = segments[i - 1]['arrival']?['airport']?.toString().toUpperCase() ?? '';
      final currentDeparture = segments[i]['departure']?['airport']?.toString().toUpperCase() ?? '';

      // If airports match, it's a connecting flight in the same leg
      if (previousArrival == currentDeparture && previousArrival.isNotEmpty) {
        currentLegSegments.add(segments[i]);
      } else {
        // Different leg - save current and start new one
        legs.add(_createLegFromSegments(currentLegSegments));
        currentLegSegments = [segments[i]];
      }
    }

    // Add the last leg
    if (currentLegSegments.isNotEmpty) {
      legs.add(_createLegFromSegments(currentLegSegments));
    }

    return legs;
  }

  Map<String, dynamic> _createLegFromSegments(List<Map<String, dynamic>> segments) {
    if (segments.isEmpty) {
      return {
        'departure': {'airport': 'N/A', 'dateTime': '', 'city': 'N/A'},
        'arrival': {'airport': 'N/A', 'dateTime': '', 'city': 'N/A'},
        'segments': [],
        'elapsedTime': 0,
        'stops': [],
      };
    }

    final stops = <String>[];
    
    // Collect intermediate stops
    for (int i = 0; i < segments.length - 1; i++) {
      final stopAirport = segments[i]['arrival']['airport'];
      if (stopAirport != null) {
        stops.add(stopAirport);
      }
    }

    return {
      'departure': segments.first['departure'],
      'arrival': segments.last['arrival'],
      'segments': segments,
      'elapsedTime': getElapsedTimeForSegments(segments),
      'stops': stops,
    };
  }

  List<String> getStopsForSegments(List<Map<String, dynamic>> segments) {
    final stops = <String>[];
    
    for (int i = 0; i < segments.length - 1; i++) {
      final stopAirport = segments[i]['arrival']['airport'];
      if (stopAirport != null) {
        stops.add(stopAirport);
      }
    }
    
    return stops;
  }

  int getElapsedTimeForSegments(List<Map<String, dynamic>> segments) {
    if (segments.isEmpty) return 0;
    
    try {
      final firstDeparture = DateTime.parse(segments.first['departure']['dateTime']);
      final lastArrival = DateTime.parse(segments.last['arrival']['dateTime']);
      return lastArrival.difference(firstDeparture).inMinutes;
    } catch (e) {
      return segments.fold(0, (sum, segment) {
        return sum + (segment['elapsedTime'] as int? ?? 0);
      });
    }
  }

  int getTotalDuration() {
    return widget.flight.flightSegments.fold(0, (sum, segment) {
      return sum + (segment['elapsedTime'] as int? ?? 0);
    });
  }

  String formatTime(String? timeString) {
    if (timeString == null || timeString.isEmpty) return 'N/A';
    
    try {
      if (timeString.contains(':') && !timeString.contains('T')) {
        final timeParts = timeString.split(':').sublist(0, 2);
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        
        // Create a DateTime object with current date for formatting
        final now = DateTime.now();
        final dateTime = DateTime(now.year, now.month, now.day, hour, minute);
        
        return DateFormat('hh:mm a').format(dateTime);
      }
      
      final dateTime = DateTime.parse(timeString);
      return DateFormat('hh:mm a').format(dateTime);
    } catch (e) {
      return timeString.length >= 5 ? timeString.substring(0, 5) : timeString;
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
      barrierDismissible: false,
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
                      onTap: () {
                        if (mounted) {
                          Navigator.of(context).pop();
                        }
                      },
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
                      itemCount: widget.flight.flightSegments.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        return _buildDialogFlightSegment(
                          widget.flight.flightSegments[index],
                          index,
                          widget.flight.flightSegments.length,
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Baggage Information
                    _buildDialogSectionCard(
                      title: 'Baggage Allowance',
                      content: '20 KGS included',
                      icon: Icons.luggage,
                    ),

                    const SizedBox(height: 16),

                    // Fare Rules
                    _buildDialogSectionCard(
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

  Widget _buildDialogFlightSegment(
      Map<String, dynamic> segment,
      int index,
      int totalSegments,
      ) {
    final flightNumber = segment['flightNumber'] ?? 'G9-000';

    // Calculate layover time
    String? layoverTime;
    if (index < widget.flight.flightSegments.length - 1) {
      final nextSegment = widget.flight.flightSegments[index + 1];
      final currentArrivalTime = segment['arrival']['dateTime'];
      final nextDepartureTime = nextSegment['departure']['dateTime'];

      try {
        final arrival = DateTime.parse(currentArrivalTime);
        final departure = DateTime.parse(nextDepartureTime);

        final difference = departure.difference(arrival);
        final totalMinutes = difference.inMinutes;

        if (totalMinutes > 0) {
          final hours = totalMinutes ~/ 60;
          final minutes = totalMinutes % 60;
          layoverTime = '${hours}h ${minutes}m';
        }
      } catch (e) {
        // Handle parsing errors
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flight number and carrier info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: TColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.flight_takeoff,
                  size: 16,
                  color: TColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Segment ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: TColors.primary,
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
              getCabinClassName(widget.flight.cabinClass),
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
                imageUrl: widget.flight.airlineImg,
                height: 24,
                width: 24,
                placeholder: (context, url) => const SizedBox(
                  height: 24,
                  width: 24,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.flight, size: 24),
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.flight.airlineName} $flightNumber',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                        Text(
                          _formatLocation(
                              segment['departure'] as Map<String, dynamic>?,
                              fallbackCode:
                                  segment['departure']['airport']?.toString()),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Terminal ${segment['departure']['terminal'] ?? "Main"}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      formatTimeFromDateTime(segment['departure']['dateTime']),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      formatFullDateTime(segment['departure']['dateTime']),
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          size: 12,
                          color: Colors.green,
                        ),
                        SizedBox(width: 4),
                        Text(
                          "Meal Yes",
                          style: TextStyle(
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
                          _formatLocation(
                              segment['arrival'] as Map<String, dynamic>?,
                              fallbackCode:
                                  segment['arrival']['airport']?.toString()),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Terminal ${segment['arrival']['terminal'] ?? "Main"}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      formatTimeFromDateTime(segment['arrival']['dateTime']),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      formatFullDateTime(segment['arrival']['dateTime']),
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
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withOpacity(0.1),
                    Colors.orange.withOpacity(0.05),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 6),
                  Text(
                    'Layover: $layoverTime',
                    style: TextStyle(
                      color: Colors.orange[700],
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

  Widget _buildDialogSectionCard({
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: TColors.primary),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: TColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              content,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AirArabiaFlightController airArabiaController = Get.put(AirArabiaFlightController());
    final legSchedules = getLegSchedules();

    return InkWell(
      onTap: widget.isShowBookButton ? () {
        airArabiaController.handleAirArabiaFlightSelection(widget.flight);
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
                CachedNetworkImage(
                  imageUrl: widget.flight.airlineImg,
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
                    color: Color(0xFFDF0104),
                  ),
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 8),
                // Airline name
                Expanded(
                  child: Text(
                    widget.flight.airlineName,
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
            ...legSchedules.map((legSchedule) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Departure
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatTime(legSchedule['departure']['dateTime']),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatLocation(
                              legSchedule['departure'] as Map<String, dynamic>?),
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
                          color: const Color(0xFFDF0104),
                        ),
                        const SizedBox(height: 4),
                        // Stop indicator below line
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDF0104).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getStopText(legSchedule),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFDF0104),
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
                          formatTime(legSchedule['arrival']['dateTime']),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatLocation(
                              legSchedule['arrival'] as Map<String, dynamic>?),
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
                const SizedBox(),
                if (widget.isShowBookButton)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'PKR ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            color: Colors.black54,
                          ),
                        ),
                        TextSpan(
                          text: NumberFormat('#,###').format(widget.flight.price),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _buildFareRules() {
    return '''
• Non-refundable ticket
• Date change permitted with fee
• Standard meal included
• Free seat selection
• Cabin baggage allowed
• Check-in baggage as per policy''';
  }
}