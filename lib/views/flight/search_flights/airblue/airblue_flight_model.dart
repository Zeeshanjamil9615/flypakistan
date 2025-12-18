// models/airblue_flight_model.dart

// ignore_for_file: empty_catches

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../sabre/sabre_flight_models.dart';
import 'airblue_pnr_pricing.dart';
import '../../../../widgets/city_selection_bottom_sheet.dart';

class AirBlueFlight {
  final String id;
  final double price; // Selling price (display price) - with margin applied
  final double buyingPrice; // Buying price (without margin) - for PNR creation
  final double sellingPrice; // Selling price (with margin) - same as price for backward compatibility
  final double basePrice;
  final double taxAmount;
  final double feeAmount;
  final String currency;
  final bool isRefundable;
  final BaggageAllowance baggageAllowance;
  final List<Map<String, dynamic>> legSchedules;
  final List<Map<String, dynamic>> stopSchedules;
  final List<FlightSegmentInfo> segmentInfo;
  final String airlineCode;
  final String airlineName;
  final String airlineImg;
  final String rph; // Added RPH field
  final String rphFareSegment; // Added RPH field
  final List<AirBlueFareOption>? fareOptions;
  final Map<String, dynamic> rawData;// Added for storing different fare options
  final List<AirBluePNRPricing>? pnrPricing;
  final List<Map<String, dynamic>> changeFeeDetails;
  final List<Map<String, dynamic>> refundFeeDetails;

  AirBlueFlight({
    required this.id,
    required this.price, // Selling price (display)
    required this.buyingPrice, // Buying price (for PNR)
    required this.sellingPrice, // Selling price (with margin)
    required this.basePrice,
    required this.taxAmount,
    required this.feeAmount,
    required this.currency,
    required this.isRefundable,
    required this.baggageAllowance,
    required this.legSchedules,
    required this.stopSchedules,
    required this.segmentInfo,
    required this.airlineCode,
    required this.airlineName,
    required this.airlineImg,
    required this.rph, // Required RPH parameter
    required this.rphFareSegment, // Required RPH parameter
    required this.changeFeeDetails,
    required this.refundFeeDetails,
    this.fareOptions,
    required this.rawData,
    this.pnrPricing,
  });

