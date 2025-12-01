// models/emirates_flight_model.dart
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../../widgets/city_selection_bottom_sheet.dart';

class EmiratesFlight {
  final String id;
  final double price; // Real price without margin
  final double basePrice;
  final double taxAmount;
  final String currency;
  final bool isRefundable;
  final BaggageAllowance baggageAllowance;
  final List<Map<String, dynamic>> legSchedules;
  final List<Map<String, dynamic>> stopSchedules;
  final String airlineCode;
  final String airlineName;
  final String airlineImg;
  final String offerId;
  final Map<String, dynamic> rawData;
  final String fareBasisCode;
  final String cabinClass;
  final String cabinName;
  final String priceClassName;
  final List<String> amenities;
  final String flightNumber;
  final String departureDate;
  final String departureTime;
    final String responseId;

  EmiratesFlight({
    required this.id,
    required this.price,
    required this.basePrice,
    required this.taxAmount,
    required this.currency,
    required this.isRefundable,
    required this.baggageAllowance,
    required this.legSchedules,
    required this.stopSchedules,
    required this.airlineCode,
    required this.airlineName,
    required this.airlineImg,
    required this.offerId,
    required this.rawData,
    required this.fareBasisCode,
    required this.cabinClass,
    required this.cabinName,
    required this.priceClassName,
    required this.amenities,
    required this.flightNumber,
    required this.departureDate,
    required this.departureTime,
     required this.responseId,
  });

