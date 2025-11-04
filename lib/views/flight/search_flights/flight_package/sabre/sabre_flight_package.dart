import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../services/api_service_sabre.dart';
import '../../../../../utility/colors.dart';
import '../../../../../widgets/snackbar.dart';
import '../../../../../widgets/travelers_selection_bottom_sheet.dart';

import '../../../form/controllers/flight_date_controller.dart';
import '../../review_flight/sabre_review_flight.dart';
import '../../sabre/sabre_flight_controller.dart';
import '../../sabre/sabre_flight_models.dart';
import '../../search_flight_utils/widgets/sabre_flight_card.dart';
import '../../sabre/sabre_package_modal.dart';

class SabrePackageSelectionDialog extends StatelessWidget {
  final SabreFlight flight;
  final bool isAnyFlightRemaining;
  final isLoading = false.obs;

  SabrePackageSelectionDialog({
    super.key,
    required this.flight,
    required this.isAnyFlightRemaining,
  });

  final flightController = Get.find<SabreFlightController>();
  final flightDateController = Get.find<FlightDateController>();
  final travelersController = Get.find<TravelersController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColors.background,
      appBar: AppBar(
        backgroundColor: TColors.background,
        surfaceTintColor: TColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Select a fare option',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _buildFlightInfo(),
          SizedBox(height: 12),
          Expanded(
            child: _buildPackagesList(),
          ),
        ],
      ),
    );
  }
  Widget _buildFlightInfo() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height*0.7,
          ),
          child: SingleChildScrollView(
            child: FlightCard(
              flight: flight,
              showReturnFlight: false,
              isShowBookButton: false,
            ),
          ),
        );
      },
    );
  }

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

  Widget _buildPackagesList() {
    return ListView.builder(
      scrollDirection: Axis.vertical,
      physics: const BouncingScrollPhysics(),
      primary: false,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: flight.packages.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildHorizontalPackageCard(flight.packages[index], index),
        );
      },
    );
  }

  Widget _buildHorizontalPackageCard(FlightPackageInfo package, int index) {
    print(package.seatsAvailable);
    final Rx<Map<String, dynamic>> marginData = Rx<Map<String, dynamic>>({});
    final RxDouble finalPrice = 0.0.obs;

    // Fetch margin data
    Future<void> fetchMarginData() async {
      try {
        final apiService = Get.find<ApiServiceSabre>();
        final data = await apiService.getMargin(flight.airlineCode, flight.airline);
        marginData.value = data;

        // Calculate final price with margin
        finalPrice.value = apiService.calculatePriceWithMargin(
          package.totalPrice,
          data,
        );
      } catch (e) {
        // If margin fetch fails, use original price
        finalPrice.value = package.totalPrice;
      }
    }
    fetchMarginData();

    // Determine if this is the cheapest option
    final sortedPackages = List<FlightPackageInfo>.from(flight.packages);
    sortedPackages.sort((a, b) => a.totalPrice.compareTo(b.totalPrice));
    final isCheapest = sortedPackages.isNotEmpty && package == sortedPackages.first;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: TColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  package.brandDescription.isNotEmpty
                      ? package.brandDescription
                      : package.cabinName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: TColors.text,
                  ),
                ),
              ),
              
              // Package details
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildCompactPackageDetail(
                      Icons.airline_seat_recline_normal,
                      'Cabin',
                      package.isSoldOut ? 'Not available' : package.cabinName,
                    ),
                    const SizedBox(height: 12),
                    _buildCompactPackageDetail(
                      Icons.luggage,
                      'Baggage',
                      package.isSoldOut
                          ? 'Not available'
                          : package.baggageAllowance.type,
                    ),
                    const SizedBox(height: 12),
                    _buildCompactPackageDetail(
                      Icons.restaurant,
                      'Meal',
                      package.isSoldOut
                          ? 'Not available'
                          : getMealInfo(package.mealCode),
                    ),
                    const SizedBox(height: 12),
                    _buildCompactPackageDetail(
                      Icons.event_seat,
                      'Seats Available',
                      package.isSoldOut
                          ? '0'
                          : package.seatsAvailable.toString(),
                    ),
                    const SizedBox(height: 12),
                    _buildCompactPackageDetail(
                      Icons.currency_exchange,
                      'Refundable',
                      package.isSoldOut
                          ? 'Not applicable'
                          : (package.isNonRefundable
                          ? 'Non-Refundable'
                          : 'Refundable'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              
              // Price button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Obx(() => SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: package.isSoldOut || isLoading.value
                        ? null
                        : () => onSelectPackage(index),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: package.isSoldOut ? Colors.grey : TColors.primary,
                      foregroundColor: TColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading.value
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(TColors.white),
                      ),
                    )
                        : Text(
                      '${package.currency} ${finalPrice.value.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )),
              ),
            ],
          ),
          
          // "Cheapest" text positioned on top border
          if (isCheapest)
            Positioned(
              top: -8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Cheapest',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactPackageDetail(
      IconData icon,
      String title,
      String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: TColors.text.withOpacity(0.6),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: TColors.text.withOpacity(0.7),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: TColors.text,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactDetail(
      IconData icon,
      String title,
      String value,
      Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: iconColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: iconColor, size: 14),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: TColors.text.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: TColors.text,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  Widget _buildPackageDetail(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TColors.secondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: TColors.background, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: TColors.grey),
                ),
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
        ],
      ),
    );
  }

  void onSelectPackage(int selectedPackageIndex) async {
    try {
      isLoading.value = true;
      final apiService = ApiServiceSabre();
      final travelersController = Get.find<TravelersController>();
      final flightController = Get.find<SabreFlightController>();

      // Extract flight segments and organize them based on the flight scenario
      final List<Map<String, dynamic>> originDestinations = [];

      Map<String, dynamic> requestBody;

      if (flight.isNDC) {
        print("offer item id check ");
        print(flight.packages[selectedPackageIndex].offerItemId);
        // Prepare NDC validation request
        requestBody = {
          "offerItemId": [flight.packages[selectedPackageIndex].offerItemId],
          "formOfPayment": [
            {
              "binNumber": "545251",
              "subCode": "FDA",
              "cardType": "MC"
            }
          ],
        };
      } else {
        // Process all flight segments for each leg schedule
        for (var legIndex = 0;
        legIndex < flight.legSchedules.length;
        legIndex++) {
          final legSchedule = flight.legSchedules[legIndex];
          final List<Map<String, dynamic>> flightSegments = [];

          // Process all schedules within this leg
          for (var i = 0; i < legSchedule['schedules'].length; i++) {
            var schedule = legSchedule['schedules'][i];

            // Access the bookingCode from the current segment index
            final bookingCode = (flight.segmentInfo.length > i)
                ? flight.segmentInfo[i].bookingCode
                : '';

            final carrier = schedule['carrier'];
            flightSegments.add({
              "ClassOfService": bookingCode,
              "Number": carrier['marketingFlightNumber'],
              "DepartureDateTime": schedule['departure']['dateTime'],
              "ArrivalDateTime": schedule['arrival']['dateTime'],
              "Type": "A",
              "OriginLocation": {
                "LocationCode": schedule['departure']['airport'],
              },
              "DestinationLocation": {
                "LocationCode": schedule['arrival']['airport'],
              },
              "Airline": {
                "Operating": carrier['operating'] ?? carrier['marketing'],
                "Marketing": carrier['marketing'],
              },
            });
          }

          // Create origin destination information for this leg
          final originDestination = {
            "RPH": (legIndex + 1).toString(),
            "DepartureDateTime": legSchedule['departure']['dateTime'],
            "OriginLocation": {
              "LocationCode": legSchedule['departure']['airport'],
            },
            "DestinationLocation": {
              "LocationCode": legSchedule['arrival']['airport'],
            },
            "TPA_Extensions": {
              "Flight": flightSegments,
              "SegmentType": {"Code": "O"},
            },
          };

          originDestinations.add(originDestination);
        }

        // Create the request body
        requestBody = {
          "OTA_AirLowFareSearchRQ": {
            "Version": "4",
            "TravelPreferences": {
              "LookForAlternatives": false,
              "TPA_Extensions": {
                "VerificationItinCallLogic": {
                  "AlwaysCheckAvailability": true,
                  "Value": "B",
                },
              },
            },
            "TravelerInfoSummary": {
              "SeatsRequested": [
                travelersController.adultCount.value +
                    travelersController.childrenCount.value,
              ],
              "AirTravelerAvail": [
                {
                  "PassengerTypeQuantity": [
                    if (travelersController.adultCount.value > 0)
                      {
                        "Code": "ADT",
                        "Quantity": travelersController.adultCount.value,
                      },
                    if (travelersController.childrenCount.value > 0)
                      {
                        "Code": "CHD",
                        "Quantity": travelersController.childrenCount.value,
                      },
                    if (travelersController.infantCount.value > 0)
                      {
                        "Code": "INF",
                        "Quantity": travelersController.infantCount.value,
                      },
                  ],
                },
              ],
              "PriceRequestInformation": {
                "TPA_Extensions": {
                  "BrandedFareIndicators": {
                    "MultipleBrandedFares": true,
                    "ReturnBrandAncillaries": true,
                  },
                },
              },
            },
            "POS": {
              "Source": [
                {
                  "PseudoCityCode": "6MD8",
                  "RequestorID": {
                    "Type": "1",
                    "ID": "1",
                    "CompanyName": {"Code": "TN"},
                  },
                },
              ],
            },
            "OriginDestinationInformation": originDestinations,
            "TPA_Extensions": {
              "IntelliSellTransaction": {
                "RequestType": {"Name": "50ITINS"},
              },
            },
          },
        };
      }

      // Check flight availability
      final response = await apiService.checkFlightAvailability(
        type: flightController.currentScenario.value.index,
        flightSegments: flight.isNDC
            ? []
            : originDestinations
            .expand((od) => (od['TPA_Extensions']['Flight']
        as List<Map<String, dynamic>>))
            .toList(),
        adult: travelersController.adultCount.value,
        child: travelersController.childrenCount.value,
        infant: travelersController.infantCount.value,
        requestBody: requestBody,
        isNDC: flight.isNDC, // Pass the flag
      );

      print("availability check:");
      print(response);

      // Parse the response
      flightController.parseApiResponse(response, isAvailabilityCheck: true);

      if (response.containsKey('groupedItineraryResponse') ||
          response.containsKey('payloadAttributes')) {
        // Handle response based on NDC or standard
        if (flight.isNDC) {
          final revalidateID = response['id'];
          final responseData = response['response'] as Map<String, dynamic>;
          final offers = responseData['offers'] as List<dynamic>;
          final offerId = offers[0]['id'] as String;

          final firstOfferItem = offers[0]['offerItems'][0] as Map<String, dynamic>;
          final passengers = firstOfferItem['passengers'] as List<dynamic>;
          final firstPassenger = passengers[0] as Map<String, dynamic>;
          final price = firstPassenger['price'] as Map<String, dynamic>;

// Get the offer item ID
          final offerItemID = firstOfferItem['id'] as String;

// Extract total amount
          final totalAmount = price['totalAmount']['amount'] as String;
          final totalCurrency = price['totalAmount']['curCode'] as String;

// Extract base amount - it might be in different locations
          String baseAmount = '0';
          String baseCurrency = totalCurrency;
          if (price.containsKey('baseAmount')) {
            baseAmount = price['baseAmount']['amount'] as String;
            baseCurrency = price['baseAmount']['curCode'] as String;
          } else if (price.containsKey('filingInformation') &&
              price['filingInformation'] != null &&
              price['filingInformation'].containsKey('baseAmount')) {
            baseAmount = price['filingInformation']['baseAmount']['amount'] as String;
            baseCurrency = price['filingInformation']['baseAmount']['curCode'] as String;
          }

// Extract taxes - handle different structures
          String taxesAmount = '0';
          String taxesCurrency = totalCurrency;
          if (price.containsKey('taxes')) {
            final taxes = price['taxes'] as Map<String, dynamic>;
            taxesAmount = taxes['total']['amount'] as String;
            taxesCurrency = taxes['total']['curCode'] as String;
          } else {
            // Calculate taxes from total - base if needed
            try {
              final total = double.parse(totalAmount);
              final base = double.parse(baseAmount);
              taxesAmount = (total - base).toStringAsFixed(2);
            } catch (e) {
              taxesAmount = '0';
            }
          }

// Create pricing information map
          final pricingInformation = {
            'totalAmount': totalAmount,
            'totalCurrency': totalCurrency,
            'baseAmount': baseAmount,
            'baseCurrency': baseCurrency,
            'taxes': taxesAmount,
            'taxesCurrency': taxesCurrency,
            'offerId': offerId,
            'offerItemId': offerItemID
          };
          // Handle NDC response
          Get.to(() => ReviewTripPage(
            isMulti: false,
            flight: flight,
            pricingInformation: pricingInformation,
            isNDC: true,
          ));
        } else {
          // Handle standard response
          final validateBasicCode = flightController
              .availabilityFlights.first.legSchedules.first['fareBasisCode'];
          final basicCode = flight.legSchedules.first['fareBasisCode'];

          if (validateBasicCode == basicCode) {
            Get.to(() => ReviewTripPage(
              isMulti: false,
              flight: flight,
              pricingInformation: flightController
                  .availabilityFlights
                  .first
                  .pricingInforArray[selectedPackageIndex],
              isNDC: false,
            ));
          } else {
            CustomSnackBar(
              message: 'Basic Flight Code Not Matched',
              backgroundColor: TColors.third,
            ).show();
          }
        }
      } else {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      print(e.toString());
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isLoading.value = false;
    }
  }
}