// 1. First, let's update the Flight model to match the API response


import '../../../../utility/colors.dart';
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

  CustomSnackBar(message: 'Airlines name and logo could not be loaded from API', backgroundColor: TColors.third);

  return AirlineInfo(
      'Unknown Airline',
      'https://cdn-icons-png.flaticon.com/128/15700/15700374.png');
}