  factory EmiratesFlight.fromJson(Map<String, dynamic> json, {String? searchOrigin, String? searchDestination}) {
    try {
      debugPrint('\n🔵 Creating EmiratesFlight from JSON');
      debugPrint('Offer ID: ${json['OfferID']}');
      debugPrint('Search Origin: $searchOrigin');
      debugPrint('Search Destination: $searchDestination');
       // ✅ Extract ResponseID from rawData
      String responseId = '';
      if (json['ResponseID'] != null) {
        responseId = json['ResponseID'].toString();
      } else if (json['ShoppingResponseID'] != null) {
        responseId = json['ShoppingResponseID']['ResponseID']?.toString() ?? '';
      }
      debugPrint('ResponseID: $responseId');

      // Extract DataLists for reference data
      final dataLists = json['DataLists'] ?? {};
      
      // Extract flight segment information - throw exception if extraction fails
      final segments = _extractFlightSegments(
        json,
        dataLists,
        searchOrigin: searchOrigin,
        searchDestination: searchDestination,
      );
      if (segments.isEmpty) {
        debugPrint('❌ Failed to extract flight segment data - skipping this offer');
        throw Exception('Failed to extract flight segment data');
      }
      final firstSegment = segments.first;
      final lastSegment = segments.last;
      debugPrint('Flight segment data extracted: ${firstSegment['departure']['airport']} -> ${lastSegment['arrival']['airport']} (Segments: ${segments.length})');

      // Extract price information (real price without margin)
      final priceInfo = _extractPriceInfo(json);
      debugPrint('Base Price: ${priceInfo['base']} ${priceInfo['currency']}');
      debugPrint('Tax: ${priceInfo['tax']} ${priceInfo['currency']}');
      debugPrint('Total: ${priceInfo['total']} ${priceInfo['currency']}');

      // Extract fare details FROM OFFERITEM
      final offerItem = json['OfferItem'];
      final fareDetail = offerItem != null ? offerItem['FareDetail'] : null;
      
      // Extract price class directly from OfferItem's PriceClassRef
      final priceClassInfo = _extractPriceClassFromOfferItem(json, dataLists, fareDetail);
      debugPrint('🏷️ Price Class: "${priceClassInfo['name']}" (${priceClassInfo['code']})');
      debugPrint('   Cabin: ${priceClassInfo['cabinName']}');

      // Create leg schedules with proper airport codes
      final legSchedules = _createLegSchedules(segments);
      final stopSchedules = _createStopSchedules(segments);

      debugPrint('✅ EmiratesFlight created successfully\n');

      return EmiratesFlight(
        id: json['OfferID']?.toString() ?? 'UNKNOWN',
        price: priceInfo['total'], // Store real price without margin
        basePrice: priceInfo['base'],
        taxAmount: priceInfo['tax'],
        currency: priceInfo['currency'],
        isRefundable: _determineRefundable(fareDetail),
        baggageAllowance: _getBaggageAllowance(json, dataLists),
        legSchedules: legSchedules,
        stopSchedules: stopSchedules,
        airlineCode: 'EK',
        airlineName: 'Emirates',
        airlineImg: 'https://images.kiwi.com/airlines/64/EK.png',
        offerId: json['OfferID']?.toString() ?? '',
        rawData: json,
        fareBasisCode: _extractFareBasisCode(fareDetail),
        cabinClass: priceClassInfo['cabinCode'],
        cabinName: priceClassInfo['cabinName'],
        priceClassName: priceClassInfo['name'],
        amenities: priceClassInfo['amenities'],
        flightNumber: firstSegment['flightNumber'],
        departureDate: firstSegment['departure']['date'],
        departureTime: firstSegment['departure']['time'],
        responseId: responseId, 
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error creating EmiratesFlight: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON keys: ${json.keys}');
      rethrow;
    }
  }

  static Map<String, dynamic> _extractPriceClassFromOfferItem(
    Map<String, dynamic> offer,
    Map<String, dynamic> dataLists,
    Map<String, dynamic>? fareDetail,
  ) {
    try {
      debugPrint('🔍 Extracting price class from OfferItem...');
      
      // Step 1: Get PriceClassRef from OfferItem's FareDetail > FareComponent
      String? priceClassRef;
      if (fareDetail != null) {
        final fareComponent = fareDetail['FareComponent'];
        if (fareComponent != null) {
          priceClassRef = _extractValue(fareComponent['PriceClassRef']);
          debugPrint('  PriceClassRef from OfferItem: $priceClassRef');
        }
      }

      // Step 2: Look up the price class in DataLists using the reference
      if (priceClassRef != null && priceClassRef.isNotEmpty) {
        final priceClassList = dataLists['PriceClassList'];
        if (priceClassList != null) {
          final priceClasses = priceClassList['PriceClass'];
          if (priceClasses is Map) {
            final priceClass = priceClasses[priceClassRef];
            if (priceClass != null) {
              final name = _extractValue(priceClass['Name']) ?? 'Standard';
              final code = _extractValue(priceClass['Code']) ?? 'Y';
              
              debugPrint('  ✅ Price Class Found in DataLists: $name (Code: $code)');
              
              return {
                'name': name,
                'code': code,
                'cabinCode': _extractCabinCodeFromPriceClass(priceClass, fareDetail),
                'cabinName': _extractCabinNameFromPriceClass(priceClass, fareDetail),
                'amenities': _extractAmenities(priceClass),
              };
            }
          }
        }
      }

      debugPrint('  ⚠️ Using fallback cabin extraction from FareDetail');
      final cabinCode = _extractCabinClass(fareDetail);
      return {
        'name': _getCabinBasedPriceName(cabinCode),
        'code': cabinCode,
        'cabinCode': cabinCode,
        'cabinName': _extractCabinName(fareDetail),
        'amenities': <String>[],
      };
      
    } catch (e) {
      debugPrint('  ❌ Error extracting price class: $e');
      return {
        'name': 'Standard',
        'code': 'Y',
        'cabinCode': 'Y',
        'cabinName': 'Economy Class',
        'amenities': <String>[],
      };
    }
  }

  static String _extractCabinCodeFromPriceClass(
    Map<String, dynamic> priceClass,
    Map<String, dynamic>? fareDetail,
  ) {
    // First try to get from FareDetail
    if (fareDetail != null) {
      final cabinFromFare = _extractCabinClass(fareDetail);
      if (cabinFromFare.isNotEmpty && cabinFromFare != 'Y') {
        return cabinFromFare;
      }
    }
    
    // Fallback: infer from price class name
    final name = _extractValue(priceClass['Name'])?.toLowerCase() ?? '';
    if (name.contains('business')) return 'C';
    if (name.contains('first')) return 'F';
    if (name.contains('premium')) return 'W';
    return 'Y';
  }

  static String _extractCabinNameFromPriceClass(
    Map<String, dynamic> priceClass,
    Map<String, dynamic>? fareDetail,
  ) {
    final cabinCode = _extractCabinCodeFromPriceClass(priceClass, fareDetail);
    switch (cabinCode) {
      case 'F':
        return 'First Class';
      case 'C':
      case 'J':
        return 'Business Class';
      case 'W':
        return 'Premium Economy';
      case 'Y':
      default:
        return 'Economy Class';
    }
  }

  static String _getCabinBasedPriceName(String cabinCode) {
    switch (cabinCode) {
      case 'F':
        return 'First Class';
      case 'C':
      case 'J':
        return 'Business Class';
      case 'W':
        return 'Premium Economy';
      case 'Y':
      default:
        return 'Economy Standard';
    }
  }

  static List<Map<String, dynamic>> _extractFlightSegments(
    Map<String, dynamic> offer,
    Map<String, dynamic> dataLists, {
    String? searchOrigin,
    String? searchDestination,
  }) {
    try {
      final offerItem = offer['OfferItem'];
      if (offerItem == null) return [];

      final fareDetail = offerItem['FareDetail'];
      if (fareDetail == null) return [];

      final fareComponentRaw = fareDetail['FareComponent'];
      if (fareComponentRaw == null) return [];

      final List<dynamic> fareComponents = fareComponentRaw is List
          ? fareComponentRaw
          : [fareComponentRaw];

      final flightSegmentList = dataLists['FlightSegmentList'];
      if (flightSegmentList == null) return [];

      final flightSegments = flightSegmentList['FlightSegment'];
      if (flightSegments == null) return [];

      final segments = <Map<String, dynamic>>[];

      for (var component in fareComponents) {
        if (component == null) continue;

        final originDestinationRefs = _extractStringValues(
          component['OriginDestinationReferences'] ??
              component['OriginDestinationReference'],
        );

        final segmentReferenceNode = component['SegmentRefs'] ??
            component['SegmentRef'] ??
            component['SegmentReference'];

        final segmentKeys = _extractStringValues(segmentReferenceNode);

        if (segmentKeys.isNotEmpty) {
          for (var segmentKey in segmentKeys) {
            final segmentData = flightSegments[segmentKey];
            if (segmentData is Map<String, dynamic>) {
              final segment = _buildSegmentFromData(
                segmentKey,
                segmentData,
                originDestinationRefs,
              );
              segments.add(segment);
            }
          }
        } else {
          // Fallback: try matching using ON/OFF point data
          if (segmentReferenceNode is Map) {
            final onPoint = segmentReferenceNode['ON_Point']?.toString() ?? '';
            final offPoint = segmentReferenceNode['OFF_Point']?.toString() ?? '';

            if (onPoint.isNotEmpty && offPoint.isNotEmpty) {
              final matchedSegment = _matchSegmentByAirports(
                flightSegments,
                onPoint,
                offPoint,
                originDestinationRefs,
              );
              if (matchedSegment != null) {
                segments.add(matchedSegment);
              }
            }
          }
        }
      }

      // Deduplicate segments by segment key
      final seen = <String>{};
      final uniqueSegments = <Map<String, dynamic>>[];
      for (var segment in segments) {
        final key = segment['segmentKey']?.toString() ?? '';
        if (key.isEmpty) continue;
        if (seen.add(key)) {
          uniqueSegments.add(segment);
        }
      }

      uniqueSegments.sort((a, b) {
        final aDateTime = a['departure']?['dateTime']?.toString() ?? '';
        final bDateTime = b['departure']?['dateTime']?.toString() ?? '';
        return aDateTime.compareTo(bDateTime);
      });

      return uniqueSegments;
    } catch (e, stackTrace) {
      debugPrint('❌ Error extracting flight segments: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  static List<String> _extractStringValues(dynamic node) {
    final values = <String>[];
    if (node == null) return values;

    if (node is String) {
      values.addAll(
        node
            .split(RegExp(r'\s+'))
            .where((element) => element.isNotEmpty)
            .map((e) => e.trim()),
      );
    } else if (node is Map) {
      if (node.containsKey('\$t')) {
        values.addAll(_extractStringValues(node['\$t']));
      } else {
        for (var entry in node.values) {
          values.addAll(_extractStringValues(entry));
        }
      }
    } else if (node is List) {
      for (var item in node) {
        values.addAll(_extractStringValues(item));
      }
    }
    return values.where((value) => value.isNotEmpty).toList();
  }

  static Map<String, dynamic> _buildSegmentFromData(
    String segmentKey,
    Map<String, dynamic> segmentData,
    List<String> originDestinationRefs,
  ) {
    final departureRaw = segmentData['Departure'] ?? {};
    final arrivalRaw = segmentData['Arrival'] ?? {};
    final marketingCarrier = segmentData['MarketingCarrier'] ?? segmentData['Carrier'] ?? {};
    final operatingCarrier = segmentData['OperatingCarrier'] ?? marketingCarrier;
    final flightDetail = segmentData['FlightDetail'] ?? {};

    final departureAirport = _extractValue(departureRaw['AirportCode']) ?? '';
    final arrivalAirport = _extractValue(arrivalRaw['AirportCode']) ?? '';
    final departureDate = _extractValue(departureRaw['Date']) ?? '';
    final departureTime = _extractValue(departureRaw['Time']) ?? '00:00';
    final arrivalDate = _extractValue(arrivalRaw['Date']) ?? '';
    final arrivalTime = _extractValue(arrivalRaw['Time']) ?? '00:00';

    return {
      'segmentKey': segmentKey,
      'originDestinationReference': originDestinationRefs.isNotEmpty ? originDestinationRefs.first : '',
      'departure': {
        'airport': departureAirport,
        'city': _getCityName(departureAirport),
        'terminal': _extractValue(departureRaw['Terminal']?['Name']) ?? 'Main',
        'time': departureTime,
        'date': departureDate,
        'dateTime': '${departureDate}T$departureTime',
      },
      'arrival': {
        'airport': arrivalAirport,
        'city': _getCityName(arrivalAirport),
        'terminal': _extractValue(arrivalRaw['Terminal']?['Name']) ?? 'Main',
        'time': arrivalTime,
        'date': arrivalDate,
        'dateTime': '${arrivalDate}T$arrivalTime',
      },
      'carrier': {
        'marketing': _extractValue(marketingCarrier['AirlineID']) ?? 'EK',
        'marketingFlightNumber': _extractValue(marketingCarrier['FlightNumber']) ?? '',
        'operating': _extractValue(operatingCarrier['AirlineID']) ??
            _extractValue(marketingCarrier['AirlineID']) ??
            'EK',
        'operatingName': _extractValue(operatingCarrier['Name']) ??
            _extractValue(marketingCarrier['Name']) ??
            'Emirates',
      },
      'equipment': _extractValue(segmentData['Equipment']?['AircraftCode']) ?? '777',
      'flightNumber': _extractValue(marketingCarrier['FlightNumber']) ?? '',
      'duration': _calculateFlightDuration(flightDetail),
    };
  }

  static Map<String, dynamic>? _matchSegmentByAirports(
    dynamic flightSegments,
    String onPoint,
    String offPoint,
    List<String> originDestinationRefs,
  ) {
    if (flightSegments is Map) {
      for (var entry in flightSegments.entries) {
        final segmentData = entry.value;
        if (segmentData is Map<String, dynamic>) {
          final departure = segmentData['Departure'];
          final arrival = segmentData['Arrival'];

          if (departure != null && arrival != null) {
            final depAirport = _extractValue(departure['AirportCode']);
            final arrAirport = _extractValue(arrival['AirportCode']);

            if (depAirport == onPoint && arrAirport == offPoint) {
              return _buildSegmentFromData(
                entry.key.toString(),
                segmentData,
                originDestinationRefs,
              );
            }
          }
        }
      }
    } else if (flightSegments is List) {
      for (var segmentData in flightSegments) {
        if (segmentData is Map<String, dynamic>) {
          final departure = segmentData['Departure'];
          final arrival = segmentData['Arrival'];

          if (departure != null && arrival != null) {
            final depAirport = _extractValue(departure['AirportCode']);
            final arrAirport = _extractValue(arrival['AirportCode']);

            if (depAirport == onPoint && arrAirport == offPoint) {
              final segmentKey = segmentData['SegmentKey']?.toString() ?? '';
              return _buildSegmentFromData(
                segmentKey,
                segmentData,
                originDestinationRefs,
              );
            }
          }
        }
      }
    }

    return null;
  }

  static String _extractValue(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map) {
      return value['\$t']?.toString() ?? value['value']?.toString() ?? '';
    }
    return value.toString();
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


  static Map<String, dynamic> _extractPriceInfo(Map<String, dynamic> json) {
    try {
      final totalPrice = json['TotalPrice']?['DetailCurrencyPrice']?['Total'] ?? {};
      final offerItem = json['OfferItem'];
      
      double total = 0;
      double base = 0;
      double tax = 0;
      String currency = 'PKR';

      if (totalPrice is Map) {
        total = double.tryParse(totalPrice['\$t']?.toString() ?? totalPrice['value']?.toString() ?? totalPrice.toString()) ?? 0;
        currency = totalPrice['Code']?.toString() ?? 'PKR';
      } else {
        total = double.tryParse(totalPrice.toString()) ?? 0;
      }

      if (offerItem != null) {
        final fareDetail = offerItem['FareDetail'];
        if (fareDetail != null) {
          final price = fareDetail['Price'];
          if (price != null) {
            final baseAmount = price['BaseAmount'];
            if (baseAmount != null) {
              base = double.tryParse(_extractValue(baseAmount)) ?? 0;
            }

            final taxes = price['Taxes'];
            if (taxes != null) {
              final taxTotal = taxes['Total'];
              if (taxTotal != null) {
                tax = double.tryParse(_extractValue(taxTotal)) ?? 0;
              }
            }
          }
        }
      }

      return {
        'total': total,
        'base': base,
        'tax': tax,
        'currency': currency,
      };
    } catch (e) {
      return {
        'total': 0.0,
        'base': 0.0,
        'tax': 0.0,
        'currency': 'PKR',
      };
    }
  }

  static List<Map<String, dynamic>> _createLegSchedules(List<Map<String, dynamic>> segments) {
    return segments.map((segment) {
      return {
        'airlineCode': 'EK',
        'airlineName': 'Emirates',
        'airlineImg': 'https://images.kiwi.com/airlines/64/EK.png',
        'departure': segment['departure'],
        'arrival': segment['arrival'],
        'elapsedTime': segment['duration'],
        'stops': 0,
        'schedules': [
          {
            'carrier': segment['carrier'],
            'departure': segment['departure'],
            'arrival': segment['arrival'],
            'equipment': segment['equipment'],
          }
        ],
        'segmentKey': segment['segmentKey'],
        'originDestinationReference': segment['originDestinationReference'],
      };
    }).toList();
  }

  static List<Map<String, dynamic>> _createStopSchedules(List<Map<String, dynamic>> segments) {
    return segments.map((segment) {
      return {
        'carrier': segment['carrier'],
        'departure': segment['departure'],
        'arrival': segment['arrival'],
        'equipment': segment['equipment'],
        'segmentKey': segment['segmentKey'],
        'originDestinationReference': segment['originDestinationReference'],
      };
    }).toList();
  }

  static int _calculateFlightDuration(Map<String, dynamic> flightDetail) {
    try {
      final duration = flightDetail['FlightDuration']?['Value']?.toString() ?? '';
      if (duration.startsWith('PT')) {
        final hoursMatch = RegExp(r'(\d+)H').firstMatch(duration);
        final minutesMatch = RegExp(r'(\d+)M').firstMatch(duration);
        final hours = hoursMatch != null ? int.parse(hoursMatch.group(1)!) : 0;
        final minutes = minutesMatch != null ? int.parse(minutesMatch.group(1)!) : 0;
        return hours * 60 + minutes;
      }
      return 195;
    } catch (e) {
      return 195;
    }
  }

  static BaggageAllowance _getBaggageAllowance(
    Map<String, dynamic> offer,
    Map<String, dynamic> dataLists,
  ) {
    try {
      final baggageAllowances = offer['BaggageAllowance'];
      if (baggageAllowances != null) {
        final baggageList = baggageAllowances is List ? baggageAllowances : [baggageAllowances];
        
        for (var baggage in baggageList) {
          final baggageRef = baggage['BaggageAllowanceRef'];
          final baggageAllowanceList = dataLists['BaggageAllowanceList'];
          
          if (baggageAllowanceList != null) {
            final baggageDetails = baggageAllowanceList['BaggageAllowance'];
            
            if (baggageDetails is Map) {
              final detail = baggageDetails[baggageRef];
              if (detail != null) {
                final category = detail['BaggageCategory']?.toString() ?? 'Checked';
                
                if (category == 'Checked') {
                  final weightAllowance = detail['WeightAllowance'];
                  if (weightAllowance != null) {
                    final maxWeight = weightAllowance['MaximumWeight'];
                    return BaggageAllowance(
                      type: 'Checked',
                      pieces: 0,
                      weight: double.tryParse(_extractValue(maxWeight['Value'])) ?? 25,
                      unit: maxWeight['UOM']?.toString() ?? 'KG',
                    );
                  }
                }
              }
            }
          }
        }
      }

      return BaggageAllowance(type: 'Checked', pieces: 0, weight: 25, unit: 'KG');
    } catch (e) {
      return BaggageAllowance(type: 'Checked', pieces: 0, weight: 25, unit: 'KG');
    }
  }

  static bool _determineRefundable(Map<String, dynamic>? fareDetail) {
    try {
      if (fareDetail != null) {
        final fareComponent = fareDetail['FareComponent'];
        if (fareComponent != null) {
          final fareRules = fareComponent['FareRules'];
          if (fareRules != null) {
            final penalty = fareRules['Penalty'];
            if (penalty != null) {
              final refundable = penalty['RefundableInd'];
              return refundable == 'true' || refundable == true;
            }
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static String _extractFareBasisCode(Map<String, dynamic>? fareDetail) {
    try {
      if (fareDetail != null) {
        final fareComponent = fareDetail['FareComponent'];
        if (fareComponent != null) {
          final fareBasis = fareComponent['FareBasis'];
          if (fareBasis != null) {
            final fareBasisCode = fareBasis['FareBasisCode'];
            if (fareBasisCode != null) {
              return _extractValue(fareBasisCode['Code']);
            }
          }
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  static String _extractCabinClass(Map<String, dynamic>? fareDetail) {
    try {
      if (fareDetail != null) {
        final fareComponent = fareDetail['FareComponent'];
        if (fareComponent != null) {
          final fareBasis = fareComponent['FareBasis'];
          if (fareBasis != null) {
            final cabinType = fareBasis['CabinType'];
            if (cabinType != null) {
              return cabinType['CabinTypeCode']?.toString() ?? 'Y';
            }
          }
        }
      }
      return 'Y';
    } catch (e) {
      return 'Y';
    }
  }

  static String _extractCabinName(Map<String, dynamic>? fareDetail) {
    final cabinCode = _extractCabinClass(fareDetail);
    switch (cabinCode) {
      case 'F':
        return 'First Class';
      case 'C':
      case 'J':
        return 'Business Class';
      case 'W':
        return 'Premium Economy';
      case 'Y':
      default:
        return 'Economy Class';
    }
  }

  static List<String> _extractAmenities(Map<String, dynamic> priceClass) {
    final amenities = <String>[];
    try {
      final descriptions = priceClass['Descriptions'];
      if (descriptions != null) {
        final descriptionList = descriptions['Description'];
        if (descriptionList != null) {
          final descList = descriptionList is List ? descriptionList : [descriptionList];
          for (var desc in descList) {
            final text = desc['Text']?.toString() ?? '';
            if (text.isNotEmpty && 
                !text.contains('OriginDestinationReference') && 
                !text.contains('Icons') &&
                !text.contains('Cabin') &&
                text.startsWith('•')) {
              amenities.add(text.substring(1).trim());
            }
          }
        }
      }
    } catch (e) {
      // Ignore
    }
    
    if (amenities.isEmpty) {
      amenities.addAll([
        'ICE entertainment',
        'Hot and cold refreshments',
        'Complimentary Wi-Fi for Skywards members'
      ]);
    }
    
    return amenities;
  }

}

class BaggageAllowance {
  final String type;
  final int pieces;
  final double weight;
  final String unit;

  BaggageAllowance({
    required this.type,
    required this.pieces,
    required this.weight,
    required this.unit,
  });
}