// models/flydubai_flight_model.dart

// ignore_for_file: empty_catches

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../sabre/sabre_flight_models.dart';
import '../../../../widgets/city_selection_bottom_sheet.dart';

class FlydubaiResponse {
  final bool success;
  final List<FlydubaiFlightSegment> flightSegments;
  final String currency;
  final String searchStatus;
  final String? errorMessage;

  FlydubaiResponse({
    required this.success,
    required this.flightSegments,
    required this.currency,
    required this.searchStatus,
    this.errorMessage,
  });

  factory FlydubaiResponse.fromJson(Map<String, dynamic> json) {
    try {
      final response = json['RetrieveFareQuoteDateRangeResponse'];
      if (response == null) {
        return FlydubaiResponse(
          success: false,
          flightSegments: [],
          currency: 'PKR',
          searchStatus: 'Failed',
          errorMessage: 'Invalid response format',
        );
      }

      final result = response['RetrieveFareQuoteDateRangeResult'];
      if (result == null) {
        return FlydubaiResponse(
          success: false,
          flightSegments: [],
          currency: 'PKR',
          searchStatus: 'Failed',
          errorMessage: 'No result data found',
        );
      }

      // Check for exceptions first
      final exceptions = result['Exceptions']?['ExceptionInformation.Exception'];
      String status = 'Success';
      if (exceptions is List && exceptions.isNotEmpty) {
        final firstException = exceptions.first;
        status = firstException['ExceptionDescription']?.toString() ?? 'Success';
        if (firstException['ExceptionLevel']?.toString() != 'SUCCESS') {
          return FlydubaiResponse(
            success: false,
            flightSegments: [],
            currency: 'PKR',
            searchStatus: 'Failed',
            errorMessage: status,
          );
        }
      }

      List<FlydubaiFlightSegment> segments = [];

      // Parse from FlightSegments in the API response
      final flightSegmentsData = result['FlightSegments']?['FlightSegment'];
      if (flightSegmentsData != null) {
        if (flightSegmentsData is List) {
          for (var segmentData in flightSegmentsData) {
            try {
              final segment = FlydubaiFlightSegment.fromJson(segmentData, result);
              segments.add(segment);
            } catch (e) {
              if (kDebugMode) {
                print('Error parsing segment: $e');
              }
            }
          }
        } else if (flightSegmentsData is Map) {
          try {
            final segment = FlydubaiFlightSegment.fromJson(
                Map<String, dynamic>.from(flightSegmentsData), result);
            segments.add(segment);
          } catch (e) {
            if (kDebugMode) {
              print('Error parsing single segment: $e');
            }
          }
        }
      }

      return FlydubaiResponse(
        success: segments.isNotEmpty,
        flightSegments: segments,
        currency: result['CurrencyOfFareQuote']?.toString() ?? 'PKR',
        searchStatus: status,
        errorMessage: segments.isEmpty ? 'No flights found' : null,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing Flydubai response: $e');
      }
      return FlydubaiResponse(
        success: false,
        flightSegments: [],
        currency: 'PKR',
        searchStatus: 'Failed',
        errorMessage: 'Parsing error: $e',
      );
    }
  }
}

class FlydubaiFlightSegment {
  final int lfid;
  final String origin;
  final String destination;
  final String flightNumber;
  final DateTime departureDateTime;
  final DateTime arrivalDateTime;
  final List<FlydubaiFlightFare> fareTypes;
  final String aircraft;
  final String cabinClass;
  final Map<String, dynamic> legDetails;

  FlydubaiFlightSegment({
    required this.lfid,
    required this.origin,
    required this.destination,
    required this.flightNumber,
    required this.departureDateTime,
    required this.arrivalDateTime,
    required this.fareTypes,
    required this.aircraft,
    required this.cabinClass,
    required this.legDetails,
  });

