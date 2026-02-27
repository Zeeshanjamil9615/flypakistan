import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:ready_flights/utility/colors.dart';
import 'package:ready_flights/views/hotel/search_hotels/select_room/controller/select_room_controller.dart';

import '../../../hotel/guests/guests_controller.dart';
import '../../../hotel/hotel_date_controller.dart';
import '../../search_hotel_controller.dart';

class ImportantBookingDetailsCard extends StatefulWidget {
  const ImportantBookingDetailsCard({super.key});

  @override
  State<ImportantBookingDetailsCard> createState() =>
      _ImportantBookingDetailsCardState();
}

class _ImportantBookingDetailsCardState
    extends State<ImportantBookingDetailsCard> {
  Timer? _timer;
  int _timeLeft = 15 * 60; // 15 minutes in seconds

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _timer?.cancel();
          Get.back();
        }
      });
    });
  }

  String get formattedTime {
    int minutes = _timeLeft ~/ 60;
    int seconds = _timeLeft % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String formatDate(DateTime date) {
    return DateFormat('EEE, dd MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final searchHomeController = Get.find<SearchHotelController>();
    final hotelDateController = Get.find<HotelDateController>();
    final guestsController = Get.find<GuestsController>();
    final selectRoomController = Get.find<SelectRoomController>();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      color: TColors.background,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Booking Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: TColors.primary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: TColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: TColors.primary, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer, size: 18, color: TColors.iconclr),
                      const SizedBox(width: 4),
                      Text(
                        formattedTime,
                        style: const TextStyle(
                          color: TColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.hotel,
              'Hotel',
              searchHomeController.hotelName.value,
              '',
            ),
            const Divider(height: 24),
            
            // Selected Rooms Section
            Obx(() => _buildSelectedRoomsSection(selectRoomController)),
            const Divider(height: 24),
            
            _buildInfoRow(
              Icons.calendar_today,
              'Check-in',
              formatDate(hotelDateController.checkInDate.value),
              '',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.calendar_today,
              'Check-out',
              formatDate(hotelDateController.checkOutDate.value),
              '',
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.people_outline,
              'Guests',
              '${guestsController.totalAdults.toString()} Adults, ${guestsController.totalChildren} Child',
              '${guestsController.roomCount.toString()} Room',
            ),
            const Divider(height: 24),
            Obx(() => _buildPriceSection(selectRoomController.totalPrice.value.toStringAsFixed(0))),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedRoomsSection(SelectRoomController selectRoomController) {
    if (selectRoomController.roomNames.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: TColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.meeting_room, color: TColors.iconclr, size: 20),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                      'Selected Rooms',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
            ),
            ],
        ),
         Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             
             const SizedBox(height: 8),
             ...selectRoomController.roomNames.entries.map((entry) {
               int roomIndex = entry.key;
               String roomName = entry.value;
               
               return Container(
                 margin: const EdgeInsets.only(bottom: 8),
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: Colors.grey.shade50,
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: Colors.grey.shade200),
                 ),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Expanded(
                           child: Text(
                             'Room ${roomIndex + 1}: $roomName',
                             style: const TextStyle(
                               fontWeight: FontWeight.bold,
                               fontSize: 15,
                             ),
                           ),
                         ),
                        
                       ],
                     ),
                       ],
                 ),
               );
             }).toList(),
           ],
         ),
         
      ],
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String title,
    String primaryInfo,
    String secondaryInfo,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: TColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: TColors.iconclr, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                primaryInfo,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (secondaryInfo.isNotEmpty)
                Text(
                  secondaryInfo,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSection(String price) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text("Your time to proceed booking will expire in 15 minutes."),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: _buildBadge("Refundable"),
          ),
          const Divider(height: 16),
          _buildPriceRow('Total Price', 'PKR $price', isTotal: true),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? TColors.primary : Colors.grey[800],
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? TColors.primary : Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String text) {
    final isRefundable = text.toLowerCase() == 'refundable';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isRefundable ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isRefundable ? Colors.green.shade700 : Colors.red.shade700,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}