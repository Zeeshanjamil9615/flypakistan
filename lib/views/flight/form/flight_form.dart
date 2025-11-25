// flight_booking_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../utility/colors.dart';
import '../../../utility/app_constants.dart';
import '../../../widgets/city_selection_bottom_sheet.dart';
import '../../../widgets/custom_date_picker_sheet.dart';
import '../../../widgets/passenger_class_selection_sheet.dart';
import 'flight_booking_controller.dart';

class FlightBookingScreen extends StatelessWidget {
  FlightBookingScreen({super.key});

  final FlightBookingController controller = Get.put(FlightBookingController());

  String _getCityDisplayName(String cityValue) {
    // Try to get airport data to show city name with code
    final airportData = _getAirportByCode(cityValue);
    if (airportData != null) {
      return '${airportData.cityName} (${airportData.code})';
    }
    
    // Fallback: if no airport data found, try to get from controller's stored names
    if (controller.fromCity.value == cityValue && controller.fromCityName.value.isNotEmpty) {
      return '${controller.fromCityName.value} ($cityValue)';
    }
    if (controller.toCity.value == cityValue && controller.toCityName.value.isNotEmpty) {
      return '${controller.toCityName.value} ($cityValue)';
    }
    
    // Check multi-city pairs
    for (var pair in controller.cityPairs) {
      if (pair.fromCity.value == cityValue && pair.fromCityName.value.isNotEmpty) {
        return '${pair.fromCityName.value} ($cityValue)';
      }
      if (pair.toCity.value == cityValue && pair.toCityName.value.isNotEmpty) {
        return '${pair.toCityName.value} ($cityValue)';
      }
    }
    
    // Final fallback: return just the code
    return cityValue;
  }

  AirportData? _getAirportByCode(String code) {
    try {
      final airportController = Get.find<AirportController>();
      for (var airport in airportController.airports) {
        if (airport.code == code) {
          return airport;
        }
      }
      return null;
    } catch (e) {
      // AirportController not found or error accessing airports
      return null;
    }
  }