  factory FlydubaiFlightSegment.fromJson(
      Map<String, dynamic> json,
      Map<String, dynamic> fullResponse,
      ) {
    try {
      List<FlydubaiFlightFare> fares = [];

      // Parse fare types from the segment data
      final fareTypesData = json['FareTypes']?['FareType'];
      if (fareTypesData is List) {
        for (var fareType in fareTypesData) {
          final fareInfos = fareType['FareInfos']?['FareInfo'];
          if (fareInfos is List) {
            for (var fareInfo in fareInfos) {
              try {
                fares.add(FlydubaiFlightFare.fromJson(fareInfo, fareType));
              } catch (e) {
                if (kDebugMode) {
                  print('Error parsing fare: $e');
                }
              }
            }
          } else if (fareInfos is Map) {
            try {
              fares.add(FlydubaiFlightFare.fromJson(
                  Map<String, dynamic>.from(fareInfos), fareType));
            } catch (e) {
              if (kDebugMode) {
                print('Error parsing single fare: $e');
              }
            }
          }
        }
      }

      // Extract flight details from SegmentDetails instead of LegDetails
      String origin = '';
      String destination = '';
      String flightNumber = '';
      DateTime departureDateTime = DateTime.now();
      DateTime arrivalDateTime = DateTime.now().add(Duration(hours: 3));

      // Try to find matching segment in SegmentDetails
      final lfid = (json['LFID'] as num?)?.toInt();
      
      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('🔍 Parsing segment LFID: $lfid');
        print('  FullResponse type: ${fullResponse.runtimeType}');
        print('  FullResponse keys: ${fullResponse.keys}');
        print('  FullResponse has SegmentDetails key: ${fullResponse.containsKey('SegmentDetails')}');
        print('  FullResponse has LegDetails key: ${fullResponse.containsKey('LegDetails')}');
      }
      
      final segmentDetails = fullResponse['SegmentDetails']?['SegmentDetail'];
      
      if (kDebugMode) {
        print('  SegmentDetails found: ${segmentDetails != null}');
        if (segmentDetails != null) {
          print('  SegmentDetails type: ${segmentDetails.runtimeType}');
          if (segmentDetails is List) {
            print('  SegmentDetails count: ${segmentDetails.length}');
            if (segmentDetails.isNotEmpty) {
              print('  First SegmentDetail keys: ${segmentDetails[0].keys}');
              print('  First SegmentDetail LFID: ${segmentDetails[0]['LFID']}');
            }
          } else if (segmentDetails is Map) {
            print('  Single SegmentDetail keys: ${segmentDetails.keys}');
            print('  Single SegmentDetail LFID: ${segmentDetails['LFID']}');
          }
        } else {
          print('  ⚠️ SegmentDetails is null - checking alternative paths...');
          // Try alternative path
          final altPath = fullResponse['RetrieveFareQuoteDateRangeResult']?['SegmentDetails']?['SegmentDetail'];
          print('  Alternative path (RetrieveFareQuoteDateRangeResult.SegmentDetails): ${altPath != null}');
        }
      }

      if (segmentDetails is List) {
        bool found = false;
        for (var segment in segmentDetails) {
          final segmentLfid = (segment['LFID'] as num?)?.toInt();
          if (segmentLfid == lfid) {
            origin = segment['Origin']?.toString() ?? '';
            destination = segment['Destination']?.toString() ?? '';
            flightNumber = segment['FlightNum']?.toString() ?? '';

            // Parse dates
            if (segment['DepartureDate'] != null) {
              departureDateTime = DateTime.parse(segment['DepartureDate'].toString());
            }
            if (segment['ArrivalDate'] != null) {
              arrivalDateTime = DateTime.parse(segment['ArrivalDate'].toString());
            }
            
            if (kDebugMode) {
              print('  ✅ Found segment in SegmentDetails: $origin -> $destination');
            }
            found = true;
            break;
          }
        }
        
        if (!found && kDebugMode) {
          print('  ⚠️ Segment LFID $lfid not found in SegmentDetails');
          if (segmentDetails.isNotEmpty) {
            print('  Available LFIDs: ${segmentDetails.map((s) => (s['LFID'] as num?)?.toInt()).toList()}');
          }
        }
      } else if (segmentDetails is Map) {
        // Handle single segment case
        final segmentLfid = (segmentDetails['LFID'] as num?)?.toInt();
        if (segmentLfid == lfid) {
          origin = segmentDetails['Origin']?.toString() ?? '';
          destination = segmentDetails['Destination']?.toString() ?? '';
          flightNumber = segmentDetails['FlightNum']?.toString() ?? '';

          if (segmentDetails['DepartureDate'] != null) {
            departureDateTime = DateTime.parse(segmentDetails['DepartureDate'].toString());
          }
          if (segmentDetails['ArrivalDate'] != null) {
            arrivalDateTime = DateTime.parse(segmentDetails['ArrivalDate'].toString());
          }
          
          if (kDebugMode) {
            print('  ✅ Found segment in SegmentDetails (single): $origin -> $destination');
          }
        }
      }

      // Fallback: Use dates from FlightSegment if SegmentDetails lookup failed
      if (origin.isEmpty || destination.isEmpty) {
        if (kDebugMode) {
          print('  ⚠️ Using fallback - checking FlightSegment dates and LegDetails');
        }
        
        // Use dates from the FlightSegment itself
        if (json['DepartureDate'] != null) {
          departureDateTime = DateTime.parse(json['DepartureDate'].toString());
        }
        if (json['ArrivalDate'] != null) {
          arrivalDateTime = DateTime.parse(json['ArrivalDate'].toString());
        }
        
        // Try to get from FlightLegDetails first (inside the segment)
        final flightLegDetails = json['FlightLegDetails']?['FlightLegDetail'];
        if (flightLegDetails != null) {
          if (kDebugMode) {
            print('  Checking FlightLegDetails...');
          }
          final legList = flightLegDetails is List ? flightLegDetails : [flightLegDetails];
          // Get PFIDs from FlightLegDetails
          final pfids = <int>[];
          for (var leg in legList) {
            final pfid = (leg['PFID'] as num?)?.toInt();
            if (pfid != null) {
              pfids.add(pfid);
            }
          }
          if (kDebugMode && pfids.isNotEmpty) {
            print('  Found PFIDs: $pfids');
          }
          
          // Now try to match in top-level LegDetails using PFID
          final legDetails = fullResponse['LegDetails']?['LegDetail'];
          if (legDetails != null) {
            final legList2 = legDetails is List ? legDetails : [legDetails];
            for (var pfid in pfids) {
              for (var leg in legList2) {
                final legPfid = (leg['PFID'] as num?)?.toInt();
                if (legPfid == pfid) {
                  // Match found! Extract origin/destination
                  if (origin.isEmpty) {
                    origin = leg['Origin']?.toString() ?? '';
                  }
                  if (destination.isEmpty) {
                    destination = leg['Destination']?.toString() ?? '';
                  }
                  if (flightNumber.isEmpty) {
                    flightNumber = leg['FlightNum']?.toString() ?? '';
                  }
                  if (kDebugMode && (origin.isNotEmpty || destination.isNotEmpty)) {
                    print('  ✅ Found from LegDetails (PFID $pfid): $origin -> $destination');
                  }
                  break;
                }
              }
              if (origin.isNotEmpty && destination.isNotEmpty) break;
            }
          }
        }
        
        // Final fallback: Try direct LegDetails match by date
        if ((origin.isEmpty || destination.isEmpty) && fullResponse['LegDetails'] != null) {
          final legDetails = fullResponse['LegDetails']?['LegDetail'];
          if (legDetails != null) {
            final legList = legDetails is List ? legDetails : [legDetails];
            for (var leg in legList) {
              final legDate = leg['DepartureDate']?.toString();
              if (legDate != null) {
                try {
                  final legDateTime = DateTime.parse(legDate);
                  if (legDateTime.year == departureDateTime.year &&
                      legDateTime.month == departureDateTime.month &&
                      legDateTime.day == departureDateTime.day) {
                    if (origin.isEmpty) {
                      origin = leg['Origin']?.toString() ?? '';
                    }
                    if (destination.isEmpty) {
                      destination = leg['Destination']?.toString() ?? '';
                    }
                    if (flightNumber.isEmpty) {
                      flightNumber = leg['FlightNum']?.toString() ?? '';
                    }
                    if (kDebugMode && (origin.isNotEmpty || destination.isNotEmpty)) {
                      print('  ✅ Found from LegDetails (date match): $origin -> $destination');
                    }
                    break;
                  }
                } catch (e) {
                  if (kDebugMode) {
                    print('  Error parsing leg date: $e');
                  }
                }
              }
            }
          }
        }
      }

      // Final fallback
      if (origin.isEmpty) {
        origin = json['Origin']?.toString() ?? 'N/A';
      }
      if (destination.isEmpty) {
        destination = json['Destination']?.toString() ?? 'N/A';
      }
      if (flightNumber.isEmpty) {
        flightNumber = json['FlightNum']?.toString() ?? 'N/A';
      }
      
      if (kDebugMode) {
        print('  Final segment: $origin -> $destination on ${departureDateTime.toIso8601String().substring(0, 10)}');
      }

      return FlydubaiFlightSegment(
        lfid: lfid ?? 0,
        origin: origin,
        destination: destination,
        flightNumber: flightNumber,
        departureDateTime: departureDateTime,
        arrivalDateTime: arrivalDateTime,
        fareTypes: fares,
        aircraft: json['AircraftType']?.toString() ?? 'B737',
        cabinClass: 'Y',
        legDetails: {}, // Keep empty as we're using SegmentDetails
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing flight segment: $e');
      }
      rethrow;
    }
  }}

