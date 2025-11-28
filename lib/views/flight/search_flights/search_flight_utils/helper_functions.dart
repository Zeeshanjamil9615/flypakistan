// 1. First, let's update the Flight model to match the API response


import 'package:get/get.dart';

import '../../../../utility/colors.dart';
import '../../../../widgets/city_selection_bottom_sheet.dart';
import '../../../../widgets/snackbar.dart';
import '../sabre/sabre_flight_models.dart';

String getFareType(Map<String, dynamic> fareInfo) {
  try {
    final cabinCode = fareInfo['passengerInfoList']?[0]?['passengerInfo']
            ?['fareComponents']?[0]?['segments']?[0]?['segment']?['cabinCode']
        as String?;
    switch (cabinCode) {
      case 'C':
        return 'Business';
      case 'F':
        return 'First';
      default:
        return 'Economy';
    }
  } catch (e) {
    return 'Economy'; // Default to Economy if there's any error
  }
}


BaggageAllowance parseBaggageAllowance(
    List<dynamic> baggageInfo, {
      Map<int, Map<String, dynamic>>? baggageAllowanceDescsMap,
    }) {
  try {
    if (baggageInfo.isEmpty) {
      return BaggageAllowance(
          pieces: 0, weight: 0, unit: '', type: 'Check airline policy');
    }

    final allowance = baggageInfo[0]?['allowance'] as Map<String, dynamic>?;
    if (allowance == null) {
      return BaggageAllowance(
          pieces: 0, weight: 0, unit: '', type: 'Check airline policy');
    }

    // Try to resolve the allowance reference (Sabre provides only refs here)
    final ref = allowance['ref'];
    final allowanceDesc = (ref is int && baggageAllowanceDescsMap != null)
        ? baggageAllowanceDescsMap[ref]
        : null;

    final source = allowanceDesc ?? allowance;

    // Check if we have weight-based allowance
    if (source['weight'] != null) {
      return BaggageAllowance(
        pieces: 0,
        weight: (source['weight'] as num).toDouble(),
        unit: source['unit']?.toString() ?? 'KG',
        type: '${source['weight']} ${source['unit'] ?? 'KG'}',
      );
    }

    // Check if we have piece-based allowance
    if (source['pieceCount'] != null) {
      return BaggageAllowance(
        pieces: (source['pieceCount'] as num).toInt(),
        weight: 0,
        unit: 'PC',
        type: '${source['pieceCount']} PC',
      );
    }

    // Default case
    return BaggageAllowance(
        pieces: 0, weight: 0, unit: '', type: 'Check airline policy');
  } catch (e) {
    return BaggageAllowance(
        pieces: 0, weight: 0, unit: '', type: 'Check airline policy');
  }
}

AirlineInfo getAirlineInfo(String code, Map<String, AirlineInfo>? apiAirlineMap) {
  // First try to get from API data
  if (apiAirlineMap != null && apiAirlineMap.containsKey(code)) {
    return apiAirlineMap[code]!;
  }

  // Special case for X1 - Salam Airline
  if (code == 'X1') {
    return AirlineInfo(
      'Salam Airline',
      'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcT8_PEhMe5rBBr_HHy9-QjQuP68cMtZhQXv2Q&s');
  }

  CustomSnackBar(message: 'Airlines name and logo could not be loaded from API', backgroundColor: TColors.third);

  return AirlineInfo(
      'Unknown Airline',
      'https://cdn-icons-png.flaticon.com/128/15700/15700374.png');
}

String getCityNameByCode(String? code) {
  if (code == null || code.isEmpty) {
    return 'Unknown City';
  }

  try {
    final airportController = Get.find<AirportController>();
    for (final airport in airportController.airports) {
      if (airport.code.toUpperCase() == code.toUpperCase()) {
        return airport.cityName;
      }
    }
  } catch (e) {
    // Ignore errors – fall back to showing the code
  }

  return code;
}

String formatCityLabel({String? cityName, String? code}) {
  final trimmedCity = cityName?.trim() ?? '';
  final normalizedCode = code?.toUpperCase() ?? '';

  if (trimmedCity.isNotEmpty) {
    if (normalizedCode.isEmpty) {
      return trimmedCity;
    }
    if (trimmedCity.toUpperCase() == normalizedCode) {
      // Avoid duplicates like "LHE (LHE)"
      final resolved = getCityNameByCode(normalizedCode);
      return resolved == normalizedCode ? normalizedCode : '$resolved ($normalizedCode)';
    }
    return '$trimmedCity ($normalizedCode)';
  }

  if (normalizedCode.isEmpty) {
    return 'Unknown City';
  }

  final resolvedCity = getCityNameByCode(normalizedCode);
  if (resolvedCity == normalizedCode) {
    return normalizedCode;
  }
  return '$resolvedCity ($normalizedCode)';
}





