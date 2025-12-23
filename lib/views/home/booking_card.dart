
import 'package:flutter/material.dart';

import '../../views/flight/form/flight_form.dart';
import '../../views/hotel/hotel/hotel_form.dart';
import '../../utility/colors.dart';
import '../../utility/app_constants.dart';

import 'type_selector/type_selector.dart';
import 'group_tickets/group_tickets_selector.dart';

class BookingCard extends StatefulWidget {
  const BookingCard({super.key});

  @override
  State<BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<BookingCard> {
  String selectedType = 'Flights'; // Default type

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, 40),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppConstants.screenPadding),
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
          boxShadow: AppConstants.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Type Selector
            TypeSelector(
              onTypeChanged: (String type) {
                setState(() {
                  selectedType = type;
                });
              },
            ),
            const SizedBox(height: 12),
            // Show the relevant form based on the selected type
            if (selectedType == 'Flights') FlightBookingScreen(),
            if (selectedType == 'Hotels') HotelForm(),
            if (selectedType == 'Group Tickets') const GroupTicketsSelector(),
          ],
        ),
      ),
    );
  }
}