class FlydubaiFlightFare {
  final String fareTypeId;
  final String fareTypeName;
  final String paxId;
  final int fareId;
  final int solnId; // Add solution ID for combinability logic
  final double displayFareAmount;
  final double baseFareAmountIncludingTax;
  final int seatsAvailable;
  final int passengerTypeId;
  final String currency;
  final String bookingCode;
  final String cabin;

  FlydubaiFlightFare({
    required this.fareTypeId,
    required this.fareTypeName,
    required this.paxId,
    required this.fareId,
    required this.solnId,
    required this.displayFareAmount,
    required this.baseFareAmountIncludingTax,
    required this.seatsAvailable,
    required this.passengerTypeId,
    required this.currency,
    required this.bookingCode,
    required this.cabin,
  });

  factory FlydubaiFlightFare.fromJson(Map<String, dynamic> fareInfo, Map<String, dynamic> fareType) {
    try {
      final paxData = fareInfo['Pax'];
      Map<String, dynamic> pax = {};

      if (paxData is List && paxData.isNotEmpty) {
        pax = paxData.first;
      } else if (paxData is Map) {
        pax = Map<String, dynamic>.from(paxData as Map);
      }

      // Get booking codes
      String bookingCode = 'Y';
      String cabin = 'ECONOMY';
      final bookingCodes = pax['BookingCodes']?['Bookingcode'];
      if (bookingCodes is List && bookingCodes.isNotEmpty) {
        final firstBooking = bookingCodes.first;
        bookingCode = firstBooking['RBD']?.toString() ?? 'Y';
        cabin = firstBooking['Cabin']?.toString() ?? 'ECONOMY';
      } else if (bookingCodes is Map) {
        bookingCode = bookingCodes['RBD']?.toString() ?? 'Y';
        cabin = bookingCodes['Cabin']?.toString() ?? 'ECONOMY';
      }

      return FlydubaiFlightFare(
        fareTypeId: fareType['FareTypeID']?.toString() ?? '',
        fareTypeName: fareType['FareTypeName']?.toString() ?? 'Economy',
        paxId: pax['ID']?.toString() ?? '',
        fareId: (pax['FareID'] as num?)?.toInt() ?? 0,
        solnId: (fareType['SolnId'] as num?)?.toInt() ?? 0, // Add solution ID
        displayFareAmount: (pax['BaseFareAmtInclTax'] as num?)?.toDouble() ??
            (pax['FareAmtInclTax'] as num?)?.toDouble() ?? 0.0,
        baseFareAmountIncludingTax: (pax['BaseFareAmtInclTax'] as num?)?.toDouble() ??
            (pax['FareAmtInclTax'] as num?)?.toDouble() ?? 0.0,
        seatsAvailable: (pax['SeatsAvailable'] as num?)?.toInt() ?? 0,
        passengerTypeId: (pax['PTCID'] as num?)?.toInt() ?? 1,
        currency: 'PKR',
        bookingCode: bookingCode,
        cabin: cabin,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing flight fare: $e');
      }
      rethrow;
    }
  }
}