  factory AirBlueFlight.fromJson(
    Map<String, dynamic> json,
    Map<String, AirlineInfo> airlineMap, {
    double? sellingPrice, // Optional selling price with margin applied
  }) {
    try {
      // Extract flight segment data
      // Handle case where OriginDestinationOption might be a List or Map
      final airItinerary = json['AirItinerary'] ?? {};
      final originDestOptions = airItinerary['OriginDestinationOptions'] ?? {};
      dynamic originDestOptionRaw = originDestOptions['OriginDestinationOption'];
      
      // Normalize to Map - if it's a List, use first element
      Map<String, dynamic> originDestOption;
      if (originDestOptionRaw == null) {
        originDestOption = {};
      } else if (originDestOptionRaw is List && originDestOptionRaw.isNotEmpty) {
        originDestOption = originDestOptionRaw[0] is Map ? Map<String, dynamic>.from(originDestOptionRaw[0]) : {};
      } else if (originDestOptionRaw is Map) {
        originDestOption = Map<String, dynamic>.from(originDestOptionRaw);
      } else {
        originDestOption = {};
      }
      
      final flightSegment = originDestOption['FlightSegment'] ?? {};
      final rph = originDestOption['RPH']?.toString() ?? 'n/a'; // Default value if RPH is not found
      final rphFareSegment = flightSegment['RPH']?.toString() ?? 'n/a'; // Default value if RPH is not found

      // Extract airline info
      final marketingAirline = flightSegment['MarketingAirline'] ?? {};
      final airlineCode = marketingAirline['Code'] ?? 'PA';

      // Get airline info from the map
      final airlineInfo = airlineMap[airlineCode] ??
          AirlineInfo('Air Blue', 'https://images.kiwi.com/airlines/64/PA.png');

      // Extract pricing info
      final pricingInfo = json['AirItineraryPricingInfo']!;
      final totalFare = pricingInfo['ItinTotalFare']['TotalFare'];
      final basePrice = pricingInfo['ItinTotalFare']['BaseFare'];
      final taxAmount = pricingInfo['ItinTotalFare']['Taxes'];
      final feeAmount = pricingInfo['ItinTotalFare']['Fees'];

      // Get buying price (base price from API)
      final buyingPrice = double.tryParse(totalFare['Amount']?.toString() ?? '0') ?? 0;

      // Use provided selling price or default to buying price
      final finalSellingPrice = sellingPrice ?? buyingPrice;

      // Generate a unique ID
      final flightId = '${flightSegment['FlightNumber'] ?? 'UNKNOWN'}-${DateTime.now().millisecondsSinceEpoch}';

      // Get baggage allowance
      final baggageInfo = _getBaggageAllowance(pricingInfo);

      // Create flight segments
      final segmentInfo = _createSegmentInfo(json);


      // Extract detailed fee information
      final feeDetails = _extractFeeDetails(json);


      return AirBlueFlight(
        id: flightId,
        price: finalSellingPrice, // Display selling price
        buyingPrice: buyingPrice, // Store buying price for PNR
        sellingPrice: finalSellingPrice, // Store selling price
        basePrice: double.tryParse(basePrice['Amount']?.toString() ?? '0') ?? 0,
        taxAmount: double.tryParse(taxAmount['Amount']?.toString() ?? '0') ?? 0,
        feeAmount: double.tryParse(feeAmount['Amount']?.toString() ?? '0') ?? 0,
        currency: totalFare['CurrencyCode'] ?? 'PKR',
        isRefundable: _determineRefundable(json),
        baggageAllowance: baggageInfo,
        legSchedules: _createLegSchedules(json, airlineInfo),
        stopSchedules: _createStopSchedules(json),
        segmentInfo: segmentInfo,
        airlineCode: airlineCode,
        airlineName: airlineInfo.name,
        airlineImg: airlineInfo.logoPath,
        rph: rph,
        rphFareSegment: rphFareSegment,
        rawData: json,// Set the RPH value
        changeFeeDetails: feeDetails['changeFeeDetails']!,
        refundFeeDetails: feeDetails['refundFeeDetails']!,

      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error creating AirBlueFlight: $e');
        print('Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  AirBlueFlight copyWithFareOptions(List<AirBlueFareOption> options) {
    return AirBlueFlight(
      id: id,
      price: price,
      buyingPrice: buyingPrice,
      sellingPrice: sellingPrice,
      basePrice: basePrice,
      taxAmount: taxAmount,
      feeAmount: feeAmount,
      currency: currency,
      isRefundable: isRefundable,
      baggageAllowance: baggageAllowance,
      legSchedules: legSchedules,
      stopSchedules: stopSchedules,
      segmentInfo: segmentInfo,
      airlineCode: airlineCode,
      airlineName: airlineName,
      airlineImg: airlineImg,
      rph: rph,
      rphFareSegment: rphFareSegment,
      fareOptions: options,
      rawData: rawData,
      pnrPricing: pnrPricing, changeFeeDetails: changeFeeDetails, refundFeeDetails: refundFeeDetails, // Keep existing pnrPricing if any
    );
  }


  // Separate method for PNR pricing
  AirBlueFlight copyWithPNRPricing(List<AirBluePNRPricing> pricing) {
    return AirBlueFlight(
      id: id,
      price: price,
      buyingPrice: buyingPrice,
      sellingPrice: sellingPrice,
      basePrice: basePrice,
      taxAmount: taxAmount,
      feeAmount: feeAmount,
      currency: currency,
      isRefundable: isRefundable,
      baggageAllowance: baggageAllowance,
      legSchedules: legSchedules,
      stopSchedules: stopSchedules,
      segmentInfo: segmentInfo,
      airlineCode: airlineCode,
      airlineName: airlineName,
      airlineImg: airlineImg,
      rph: rph,
      rphFareSegment: rphFareSegment,
      fareOptions: fareOptions,
      rawData: rawData,
      pnrPricing: pricing, changeFeeDetails: changeFeeDetails, refundFeeDetails: refundFeeDetails,
    );
  }
  static BaggageAllowance _getBaggageAllowance(Map<String, dynamic> pricingInfo) {
    try {
      final fareBreakdown = pricingInfo['PTC_FareBreakdowns']['PTC_FareBreakdown'];

      // Check if FareInfo is a list and get the baggage information
      if (fareBreakdown['FareInfo'] is List) {
        // Find the entry with baggage information
        for (var fareInfo in fareBreakdown['FareInfo']) {
          if (fareInfo['PassengerFare']?['FareBaggageAllowance'] != null) {
            final baggage = fareInfo['PassengerFare']['FareBaggageAllowance'];
            final weight = baggage['UnitOfMeasureQuantity']?.toString() ?? '20';
            final unit = baggage['UnitOfMeasure']?.toString() ?? 'KGS';

            return BaggageAllowance(
              type: 'Checked',
              pieces: 0, // AirBlue typically specifies by weight, not pieces
              weight: double.tryParse(weight) ?? 20,
              unit: unit,
            );
          }
        }
      } else if (fareBreakdown['FareInfo']?['PassengerFare']?['FareBaggageAllowance'] != null) {
        // Direct access if not a list
      // Handle nested structure - check if FareInfo is a List or Map
      final fareInfo = fareBreakdown['FareInfo'];
      if (fareInfo == null) {
        throw Exception('FareInfo is null');
      }
      
      // If FareInfo is a List, use first element
      final fareInfoMap = fareInfo is List ? (fareInfo.isNotEmpty ? fareInfo[0] : null) : fareInfo;
      if (fareInfoMap == null || fareInfoMap is! Map) {
        throw Exception('FareInfo is not a valid Map');
      }
      
      final passengerFare = fareInfoMap['PassengerFare'];
      if (passengerFare == null || passengerFare is! Map) {
        throw Exception('PassengerFare is not a valid Map');
      }
      
      final baggage = passengerFare['FareBaggageAllowance'];
      if (baggage == null || baggage is! Map) {
        throw Exception('FareBaggageAllowance is not a valid Map');
      }
      
      final weight = baggage['UnitOfMeasureQuantity']?.toString() ?? '20';
      final unit = baggage['UnitOfMeasure']?.toString() ?? 'KGS';

        return BaggageAllowance(
          type: 'Checked',
          pieces: 0,
          weight: double.tryParse(weight) ?? 20,
          unit: unit,
        );
      }

      // Default baggage allowance if not found
      return BaggageAllowance(
        type: 'Checked',
        pieces: 0,
        weight: 20,
        unit: 'KGS',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error getting baggage allowance: $e');
      }
      return BaggageAllowance(
        type: 'Checked',
        pieces: 0,
        weight: 20,
        unit: 'KGS',
      );
    }
  }

// Helper method to extract detailed fee information
  static Map<String, List<Map<String, dynamic>>> _extractFeeDetails(Map<String, dynamic> data) {
    final Map<String, List<Map<String, dynamic>>> feeDetails = {
      'changeFeeDetails': [],
      'refundFeeDetails': [],
    };

    try {
      final pricingInfo = data['AirItineraryPricingInfo'];
      if (pricingInfo == null) return feeDetails;

      final ptcFareBreakdown = pricingInfo['PTC_FareBreakdowns']?['PTC_FareBreakdown'];
      if (ptcFareBreakdown == null) return feeDetails;

      // Handle both single breakdown and list of breakdowns
      List<dynamic> fareBreakdowns = [];
      if (ptcFareBreakdown is List) {
        fareBreakdowns = ptcFareBreakdown;
      } else {
        fareBreakdowns = [ptcFareBreakdown];
      }

      // Iterate through all fare breakdowns
      for (var breakdown in fareBreakdowns) {
        final fareInfoList = breakdown['FareInfo'];

        // Handle both single FareInfo and list of FareInfo
        List<dynamic> fareInfos = [];
        if (fareInfoList is List) {
          fareInfos = fareInfoList;
        } else if (fareInfoList != null) {
          fareInfos = [fareInfoList];
        }

        // Look for RuleInfo in any of the FareInfo entries
        for (var fareInfo in fareInfos) {
          final ruleInfo = fareInfo['RuleInfo'];
          if (ruleInfo != null) {
            final chargesRules = ruleInfo['ChargesRules'];
            if (chargesRules != null) {

              // Extract change fees
              final voluntaryChanges = chargesRules['VoluntaryChanges'];
              if (voluntaryChanges != null) {
                final changePenalties = voluntaryChanges['Penalty'];
                if (changePenalties != null) {
                  List<dynamic> penalties = [];
                  if (changePenalties is List) {
                    penalties = changePenalties;
                  } else {
                    penalties = [changePenalties];
                  }

                  for (var penalty in penalties) {
                    feeDetails['changeFeeDetails']!.add({
                      'condition': penalty['HoursBeforeDeparture']?.toString() ?? '',
                      'amount': '${penalty['CurrencyCode']} ${penalty['Amount']}',
                      'currencyCode': penalty['CurrencyCode']?.toString() ?? '',
                      'penaltyAmount': penalty['Amount']?.toString() ?? '',
                    });
                  }
                }
              }

              // Extract refund fees
              final voluntaryRefunds = chargesRules['VoluntaryRefunds'];
              if (voluntaryRefunds != null) {
                final refundPenalties = voluntaryRefunds['Penalty'];
                if (refundPenalties != null) {
                  List<dynamic> penalties = [];
                  if (refundPenalties is List) {
                    penalties = refundPenalties;
                  } else {
                    penalties = [refundPenalties];
                  }

                  for (var penalty in penalties) {
                    feeDetails['refundFeeDetails']!.add({
                      'condition': penalty['HoursBeforeDeparture']?.toString() ?? '',
                      'amount': '${penalty['CurrencyCode']} ${penalty['Amount']}',
                      'currencyCode': penalty['CurrencyCode']?.toString() ?? '',
                      'penaltyAmount': penalty['Amount']?.toString() ?? '',
                    });
                  }
                }
              }

              // If we found rules, we can break out of the loops
              if (feeDetails['changeFeeDetails']!.isNotEmpty || feeDetails['refundFeeDetails']!.isNotEmpty) {
                break;
              }
            }
          }
        }

        // If we found rules, break out of the outer loop too
        if (feeDetails['changeFeeDetails']!.isNotEmpty || feeDetails['refundFeeDetails']!.isNotEmpty) {
          break;
        }
      }

    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error extracting fee details: $e');
        print('Stack trace: $stackTrace');
      }
    }

    return feeDetails;
  }

// Additional helper method to get human-readable fee conditions
  static String _formatFeeCondition(String condition) {
    switch (condition) {
      case '<0':
        return 'After departure';
      case '<48':
        return 'Less than 48 hours before departure';
      case '>48':
        return 'More than 48 hours before departure';
      default:
        return '${condition.replaceAll('<', 'Less than ').replaceAll('>', 'More than ')} hours';
    }
  }

// Method to get formatted fee details for display
  static Map<String, List<Map<String, String>>> getFormattedFeeDetails(
      List<Map<String, dynamic>> changeFees,
      List<Map<String, dynamic>> refundFees,
      ) {
    return {
      'changeFees': changeFees.map((fee) => {
        'condition': _formatFeeCondition(fee['condition'] ?? ''),
        'amount': fee['amount']?.toString() ?? '',
        'description': 'Change fee ${_formatFeeCondition(fee['condition'] ?? '')}',
      }).toList(),
      'refundFees': refundFees.map((fee) => {
        'condition': _formatFeeCondition(fee['condition'] ?? ''),
        'amount': fee['amount']?.toString() ?? '',
        'description': 'Refund fee ${_formatFeeCondition(fee['condition'] ?? '')}',
      }).toList(),
    };
  }
  static bool _determineRefundable(Map<String, dynamic> json) {
    try {
      final pricingInfo = json['AirItineraryPricingInfo'] ?? {};
      final fareBreakdown = pricingInfo['PTC_FareBreakdowns']?['PTC_FareBreakdown'];

      if (fareBreakdown == null) return false;

      // Check if FareInfo is a list
      if (fareBreakdown['FareInfo'] is List) {
        for (var fareInfo in fareBreakdown['FareInfo']) {
          final fareType = fareInfo['FareInfo']?['FareType']?.toString() ?? '';
          if (fareType.contains('NONREF')) {
            return false;
          }
        }
      } else {
        final fareType = fareBreakdown['FareInfo']?['FareInfo']?['FareType']?.toString() ?? '';
        if (fareType.contains('NONREF')) {
          return false;
        }
      }

      // If no non-refundable indication found, return true
      // This is based on the fare basis code containing 'EF' or 'EV' from the sample data
      // You might need to adjust this logic based on your actual business requirements
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error determining refundable status: $e');
      }
      return false;
    }
  }

  static List<Map<String, dynamic>> _createLegSchedules(
      Map<String, dynamic> json,
      AirlineInfo airlineInfo
      ) {
    try {
      final airItinerary = json['AirItinerary'] ?? {};
      final originDestOptions = airItinerary['OriginDestinationOptions'] ?? {};
      dynamic originDestOptionRaw = originDestOptions['OriginDestinationOption'];
      
      // Normalize to Map - if it's a List, use first element
      Map<String, dynamic> originDestOption;
      if (originDestOptionRaw == null) {
        originDestOption = {};
      } else if (originDestOptionRaw is List && originDestOptionRaw.isNotEmpty) {
        originDestOption = originDestOptionRaw[0] is Map ? Map<String, dynamic>.from(originDestOptionRaw[0]) : {};
      } else if (originDestOptionRaw is Map) {
        originDestOption = Map<String, dynamic>.from(originDestOptionRaw);
      } else {
        originDestOption = {};
      }
      
      final flightSegment = originDestOption['FlightSegment'] ?? {};

      final departure = flightSegment['DepartureAirport'] ?? {};
      final arrival = flightSegment['ArrivalAirport'] ?? {};
      final departureDateTime = flightSegment['DepartureDateTime']?.toString() ?? '';
      final arrivalDateTime = flightSegment['ArrivalDateTime']?.toString() ?? '';

      print("airblue time check");
      print(departureDateTime);
      print(arrivalDateTime);

      return [
        {
          'airlineCode': flightSegment['MarketingAirline']?['Code'] ?? 'PA',
          'airlineName': airlineInfo.name,
          'airlineImg': airlineInfo.logoPath,
          'departure': {
            'airport': departure['LocationCode'] ?? '',
            'city': _getCityName(departure['LocationCode']?.toString() ?? ''),
            'terminal': '1', // Default terminal
            'time': departureDateTime,
            'dateTime': departureDateTime,
          },
          'arrival': {
            'airport': arrival['LocationCode'] ?? '',
            'city': _getCityName(arrival['LocationCode']?.toString() ?? ''),
            'terminal': '1', // Default terminal
            'time': arrivalDateTime,
            'dateTime': arrivalDateTime,
          },
          'elapsedTime': _calculateFlightDuration(departureDateTime, arrivalDateTime),
          'stops': 0, // AirBlue flights in the sample are non-stop
          'schedules': [
            {
              'carrier': {
                'marketing': flightSegment['MarketingAirline']['Code'] ?? 'PA',
                'marketingFlightNumber': flightSegment['FlightNumber'] ?? '',
                'operating': flightSegment['OperatingAirline']?['Code'] ?? flightSegment['MarketingAirline']['Code'] ?? 'PA',
              },
              'departure': {
                'airport': departure['LocationCode'] ?? '',
                'terminal': '1',
                'time': departureDateTime,
                'dateTime': departureDateTime,
              },
              'arrival': {
                'airport': arrival['LocationCode'] ?? '',
                'terminal': '1',
                'time': arrivalDateTime,
                'dateTime': arrivalDateTime,
              },
              'equipment': flightSegment['Equipment']?['AirEquipType'] ?? 'A320',
            }
          ],
        }
      ];
    } catch (e) {
      if (kDebugMode) {
        print('Error creating leg schedules: $e');
      }
      return [];
    }
  }

  static List<Map<String, dynamic>> _createStopSchedules(Map<String, dynamic> json) {
    try {
      final airItinerary = json['AirItinerary'] ?? {};
      final originDestOptions = airItinerary['OriginDestinationOptions'] ?? {};
      dynamic originDestOptionRaw = originDestOptions['OriginDestinationOption'];
      
      // Normalize to Map - if it's a List, use first element
      Map<String, dynamic> originDestOption;
      if (originDestOptionRaw == null) {
        originDestOption = {};
      } else if (originDestOptionRaw is List && originDestOptionRaw.isNotEmpty) {
        originDestOption = originDestOptionRaw[0] is Map ? Map<String, dynamic>.from(originDestOptionRaw[0]) : {};
      } else if (originDestOptionRaw is Map) {
        originDestOption = Map<String, dynamic>.from(originDestOptionRaw);
      } else {
        originDestOption = {};
      }
      
      final flightSegment = originDestOption['FlightSegment'] ?? {};

      final departure = flightSegment['DepartureAirport'] ?? {};
      final arrival = flightSegment['ArrivalAirport'] ?? {};

      return [
        {
          'carrier': {
            'marketing': flightSegment['MarketingAirline']['Code'] ?? 'PA',
            'marketingFlightNumber': flightSegment['FlightNumber'] ?? '',
            'operating': flightSegment['OperatingAirline']?['Code'] ?? flightSegment['MarketingAirline']['Code'] ?? 'PA',
          },
          'departure': {
            'airport': departure['LocationCode'] ?? '',
            'terminal': '1',
            'time': flightSegment['DepartureDateTime'] ?? '',
            'dateTime': flightSegment['DepartureDateTime'] ?? '',
          },
          'arrival': {
            'airport': arrival['LocationCode'] ?? '',
            'terminal': '1',
            'time': flightSegment['ArrivalDateTime'] ?? '',
            'dateTime': flightSegment['ArrivalDateTime'] ?? '',
          },
          'equipment': flightSegment['Equipment']?['AirEquipType'] ?? 'A320',
        }
      ];
    } catch (e) {
      if (kDebugMode) {
        print('Error creating stop schedules: $e');
      }
      return [];
    }
  }

  static List<FlightSegmentInfo> _createSegmentInfo(Map<String, dynamic> json) {
    try {
      final pricingInfo = json['AirItineraryPricingInfo'] ?? {};
      final fareBreakdown = pricingInfo['PTC_FareBreakdowns']?['PTC_FareBreakdown'];

      if (fareBreakdown == null) {
        return [FlightSegmentInfo(bookingCode: 'L', cabinCode: 'Y', mealCode: 'M', seatsAvailable: '')];
      }

      // Check if FareInfo is a list
      if (fareBreakdown['FareInfo'] is List) {
        final fareInfo = fareBreakdown['FareInfo'][0];
        final bookingCode = fareInfo['FareInfo']?['FareBasisCode']?.toString() ?? 'L';
        final fareType = fareInfo['FareInfo']?['FareType']?.toString() ?? '';

        return [
          FlightSegmentInfo(
            bookingCode: bookingCode,
            cabinCode: _determineCabinClass(fareType),
            mealCode: 'M', // Default meal code
            seatsAvailable: '',
          )
        ];
      } else {
        final fareInfo = fareBreakdown['FareInfo'];
        final bookingCode = fareInfo['FareInfo']?['FareBasisCode']?.toString() ?? 'L';
        final fareType = fareInfo['FareInfo']?['FareType']?.toString() ?? '';

        return [
          FlightSegmentInfo(
            bookingCode: bookingCode,
            cabinCode: _determineCabinClass(fareType),
            mealCode: 'M',
            seatsAvailable: '',
          )
        ];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error creating segment info: $e');
      }
      return [FlightSegmentInfo(bookingCode: 'L', cabinCode: 'Y', mealCode: 'M', seatsAvailable: '')];
    }
  }

  static String _determineCabinClass(String fareType) {
    if (fareType.contains('F')) return 'F'; // First
    if (fareType.contains('C')) return 'C'; // Business
    if (fareType.contains('W')) return 'W'; // Premium Economy
    return 'Y'; // Default to Economy
  }

  static int _calculateFlightDuration(String departure, String arrival) {
    try {
      final depTime = DateTime.parse(departure);
      final arrTime = DateTime.parse(arrival);
      return arrTime.difference(depTime).inMinutes;
    } catch (e) {
      if (kDebugMode) {
        print('Error calculating flight duration: $e');
      }
      return 0;
    }
  }

   static String _getCityName(String airportCode) {
    try {
      final airportController = Get.find<AirportController>();
      for (var airport in airportController.airports) {
        if (airport.code.toUpperCase() == airportCode.toUpperCase()) {
          return airport.cityName;
        }
      }
    } catch (e) {
      // AirportController not found or error accessing airports
    }
    
    // Fallback to airport code if not found
    return airportCode;
  }
}


// New class to represent different fare options for the same flight
// In airblue_flight_model.dart
class AirBlueFareOption {
  final String cabinCode;
  final String cabinName;
  final String brandName;
  final double price;
  final double basePrice;
  final double taxAmount;
  final double feeAmount;
  final String currency;
  final bool isRefundable;
  final String mealCode;
  final String baggageAllowance;
  final Map<String, dynamic> rawData;
  final Map<String, dynamic> pricingInfo;
  final String fareName;
  final String changeFee;
  final String refundFee;
  final String fareBasisCode; // Changed to lowercase for consistency
  final Map<String, dynamic> fareInfoRawData; // New field for raw FareInfo data

