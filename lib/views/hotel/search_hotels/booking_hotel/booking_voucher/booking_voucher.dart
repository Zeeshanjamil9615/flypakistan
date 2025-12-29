import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:ready_flights/views/home/home_screen.dart';
import 'package:ready_flights/views/hotel/search_hotels/booking_hotel/payment_hotel/payment_controller.dart';
import 'package:ready_flights/views/hotel/search_hotels/select_room/controller/select_room_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import '../../../../../utility/colors.dart';
import '../../../hotel/guests/guests_controller.dart';
import '../../../hotel/hotel_date_controller.dart';
import '../../search_hotel_controller.dart';
import '../booking_controller.dart';

class HotelBookingThankYouScreen extends StatelessWidget {
  final SearchHotelController searchHotelController = Get.find<SearchHotelController>();
  final HotelDateController hotelDateController = Get.find<HotelDateController>();
  final GuestsController guestsController = Get.find<GuestsController>();
  final BookingController bookingController = Get.find<BookingController>();
  final SelectRoomController selectRoomController = Get.find<SelectRoomController>();
  final PaymentController paymentController=Get.put(PaymentController());
  final Map<int, dynamic> selectedRooms = {};

  HotelBookingThankYouScreen({super.key});

  @override
  Widget build(BuildContext context) {
   
    for (int i = 0; i < bookingController.roomGuests.length; i++) {
    print('Room $i - Name: ${selectRoomController.getRoomName(i)}, Meal: ${selectRoomController.getRoomMeal(i)}');
  }
    final arguments = Get.arguments;
    if (arguments != null && arguments['selectedRooms'] != null) {
      selectedRooms.addAll(arguments['selectedRooms']);
    }
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
          onPressed: () => Get.off(HomeScreen()),
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
            _buildHotelDetailsCard(),
            const SizedBox(height: 16),
            ..._buildRoomDetailsCards(), // Changed to build multiple room cards
            const SizedBox(height: 16),
            // _buildBookerDetailsCard(),
            const SizedBox(height: 16),
            _buildPrivacyPolicySection(), // New privacy policy section

            const SizedBox(height: 16),
            _buildContactSupportSection(), // New contact support section

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
            'Dear ${bookingController.firstNameController.text} ${bookingController.lastNameController.text},',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: TColors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your booking has been submitted successfully!',
            style: TextStyle(
              fontSize: 16,
              color: TColors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Thanks for choosing readyflight.pk. We have received your hotel booking and it will be confirmed with hotel shortly after confirmation of payment from your side.',
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
                _buildDetailRow('Order Number', bookingController.booking_num.value.toString()),
                const SizedBox(height: 12),
                _buildDetailRow('Booking Status', 'On Request'),
                const SizedBox(height: 12),
                _buildHighlightedTotalRow(), // Updated total row
                const SizedBox(height: 12),
                _buildDetailRow('Payment Status', bookingController.payment_status.value.toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // New highlighted total row widget
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
              'PKR ${selectRoomController.totalPrice.value.toStringAsFixed(0)}',
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

  Widget _buildHotelDetailsCard() {
    final hotelName = searchHotelController.hotelName.value.isNotEmpty
        ? searchHotelController.hotelName.value
        : 'Smana Hotel Al Raffa';

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
                const Icon(Icons.hotel, color: TColors.third),
                const SizedBox(width: 8),
                const Text(
                  'Hotel details',
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildHotelImage(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hotelName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: TColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Al Raffa Road, Dubai, UNITED ARAB EMIRATES',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey.shade300, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Check in',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('E dd MMM yyyy')
                              .format(hotelDateController.checkInDate.value),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: TColors.text,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Check out',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('E dd MMM yyyy')
                              .format(hotelDateController.checkOutDate.value),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: TColors.text,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TColors.background2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: TColors.text, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Total length of stay: ${hotelDateController.nights.value} nights',
                          style: const TextStyle(
                            fontSize: 12,
                            color: TColors.text,
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

  // New method to build multiple room detail cards
  List<Widget> _buildRoomDetailsCards() {
    List<Widget> roomCards = [];
    
    for (int roomIndex = 0; roomIndex < bookingController.roomGuests.length; roomIndex++) {
      roomCards.add(_buildSingleRoomDetailsCard(roomIndex));
      if (roomIndex < bookingController.roomGuests.length - 1) {
        roomCards.add(const SizedBox(height: 16));
      }
    }
    
    return roomCards;
  }

  // Updated room details card with check-in/check-out dates
  Widget _buildSingleRoomDetailsCard(int roomIndex) {
    final room = bookingController.roomGuests[roomIndex];
    final roomNumber = roomIndex + 1;
    
    String roomType = 'STANDARD KING ROOM • 1 KING BED • NON SMOKING';
    String boardBasis = 'Bed and Breakfast';
    
    // Use the passed room data if available
    if (selectedRooms.containsKey(roomIndex)) {
      final roomData = selectedRooms[roomIndex];
      roomType = roomData['roomName'] ?? roomType;
      boardBasis = roomData['meal'] ?? boardBasis;
    } else {
      // Fallback to controller data
      roomType = selectRoomController.getRoomName(roomIndex);
      boardBasis = selectRoomController.getRoomMeal(roomIndex);
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
                const Icon(Icons.bed, color: TColors.secondary),
                const SizedBox(width: 8),
                Text(
                  'Room $roomNumber Details',
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
                _buildDetailRow('Room Type', roomType),
                const SizedBox(height: 12),
                _buildDetailRow('Board Bases', boardBasis),
                const SizedBox(height: 12),
                _buildDetailRow(
                  'Guests', 
                  '${room.adults.length} Adults, ${room.children.length} Children'
                ),
                 const SizedBox(height: 16),
                ..._buildGuestListForRoom(roomIndex),
                const SizedBox(height: 16),

                   
                // Added check-in/check-out dates for each room
                // Added check-in/check-out dates for each room
Container(
  decoration: BoxDecoration(
    color: TColors.white,
    borderRadius: BorderRadius.circular(8),
  ),
  child: Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ✅ Check-in section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Check in',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd MMM yyyy')
                    .format(hotelDateController.checkInDate.value),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: TColors.text,
                ),
              ),
            ],
          ),

          // ✅ Check-out section
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Check out',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd MMM yyyy')
                    .format(hotelDateController.checkOutDate.value),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: TColors.text,
                ),
              ),
            ],
          ),
        ],
      ),
      // const SizedBox(height: 8),
      // Row(
      //   children: [
      //     const Icon(Icons.access_time, color: TColors.text, size: 16),
      //     const SizedBox(width: 8),
      //     Text(
      //       '${hotelDateController.nights.value} nights stay',
      //       style: const TextStyle(
      //         fontSize: 12,
      //         color: TColors.text,
      //       ),
      //     ),
      //   ],
      // ),
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

  List<Widget> _buildGuestListForRoom(int roomIndex) {
    List<Widget> guestWidgets = [];
    final room = bookingController.roomGuests[roomIndex];
    int guestCounter = 1;
    
    // Add adults
    for (int adultIndex = 0; adultIndex < room.adults.length; adultIndex++) {
      final adult = room.adults[adultIndex];
      guestWidgets.add(
        _buildDetailRow(
          'Guest $guestCounter', 
          'Adult ${adult.titleController.text} ${adult.firstNameController.text} ${adult.lastNameController.text}'
        )
      );
      guestCounter++;
      if (adultIndex < room.adults.length - 1 || room.children.isNotEmpty) {
        guestWidgets.add(const SizedBox(height: 8));
      }
    }
    
    // Add children
    for (int childIndex = 0; childIndex < room.children.length; childIndex++) {
      final child = room.children[childIndex];
      // Get child age if available
      String childAge = '';
      if (guestsController.rooms.length > roomIndex &&
          guestsController.rooms[roomIndex].childrenAges.length > childIndex) {
        childAge = ' (Age: ${guestsController.rooms[roomIndex].childrenAges[childIndex]})';
      }
      
      guestWidgets.add(
        _buildDetailRow(
          'Guest $guestCounter', 
          'Child ${child.titleController.text} ${child.firstNameController.text} ${child.lastNameController.text}$childAge'
        )
      );
      guestCounter++;
      if (childIndex < room.children.length - 1) {
        guestWidgets.add(const SizedBox(height: 8));
      }
    }

    return guestWidgets;
  }

  // New Contact Support Section
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
                  'Contact one of our Viator support agents and we will help you with your query.',
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

  Widget _buildBookerDetailsCard() {
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
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Booker Details',
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
                _buildDetailRow('Booker Name', '${bookingController.firstNameController.text} ${bookingController.lastNameController.text}'),
                const SizedBox(height: 12),
                _buildDetailRow('Email address', bookingController.emailController.text),
                const SizedBox(height: 12),
                _buildDetailRow('Phone', bookingController.getFullPhoneNumber()),
                const SizedBox(height: 12),
                _buildDetailRow('Street Address', bookingController.addressController.text),
                const SizedBox(height: 12),
                _buildDetailRow('Town/City', bookingController.cityController.text),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _generatePDF(Get.context!),
              icon: const Icon(Icons.download, color: Colors.white),
              label: const Text(
                'Download PDF',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: TColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
        ],
      ),
    );
  }

  // New Privacy Policy Section
 // New Privacy Policy Section with improved design
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
        // Header Section
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
        
        // Content Section
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
              
              // Privacy Policy Button
              _buildPolicyButton(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: 'How we collect and use your data',
                onTap: () => _launchPrivacyPolicy(),
                color: TColors.primary,
              ),
              
              const SizedBox(height: 12),
              
              // Terms of Service Button (optional - you can add this method)
              _buildPolicyButton(
                icon: Icons.article_outlined,
                title: 'Terms of Service',
                subtitle: 'Rules and guidelines for using our service',
                onTap: () => _launchTermsOfService(),
                color: TColors.secondary,
              ),
              
              const SizedBox(height: 12),
              
              // Cancellation Policy Button (optional - you can add this method)
              _buildPolicyButton(
                icon: Icons.cancel_outlined,
                title: 'Cancellation Policy',
                subtitle: 'Booking modification and cancellation terms',
                onTap: () => _launchCancellationPolicy(),
                color: TColors.third,
              ),
              
              const SizedBox(height: 16),
              
              // Footer note
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