class FlydubaiFlight {
  final String id;
  final double price;
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
  final String rph;
  final List<FlydubaiFlightFare>? fareOptions;
  final Map<String, dynamic> rawData;
  final FlydubaiFlightSegment flightSegment;
  final List<Map<String, dynamic>> changeFeeDetails;
  final List<Map<String, dynamic>> refundFeeDetails;
  // Add stop information
  final int stops;
  final bool isNonStop;
  final List<String> stopCities;

  FlydubaiFlight({
    required this.id,
    required this.price,
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
    required this.rph,
    required this.flightSegment,
    required this.changeFeeDetails,
    required this.refundFeeDetails,
    required this.stops,
    required this.isNonStop,
    required this.stopCities,
    this.fareOptions,
    required this.rawData,

  });

  factory FlydubaiFlight.fromFlightSegment(
      FlydubaiFlightSegment segment,
      Map<String, AirlineInfo> airlineMap,
      Map<String, dynamic> rawData, {
        String? expectedOrigin,
        String? expectedDestination,
      }) {
    try {
      // Get the lowest price fare
      final lowestFare = segment.fareTypes.isNotEmpty
          ? segment.fareTypes.reduce((a, b) => a.baseFareAmountIncludingTax < b.baseFareAmountIncludingTax ? a : b)
          : null;

      if (lowestFare == null) {
        throw Exception('No fare options available');
      }

      // Get airline info
      final airlineInfo =
      AirlineInfo('FlyDubai', 'https://agent1.pk/images/airline-logo/flydubai.png');

      // Generate unique ID
      final flightId = '${segment.flightNumber}-${segment.lfid}-${DateTime.now().millisecondsSinceEpoch}';

      // Force correct origin/destination if provided
      if (expectedOrigin != null && expectedDestination != null) {
        segment = FlydubaiFlightSegment(
          lfid: segment.lfid,
          origin: expectedOrigin,
          destination: expectedDestination,
          flightNumber: segment.flightNumber,
          departureDateTime: segment.departureDateTime,
          arrivalDateTime: segment.arrivalDateTime,
          fareTypes: segment.fareTypes,
          aircraft: segment.aircraft,
          cabinClass: segment.cabinClass,
          legDetails: segment.legDetails,
        );
      }

      // Create leg schedules with corrected origin/destination
      final legSchedules = _createLegSchedules(segment, airlineInfo, rawData);

      // Create stop schedules
      final stopSchedules = _createStopSchedules(segment, legSchedules);

      // Create segment info
      final segmentInfo = _createSegmentInfo(segment);

      // Create baggage allowance based on fare type
      final baggageAllowance = _createBaggageAllowance(lowestFare.fareTypeName);

      // Calculate pricing breakdown
      final totalPrice = lowestFare.baseFareAmountIncludingTax;
      final taxAmount = totalPrice * 0.25; // Approximate 25% for taxes and fees
      final basePrice = totalPrice - taxAmount;


      // Calculate stops from segment details
      final segmentDetails = rawData['RetrieveFareQuoteDateRangeResponse']?
      ['RetrieveFareQuoteDateRangeResult']?['SegmentDetails']?['SegmentDetail'];

      int stops = 0;
      List<String> stopCities = [];

      // Find the matching segment detail by LFID
      if (segmentDetails is List) {
        for (var segmentDetail in segmentDetails) {
          if ((segmentDetail['LFID'] as num?)?.toInt() == segment.lfid) {
            stops = (segmentDetail['Stops'] as num?)?.toInt() ?? 0;

            // Extract stop cities from the flight number (e.g., "360/807" means stop in DXB)
            if (stops > 0) {
              final flightNumbers = segmentDetail['FlightNum']?.toString().split('/') ?? [];
              if (flightNumbers.length > 1) {
                // For LHE-DXB-JED, the stop city would be DXB
                // You might need additional logic to map airport codes to city names
                stopCities = ['Dubai']; // Simplified - you'll need proper mapping
              }
            }
            break;
          }
        }
      }


      return FlydubaiFlight(
        id: flightId,
        price: totalPrice,
        basePrice: basePrice,
        taxAmount: taxAmount,
        feeAmount: 0,
        currency: lowestFare.currency,
        isRefundable: _determineRefundable(lowestFare.fareTypeName),
        baggageAllowance: baggageAllowance,
        legSchedules: legSchedules,
        stopSchedules: stopSchedules,
        segmentInfo: segmentInfo,
        airlineCode: 'FZ',
        airlineName: airlineInfo.name,
        airlineImg: airlineInfo.logoPath,
        rph: segment.lfid.toString(),
        flightSegment: segment,
        stops: stops,
        isNonStop: stops == 0,
        stopCities: stopCities,
        fareOptions: segment.fareTypes,
        rawData: rawData,
        changeFeeDetails: _getChangeFees(lowestFare.fareTypeName),
        refundFeeDetails: _getRefundFees(lowestFare.fareTypeName),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error creating FlydubaiFlight: $e');
      }
      rethrow;
    }
  }static List<Map<String, dynamic>> _createLegSchedules(
      FlydubaiFlightSegment segment,
      AirlineInfo airlineInfo,
      Map<String, dynamic> rawData,
      ) {
    final retrieveResult = rawData['RetrieveFareQuoteDateRangeResponse']
        ?['RetrieveFareQuoteDateRangeResult'];

    List<Map<String, dynamic>> _toMapList(dynamic data) {
      if (data == null) return [];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      if (data is Map) {
        return [Map<String, dynamic>.from(data)];
      }
      return [];
    }

    Map<String, dynamic>? _findMatchingSegment() {
      final segmentsData = retrieveResult?['FlightSegments']?['FlightSegment'];
      for (final seg in _toMapList(segmentsData)) {
        if ((seg['LFID'] as num?)?.toInt() == segment.lfid) {
          return seg;
        }
      }
      return null;
    }

    final legDetailMap = <int, Map<String, dynamic>>{};
    final legDetailsData = retrieveResult?['LegDetails']?['LegDetail'];
    for (final detail in _toMapList(legDetailsData)) {
      final pfid = (detail['PFID'] as num?)?.toInt();
      if (pfid != null) {
        legDetailMap[pfid] = detail;
      }
    }

    DateTime _parseDate(String? value, DateTime fallback) {
      if (value == null) return fallback;
      return DateTime.tryParse(value) ?? fallback;
    }

    Map<String, dynamic> _buildSchedule({
      required String origin,
      required String destination,
      required DateTime departure,
      required DateTime arrival,
      required String marketingCarrier,
      required String marketingFlightNumber,
      required String operatingCarrier,
      required String equipment,
      required String fromTerminal,
      required String toTerminal,
      required int elapsedMinutes,
    }) {
      final departureIso = departure.toIso8601String();
      final arrivalIso = arrival.toIso8601String();

      return {
        'airlineCode': marketingCarrier,
        'airlineName': airlineInfo.name,
        'airlineImg': airlineInfo.logoPath,
        'departure': {
          'airport': origin,
          'city': _getCityName(origin),
          'terminal': fromTerminal,
          'time': departureIso,
          'dateTime': departureIso,
        },
        'arrival': {
          'airport': destination,
          'city': _getCityName(destination),
          'terminal': toTerminal,
          'time': arrivalIso,
          'dateTime': arrivalIso,
        },
        'elapsedTime': elapsedMinutes,
        'stops': 0,
        'schedules': [
          {
            'carrier': {
              'marketing': marketingCarrier,
              'marketingFlightNumber': marketingFlightNumber,
              'operating': operatingCarrier,
            },
            'departure': {
              'airport': origin,
              'terminal': fromTerminal,
              'time': departureIso,
              'dateTime': departureIso,
            },
            'arrival': {
              'airport': destination,
              'terminal': toTerminal,
              'time': arrivalIso,
              'dateTime': arrivalIso,
            },
            'equipment': equipment,
          }
        ],
      };
    }

    final matchingSegment = _findMatchingSegment();
    final flightLegRefs = matchingSegment != null
        ? _toMapList(matchingSegment['FlightLegDetails']?['FlightLegDetail'])
        : <Map<String, dynamic>>[];

    final List<Map<String, dynamic>> schedules = [];

    for (final legRef in flightLegRefs) {
      final pfid = (legRef['PFID'] as num?)?.toInt();
      final detail = pfid != null ? legDetailMap[pfid] : null;

      final origin = detail?['Origin']?.toString() ??
          legRef['Origin']?.toString() ??
          segment.origin;
      final destination = detail?['Destination']?.toString() ??
          legRef['Destination']?.toString() ??
          segment.destination;

      final departureDate = _parseDate(
        detail?['DepartureDate']?.toString() ?? legRef['DepartureDate']?.toString(),
        segment.departureDateTime,
      );
      final arrivalDate = _parseDate(
        detail?['ArrivalDate']?.toString() ?? legRef['ArrivalDate']?.toString(),
        segment.arrivalDateTime,
      );

      final marketingCarrier =
          detail?['MarketingCarrier']?.toString() ?? segment.legDetails['MarketingCarrier']?.toString() ?? 'FZ';
      final operatingCarrier =
          detail?['OperatingCarrier']?.toString() ?? segment.legDetails['OperatingCarrier']?.toString() ?? marketingCarrier;
      final marketingFlightNumber =
          detail?['MarketingFlightNum']?.toString() ?? legRef['FlightNum']?.toString() ?? segment.flightNumber;
      final equipment = detail?['EQP']?.toString() ?? segment.aircraft;
      final fromTerminal =
          detail?['FromTerminal']?.toString() ?? segment.legDetails['FromTerminal']?.toString() ?? _getTerminal(origin);
      final toTerminal =
          detail?['ToTerminal']?.toString() ?? segment.legDetails['ToTerminal']?.toString() ?? _getTerminal(destination);
      final elapsedMinutes = (detail?['FlightTime'] as num?)?.toInt() ??
          arrivalDate.difference(departureDate).inMinutes;

      schedules.add(
        _buildSchedule(
          origin: origin,
          destination: destination,
          departure: departureDate,
          arrival: arrivalDate,
          marketingCarrier: marketingCarrier,
          marketingFlightNumber: marketingFlightNumber,
          operatingCarrier: operatingCarrier,
          equipment: equipment,
          fromTerminal: fromTerminal,
          toTerminal: toTerminal,
          elapsedMinutes: elapsedMinutes,
        ),
      );
    }

    if (schedules.isNotEmpty) {
      return schedules;
    }

    // Fallback to single segment schedule when leg data is missing
    final flightTime = segment.arrivalDateTime.difference(segment.departureDateTime).inMinutes;
    String origin = segment.origin;
    String destination = segment.destination;

    if (origin.isEmpty || origin == 'N/A') {
      origin = segment.legDetails['Origin']?.toString() ?? 'DXB';
    }
    if (destination.isEmpty || destination == 'N/A') {
      destination = segment.legDetails['Destination']?.toString() ?? 'LHE';
    }

    return [
      _buildSchedule(
        origin: origin,
        destination: destination,
        departure: segment.departureDateTime,
        arrival: segment.arrivalDateTime,
        marketingCarrier: 'FZ',
        marketingFlightNumber: segment.flightNumber,
        operatingCarrier: segment.legDetails['OperatingCarrier']?.toString() ?? 'FZ',
        equipment: segment.aircraft,
        fromTerminal: segment.legDetails['FromTerminal']?.toString() ?? _getTerminal(origin),
        toTerminal: segment.legDetails['ToTerminal']?.toString() ?? _getTerminal(destination),
        elapsedMinutes: flightTime,
      )
    ];
  }
  static List<Map<String, dynamic>> _createStopSchedules(
      FlydubaiFlightSegment segment,
      List<Map<String, dynamic>> legSchedules,
      ) {
    if (legSchedules.isNotEmpty) {
      return legSchedules.map((leg) {
        Map<String, dynamic> carrier = {};
        final schedules = leg['schedules'];
        if (leg['carrier'] is Map) {
          carrier = Map<String, dynamic>.from(leg['carrier']);
        } else if (schedules is List && schedules.isNotEmpty && schedules.first is Map) {
          carrier = Map<String, dynamic>.from(
              (schedules.first as Map)['carrier'] as Map? ?? {});
        }
        carrier.putIfAbsent('marketing', () => leg['airlineCode'] ?? 'FZ');
        carrier.putIfAbsent('marketingFlightNumber', () => segment.flightNumber);
        carrier.putIfAbsent('operating', () => carrier['marketing']);

        Map<String, dynamic> _copyLocation(String key) {
          final source = leg[key];
          final scheduleSource = (schedules is List && schedules.isNotEmpty)
              ? (schedules.first as Map)[key]
              : null;
          if (source is Map) {
            return Map<String, dynamic>.from(source);
          }
          if (scheduleSource is Map) {
            return Map<String, dynamic>.from(scheduleSource);
          }
          return {
            'airport': key == 'departure' ? segment.origin : segment.destination,
            'terminal': _getTerminal(
              key == 'departure' ? segment.origin : segment.destination,
            ),
            'time': key == 'departure'
                ? segment.departureDateTime.toIso8601String()
                : segment.arrivalDateTime.toIso8601String(),
            'dateTime': key == 'departure'
                ? segment.departureDateTime.toIso8601String()
                : segment.arrivalDateTime.toIso8601String(),
          };
        }

        return {
          'carrier': carrier,
          'departure': _copyLocation('departure'),
          'arrival': _copyLocation('arrival'),
          'equipment': leg['equipment'] ??
              (schedules is List && schedules.isNotEmpty
                  ? (schedules.first as Map)['equipment']
                  : segment.aircraft),
        };
      }).toList();
    }

    // Get origin and destination with fallbacks
    String origin = segment.origin;
    String destination = segment.destination;

    if (origin.isEmpty || origin == 'N/A') {
      origin = segment.legDetails['Origin']?.toString() ?? 'DXB';
    }
    if (destination.isEmpty || destination == 'N/A') {
      destination = segment.legDetails['Destination']?.toString() ?? 'LHE';
    }

    return [
      {
        'carrier': {
          'marketing': 'FZ',
          'marketingFlightNumber': segment.flightNumber,
          'operating': segment.legDetails['OperatingCarrier']?.toString() ?? 'FZ',
        },
        'departure': {
          'airport': origin, // Use determined origin
          'terminal': segment.legDetails['FromTerminal']?.toString() ?? _getTerminal(origin),
          'time': segment.departureDateTime.toIso8601String(),
          'dateTime': segment.departureDateTime.toIso8601String(),
        },
        'arrival': {
          'airport': destination, // Use determined destination
          'terminal': segment.legDetails['ToTerminal']?.toString() ?? _getTerminal(destination),
          'time': segment.arrivalDateTime.toIso8601String(),
          'dateTime': segment.arrivalDateTime.toIso8601String(),
        },
        'equipment': segment.aircraft,
      }
    ];
  } static List<FlightSegmentInfo> _createSegmentInfo(FlydubaiFlightSegment segment) {
    final mainFare = segment.fareTypes.isNotEmpty ? segment.fareTypes.first : null;

    return [
      FlightSegmentInfo(
        bookingCode: mainFare?.bookingCode ?? 'Y',
        cabinCode: mainFare?.bookingCode ?? 'Y',
        mealCode: 'M',
        seatsAvailable: mainFare?.seatsAvailable.toString() ?? '9',
      )
    ];
  }

