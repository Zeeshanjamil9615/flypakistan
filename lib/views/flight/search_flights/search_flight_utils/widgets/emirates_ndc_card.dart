// widgets/emirates_flight_card.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:ready_flights/utility/colors.dart';
import 'package:ready_flights/views/flight/search_flights/emirates_ndc/emirates_flight_controller.dart';
import 'package:ready_flights/views/flight/search_flights/emirates_ndc/emirates_model.dart';

class EmiratesFlightCard extends StatefulWidget {
  final EmiratesFlight flight;
  final bool showReturnFlight;
  final bool isShowBookButton;
  final bool isMultiCity;
  final int currentSegment;
  final VoidCallback? onSelect;

  const EmiratesFlightCard({
    super.key,
    required this.flight,
    this.showReturnFlight = false,
    this.isMultiCity = false,
    this.currentSegment = 0,
    this.isShowBookButton = true,
    this.onSelect,
  });

  @override
  State<EmiratesFlightCard> createState() => _EmiratesFlightCardState();
}

class _EmiratesFlightCardState extends State<EmiratesFlightCard>
    with SingleTickerProviderStateMixin {
  bool isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  final EmiratesFlightController emiratesController =
      Get.find<EmiratesFlightController>();

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String getCabinClassName(String cabinCode) {
    switch (cabinCode) {
      case 'F':
        return 'First Class';
      case 'C':
      case 'J':
        return 'Business Class';
      case 'Y':
        return 'Economy Class';
      case 'W':
        return 'Premium Economy';
      default:
        return 'Economy Class';
    }
  }

  String formatBaggageInfo() {
    if (widget.flight.baggageAllowance.pieces > 0) {
      return '${widget.flight.baggageAllowance.pieces} piece(s) included';
    } else if (widget.flight.baggageAllowance.weight > 0) {
      return '${widget.flight.baggageAllowance.weight.toStringAsFixed(1)} ${widget.flight.baggageAllowance.unit} included';
    }
    return widget.flight.baggageAllowance.type;
  }

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

  String getFlightDuration() {
    if (widget.flight.legSchedules.isEmpty) {
      return 'N/A';
    }
    final totalMinutes = widget.flight.legSchedules.fold<int>(
      0,
      (previousValue, leg) =>
          previousValue + (leg['elapsedTime'] is int ? leg['elapsedTime'] as int : 0),
    );
    if (totalMinutes <= 0) return 'N/A';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    }
    return '${minutes}m';
  }

  String getDepartureAirport() {
    if (widget.flight.legSchedules.isEmpty) return 'N/A';
    return widget.flight.legSchedules.first['departure']['airport'] ?? 'N/A';
  }

  String getArrivalAirport() {
    if (widget.flight.legSchedules.isEmpty) return 'N/A';
    return widget.flight.legSchedules.last['arrival']['airport'] ?? 'N/A';
  }

  String getDepartureTime() {
    if (widget.flight.legSchedules.isEmpty) return 'N/A';
    final departure = widget.flight.legSchedules.first['departure']['dateTime']?.toString() ?? '';
    return departure.isEmpty ? 'N/A' : formatTimeFromDateTime(departure);
  }

  String getArrivalTime() {
    if (widget.flight.legSchedules.isEmpty) return 'N/A';
    final arrival = widget.flight.legSchedules.last['arrival']['dateTime']?.toString() ?? '';
    return arrival.isEmpty ? 'N/A' : formatTimeFromDateTime(arrival);
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
                        return _buildDialogFlightSegment(
                          widget.flight.stopSchedules[index],
                          index,
                          widget.flight.stopSchedules.length,
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Baggage Information
                    _buildDialogSectionCard(
                      title: 'Baggage Allowance',
                      content: formatBaggageInfo(),
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
    Map<String, dynamic> schedule,
    int index,
    int totalSegments,
  ) {
    final carrier = schedule['carrier'] ?? {};
    final flightNumber = '${carrier['marketing'] ?? 'EK'}-${carrier['marketingFlightNumber'] ?? '625'}';

    // Calculate layover time
    String? layoverTime;
    if (index < widget.flight.stopSchedules.length - 1) {
      final nextSchedule = widget.flight.stopSchedules[index + 1];
      final currentArrivalTime = schedule['arrival']['dateTime'];
      final nextDepartureTime = nextSchedule['departure']['dateTime'];

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
                imageUrl: "https://images.kiwi.com/airlines/64/EK.png",
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
                      schedule['departure']['airport'] ?? "UNK",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Terminal ${schedule['departure']['terminal'] ?? "Main"}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      formatTimeFromDateTime(schedule['departure']['dateTime']),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      formatFullDateTime(schedule['departure']['dateTime']),
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
                      schedule['arrival']['airport'] ?? "UNK",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Terminal ${schedule['arrival']['terminal'] ?? "Main"}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      formatTimeFromDateTime(schedule['arrival']['dateTime']),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      formatFullDateTime(schedule['arrival']['dateTime']),
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
    return InkWell(
      onTap: () {
        if (widget.onSelect != null) {
          widget.onSelect!();
          return;
        }
        if (widget.isShowBookButton) {
          emiratesController.handleEmiratesFlightSelection(widget.flight);
        } else {
          _showFlightDetailsDialog();
        }
      },
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
                  imageUrl: 'https://images.kiwi.com/airlines/64/EK.png',
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
                    color: Color(0xFFD71921),
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

            // Middle section with departure and arrival
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Departure
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        getDepartureTime(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        getDepartureAirport(),
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
                        getFlightDuration(),
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
                        color: const Color(0xFFD71921),
                      ),
                      const SizedBox(height: 4),
                      // Nonstop indicator below line
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD71921).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Nonstop',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFD71921),
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
                        getArrivalTime(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        getArrivalAirport(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

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
• ${widget.flight.isRefundable ? 'Refundable' : 'Non-refundable'} ticket
• Date change permitted with fee
• Standard meal included
• Free seat selection
• Cabin baggage allowed
• Check-in baggage as per policy''';
  }
}