  AirBlueFareOption({
    required this.cabinCode,
    required this.cabinName,
    required this.brandName,
    required this.price,
    required this.basePrice,
    required this.taxAmount,
    required this.feeAmount,
    required this.currency,
    required this.isRefundable,
    required this.mealCode,
    required this.baggageAllowance,
    required this.rawData,
    required this.pricingInfo,
    required this.fareName,
    required this.changeFee,
    required this.refundFee,
    required this.fareBasisCode,
    required this.fareInfoRawData, // Add to constructor
  });

  factory AirBlueFareOption.fromFlight(AirBlueFlight flight, Map<String, dynamic> rawData) {
    // Extract fare basis code to determine fare name and refundable status
    final String fareBasisCode = _extractFareBasisCode(rawData).toUpperCase();
    final String fareName = _getFareNameFromCode(fareBasisCode);
    final bool isRefundable = !fareBasisCode.contains('NR');

    // Extract cabin information
    final String cabinCode = _extractCabinCode(rawData);
    final String cabinName = _getCabinName(cabinCode);

    // Extract baggage allowance
    final String baggageAllowance = _extractBaggageAllowance(rawData);

    // Extract change and refund fees
    final Map<String, String> fees = _extractFees(rawData);
    final Map<String, dynamic> pricingInfo = _getPricingInfo(rawData);

    // Extract raw FareInfo data
    final Map<String, dynamic> fareInfoRawData = _extractFareInfoRawData(rawData);

    return AirBlueFareOption(
      cabinCode: cabinCode,
      cabinName: cabinName,
      brandName: fareName,
      price: flight.price,
      basePrice: flight.basePrice,
      taxAmount: flight.taxAmount,
      feeAmount: flight.feeAmount,
      currency: flight.currency,
      isRefundable: isRefundable,
      mealCode: 'M', // Default to meal available
      baggageAllowance: baggageAllowance,
      rawData: rawData,
      pricingInfo: pricingInfo,
      fareName: fareName,
      changeFee: fees['changeFee'] ?? 'Restricted',
      refundFee: fees['refundFee'] ?? 'Restricted',
      fareBasisCode: fareBasisCode,
      fareInfoRawData: fareInfoRawData, // Pass the extracted FareInfo data
    );
  }