  static BaggageAllowance _createBaggageAllowance(String fareTypeName) {
    print("**************Flydubai Fare Name Check ***********");
    print(fareTypeName);

    final type = fareTypeName.toLowerCase();


    if (type.contains('lite')) {
      return BaggageAllowance(
        type: 'Checked',
        pieces: 0,
        weight: 0,
        unit: 'KGS',
      );
    }

    if (type.contains('value')) {
      return BaggageAllowance(
        type: 'Checked',
        pieces: 1,
        weight: 20,
        unit: 'KGS',
      );
    }

    if (type.contains('flex')) {
      return BaggageAllowance(
        type: 'Checked',
        pieces: 1,
        weight: 30,
        unit: 'KGS',
      );
    }

    if (type.contains('economy')) {
      return BaggageAllowance(
        type: 'Checked',
        pieces: 1,
        weight: 30,
        unit: 'KGS',
      );
    }

    if (type.contains('business')) {
      return BaggageAllowance(
        type: 'Checked',
        pieces: 2,
        weight: 40,
        unit: 'KGS',
      );
    }

    // Default
    return BaggageAllowance(
      type: 'Checked',
      pieces: 1,
      weight: 20,
      unit: 'KGS',
    );
  }

  static bool _determineRefundable(String fareTypeName) {
    return fareTypeName.toUpperCase() == 'FLEX' || fareTypeName.toUpperCase() == 'BUSINESS';
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

  static String _getTerminal(String airportCode) {
    const terminalMap = {
      'DXB': 'Terminal 2',
      'AUH': 'Terminal 3',
      'SHJ': 'Terminal 1',
      'KHI': 'Terminal 1',
      'LHE': 'Terminal 1',
      'ISB': 'Terminal 1',
    };
    return terminalMap[airportCode] ?? 'Main';
  }

  static List<Map<String, dynamic>> _getChangeFees(String fareTypeName) {
    switch (fareTypeName.toUpperCase()) {
      case 'LITE':
        return [
          {
            'condition': 'Any time',
            'amount': 'Not permitted',
            'currencyCode': 'PKR',
            'penaltyAmount': '0',
          },
        ];
      case 'VALUE':
        return [
          {
            'condition': '>24h',
            'amount': 'AED 150',
            'currencyCode': 'AED',
            'penaltyAmount': '150',
          },
          {
            'condition': '<24h',
            'amount': '100%',
            'currencyCode': 'PKR',
            'penaltyAmount': '100',
          },
        ];
      case 'FLEX':
      case 'BUSINESS':
        return [
          {
            'condition': '>12h',
            'amount': 'Free',
            'currencyCode': 'PKR',
            'penaltyAmount': '0',
          },
          {
            'condition': '<12h',
            'amount': '100%',
            'currencyCode': 'PKR',
            'penaltyAmount': '100',
          },
        ];
      default:
        return [
          {
            'condition': '>24h',
            'amount': 'Fee applies',
            'currencyCode': 'PKR',
            'penaltyAmount': '5000',
          },
        ];
    }
  }

  static List<Map<String, dynamic>> _getRefundFees(String fareTypeName) {
    switch (fareTypeName.toUpperCase()) {
      case 'LITE':
        return [
          {
            'condition': 'Any time',
            'amount': 'Non-refundable',
            'currencyCode': 'PKR',
            'penaltyAmount': '0',
          },
        ];
      case 'VALUE':
        return [
          {
            'condition': '>24h',
            'amount': 'AED 200',
            'currencyCode': 'AED',
            'penaltyAmount': '200',
          },
          {
            'condition': '<24h',
            'amount': 'Non-refundable',
            'currencyCode': 'PKR',
            'penaltyAmount': '0',
          },
        ];
      case 'FLEX':
        return [
          {
            'condition': '>24h',
            'amount': 'Free',
            'currencyCode': 'PKR',
            'penaltyAmount': '0',
          },
          {
            'condition': '<24h',
            'amount': 'AED 400',
            'currencyCode': 'AED',
            'penaltyAmount': '400',
          },
        ];
      case 'BUSINESS':
        return [
          {
            'condition': '>24h',
            'amount': 'Free',
            'currencyCode': 'PKR',
            'penaltyAmount': '0',
          },
          {
            'condition': '<24h',
            'amount': 'AED 400',
            'currencyCode': 'AED',
            'penaltyAmount': '400',
          },
        ];
      default:
        return [
          {
            'condition': '>24h',
            'amount': 'Fee applies',
            'currencyCode': 'PKR',
            'penaltyAmount': '8000',
          },
        ];
    }
  }

  FlydubaiFlight copyWithFareOptions(List<FlydubaiFlightFare> options) {
    return FlydubaiFlight(
      id: id,
      price: price,
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
      flightSegment: flightSegment,
      fareOptions: options,
      rawData: rawData,
      changeFeeDetails: changeFeeDetails,
      refundFeeDetails: refundFeeDetails, stops: stops, isNonStop: isNonStop, stopCities: stopCities,
    );
  }
}