  String _formatDate(DateTime date) {
    // Format date as "Jan 15, 2024" or similar
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getPassengerDisplayText() {
    final adults = controller.adultCount.value;
    final children = controller.childrenCount.value;
    final infants = controller.infantCount.value;
    final total = adults + children + infants;

    String passengerText = '$total Passenger';
    if (total > 1) passengerText += 's';

    return '$passengerText, ${controller.travelClass.value}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: Obx(() {
          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 2),
                _buildTripTypeSelector(),
                const SizedBox(height: 8),

                // Different content based on trip type
                if (controller.tripType.value != TripType.multiCity)
                  Column(
                    children: [
                      _buildCitySelector(context),
                      const SizedBox(height: 8),
                      _buildDateSelectors(context),
                    ],
                  )
                else
                  _buildMultiCitySelector(context),

                const SizedBox(height: 8),
                _buildTravellerAndClassSelectors(context),
                const SizedBox(height: 8),
                _buildSearchButton(),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTripTypeSelector() {
    return Obx(
          () => Row(
        children: [
          GestureDetector(
            onTap: () => controller.setTripType(TripType.oneWay),
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              decoration: BoxDecoration(
                color: controller.tripType.value == TripType.oneWay
                    ? TColors.primary.withOpacity(0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: controller.tripType.value == TripType.oneWay
                      ? TColors.primary.withOpacity(0.3)
                      : AppConstants.fieldBorderColor,
                  width: 1,
                ),
                boxShadow: controller.tripType.value == TripType.oneWay
                    ? AppConstants.cardShadow
                    : null,
              ),
              child: Text(
                'One Way',
                style: TextStyle(
                  color: controller.tripType.value == TripType.oneWay
                      ? TColors.primary
                      :TColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => controller.setTripType(TripType.roundTrip),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              decoration: BoxDecoration(
                color: controller.tripType.value == TripType.roundTrip
                    ? TColors.primary.withOpacity(0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: controller.tripType.value == TripType.roundTrip
                      ? TColors.primary.withOpacity(0.3)
                      : AppConstants.fieldBorderColor,
                  width: 1,
                ),
                boxShadow: controller.tripType.value == TripType.roundTrip
                    ? AppConstants.cardShadow
                    : null,
              ),
              child: Text(
                'Return',
                style: TextStyle(
                  color: controller.tripType.value == TripType.roundTrip
                      ? TColors.primary
                      : TColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => controller.setTripType(TripType.multiCity),
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              decoration: BoxDecoration(
                color: controller.tripType.value == TripType.multiCity
                    ? TColors.primary.withOpacity(0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: controller.tripType.value == TripType.multiCity
                      ? TColors.primary.withOpacity(0.3)
                      : AppConstants.fieldBorderColor,
                  width: 1,
                ),
                boxShadow: controller.tripType.value == TripType.multiCity
                    ? AppConstants.cardShadow
                    : null,
              ),
              child: Text(
                'Multi City',
                style: TextStyle(
                  color: controller.tripType.value == TripType.multiCity
                      ? TColors.primary
                      : TColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCitySelector(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // FROM field
            GestureDetector(
              onTap: () => controller.showCitySelectionBottomSheet(
                context,
                FieldType.departure,
              ),
              child: Container(
                height: AppConstants.fieldHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  border: Border.all(color: AppConstants.fieldBorderColor),
                  boxShadow: AppConstants.cardShadow,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Obx(
                        () => controller.fromCity.value.isEmpty
                            ? Row(
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    color: AppConstants.tabInactiveColor,
                                    size: AppConstants.smallIconSize,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Flying From (City or Airport)',
                                    style: AppConstants.fieldLabelStyle,
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    color: TColors.primary,
                                    size: AppConstants.smallIconSize,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _getCityDisplayName(controller.fromCity.value),
                                      style: AppConstants.fieldValueStyle,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // TO field
            GestureDetector(
              onTap: () => controller.showCitySelectionBottomSheet(
                context,
                FieldType.destination,
              ),
              child: Container(
                height: AppConstants.fieldHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  border: Border.all(color: AppConstants.fieldBorderColor),
                  boxShadow: AppConstants.cardShadow,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Obx(
                        () => controller.toCity.value.isEmpty
                            ? Row(
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    color: AppConstants.tabInactiveColor,
                                    size: AppConstants.smallIconSize,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Flying To (City or Airport)',
                                    style: AppConstants.fieldLabelStyle,
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    color: TColors.primary,
                                    size: AppConstants.smallIconSize,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _getCityDisplayName(controller.toCity.value),
                                      style: AppConstants.fieldValueStyle,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // Swap button positioned to overlap both fields
        Positioned(
          left: 150,
          right: 0,
          top: AppConstants.fieldHeight - (AppConstants.swapperIconSize / 2),
          child: Center(
            child: Container(
              width: AppConstants.swapperIconSize,
              height: AppConstants.swapperIconSize,
              decoration: BoxDecoration(
                color: AppConstants.swapperIconColor,
                shape: BoxShape.circle,
                boxShadow: AppConstants.swapperShadow,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.swap_vert,
                  color: TColors.grey,
                  size: 32,
                ),
                onPressed: () => controller.swapCities(),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiCitySelector(BuildContext context) {
    return Column(
      children: [
        ...List.generate(controller.cityPairs.length, (index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (index > 0) const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                child: Text(
                  'Flight ${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              _buildMultiCityPair(index, context),
            ],
          );
        }),
        const SizedBox(height: 16),
        _buildAddRemoveButtons(),
      ],
    );
  }

  Widget _buildMultiCityPair(int index, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(color: AppConstants.fieldBorderColor),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Column(
        children: [
          // FROM field with arrow in one row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  // Move GestureDetector to wrap the entire clickable area
                  onTap:
                      () => controller.showCitySelectionBottomSheet(
                    context,
                    FieldType.departure,
                    multiCityIndex: index,
                  ),
                  child: Container(
                    height: AppConstants.fieldHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Obx(
                          () => controller.cityPairs[index].fromCity.value.isEmpty
                              ? Row(
                                  children: [
                                    Icon(
                                      Icons.flight_takeoff,
                                      color: AppConstants.tabInactiveColor,
                                      size: AppConstants.smallIconSize,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Flying From (City or Airport)',
                                      style: AppConstants.fieldLabelStyle,
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Icon(
                                      Icons.flight_takeoff,
                                      color: TColors.primary,
                                      size: AppConstants.smallIconSize,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _getCityDisplayName(controller.cityPairs[index].fromCity.value),
                                        style: AppConstants.fieldValueStyle,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Swap button
              Container(
                margin: const EdgeInsets.only(right: 16),
                width: AppConstants.swapperIconSize,
                height: AppConstants.swapperIconSize,
                decoration: BoxDecoration(
                  color: AppConstants.swapperIconColor,
                  shape: BoxShape.circle,
                  boxShadow: AppConstants.swapperShadow,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.swap_vert,
                    color: TColors.grey,
                    size: 32,
                  ),
                  onPressed: () => controller.swapCitiesForPair(index),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),

          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.grey.shade200,
          ),

          // TO field - GestureDetector already wraps the entire Container properly
          GestureDetector(
            onTap:
                () => controller.showCitySelectionBottomSheet(
              context,
              FieldType.destination,
              multiCityIndex: index,
            ),
            child: Container(
              height: AppConstants.fieldHeight,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Obx(
                          () => controller.cityPairs[index].toCity.value.isEmpty
                              ? Row(
                                  children: [
                                    Icon(
                                      Icons.flight_land,
                                      color: AppConstants.tabInactiveColor,
                                      size: AppConstants.smallIconSize,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Flying To (City or Airport)',
                                      style: AppConstants.fieldLabelStyle,
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Icon(
                                      Icons.flight_land,
                                      color: TColors.primary,
                                      size: AppConstants.smallIconSize,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _getCityDisplayName(controller.cityPairs[index].toCity.value),
                                        style: AppConstants.fieldValueStyle,
                                        overflow: TextOverflow.ellipsis,
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
            ),
          ),

          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.grey.shade200,
          ),

          // Date field - Simple date picker like one-way
          GestureDetector(
            onTap: () async {
              final result = await showCustomDatePicker(
                context: context,
                selectedDate: controller.cityPairs[index].departureDateTime.value,
                initialDate: controller.cityPairs[index].departureDateTime.value,
                title: 'Select Date',
                label: 'Depart on',
              );
              if (result != null) {
                controller.updateMultiCityFlightDate(index, result);
              }
            },
            child: Container(
              height: AppConstants.fieldHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                border: Border.all(color: AppConstants.fieldBorderColor),
                boxShadow: AppConstants.cardShadow,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: TColors.primary,
                      size: AppConstants.smallIconSize,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatDate(controller.cityPairs[index].departureDateTime.value),
                        style: AppConstants.fieldValueStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddRemoveButtons() {
    return Obx(
          () => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (controller.cityPairs.length < 4)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                onPressed: () => controller.addCityPair(),
                icon: Icon(Icons.add, color: TColors.primary, size: 18),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: TColors.primary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                label: Text(
                  'Add City',
                  style: TextStyle(
                    color: TColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          if (controller.cityPairs.length > 2)
            OutlinedButton.icon(
              onPressed: () => controller.removeCityPair(),
              icon: Icon(Icons.remove, color: Colors.grey.shade600, size: 18),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade400),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              label: Text(
                'Remove',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Updated Date Selectors - Separate fields for round trip, single field for one way
  Widget _buildDateSelectors(BuildContext context) {
    return Obx(() {
      if (controller.tripType.value == TripType.roundTrip) {
        // Round Trip - Two separate date fields in one row
        return Row(
          children: [
            // Outbound date field
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final result = await showCustomDatePicker(
                    context: context,
                    selectedDate: controller.departureDateTimeValue.value,
                    initialDate: controller.departureDateTimeValue.value,
                    title: 'Select Departure Date',
                    label: 'Depart on',
                  );
                  if (result != null) {
                    controller.updateDepartureDate(result);
                  }
                },
                child: Container(
                  height: AppConstants.fieldHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    border: Border.all(color: AppConstants.fieldBorderColor),
                    boxShadow: AppConstants.cardShadow,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: TColors.primary,
                          size: AppConstants.smallIconSize,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatDate(controller.departureDateTimeValue.value),
                            style: AppConstants.fieldValueStyle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Return date field
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final result = await showCustomDatePicker(
                    context: context,
                    selectedDate: controller.returnDateTimeValue.value,
                    initialDate: controller.returnDateTimeValue.value,
                    title: 'Select Return Date',
                    label: 'Returning',
                  );
                  if (result != null) {
                    controller.updateReturnDate(result);
                  }
                },
                child: Container(
                  height: AppConstants.fieldHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    border: Border.all(color: AppConstants.fieldBorderColor),
                    boxShadow: AppConstants.cardShadow,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: TColors.primary,
                          size: AppConstants.smallIconSize,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatDate(controller.returnDateTimeValue.value),
                            style: AppConstants.fieldValueStyle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        // One Way - Show selected date
        return GestureDetector(
          onTap: () async {
            final result = await showCustomDatePicker(
              context: context,
              selectedDate: controller.departureDateTimeValue.value,
              initialDate: controller.departureDateTimeValue.value,
              title: 'Select Date',
              label: 'Depart on',
            );
            if (result != null) {
              controller.updateDepartureDate(result);
            }
          },
          child: Container(
            height: AppConstants.fieldHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(color: AppConstants.fieldBorderColor),
              boxShadow: AppConstants.cardShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: TColors.primary,
                    size: AppConstants.smallIconSize,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatDate(controller.departureDateTimeValue.value),
                      style: AppConstants.fieldValueStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    });
  }

  Widget _buildTravellerAndClassSelectors(BuildContext context) {
    return Obx(() => GestureDetector(
      onTap: () async {
        final result = await showPassengerClassSelection(
          context: context,
          adults: controller.adultCount.value,
          children: controller.childrenCount.value,
          infants: controller.infantCount.value,
          travelClass: controller.travelClass.value,
        );
        if (result != null) {
          controller.updateTravellerCounts(
            result['adults'],
            result['children'],
            result['infants'],
          );
          controller.travelClass.value = result['travelClass'];
        }
      },
      child: Container(
        height: AppConstants.fieldHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(color: AppConstants.fieldBorderColor),
          boxShadow: AppConstants.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.person,
                color: TColors.primary,
                size: AppConstants.smallIconSize,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getPassengerDisplayText(),
                  style: AppConstants.fieldValueStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Icon(
              //   Icons.keyboard_arrow_down,
              //   color: AppConstants.tabInactiveColor,
              //   size: 16,
              // ),
            ],
          ),
        ),
      ),
    ));
  }


  Widget _buildSearchButton() {
    return Obx(
          () => Container(
        width: double.infinity,
        height: AppConstants.buttonHeight + 8, // Add extra height for better tap area
        padding: const EdgeInsets.symmetric(vertical: 4), // Add padding for larger tap area
        child: GestureDetector(
          onTap: _canSearch() && !controller.isSearching.value
              ? () => _handleSearchTap()
              : null,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _canSearch() && !controller.isSearching.value
                  ? () => _handleSearchTap()
                  : null,
              borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
              splashColor: _canSearch() && !controller.isSearching.value
                  ? Colors.white.withOpacity(0.2)
                  : Colors.transparent,
              highlightColor: _canSearch() && !controller.isSearching.value
                  ? Colors.white.withOpacity(0.1)
                  : Colors.transparent,
              child: Container(
                height: AppConstants.buttonHeight,
                decoration: BoxDecoration(
                  color: _canSearch() && !controller.isSearching.value
                      ? TColors.primary
                      : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
                  boxShadow: _canSearch() && !controller.isSearching.value
                      ? [
                          BoxShadow(
                            color: TColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: controller.isSearching.value
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search,
                        color: _canSearch() && !controller.isSearching.value
                            ? Colors.white
                            : Colors.grey.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getSearchButtonText(),
                        style: AppConstants.buttonTextStyle.copyWith(
                          color: _canSearch() && !controller.isSearching.value
                              ? Colors.white
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _canSearch() {
    if (controller.tripType.value == TripType.multiCity) {
      // For multi-city, check if all city pairs have valid data
      if (controller.cityPairs.isEmpty) return false;

      for (var pair in controller.cityPairs) {
        if (pair.fromCity.value.isEmpty ||
            pair.toCity.value.isEmpty ||
            pair.fromCity.value == pair.toCity.value) {
          return false;
        }
      }
      return true;
    } else {
      // For one-way and round-trip, check basic fields
      return controller.fromCity.value.isNotEmpty &&
             controller.toCity.value.isNotEmpty &&
             controller.fromCity.value != controller.toCity.value;
    }
  }

  String _getSearchButtonText() {
    if (!_canSearch()) {
      if (controller.tripType.value == TripType.multiCity) {
        return 'SELECT CITIES & DATES';
      } else {
        return 'SELECT DEPARTURE & DESTINATION';
      }
    }
    return 'SEARCH FLIGHTS';
  }

  void _handleSearchTap() async {
    debugPrint('🔍 Search button tapped!');

    // Add haptic feedback for better UX
    try {
      HapticFeedback.lightImpact();
      debugPrint('✅ Haptic feedback triggered');
    } catch (e) {
      debugPrint('❌ Haptic feedback failed: $e');
    }

    // Prevent multiple rapid taps
    if (controller.isSearching.value) {
      debugPrint('⚠️ Search already in progress, ignoring tap');
      return;
    }

    // Add a small delay to prevent accidental double-taps
    await Future.delayed(const Duration(milliseconds: 50));

    // Check again after delay to ensure no duplicate calls
    if (controller.isSearching.value) {
      debugPrint('⚠️ Search started during delay, ignoring tap');
      return;
    }

    debugPrint('🚀 Starting search from button tap');
    await controller.searchFlights();
  }
}