  // New helper method to extract raw FareInfo data
  // New helper method to extract raw FareInfo data for the specific fare basis code
  static Map<String, dynamic> _extractFareInfoRawData(Map<String, dynamic> data) {
    try {
      final pricingInfo = data['AirItineraryPricingInfo'];
      if (pricingInfo == null) return {};

      final ptcFareBreakdown = pricingInfo['PTC_FareBreakdowns']?['PTC_FareBreakdown'];
      if (ptcFareBreakdown == null) return {};

      // Get the fare basis code we're looking for
      final fareBasisCode = _extractFareBasisCode(data);
      if (fareBasisCode.isEmpty) return {};

      // Handle both list and single item cases
      final List<dynamic> breakdowns = ptcFareBreakdown is List ? ptcFareBreakdown : [ptcFareBreakdown];

      for (var breakdown in breakdowns) {
        final fareInfos = breakdown['FareInfo'];
        if (fareInfos == null) continue;

        // Handle both single FareInfo and list of FareInfos
        final List<dynamic> fareInfoList = fareInfos is List ? fareInfos : [fareInfos];

        for (var fareInfo in fareInfoList) {
          if (fareInfo is Map) {
            // Check if this FareInfo contains the nested FareInfo with FareBasisCode
            final nestedInfo = fareInfo['FareInfo'];
            if (nestedInfo is Map &&
                nestedInfo['FareBasisCode']?.toString().toUpperCase() == fareBasisCode.toUpperCase()) {
              // Return the entire outer FareInfo object (which contains DepartureDate, DepartureAirport, etc.)
              return Map<String, dynamic>.from(fareInfo);
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error extracting FareInfo raw data: $e');
      }
    }
    return {};
  }
  // Helper method to get fare name from code
  static String _getFareNameFromCode(String fareCode) {
    if (fareCode.contains('EV')) return 'Value';
    if (fareCode.contains('EF')) return 'Flexi';
    if (fareCode.contains('EX')) return 'Extra';
    return 'Standard';
  }

  static Map<String, dynamic> _getPricingInfo(Map<String, dynamic> data) {
    final pricingInfo = data['AirItineraryPricingInfo'];
    return pricingInfo ?? {};
  }

  static Map<String, String> _extractFees(Map<String, dynamic> data) {
    final Map<String, String> fees = {
      'changeFee': 'Restricted',
      'refundFee': 'Restricted',
    };

    try {
      final pricingInfo = data['AirItineraryPricingInfo'];
      if (pricingInfo == null) return fees;

      final ptcFareBreakdown = pricingInfo['PTC_FareBreakdowns']?['PTC_FareBreakdown'];
      if (ptcFareBreakdown == null) return fees;

      // Handle both list and single item cases
      final List<dynamic> breakdowns = ptcFareBreakdown is List ? ptcFareBreakdown : [ptcFareBreakdown];

      if (breakdowns.isNotEmpty) {
        final fareInfo = breakdowns[0]['FareInfo'];
        if (fareInfo is List && fareInfo.length > 1) {
          final ruleInfo = fareInfo[1]['RuleInfo'];
          if (ruleInfo != null) {
            final chargesRules = ruleInfo['ChargesRules'];
            if (chargesRules != null) {
              // Change fees
              final changePenalties = chargesRules['VoluntaryChanges']?['Penalty'];
              if (changePenalties is List) {
                fees['changeFee'] = 'Restricted'; // As per web UI
              }

              // Refund fees
              final refundPenalties = chargesRules['VoluntaryRefunds']?['Penalty'];
              if (refundPenalties is List) {
                fees['refundFee'] = 'Restricted'; // As per web UI
              }
            }
          }
        }
      }
    } catch (e) {
      // Error handling
    }

    return fees;
  }

  static String _extractBaggageAllowance(Map<String, dynamic> data) {
    try {
      final pricingInfo = data['AirItineraryPricingInfo'];
      if (pricingInfo == null) return '20 KGS';

      final ptcFareBreakdown = pricingInfo['PTC_FareBreakdowns']?['PTC_FareBreakdown'];
      if (ptcFareBreakdown == null) return 'No Baggage';

      // Handle both list and single item cases
      final List<dynamic> breakdowns = ptcFareBreakdown is List ? ptcFareBreakdown : [ptcFareBreakdown];

      if (breakdowns.isNotEmpty) {
        final fareInfo = breakdowns[0]['FareInfo'];
        if (fareInfo is List && fareInfo.length > 1) {
          final baggage = fareInfo[1]['PassengerFare']?['FareBaggageAllowance'];
          if (baggage != null) {
            final weight = baggage['UnitOfMeasureQuantity']?.toString() ?? 'No';
            final unit = baggage['UnitOfMeasure']?.toString() ?? 'Baggage';
            return '$weight $unit';
          }
        }
      }
    } catch (e) {
      // Error handling
    }

    return 'No Baggage';
  }

  static String _extractFareBasisCode(Map<String, dynamic> data) {
    try {
      final pricingInfo = data['AirItineraryPricingInfo'];
      if (pricingInfo == null) return '';

      final ptcFareBreakdown = pricingInfo['PTC_FareBreakdowns']?['PTC_FareBreakdown'];
      if (ptcFareBreakdown == null) return '';

      // Handle both list and single item cases
      final List<dynamic> breakdowns = ptcFareBreakdown is List ? ptcFareBreakdown : [ptcFareBreakdown];

      if (breakdowns.isNotEmpty) {
        final fareInfo = breakdowns[0]['FareInfo'];
        if (fareInfo is List && fareInfo.isNotEmpty) {
          return fareInfo[0]['FareInfo']?['FareBasisCode']?.toString() ?? '';
        } else if (fareInfo is Map) {
          return fareInfo['FareBasisCode']?.toString() ?? '';
        }
      }
    } catch (e) {
      // Error handling
    }

    return '';
  }

  static String _extractCabinCode(Map<String, dynamic> data) {
    try {
      final originDestOption = data['AirItinerary']?['OriginDestinationOptions']?['OriginDestinationOption'];
      if (originDestOption == null) return 'Y';

      final flightSegment = originDestOption['FlightSegment'];
      if (flightSegment is List) {
        return flightSegment[0]['ResBookDesigCode']?.toString() ?? 'Y';
      } else if (flightSegment is Map) {
        return flightSegment['ResBookDesigCode']?.toString() ?? 'Y';
      }
    } catch (e) {
      // Error handling
    }

    return 'Y';
  }

  static String _getCabinName(String cabinCode) {
    switch (cabinCode.toUpperCase()) {
      case 'F': return 'First Class';
      case 'C': return 'Business Class';
      case 'J': return 'Premium Business';
      case 'W': return 'Premium Economy';
      case 'S': return 'Premium Economy';
      case 'Y': return 'Economy';
      default: return 'Economy';
    }
  }
}