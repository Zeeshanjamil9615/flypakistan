// air_arabia_booking_confirmation.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../utility/colors.dart';
import '../../../../../utility/app_constants.dart';
import '../../../home/home_screen.dart';
import '../../search_flights/airarabia/airarabia_flight_model.dart';
import '../booking_flight_controller.dart';

class AirArabiaBookingConfirmation extends StatefulWidget {
  final AirArabiaFlight flight;
  final AirArabiaPackage selectedPackage;
  final Map<String, dynamic> bookingResponse;
  final double totalPrice;
  final String currency;

  const AirArabiaBookingConfirmation({
    super.key,
    required this.flight,
    required this.selectedPackage,
    required this.bookingResponse,
    required this.totalPrice,
    required this.currency,
  });

  @override
  State<AirArabiaBookingConfirmation> createState() =>
      _AirArabiaBookingConfirmationState();
}

class _AirArabiaBookingConfirmationState extends State<AirArabiaBookingConfirmation>
    with TickerProviderStateMixin {
  final BookingFlightController bookingController =
      Get.find<BookingFlightController>();

  // Timer related variables
  Timer? _countdownTimer;
  Duration? _timeRemaining;
  DateTime? _expiryDateTime;
  String _expiryMessage = '';

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeTimer();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _initializeTimer() {
    final deadlineString = widget.bookingResponse['data']['deadline'];

    if (deadlineString != null) {
      try {
        _expiryDateTime = DateTime.parse(deadlineString);
        _updateExpiryMessage();
        _startCountdown();
      } catch (e) {
        print('Error parsing deadline: $e');
      }
    }
  }

  void _updateExpiryMessage() {
    if (_expiryDateTime == null) return;

    final now = DateTime.now();
    final isToday =
        _expiryDateTime!.day == now.day &&
        _expiryDateTime!.month == now.month &&
        _expiryDateTime!.year == now.year;

    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('MMM dd, yyyy');

    if (isToday) {
      _expiryMessage =
          'This booking will expire today at ${timeFormat.format(_expiryDateTime!)}';
    } else {
      _expiryMessage =
          'This booking will expire on ${dateFormat.format(_expiryDateTime!)} at ${timeFormat.format(_expiryDateTime!)}';
    }
  }

  void _startCountdown() {
    if (_expiryDateTime == null) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final difference = _expiryDateTime!.difference(now);

      if (difference.isNegative) {
        setState(() {
          _timeRemaining = Duration.zero;
          _expiryMessage = 'This booking has expired';
        });
        timer.cancel();
      } else {
        setState(() {
          _timeRemaining = difference;
        });
      }
    });
  }

  String _formatTimeRemaining() {
    if (_timeRemaining == null || _timeRemaining!.isNegative) {
      return 'Expired';
    }

    final days = _timeRemaining!.inDays;
    final hours = _timeRemaining!.inHours.remainder(24);
    final minutes = _timeRemaining!.inMinutes.remainder(60);
    final seconds = _timeRemaining!.inSeconds.remainder(60);

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m ${seconds}s';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else {
      return '${minutes}m ${seconds}s';
    }
  }

  Color _getTimerColor() {
    if (_timeRemaining == null || _timeRemaining!.isNegative) {
      return Colors.red;
    }

    final totalMinutes = _timeRemaining!.inMinutes;
    if (totalMinutes <= 30) {
      return Colors.red;
    } else if (totalMinutes <= 120) {
      return Colors.orange;
    } else {
      return const Color(0xFF10B981);
    }
  }

  Future<void> _launchDialer(String phoneNumber) async {
    final url = "tel:$phoneNumber";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _launchWhatsApp(String phoneNumber) async {
    String message = "Ready Flights - Air Arabia Booking Support";
    final url = "https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    _buildThankYouSection(),
                    if (_expiryDateTime != null) _buildExpiryNotice(),
                    _buildBookingHeader(),
                    _buildFlightDetailsSection(),
                    _buildPassengerDetailsCard(),
                    _buildPriceBreakdownCard(),
                    const SizedBox(height: 70),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButtons(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 56,
      collapsedHeight: 56,
      floating: false,
      pinned: true,
      backgroundColor: TColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Get.offAll(() => HomeScreen()),
      ),
      title: Text(
        'Booking Confirmation',
        style: AppConstants.sectionTitleStyle.copyWith(
          color: Colors.white,
          fontSize: 18,
        ),
      ),
      centerTitle: false,
    );
  }

  Widget _buildThankYouSection() {
    String customerName = bookingController.firstNameController.text.isNotEmpty
        ? bookingController.firstNameController.text
        : bookingController.adults.isNotEmpty
        ? bookingController.adults.first.firstNameController.text
        : 'Valued Customer';

    const String supportNumber = "923007240421";

    return Container(
      margin: const EdgeInsets.all(16),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                TColors.primary,
                TColors.primary.withOpacity(0.9),
              ],
            ),
          ),
          child: Column(
            children: [
              // Success icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 35,
                ),
              ),
              const SizedBox(height: 16),

              // Thank you message
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: AppConstants.sectionTitleStyle.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                  children: [
                    const TextSpan(text: 'Dear '),
                    TextSpan(
                      text: customerName,
                      style: AppConstants.sectionTitleStyle.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const TextSpan(
                      text: ', your Air Arabia booking is confirmed!',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Contact section
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Need help? Contact us:',
                      style: AppConstants.fieldValueStyle.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Phone icon
                    GestureDetector(
                      onTap: () => _launchDialer("+$supportNumber"),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.phone,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // WhatsApp icon
                    GestureDetector(
                      onTap: () => _launchWhatsApp(supportNumber),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const FaIcon(
                          FontAwesomeIcons.whatsapp,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiryNotice() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _getTimerColor(), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: _getTimerColor(), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _expiryMessage,
                  style: AppConstants.fieldValueStyle.copyWith(
                    color: _getTimerColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (_timeRemaining != null && !_timeRemaining!.isNegative) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: _getTimerColor(),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                    Text(
                      'Time Left: ${_formatTimeRemaining()}',
                      style: AppConstants.fieldValueStyle.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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

  Widget _buildBookingHeader() {
    final bookingData = widget.bookingResponse['data'];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [TColors.primary, TColors.primary.withOpacity(0.9)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.flight_takeoff,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Air Arabia Booking',
                          style: AppConstants.sectionTitleStyle.copyWith(
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: bookingData['status'] == 'Hold'
                                ? Colors.orange.withOpacity(0.1)
                                : const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: bookingData['status'] == 'Hold'
                                  ? Colors.orange.withOpacity(0.3)
                                  : const Color(0xFF10B981).withOpacity(0.3),
                            ),
                          ),
                            child: Text(
                              bookingData['status']?.toString().toUpperCase() ?? 'CONFIRMED',
                              style: AppConstants.fieldLabelStyle.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: bookingData['status'] == 'Hold'
                                    ? Colors.orange
                                    : const Color(0xFF10B981),
                              ),
                            ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                      'Booking ID',
                      bookingData['booking_id']?.toString() ?? 'N/A',
                      Icons.confirmation_number_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'PNR',
                      bookingData['pnr']?.toString() ?? 'N/A',
                      Icons.airplane_ticket_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Booker',
                      '${bookingController.firstNameController.text} ${bookingController.lastNameController.text}',
                      Icons.person_outline,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: AppConstants.fieldLabelStyle.copyWith(fontSize: 12, color: const Color(0xFF64748B)),
        ),
        Expanded(
          child: Text(
            value,
            style: AppConstants.fieldValueStyle.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlightDetailsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Flight Details',
            style: AppConstants.sectionTitleStyle.copyWith(
              color: const Color(0xFF1E293B),
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 12),
          _buildFlightCard(),
        ],
      ),
    );
  }

  Widget _buildFlightCard() {
    final firstSegment = widget.flight.flightSegments.first;
    final lastSegment = widget.flight.flightSegments.last;
    final departureDateTime = DateTime.parse(firstSegment['departure']['dateTime']);
    final arrivalDateTime = DateTime.parse(lastSegment['arrival']['dateTime']);
    final duration = arrivalDateTime.difference(departureDateTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Column(
          children: [
            // Flight header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [TColors.primary, TColors.primary.withOpacity(0.9)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.flight_takeoff,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Air Arabia • ${widget.flight.airlineName}',
                      style: AppConstants.fieldValueStyle.copyWith(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.selectedPackage.packageName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Flight route
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('HH:mm').format(departureDateTime),
                              style: AppConstants.sectionTitleStyle.copyWith(
                                fontSize: 22,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              firstSegment['departure']['airport'],
                              style: AppConstants.fieldValueStyle.copyWith(
                                fontSize: 14,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              DateFormat('MMM dd').format(departureDateTime),
                              style: AppConstants.fieldLabelStyle.copyWith(
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: TColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${hours}h ${minutes}m',
                              style: AppConstants.fieldValueStyle.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: TColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 80,
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [TColors.primary, Color(0xFF1D4ED8)],
                              ),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Icon(
                            Icons.flight,
                            color: TColors.primary,
                            size: 20,
                          ),
                        ],
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              DateFormat('HH:mm').format(arrivalDateTime),
                              style: AppConstants.sectionTitleStyle.copyWith(
                                fontSize: 22,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              lastSegment['arrival']['airport'],
                              style: AppConstants.fieldValueStyle.copyWith(
                                fontSize: 14,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              DateFormat('MMM dd').format(arrivalDateTime),
                              style: AppConstants.fieldLabelStyle.copyWith(
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Flight segments
                  _buildFlightSegments(),

                  const SizedBox(height: 16),

                  // Baggage and amenities
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        _buildAmenityChip(
                          'Hand Baggage',
                          '7 Kg',
                          Icons.work_outline,
                        ),
                        const SizedBox(width: 12),
                        _buildAmenityChip(
                          'Checked Baggage',
                          '20 Kg',
                          Icons.luggage,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmenityChip(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppConstants.fieldLabelStyle.copyWith(
                      fontSize: 10,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  Text(
                    value,
                    style: AppConstants.fieldValueStyle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlightSegments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Flight Segments',
          style: AppConstants.sectionTitleStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 12),
        ...widget.flight.flightSegments.map((segment) {
          final departure = segment['departure'];
          final arrival = segment['arrival'];
          final flightNumber = segment['flightNumber'];

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: TColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.flight,
                    size: 16,
                    color: TColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        flightNumber,
                        style: AppConstants.fieldValueStyle.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        '${_formatTime(departure['dateTime'])} - ${_formatTime(arrival['dateTime'])}',
                        style: AppConstants.fieldLabelStyle.copyWith(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${departure['airport']} → ${arrival['airport']}',
                  style: AppConstants.fieldLabelStyle.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _formatTime(String dateTime) {
    try {
      final dt = DateTime.parse(dateTime);
      return DateFormat('HH:mm').format(dt);
    } catch (e) {
      return dateTime;
    }
  }

  Widget _buildPassengerDetailsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.people_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Passenger Details',
                        style: AppConstants.sectionTitleStyle.copyWith(
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: TColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: TColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '${bookingController.adults.length + bookingController.children.length + bookingController.infants.length} Passengers',
                          style: AppConstants.fieldLabelStyle.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: TColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Adults Section
              if (bookingController.adults.isNotEmpty) ...[
                _buildPassengerTypeHeader(
                  'Adults',
                  bookingController.adults.length,
                  TColors.primary,
                ),
                const SizedBox(height: 12),
                ...bookingController.adults.asMap().entries.map((entry) {
                  final index = entry.key;
                  final adult = entry.value;
                  return _buildPassengerCard(
                    index: index + 1,
                    name:
                        '${adult.firstNameController.text} ${adult.lastNameController.text}',
                    type: 'Adult',
                    passport: adult.passportCnicController.text,
                    typeColor: TColors.primary,
                    typeIcon: Icons.person,
                  );
                }),
              ],

              // Children Section
              if (bookingController.children.isNotEmpty) ...[
                _buildPassengerTypeHeader(
                  'Children',
                  bookingController.children.length,
                  const Color(0xFF10B981),
                ),
                const SizedBox(height: 12),
                ...bookingController.children.asMap().entries.map((entry) {
                  final index = entry.key;
                  final child = entry.value;
                  return _buildPassengerCard(
                    index: bookingController.adults.length + index + 1,
                    name:
                        '${child.firstNameController.text} ${child.lastNameController.text}',
                    type: 'Child',
                    passport: child.passportCnicController.text,
                    typeColor: const Color(0xFF10B981),
                    typeIcon: Icons.child_care,
                  );
                }),
              ],

              // Infants Section
              if (bookingController.infants.isNotEmpty) ...[
                _buildPassengerTypeHeader(
                  'Infants',
                  bookingController.infants.length,
                  const Color(0xFFF59E0B),
                ),
                const SizedBox(height: 12),
                ...bookingController.infants.asMap().entries.map((entry) {
                  final index = entry.key;
                  final infant = entry.value;
                  return _buildPassengerCard(
                    index:
                        bookingController.adults.length +
                        bookingController.children.length +
                        index +
                        1,
                    name:
                        '${infant.firstNameController.text} ${infant.lastNameController.text}',
                    type: 'Infant',
                    passport: infant.passportCnicController.text,
                    typeColor: const Color(0xFFF59E0B),
                    typeIcon: Icons.baby_changing_station,
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassengerTypeHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
          Text(
            title,
            style: AppConstants.fieldValueStyle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPassengerCard({
    required int index,
    required String name,
    required String type,
    required String passport,
    required Color typeColor,
    required IconData typeIcon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Serial number circle
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: typeColor.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                index.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: typeColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Passenger info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(typeIcon, size: 16, color: typeColor),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          fontSize: 10,
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
                  style: AppConstants.fieldValueStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.credit_card,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      passport.isNotEmpty ? passport : 'Not provided',
                      style: AppConstants.fieldLabelStyle.copyWith(
                        color:
                            passport.isNotEmpty
                                ? const Color(0xFF64748B)
                                : Colors.red.withOpacity(0.7),
                        fontStyle:
                            passport.isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Ticket status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Hold',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ticket #',
                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdownCard() {
    final bookingData = widget.bookingResponse['data'];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Price Breakdown',
                    style: AppConstants.sectionTitleStyle.copyWith(
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Adult pricing
              if (bookingController.adults.isNotEmpty) ...[
                _buildPassengerPriceSection(
                  'Adult (${bookingController.adults.length})',
                  widget.totalPrice / (bookingController.adults.length + bookingController.children.length + bookingController.infants.length),
                  widget.currency,
                  bookingController.adults.length,
                ),
                const SizedBox(height: 16),
              ],

              // Child pricing
              if (bookingController.children.isNotEmpty) ...[
                _buildPassengerPriceSection(
                  'Child (${bookingController.children.length})',
                  (widget.totalPrice * 0.75) / (bookingController.adults.length + bookingController.children.length + bookingController.infants.length),
                  widget.currency,
                  bookingController.children.length,
                ),
                const SizedBox(height: 16),
              ],

              // Infant pricing
              if (bookingController.infants.isNotEmpty) ...[
                _buildPassengerPriceSection(
                  'Infant (${bookingController.infants.length})',
                  (widget.totalPrice * 0.1) / (bookingController.adults.length + bookingController.children.length + bookingController.infants.length),
                  widget.currency,
                  bookingController.infants.length,
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1E293B).withOpacity(0.05),
                      const Color(0xFF334155).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1E293B).withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount',
                      style: AppConstants.sectionTitleStyle.copyWith(
                        fontSize: 16,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      '${bookingData['currency']} ${bookingData['total_amount']}',
                      style: AppConstants.sectionTitleStyle.copyWith(
                        fontSize: 16,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassengerPriceSection(
    String label,
    double pricePerPassenger,
    String currency,
    int count,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label Price',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          _buildPriceRow(
            'Base Fare',
            '$currency ${(pricePerPassenger * 0.7).toStringAsFixed(2)}',
          ),
          _buildPriceRow(
            'Taxes',
            '$currency ${(pricePerPassenger * 0.2).toStringAsFixed(2)}',
          ),
          _buildPriceRow(
            'Fees',
            '$currency ${(pricePerPassenger * 0.1).toStringAsFixed(2)}',
          ),
          const Divider(color: Color(0xFFE2E8F0)),
          _buildPriceRow(
            'Per Passenger',
            '$currency ${pricePerPassenger.toStringAsFixed(2)}',
            isSubtotal: true,
          ),
          if (count > 1)
            _buildPriceRow(
              'Subtotal (×$count)',
              '$currency ${(pricePerPassenger * count).toStringAsFixed(2)}',
              isSubtotal: true,
            ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    String value, {
    bool isTotal = false,
    bool isSubtotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppConstants.fieldLabelStyle.copyWith(
              fontSize: 13,
              fontWeight:
                  isTotal || isSubtotal ? FontWeight.w600 : FontWeight.normal,
              color:
                  isTotal ? const Color(0xFF1E293B) : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: AppConstants.fieldValueStyle.copyWith(
              fontSize: 13,
              fontWeight:
                  isTotal || isSubtotal ? FontWeight.w600 : FontWeight.normal,
              color:
                  isTotal ? const Color(0xFF1E293B) : const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Go Back to Home Button
          Expanded(
            child: FloatingActionButton.extended(
              onPressed: () => Get.offAll(() => HomeScreen()),
              backgroundColor: Colors.white,
              foregroundColor: TColors.primary,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: TColors.primary),
              ),
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.home_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Back to Home',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Print Button
          Expanded(
            child: FloatingActionButton.extended(
              onPressed: () => _generatePDF(),
              backgroundColor: TColors.primary,
              foregroundColor: Colors.white,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.print_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Print Voucher',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePDF() async {
    final bookingData = widget.bookingResponse['data'];
    final pdf = pw.Document();

    // Add page
    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Ready Flights',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Air Arabia Flight Booking',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Agent: ${bookingController.firstNameController.text} ${bookingController.lastNameController.text}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    pw.Text(
                      bookingController.emailController.text,
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      'Phone: +${bookingController.bookerPhoneCountry.value?.phoneCode ?? '92'} ${bookingController.phoneController.text}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Booking ID: ${bookingData['booking_id']} | PNR: ${bookingData['pnr']}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Add expiry notice to PDF
            if (_expiryDateTime != null) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.red, width: 1),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Icon(
                      const pw.IconData(0xe8b5), // schedule icon
                      color: PdfColors.red,
                      size: 16,
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Text(
                        _expiryMessage,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),
            ],

            // Flight Details
            pw.Text(
              'Flight Details',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            _buildPdfFlightSection(),
            pw.SizedBox(height: 20),

            // Passenger Details
            pw.Text(
              'Passenger Details',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.TableHelper.fromTextArray(
              context: context,
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey200),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headers: ['Sr', 'Name', 'Type', 'Passport#', 'Status'],
              data: [
                ...bookingController.adults.map(
                  (adult) => [
                    '${bookingController.adults.indexOf(adult) + 1}',
                    '${adult.firstNameController.text} ${adult.lastNameController.text}',
                    'Adult',
                    adult.passportCnicController.text,
                    bookingData['status'] ?? 'Hold',
                  ],
                ),
                ...bookingController.children.map(
                  (child) => [
                    '${bookingController.adults.length + bookingController.children.indexOf(child) + 1}',
                    '${child.firstNameController.text} ${child.lastNameController.text}',
                    'Child',
                    child.passportCnicController.text,
                    bookingData['status'] ?? 'Hold',
                  ],
                ),
                ...bookingController.infants.map(
                  (infant) => [
                    '${bookingController.adults.length + bookingController.children.length + bookingController.infants.indexOf(infant) + 1}',
                    '${infant.firstNameController.text} ${infant.lastNameController.text}',
                    'Infant',
                    infant.passportCnicController.text.isNotEmpty ? infant.passportCnicController.text : 'N/A',
                    bookingData['status'] ?? 'Hold',
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Price Breakdown
            pw.Text(
              'Price Breakdown',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            // Adult pricing breakdown
            if (bookingController.adults.isNotEmpty) ...[
              _buildPdfPriceRow(
                'Adult (${bookingController.adults.length}) Base Fare',
                '${widget.currency} ${((widget.totalPrice / (bookingController.adults.length + bookingController.children.length + bookingController.infants.length)) * 0.7 * bookingController.adults.length).toStringAsFixed(2)}',
              ),
              _buildPdfPriceRow(
                'Adult (${bookingController.adults.length}) Taxes',
                '${widget.currency} ${((widget.totalPrice / (bookingController.adults.length + bookingController.children.length + bookingController.infants.length)) * 0.2 * bookingController.adults.length).toStringAsFixed(2)}',
              ),
              _buildPdfPriceRow(
                'Adult (${bookingController.adults.length}) Fees',
                '${widget.currency} ${((widget.totalPrice / (bookingController.adults.length + bookingController.children.length + bookingController.infants.length)) * 0.1 * bookingController.adults.length).toStringAsFixed(2)}',
              ),
            ],
            // Child pricing breakdown
            if (bookingController.children.isNotEmpty) ...[
              _buildPdfPriceRow(
                'Child (${bookingController.children.length}) Base Fare',
                '${widget.currency} ${(((widget.totalPrice * 0.75) / (bookingController.adults.length + bookingController.children.length + bookingController.infants.length)) * 0.7 * bookingController.children.length).toStringAsFixed(2)}',
              ),
              _buildPdfPriceRow(
                'Child (${bookingController.children.length}) Taxes',
                '${widget.currency} ${(((widget.totalPrice * 0.75) / (bookingController.adults.length + bookingController.children.length + bookingController.infants.length)) * 0.2 * bookingController.children.length).toStringAsFixed(2)}',
              ),
              _buildPdfPriceRow(
                'Child (${bookingController.children.length}) Fees',
                '${widget.currency} ${(((widget.totalPrice * 0.75) / (bookingController.adults.length + bookingController.children.length + bookingController.infants.length)) * 0.1 * bookingController.children.length).toStringAsFixed(2)}',
              ),
            ],
            // Infant pricing breakdown
            if (bookingController.infants.isNotEmpty) ...[
              _buildPdfPriceRow(
                'Infant (${bookingController.infants.length}) Base Fare',
                '${widget.currency} ${(((widget.totalPrice * 0.1) / (bookingController.adults.length + bookingController.children.length + bookingController.infants.length)) * 0.7 * bookingController.infants.length).toStringAsFixed(2)}',
              ),
              _buildPdfPriceRow(
                'Infant (${bookingController.infants.length}) Taxes',
                '${widget.currency} ${(((widget.totalPrice * 0.1) / (bookingController.adults.length + bookingController.children.length + bookingController.infants.length)) * 0.2 * bookingController.infants.length).toStringAsFixed(2)}',
              ),
              _buildPdfPriceRow(
                'Infant (${bookingController.infants.length}) Fees',
                '${widget.currency} ${(((widget.totalPrice * 0.1) / (bookingController.adults.length + bookingController.children.length + bookingController.infants.length)) * 0.1 * bookingController.infants.length).toStringAsFixed(2)}',
              ),
            ],
            pw.Divider(),
            _buildPdfPriceRow(
              'Total Amount',
              '${bookingData['currency']} ${bookingData['total_amount']}',
              isTotal: true,
            ),
            pw.SizedBox(height: 20),

            // Important Notes
            pw.Text(
              'Important Notes:',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              '• This booking is currently on HOLD status',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
            pw.Text(
              '• Please complete payment before the deadline to confirm your booking',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
            pw.Text(
              '• Contact our support team for any assistance',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 20),

            // Footer
            pw.Center(
              child: pw.Text(
                'Thank you for booking with Ready Flights!',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  pw.Widget _buildPdfFlightSection() {
    final firstSegment = widget.flight.flightSegments.first;
    final lastSegment = widget.flight.flightSegments.last;
    final departureDateTime = DateTime.parse(firstSegment['departure']['dateTime']);
    final arrivalDateTime = DateTime.parse(lastSegment['arrival']['dateTime']);
    final duration = arrivalDateTime.difference(departureDateTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Air Arabia Flight: ${widget.flight.airlineName}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                widget.selectedPackage.packageName,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '${firstSegment['departure']['airport']} → ${lastSegment['arrival']['airport']}',
            style: pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Departure: ${departureDateTime.day}-${departureDateTime.month}-${departureDateTime.year} ${departureDateTime.hour.toString().padLeft(2, '0')}:${departureDateTime.minute.toString().padLeft(2, '0')}',
              ),
              pw.Text('Duration: ${hours}h ${minutes}m'),
              pw.Text(
                'Arrival: ${arrivalDateTime.day}-${arrivalDateTime.month}-${arrivalDateTime.year} ${arrivalDateTime.hour.toString().padLeft(2, '0')}:${arrivalDateTime.minute.toString().padLeft(2, '0')}',
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Hand Baggage:',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text('7 Kg'),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Checked Baggage:',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text('20 Kg'),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(),
          pw.SizedBox(height: 8),
          
          // Flight Segments
          pw.Text(
            'Flight Segments:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
          ),
          pw.SizedBox(height: 4),
          ...widget.flight.flightSegments.map((segment) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                '${segment['flightNumber']}: ${segment['departure']['airport']} → ${segment['arrival']['airport']} (${_formatTime(segment['departure']['dateTime'])} - ${_formatTime(segment['arrival']['dateTime'])})',
                style: const pw.TextStyle(fontSize: 10),
              ),
            );
          }),
        ],
      ),
    );
  }

  pw.Widget _buildPdfPriceRow(
    String label,
    String value, {
    bool isTotal = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isTotal ? PdfColors.blue800 : PdfColors.black,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isTotal ? PdfColors.blue800 : PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }
}