import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../utility/colors.dart';
import '../../home/home_screen.dart';
import 'booking_flight_controller.dart';

/// Unified flight booking voucher that works for all flight types
/// Similar design to hotel booking voucher
class CommonFlightBookingVoucher extends StatelessWidget {
  // Flight data - can be from any airline
  final Map<String, dynamic> flightData;
  final Map<String, dynamic>? pnrResponse;
  final String airlineName;
  final String? bookingId;
  final String? bookingStatus;
  final double totalPrice;
  final String currency;
  final DateTime? expiryDateTime;
  final Map<int, String>? selectedSeats;
  final double totalSeatPrice;
  final Map<String, dynamic>? extras; // Extras: baggage, meals, seats, etc.

  BookingFlightController get bookingController {
    try {
      if (Get.isRegistered<BookingFlightController>()) {
        final controller = Get.find<BookingFlightController>();
        print('DEBUG: Found registered controller, adults: ${controller.adults.length}');
        return controller;
      } else {
        print('DEBUG: Controller not registered, creating new one');
        return Get.put(BookingFlightController(), permanent: true);
      }
    } catch (e) {
      print('DEBUG: Error getting controller: $e');
      return Get.put(BookingFlightController(), permanent: true);
    }
  }

  CommonFlightBookingVoucher({
    super.key,
    required this.flightData,
    this.pnrResponse,
    required this.airlineName,
    this.bookingId,
    this.bookingStatus,
    required this.totalPrice,
    required this.currency,
    this.expiryDateTime,
    this.selectedSeats,
    this.totalSeatPrice = 0.0,
    this.extras,
  });

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    await launchUrl(launchUri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: TColors.primary,
        title: const Text(
          "Booking Confirmed",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Get.offAll(HomeScreen()),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () => _generatePDF(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildSuccessHeader(),
            const SizedBox(height: 20),
            _buildBookingDetailsCard(),
            const SizedBox(height: 16),
            _buildFlightDetailsCard(),
            const SizedBox(height: 16),
            _buildPassengerDetailsCard(),
            const SizedBox(height: 16),
            _buildPriceBreakdownCard(),
            if (extras != null && _hasExtras()) ...[
              const SizedBox(height: 16),
              _buildExtrasSection(),
            ],
            const SizedBox(height: 16),
            _buildPrivacyPolicySection(),
            const SizedBox(height: 16),
            _buildContactSupportSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.white, width: 1),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Dear ${bookingController.firstNameController.text.isNotEmpty ? bookingController.firstNameController.text : 'Customer'} ${bookingController.lastNameController.text.isNotEmpty ? bookingController.lastNameController.text : ''},',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: TColors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your flight booking has been submitted successfully!',
            style: TextStyle(
              fontSize: 16,
              color: TColors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Thanks for choosing readyflight.pk. We have received your flight booking and it will be confirmed with airline shortly after confirmation of payment from your side.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'You can also call us at our customer support no: +92 3219667909',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBookingDetailsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TColors.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment, color: TColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Booking Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: TColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (bookingId != null)
                  _buildDetailRow('Booking ID', bookingId!),
                if (bookingId != null) const SizedBox(height: 12),
                _buildDetailRow('PNR', _getPNR()),
                const SizedBox(height: 12),
                _buildDetailRow('Booking Status', bookingStatus ?? 'On Request'),
                const SizedBox(height: 12),
                _buildHighlightedTotalRow(),
                const SizedBox(height: 12),
                if (expiryDateTime != null) ...[
                  _buildExpiryNotice(),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPNR() {
    if (pnrResponse == null) return 'Pending';
    
    // Try different PNR field names
    return pnrResponse?['pnr'] ?? 
           pnrResponse?['data']?['pnr'] ??
           pnrResponse?['booking_id'] ??
           pnrResponse?['confirmationNumber'] ??
           pnrResponse?['CreatePassengerNameRecordRS']?['ItineraryRef']?['ID'] ??
           'Pending';
  }

  Widget _buildExpiryNotice() {
    if (expiryDateTime == null) return const SizedBox.shrink();
    
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('MMM dd, yyyy');
    final now = DateTime.now();
    final isToday = expiryDateTime!.day == now.day &&
        expiryDateTime!.month == now.month &&
        expiryDateTime!.year == now.year;
    
    final expiryMessage = isToday
        ? 'This booking will expire today at ${timeFormat.format(expiryDateTime!)}'
        : 'This booking will expire on ${dateFormat.format(expiryDateTime!)} at ${timeFormat.format(expiryDateTime!)}';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              expiryMessage,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedTotalRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              'Total Amount',
              style: TextStyle(
                fontSize: 14,
                color: TColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$currency ${totalPrice.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 16,
                color: TColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlightDetailsCard() {
    final flights = _extractFlights();
    
    if (flights.isEmpty) return const SizedBox.shrink();
    
    // Build cards for all flights (outbound, return, multicity)
    return Column(
      children: flights.asMap().entries.map((entry) {
        final index = entry.key;
        final flight = entry.value;
        final isReturn = flights.length > 1 && index == 1;
        final isMulticity = flights.length > 2;
        
        String flightTitle;
        if (isMulticity) {
          flightTitle = 'Flight ${index + 1} Details';
        } else if (isReturn) {
          flightTitle = 'Return Flight Details';
        } else if (flights.length > 1 && index == 0) {
          flightTitle = 'Outbound Flight Details';
        } else {
          flightTitle = 'Flight Details';
        }
        
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: TColors.third.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flight, color: TColors.third),
                        const SizedBox(width: 8),
                        Text(
                          flightTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: TColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildFlightInfo(flight),
                  ),
                ],
              ),
            ),
            if (index < flights.length - 1) const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  List<Map<String, dynamic>> _extractFlights() {
    // Extract flights from flightData - handle different structures
    final List<Map<String, dynamic>> flights = [];
    
    // Check for multicity flights
    if (flightData['multicityFlights'] != null) {
      final multicity = flightData['multicityFlights'] as List;
      for (var flight in multicity) {
        flights.add(flight as Map<String, dynamic>);
      }
    }
    // Check for return flight
    else if (flightData['returnFlight'] != null) {
      flights.add(flightData['outboundFlight'] as Map<String, dynamic>);
      flights.add(flightData['returnFlight'] as Map<String, dynamic>);
    }
    // Single flight
    else {
      flights.add(flightData);
    }
    
    return flights;
  }

  Widget _buildFlightInfo(Map<String, dynamic> flight) {
    final departure = _getDepartureInfo(flight);
    final arrival = _getArrivalInfo(flight);
    final departureDateTime = _parseDateTime(departure['dateTime'] ?? departure['time']);
    final arrivalDateTime = _parseDateTime(arrival['dateTime'] ?? arrival['time']);
    final duration = arrivalDateTime.difference(departureDateTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Departure',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm').format(departureDateTime),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: TColors.text,
                  ),
                ),
                Text(
                  departure['airport'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  DateFormat('E dd MMM yyyy').format(departureDateTime),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: TColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${hours}h ${minutes}m',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: TColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 60,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [TColors.primary, TColors.primary.withOpacity(0.5)],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.flight, color: TColors.primary, size: 20),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Arrival',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm').format(arrivalDateTime),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: TColors.text,
                  ),
                ),
                Text(
                  arrival['airport'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  DateFormat('E dd MMM yyyy').format(arrivalDateTime),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildFlightDetails(flight),
      ],
    );
  }

  Map<String, dynamic> _getDepartureInfo(Map<String, dynamic> flight) {
    // Handle different flight data structures
    if (flight['legSchedules'] != null && flight['legSchedules'].isNotEmpty) {
      return flight['legSchedules'][0]['departure'];
    } else if (flight['departure'] != null) {
      return flight['departure'];
    } else if (flight['stopSchedules'] != null && flight['stopSchedules'].isNotEmpty) {
      return flight['stopSchedules'][0]['departure'];
    }
    return {};
  }

  Map<String, dynamic> _getArrivalInfo(Map<String, dynamic> flight) {
    // Handle different flight data structures
    if (flight['legSchedules'] != null && flight['legSchedules'].isNotEmpty) {
      final legs = flight['legSchedules'] as List;
      return legs.last['arrival'];
    } else if (flight['arrival'] != null) {
      return flight['arrival'];
    } else if (flight['stopSchedules'] != null && flight['stopSchedules'].isNotEmpty) {
      final stops = flight['stopSchedules'] as List;
      return stops.last['arrival'];
    }
    return {};
  }

  DateTime _parseDateTime(dynamic dateTime) {
    if (dateTime == null) return DateTime.now();
    if (dateTime is DateTime) return dateTime;
    if (dateTime is String) {
      try {
        return DateTime.parse(dateTime);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  Widget _buildFlightDetails(Map<String, dynamic> flight) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TColors.background2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Airline', airlineName),
          const SizedBox(height: 8),
          if (flight['flightNumber'] != null)
            _buildDetailRow('Flight Number', flight['flightNumber']),
          if (flight['flightNumber'] == null && flight['legSchedules'] != null)
            _buildDetailRow('Flight Number', _extractFlightNumber(flight)),
          const SizedBox(height: 8),
          _buildDetailRow('Cabin Class', flight['cabinName'] ?? flight['cabin'] ?? 'Economy'),
          const SizedBox(height: 8),
          _buildBaggageInfo(flight),
        ],
      ),
    );
  }

  String _extractFlightNumber(Map<String, dynamic> flight) {
    if (flight['legSchedules'] != null && flight['legSchedules'].isNotEmpty) {
      final leg = flight['legSchedules'][0];
      if (leg['flightNumber'] != null) return leg['flightNumber'];
      if (leg['carrier'] != null) {
        final carrier = leg['carrier'];
        return '${carrier['marketing']}-${carrier['marketingFlightNumber']}';
      }
    }
    return 'N/A';
  }

  Widget _buildBaggageInfo(Map<String, dynamic> flight) {
    String handBaggage = '7 Kg';
    String checkedBaggage = 'N/A';
    
    // Try to extract baggage information from different possible locations
    if (flight['baggageAllowance'] != null) {
      final baggage = flight['baggageAllowance'];
      if (baggage is Map) {
        final weight = baggage['weight']?.toString() ?? '0';
        final unit = baggage['unit'] ?? 'Kg';
        checkedBaggage = '${weight.replaceAll(RegExp(r'\.0$'), '')} $unit';
      }
    } else if (flight['checkedBaggage'] != null) {
      checkedBaggage = flight['checkedBaggage'].toString();
    } else if (flight['check_baggage'] != null) {
      checkedBaggage = flight['check_baggage'].toString();
    }
    
    if (flight['handBaggage'] != null) {
      handBaggage = flight['handBaggage'].toString();
    } else if (flight['hand_baggage'] != null) {
      handBaggage = flight['hand_baggage'].toString();
    }
    
    return Column(
      children: [
        _buildDetailRow('Hand Baggage', handBaggage),
        const SizedBox(height: 8),
        _buildDetailRow('Checked Baggage', checkedBaggage),
      ],
    );
  }

  Widget _buildPassengerDetailsCard() {
    final totalPassengers = bookingController.adults.length + 
                           bookingController.children.length + 
                           bookingController.infants.length;
    
    // If no passengers, don't show the card
    if (totalPassengers == 0) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TColors.secondary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: TColors.secondary),
                const SizedBox(width: 8),
                Text(
                  'Passenger Details ($totalPassengers)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: TColors.text,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ..._buildPassengerList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPassengerList() {
    List<Widget> widgets = [];
    int passengerIndex = 1;

    // Debug: Print passenger data
    print('DEBUG: Adults count: ${bookingController.adults.length}');
    for (var adult in bookingController.adults) {
      print('DEBUG: Adult name: ${adult.firstNameController.text} ${adult.lastNameController.text}');
      print('DEBUG: Adult passport: ${adult.passportCnicController.text}');
    }

    // Adults
    for (var adult in bookingController.adults) {
      final firstName = adult.firstNameController.text.trim();
      final lastName = adult.lastNameController.text.trim();
      final passport = adult.passportCnicController.text.trim();
      
      final fullName = firstName.isNotEmpty || lastName.isNotEmpty
          ? '$firstName $lastName'.trim()
          : 'Passenger $passengerIndex';
      
      widgets.add(_buildPassengerRow(
        passengerIndex++,
        'Adult',
        fullName,
        passport.isNotEmpty ? passport : 'Not provided',
        TColors.primary,
      ));
      if (passengerIndex <= bookingController.adults.length + bookingController.children.length + bookingController.infants.length) {
        widgets.add(const SizedBox(height: 12));
      }
    }

    // Children
    for (var child in bookingController.children) {
      final firstName = child.firstNameController.text.trim();
      final lastName = child.lastNameController.text.trim();
      final passport = child.passportCnicController.text.trim();
      
      final fullName = firstName.isNotEmpty || lastName.isNotEmpty
          ? '$firstName $lastName'.trim()
          : 'Child $passengerIndex';
      
      widgets.add(_buildPassengerRow(
        passengerIndex++,
        'Child',
        fullName,
        passport.isNotEmpty ? passport : 'Not provided',
        const Color(0xFF10B981),
      ));
      if (passengerIndex <= bookingController.adults.length + bookingController.children.length + bookingController.infants.length) {
        widgets.add(const SizedBox(height: 12));
      }
    }

    // Infants
    for (var infant in bookingController.infants) {
      final firstName = infant.firstNameController.text.trim();
      final lastName = infant.lastNameController.text.trim();
      final passport = infant.passportCnicController.text.trim();
      
      final fullName = firstName.isNotEmpty || lastName.isNotEmpty
          ? '$firstName $lastName'.trim()
          : 'Infant $passengerIndex';
      
      widgets.add(_buildPassengerRow(
        passengerIndex++,
        'Infant',
        fullName,
        passport.isNotEmpty ? passport : 'Not provided',
        const Color(0xFFF59E0B),
      ));
      if (passengerIndex <= bookingController.adults.length + bookingController.children.length + bookingController.infants.length) {
        widgets.add(const SizedBox(height: 12));
      }
    }

    return widgets;
  }

  Widget _buildPassengerRow(int index, String type, String name, String passport, Color typeColor) {
    final seatNumber = selectedSeats?.containsKey(index - 1) == true
        ? selectedSeats![index - 1]
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: typeColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: typeColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: typeColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    index.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: typeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: TColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.credit_card, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                passport.isNotEmpty ? passport : 'Not provided',
                style: TextStyle(
                  fontSize: 12,
                  color: passport.isNotEmpty ? Colors.grey.shade600 : Colors.red.shade600,
                  fontStyle: passport.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
          if (seatNumber != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.airline_seat_recline_normal, size: 14, color: Color(0xFF10B981)),
                const SizedBox(width: 4),
                Text(
                  'Seat: $seatNumber',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceBreakdownCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                const Text(
                  'Price Breakdown',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: TColors.text,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildPriceRow('Base Fare', totalPrice * 0.7),
                const SizedBox(height: 8),
                _buildPriceRow('Taxes', totalPrice * 0.2),
                const SizedBox(height: 8),
                if (totalSeatPrice > 0) ...[
                  _buildPriceRow('Seat Selection', totalSeatPrice),
                  const SizedBox(height: 8),
                ],
                _buildPriceRow('Fees', totalPrice * 0.1),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: TColors.primary,
                        ),
                      ),
                      Text(
                        '$currency ${(totalPrice + totalSeatPrice).toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: TColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          '$currency ${amount.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: TColors.text,
          ),
        ),
      ],
    );
  }

  bool _hasExtras() {
    if (extras == null) {
      print('🔍 DEBUG: Extras is null');
      return false;
    }
    
    print('🔍 DEBUG: Checking extras: $extras');
    
    // Check if any extras exist
    final baggage = extras!['baggage'] ?? extras!['selectedBaggage'];
    final meals = extras!['meals'] ?? extras!['selectedMeals'];
    final seats = extras!['seats'] ?? extras!['selectedSeats'];
    
    print('   - Baggage: $baggage (${baggage?.runtimeType})');
    print('   - Meals: $meals (${meals?.runtimeType})');
    print('   - Seats: $seats (${seats?.runtimeType})');
    
    final hasBaggage = baggage != null && 
        (baggage is Map ? baggage.isNotEmpty : baggage is List ? baggage.isNotEmpty : false);
    final hasMeals = meals != null && 
        (meals is Map ? meals.isNotEmpty : meals is List ? meals.isNotEmpty : false);
    final hasSeats = seats != null && 
        (seats is Map ? seats.isNotEmpty : seats is List ? seats.isNotEmpty : false);
    
    print('   - Has baggage: $hasBaggage');
    print('   - Has meals: $hasMeals');
    print('   - Has seats: $hasSeats');
    
    final result = hasBaggage || hasMeals || hasSeats;
    print('   - Result: $result');
    
    return result;
  }

  Widget _buildExtrasSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                const Text(
                  'Selected Extras',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: TColors.text,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ..._buildBaggageExtras(),
                if (_buildBaggageExtras().isNotEmpty && 
                    (_buildMealExtras().isNotEmpty || _buildSeatExtras().isNotEmpty))
                  const SizedBox(height: 12),
                ..._buildMealExtras(),
                if (_buildMealExtras().isNotEmpty && _buildSeatExtras().isNotEmpty)
                  const SizedBox(height: 12),
                ..._buildSeatExtras(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBaggageExtras() {
    final baggage = extras!['baggage'] ?? extras!['selectedBaggage'];
    if (baggage == null) return [];
    
    List<Widget> widgets = [];
    
    if (baggage is Map) {
      baggage.forEach((key, value) {
        if (value != null) {
          final baggageData = value is Map ? value : {'description': value.toString()};
          final description = baggageData['description'] ?? 
                            baggageData['name'] ?? 
                            baggageData['weight'] ?? 
                            'Baggage';
          final charge = baggageData['charge'] ?? baggageData['price'] ?? 0.0;
          final chargeStr = charge is num ? charge.toStringAsFixed(0) : charge.toString();
          
          // Extract passenger info from key if available (format: "seg{code}|p{id}")
          String label = 'Extra Baggage';
          if (key is String && key.contains('|')) {
            final parts = key.split('|');
            if (parts.length == 2) {
              final passengerId = parts[1].replaceAll('p', '');
              final passengerNum = int.tryParse(passengerId);
              if (passengerNum != null) {
                label = 'Extra Baggage (Passenger ${passengerNum + 1})';
              }
            }
          }
          
          widgets.add(_buildExtraRow(
            icon: Icons.luggage,
            label: label,
            value: description,
            price: chargeStr != '0' && chargeStr != '0.0' ? '$currency $chargeStr' : null,
            color: const Color(0xFF10B981),
          ));
        }
      });
    } else if (baggage is List) {
      for (var item in baggage) {
        if (item != null) {
          final baggageData = item is Map ? item : {'description': item.toString()};
          final description = baggageData['description'] ?? 
                            baggageData['name'] ?? 
                            'Baggage';
          final charge = baggageData['charge'] ?? baggageData['price'] ?? 0.0;
          final chargeStr = charge is num ? charge.toStringAsFixed(0) : charge.toString();
          
          widgets.add(_buildExtraRow(
            icon: Icons.luggage,
            label: 'Extra Baggage',
            value: description,
            price: chargeStr != '0' && chargeStr != '0.0' ? '$currency $chargeStr' : null,
            color: const Color(0xFF10B981),
          ));
        }
      }
    }
    
    return widgets;
  }

  List<Widget> _buildMealExtras() {
    final meals = extras!['meals'] ?? extras!['selectedMeals'];
    if (meals == null) return [];
    
    List<Widget> widgets = [];
    
    if (meals is Map) {
      meals.forEach((key, value) {
        if (value != null) {
          final mealData = value is Map ? value : {'name': value.toString()};
          final name = mealData['name'] ?? 
                      mealData['description'] ?? 
                      mealData['mealName'] ?? 
                      'Meal';
          final charge = mealData['charge'] ?? mealData['price'] ?? 0.0;
          final chargeStr = charge is num ? charge.toStringAsFixed(0) : charge.toString();
          
          // Extract passenger info from key if available
          String label = 'Meal';
          if (key is String && key.contains('|')) {
            final parts = key.split('|');
            if (parts.length == 2) {
              final passengerId = parts[1].replaceAll('p', '');
              final passengerNum = int.tryParse(passengerId);
              if (passengerNum != null) {
                label = 'Meal (Passenger ${passengerNum + 1})';
              }
            }
          }
          
          widgets.add(_buildExtraRow(
            icon: Icons.restaurant,
            label: label,
            value: name,
            price: chargeStr != '0' && chargeStr != '0.0' ? '$currency $chargeStr' : null,
            color: const Color(0xFFF59E0B),
          ));
        }
      });
    } else if (meals is List) {
      for (var item in meals) {
        if (item != null) {
          final mealData = item is Map ? item : {'name': item.toString()};
          final name = mealData['name'] ?? 
                      mealData['description'] ?? 
                      'Meal';
          final charge = mealData['charge'] ?? mealData['price'] ?? 0.0;
          final chargeStr = charge is num ? charge.toStringAsFixed(0) : charge.toString();
          
          widgets.add(_buildExtraRow(
            icon: Icons.restaurant,
            label: 'Meal',
            value: name,
            price: chargeStr != '0' && chargeStr != '0.0' ? '$currency $chargeStr' : null,
            color: const Color(0xFFF59E0B),
          ));
        }
      }
    }
    
    return widgets;
  }

  List<Widget> _buildSeatExtras() {
    final seats = extras!['seats'] ?? extras!['selectedSeats'];
    if (seats == null) return [];
    
    List<Widget> widgets = [];
    
    if (seats is Map) {
      seats.forEach((key, value) {
        if (value != null) {
          final seatData = value is Map ? value : {'seatNumber': value.toString()};
          final seatNumber = seatData['seatNumber'] ?? 
                           seatData['seat'] ?? 
                           seatData['name'] ?? 
                           'Seat';
          final charge = seatData['charge'] ?? seatData['price'] ?? 0.0;
          final chargeStr = charge is num ? charge.toStringAsFixed(0) : charge.toString();
          
          // Extract passenger info from key if available
          String label = 'Seat Selection';
          if (key is String && key.contains('|')) {
            final parts = key.split('|');
            if (parts.length == 2) {
              final passengerId = parts[1].replaceAll('p', '');
              final passengerNum = int.tryParse(passengerId);
              if (passengerNum != null) {
                label = 'Seat Selection (Passenger ${passengerNum + 1})';
              }
            }
          }
          
          widgets.add(_buildExtraRow(
            icon: Icons.airline_seat_recline_normal,
            label: label,
            value: seatNumber,
            price: chargeStr != '0' && chargeStr != '0.0' ? '$currency $chargeStr' : null,
            color: TColors.primary,
          ));
        }
      });
    } else if (seats is List) {
      for (var item in seats) {
        if (item != null) {
          final seatData = item is Map ? item : {'seatNumber': item.toString()};
          final seatNumber = seatData['seatNumber'] ?? 
                           seatData['seat'] ?? 
                           'Seat';
          final charge = seatData['charge'] ?? seatData['price'] ?? 0.0;
          final chargeStr = charge is num ? charge.toStringAsFixed(0) : charge.toString();
          
          widgets.add(_buildExtraRow(
            icon: Icons.airline_seat_recline_normal,
            label: 'Seat Selection',
            value: seatNumber,
            price: chargeStr != '0' && chargeStr != '0.0' ? '$currency $chargeStr' : null,
            color: TColors.primary,
          ));
        }
      }
    }
    
    return widgets;
  }

  Widget _buildExtraRow({
    required IconData icon,
    required String label,
    required String value,
    String? price,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: TColors.text,
                  ),
                ),
              ],
            ),
          ),
          if (price != null)
            Text(
              price,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPolicySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  TColors.primary.withOpacity(0.1),
                  TColors.third.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: TColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: TColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Privacy & Legal Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: TColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Your privacy and security are important to us. Please review our policies to understand how we handle your information.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _buildPolicyButton(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'How we collect and use your data',
                  onTap: () => _launchPrivacyPolicy(),
                  color: TColors.primary,
                ),
                const SizedBox(height: 12),
                _buildPolicyButton(
                  icon: Icons.article_outlined,
                  title: 'Terms of Service',
                  subtitle: 'Rules and guidelines for using our service',
                  onTap: () => _launchTermsOfService(),
                  color: TColors.secondary,
                ),
                const SizedBox(height: 12),
                _buildPolicyButton(
                  icon: Icons.cancel_outlined,
                  title: 'Cancellation Policy',
                  subtitle: 'Booking modification and cancellation terms',
                  onTap: () => _launchCancellationPolicy(),
                  color: TColors.third,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TColors.background2.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'By proceeding with this booking, you agree to our terms and conditions.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: color.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSupportSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TColors.third.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.headset_mic, color: TColors.third),
                const SizedBox(width: 8),
                const Text(
                  'Need help?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: TColors.text,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Contact one of our support agents and we will help you with your query.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _makePhoneCall('+923219667909'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Contact Support',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: TColors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchPrivacyPolicy() async {
    const url = 'https://readyflight.pk/privacy-policy';
    final Uri uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _launchTermsOfService() async {
    const url = 'https://readyflight.pk/terms-of-service';
    final Uri uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _launchCancellationPolicy() async {
    const url = 'https://readyflight.pk/cancellation-policy';
    final Uri uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _generatePDF(BuildContext context) async {
    try {
      final pdf = await _createPDF();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf,
        name: 'Flight_Booking_Confirmation_${bookingId ?? DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF generation failed: $e')),
      );
    }
  }

  Future<Uint8List> _createPDF() async {
    final pdf = pw.Document();
    final flights = _extractFlights();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            _buildPDFHeader(),
            pw.SizedBox(height: 20),
            _buildPDFBookingDetails(),
            pw.SizedBox(height: 20),
            ..._buildPDFFlightSections(flights),
            pw.SizedBox(height: 20),
            _buildPDFPassengerDetails(),
            pw.SizedBox(height: 20),
            _buildPDFPriceBreakdown(),
            pw.SizedBox(height: 20),
            _buildPDFContactInfo(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPDFHeader() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'ReadyFlight.pk',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.Text(
                'BOOKING CONFIRMED',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Dear ${bookingController.firstNameController.text} ${bookingController.lastNameController.text},',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Your flight booking has been submitted successfully!',
            style: const pw.TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFBookingDetails() {
    return _buildPDFSection(
      'Booking Details',
      [
        if (bookingId != null) ['Booking ID', bookingId!],
        ['PNR', _getPNR()],
        ['Booking Status', bookingStatus ?? 'On Request'],
        ['Total Amount', '$currency ${totalPrice.toStringAsFixed(0)}'],
      ],
    );
  }

  List<pw.Widget> _buildPDFFlightSections(List<Map<String, dynamic>> flights) {
    return flights.asMap().entries.map((entry) {
      final index = entry.key;
      final flight = entry.value;
      return pw.Column(
        children: [
          _buildPDFFlightSection(flight, index + 1, flights.length),
          if (index < flights.length - 1) pw.SizedBox(height: 20),
        ],
      );
    }).toList();
  }

  pw.Widget _buildPDFFlightSection(Map<String, dynamic> flight, int flightNumber, int totalFlights) {
    final departure = _getDepartureInfo(flight);
    final arrival = _getArrivalInfo(flight);
    final departureDateTime = _parseDateTime(departure['dateTime'] ?? departure['time']);
    final arrivalDateTime = _parseDateTime(arrival['dateTime'] ?? arrival['time']);

    return _buildPDFSection(
      totalFlights > 1 ? 'Flight $flightNumber Details' : 'Flight Details',
      [
        ['Airline', airlineName],
        ['Flight Number', _extractFlightNumber(flight)],
        ['Departure', '${departure['airport']} - ${DateFormat('E dd MMM yyyy HH:mm').format(departureDateTime)}'],
        ['Arrival', '${arrival['airport']} - ${DateFormat('E dd MMM yyyy HH:mm').format(arrivalDateTime)}'],
        ['Cabin Class', flight['cabinName'] ?? flight['cabin'] ?? 'Economy'],
      ],
    );
  }

  pw.Widget _buildPDFPassengerDetails() {
    List<List<String>> passengerData = [];
    int index = 1;

    for (var adult in bookingController.adults) {
      passengerData.add([
        index.toString(),
        '${adult.firstNameController.text} ${adult.lastNameController.text}',
        'Adult',
        adult.passportCnicController.text,
      ]);
      index++;
    }

    for (var child in bookingController.children) {
      passengerData.add([
        index.toString(),
        '${child.firstNameController.text} ${child.lastNameController.text}',
        'Child',
        child.passportCnicController.text,
      ]);
      index++;
    }

    for (var infant in bookingController.infants) {
      passengerData.add([
        index.toString(),
        '${infant.firstNameController.text} ${infant.lastNameController.text}',
        'Infant',
        infant.passportCnicController.text,
      ]);
      index++;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Passenger Details',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(0.5),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1.5),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildPDFTableCell('Sr', isHeader: true),
                _buildPDFTableCell('Name', isHeader: true),
                _buildPDFTableCell('Type', isHeader: true),
                _buildPDFTableCell('Passport#', isHeader: true),
              ],
            ),
            // Data rows
            ...passengerData.map((row) => pw.TableRow(
              children: [
                _buildPDFTableCell(row[0]),
                _buildPDFTableCell(row[1]),
                _buildPDFTableCell(row[2]),
                _buildPDFTableCell(row[3]),
              ],
            )),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _buildPDFPriceBreakdown() {
    return _buildPDFSection(
      'Price Breakdown',
      [
        ['Base Fare', '$currency ${(totalPrice * 0.7).toStringAsFixed(0)}'],
        ['Taxes', '$currency ${(totalPrice * 0.2).toStringAsFixed(0)}'],
        if (totalSeatPrice > 0)
          ['Seat Selection', '$currency ${totalSeatPrice.toStringAsFixed(0)}'],
        ['Fees', '$currency ${(totalPrice * 0.1).toStringAsFixed(0)}'],
        ['Total Amount', '$currency ${(totalPrice + totalSeatPrice).toStringAsFixed(0)}'],
      ],
    );
  }

  pw.Widget _buildPDFContactInfo() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blue200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Support Contact',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Phone: +92 3219667909',
            style: const pw.TextStyle(fontSize: 14),
          ),
          pw.Text(
            'Email: support@readyflight.pk',
            style: const pw.TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFSection(String title, List<List<String>> data) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              children: data.map((row) => 
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 120,
                        child: pw.Text(
                          '${row[0]}:',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          row[1],
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