// Helper method for policy buttons
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

  Widget _buildHotelImage() {
    String imageUrl = searchHotelController.image.value;
    
    if (imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('http')) {
        return CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: TColors.background2,
            child: const Center(
              child: CircularProgressIndicator(
                color: TColors.primary,
                strokeWidth: 2,
              ),
            ),
          ),
          errorWidget: (context, url, error) => _buildPlaceholderImage(),
        );
      } else if (imageUrl.startsWith('/')) {
        String fullImageUrl = 'https://static.giinfotech.ae/medianew$imageUrl';
        return CachedNetworkImage(
          imageUrl: fullImageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: TColors.background2,
            child: const Center(
              child: CircularProgressIndicator(
                color: TColors.primary,
                strokeWidth: 2,
              ),
            ),
          ),
          errorWidget: (context, url, error) => _buildPlaceholderImage(),
        );
      } else {
        return Image.asset(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
        );
      }
    } else {
      return _buildPlaceholderImage();
    }
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            TColors.primary.withOpacity(0.8),
            TColors.third.withOpacity(0.6),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.hotel_rounded,
          size: 32,
          color: TColors.white.withOpacity(0.8),
        ),
      ),
    );
  }

  // Privacy Policy and Terms launch methods
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
        name: 'Hotel_Booking_Confirmation_${bookingController.booking_num.value}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF generation failed: $e')),
      );
    }
  }

  Future<Uint8List> _createPDF() async {
    final pdf = pw.Document();
    
    // Load logo if available
    pw.MemoryImage? logoImage;
    try {
      final ByteData data = await rootBundle.load('assets/images/logo.png');
      final Uint8List bytes = data.buffer.asUint8List();
      logoImage = pw.MemoryImage(bytes);
    } catch (e) {
      print('Logo not found: $e');
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            // Header with logo
            pw.Container(
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
                      logoImage != null
                          ? pw.Image(logoImage, height: 40)
                          : pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.blue900,
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Text(
                                'ReadyFlight.pk',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 16,
                                ),
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
                    'Your booking has been submitted successfully!',
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Booking Details
            _buildPDFSection(
              'Booking Details',
              [
                ['Order Number', bookingController.booking_num.value.toString()],
                ['Booking Status', 'On Request'],
                ['Total Amount', 'PKR ${selectRoomController.totalPrice.value.toStringAsFixed(0)}'],
                ['Payment Status', bookingController.payment_status.value.toString()],
              ],
            ),
            
            pw.SizedBox(height: 20),
            
            // Hotel Details
            _buildPDFSection(
              'Hotel Details',
              [
                ['Hotel Name', searchHotelController.hotelName.value.isNotEmpty 
                    ? searchHotelController.hotelName.value 
                    : 'Smana Hotel Al Raffa'],
                ['Address', 'Al Raffa Road, Dubai, UNITED ARAB EMIRATES'],
                ['Check-in', DateFormat('E dd MMM yyyy').format(hotelDateController.checkInDate.value)],
                ['Check-out', DateFormat('E dd MMM yyyy').format(hotelDateController.checkOutDate.value)],
                ['Nights', '${hotelDateController.nights.value}'],
              ],
            ),
            
            pw.SizedBox(height: 20),
            
            // Room Details - Updated to show all rooms
            ..._buildPDFRoomSections(),
            
            pw.SizedBox(height: 20),
            
            // Booker Details
            _buildPDFSection(
              'Booker Details',
              [
                ['Name', '${bookingController.firstNameController.text} ${bookingController.lastNameController.text}'],
                ['Email', bookingController.emailController.text],
                ['Phone', bookingController.getFullPhoneNumber()],
                ['Address', bookingController.addressController.text],
                ['City', bookingController.cityController.text],
              ],
            ),
            
            pw.SizedBox(height: 20),
            
            // Contact Info
            pw.Container(
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
            ),
          ];
        },
      ),
    );

    return pdf.save();
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

  // New method to build PDF sections for all rooms
  List<pw.Widget> _buildPDFRoomSections() {
    List<pw.Widget> roomSections = [];
    
    for (int roomIndex = 0; roomIndex < bookingController.roomGuests.length; roomIndex++) {
      final room = bookingController.roomGuests[roomIndex];
      final roomNumber = roomIndex + 1;
      
      // Get room type and board basis from SelectRoomController
      String roomType = selectRoomController.getRoomName(roomIndex);
      String boardBasis = selectRoomController.getRoomMeal(roomIndex);
      
      // Fallback to default values if not available
      if (roomType.isEmpty) {
        roomType = 'STANDARD KING ROOM • 1 KING BED • NON SMOKING';
      }
      if (boardBasis.isEmpty) {
        boardBasis = 'Bed and Breakfast';
      }
      
      // Build guest list for PDF
      List<List<String>> roomData = [
        ['Room Type', roomType],
        ['Board Bases', boardBasis],
        ['Guests', '${room.adults.length} Adults, ${room.children.length} Children'],
        ['Check-in', DateFormat('E dd MMM yyyy').format(hotelDateController.checkInDate.value)],
        ['Check-out', DateFormat('E dd MMM yyyy').format(hotelDateController.checkOutDate.value)],
        ['Stay Duration', '${hotelDateController.nights.value} nights'],
      ];
      
      // Add guest details
      int guestCounter = 1;
      for (final adult in room.adults) {
        roomData.add(['Guest $guestCounter', 'Adult ${adult.titleController.text} ${adult.firstNameController.text} ${adult.lastNameController.text}']);
        guestCounter++;
      }
      
      for (int childIndex = 0; childIndex < room.children.length; childIndex++) {
        final child = room.children[childIndex];
        String childAge = '';
        if (guestsController.rooms.length > roomIndex &&
            guestsController.rooms[roomIndex].childrenAges.length > childIndex) {
          childAge = ' (Age: ${guestsController.rooms[roomIndex].childrenAges[childIndex]})';
        }
        roomData.add(['Guest $guestCounter', 'Child ${child.titleController.text} ${child.firstNameController.text} ${child.lastNameController.text}$childAge']);
        guestCounter++;
      }
      
      roomSections.add(_buildPDFSection('Room $roomNumber Details', roomData));
      
      if (roomIndex < bookingController.roomGuests.length - 1) {
        roomSections.add(pw.SizedBox(height: 20));
      }
    }
    
    return roomSections;
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    await launchUrl(launchUri);
  }
}