/// Adapter functions to convert different flight types to common format
/// for use with CommonFlightBookingVoucher

import 'common_flight_voucher.dart';
import '../search_flights/airarabia/airarabia_flight_model.dart';
import '../search_flights/airblue/airblue_flight_model.dart';
import '../search_flights/emirates_ndc/emirates_model.dart';
import '../search_flights/emirates_ndc/emirates_flight_controller.dart';
import '../search_flights/flydubai/flydubai_model.dart';
import '../search_flights/sabre/sabre_flight_models.dart';

/// Convert AirArabia flight data to common format
CommonFlightBookingVoucher createAirArabiaVoucher({
  required AirArabiaFlight flight,
  required AirArabiaPackage selectedPackage,
  required Map<String, dynamic> bookingResponse,
  required double totalPrice,
  required String currency,
  Map<int, String>? selectedSeats,
  double totalSeatPrice = 0.0,
  Map<String, dynamic>? extras, // Extras: baggage, meals, seats
}) {
  final bookingData = bookingResponse['data'] ?? {};
  final deadlineString = bookingData['deadline'];
  DateTime? expiryDateTime;
  
  if (deadlineString != null) {
    try {
      expiryDateTime = DateTime.parse(deadlineString);
    } catch (e) {
      // Ignore parse errors
    }
  }

  return CommonFlightBookingVoucher(
    flightData: _airArabiaToCommon(flight),
    pnrResponse: bookingResponse,
    airlineName: flight.airlineName,
    bookingId: bookingData['booking_id']?.toString(),
    bookingStatus: bookingData['status']?.toString() ?? 'Hold',
    totalPrice: totalPrice,
    currency: currency,
    expiryDateTime: expiryDateTime,
    selectedSeats: selectedSeats,
    totalSeatPrice: totalSeatPrice,
    extras: extras,
  );
}

/// Convert AirBlue flight data to common format
CommonFlightBookingVoucher createAirBlueVoucher({
  required AirBlueFlight outboundFlight,
  AirBlueFlight? returnFlight,
  List<AirBlueFlight>? multicityFlights,
  AirBlueFareOption? outboundFareOption,
  AirBlueFareOption? returnFareOption,
  List<AirBlueFareOption>? multicityFareOptions,
  Map<String, dynamic>? pnrResponse,
  Map<int, String>? selectedSeats,
  double totalSeatPrice = 0.0,
  double totalPrice = 0.0,
  String currency = 'PKR',
}) {
  DateTime? expiryDateTime;
  if (pnrResponse != null) {
    final timeLimit = pnrResponse['TicketTimeLimit'] ?? pnrResponse['timeLimit'];
    if (timeLimit != null) {
      try {
        expiryDateTime = DateTime.parse(timeLimit);
      } catch (e) {
        // Ignore parse errors
      }
    }
  }

  Map<String, dynamic> flightData;
  if (multicityFlights != null && multicityFlights.isNotEmpty) {
    flightData = {
      'multicityFlights': multicityFlights.asMap().entries.map((entry) {
        final index = entry.key;
        final flight = entry.value;
        final fareOption = multicityFareOptions != null && 
            index < multicityFareOptions.length
            ? multicityFareOptions[index]
            : null;
        return _airBlueToCommon(flight, fareOption: fareOption);
      }).toList(),
    };
  } else if (returnFlight != null) {
    flightData = {
      'outboundFlight': _airBlueToCommon(outboundFlight, fareOption: outboundFareOption),
      'returnFlight': _airBlueToCommon(returnFlight, fareOption: returnFareOption),
    };
  } else {
    flightData = _airBlueToCommon(outboundFlight, fareOption: outboundFareOption);
  }

  return CommonFlightBookingVoucher(
    flightData: flightData,
    pnrResponse: pnrResponse,
    airlineName: outboundFlight.airlineName,
    bookingId: pnrResponse?['pnr'],
    bookingStatus: 'CONFIRMED',
    totalPrice: totalPrice,
    currency: currency,
    expiryDateTime: expiryDateTime,
    selectedSeats: selectedSeats,
    totalSeatPrice: totalSeatPrice,
  );
}

/// Convert Emirates flight data to common format
CommonFlightBookingVoucher createEmiratesVoucher({
  required EmiratesFlight flight,
  required EmiratesFarePackage selectedPackage,
  Map<String, dynamic>? pnrResponse,
  double totalPrice = 0.0,
  String currency = 'AED',
}) {
  DateTime? expiryDateTime;
  if (pnrResponse != null) {
    final timeLimit = pnrResponse['timeLimit'] ?? pnrResponse['TicketTimeLimit'];
    if (timeLimit != null) {
      try {
        expiryDateTime = DateTime.parse(timeLimit);
      } catch (e) {
        // Ignore parse errors
      }
    }
  }

  final flightData = _emiratesToCommon(flight);
  flightData['cabinName'] = selectedPackage.cabinName;

  return CommonFlightBookingVoucher(
    flightData: flightData,
    pnrResponse: pnrResponse,
    airlineName: flight.airlineName,
    bookingId: pnrResponse?['orderId']?.toString(),
    bookingStatus: 'CONFIRMED',
    totalPrice: totalPrice > 0 ? totalPrice : selectedPackage.price,
    currency: currency.isNotEmpty ? currency : selectedPackage.currency,
    expiryDateTime: expiryDateTime,
  );
}

/// Convert FlyDubai flight data to common format
CommonFlightBookingVoucher createFlyDubaiVoucher({
  required FlydubaiFlight outboundFlight,
  FlydubaiFlight? returnFlight,
  List<FlydubaiFlight>? multicityFlights,
  FlydubaiFlightFare? outboundFareOption,
  FlydubaiFlightFare? returnFareOption,
  List<FlydubaiFlightFare?>? multicityFareOptions,
  Map<String, dynamic>? pnrResponse,
  double totalPrice = 0.0,
  String currency = 'AED',
  Map<String, dynamic>? extras, // Extras: baggage, meals, seats
}) {
  DateTime? expiryDateTime;
  if (pnrResponse != null) {
    final timeLimit = pnrResponse['ReservationFulfillmentRequiredByGMT'] ??
        pnrResponse['ReservationFulfillmentRequiredByODT'];
    if (timeLimit != null) {
      try {
        expiryDateTime = DateTime.parse(timeLimit);
      } catch (e) {
        // Ignore parse errors
      }
    }
  }

  Map<String, dynamic> flightData;
  if (multicityFlights != null && multicityFlights.isNotEmpty) {
    flightData = {
      'multicityFlights': multicityFlights.map((f) => _flyDubaiToCommon(f)).toList(),
    };
  } else if (returnFlight != null) {
    flightData = {
      'outboundFlight': _flyDubaiToCommon(outboundFlight),
      'returnFlight': _flyDubaiToCommon(returnFlight),
    };
  } else {
    flightData = _flyDubaiToCommon(outboundFlight);
  }

  return CommonFlightBookingVoucher(
    flightData: flightData,
    pnrResponse: pnrResponse,
    airlineName: outboundFlight.airlineName,
    bookingId: _getFlyDubaiConfirmation(pnrResponse),
    bookingStatus: 'CONFIRMED',
    totalPrice: totalPrice,
    currency: currency,
    expiryDateTime: expiryDateTime,
    extras: extras,
  );
}

/// Convert Sabre flight data to common format
CommonFlightBookingVoucher createSabreVoucher({
  required SabreFlight flight,
  Map<String, dynamic>? pnrResponse,
  double totalPrice = 0.0,
  String currency = 'PKR',
}) {
  DateTime? expiryDateTime;
  if (pnrResponse != null) {
    final timeLimit = pnrResponse['TicketTimeLimit'] ?? pnrResponse['timeLimit'];
    if (timeLimit != null) {
      try {
        expiryDateTime = DateTime.parse(timeLimit);
      } catch (e) {
        // Ignore parse errors
      }
    }
  }

  return CommonFlightBookingVoucher(
    flightData: _sabreToCommon(flight),
    pnrResponse: pnrResponse,
    airlineName: flight.airline,
    bookingId: _getSabrePNR(pnrResponse),
    bookingStatus: 'CONFIRMED',
    totalPrice: totalPrice > 0 ? totalPrice : flight.price,
    currency: currency,
    expiryDateTime: expiryDateTime,
  );
}

// Helper functions to convert flight models to common format

Map<String, dynamic> _airArabiaToCommon(AirArabiaFlight flight) {
  return {
    'legSchedules': flight.flightSegments.map((segment) => {
      'departure': {
        'airport': segment['departure']['airport'],
        'dateTime': segment['departure']['dateTime'],
      },
      'arrival': {
        'airport': segment['arrival']['airport'],
        'dateTime': segment['arrival']['dateTime'],
      },
      'flightNumber': segment['flightNumber'],
    }).toList(),
    'flightNumber': flight.flightSegments.first['flightNumber'] ?? '',
    'cabin': 'ECONOMY',
    'baggageAllowance': {
      'weight': 20,
      'unit': 'Kg',
    },
  };
}

Map<String, dynamic> _airBlueToCommon(AirBlueFlight flight, {AirBlueFareOption? fareOption}) {
  // Extract baggage allowance from fare option if provided, otherwise use flight default
  double baggageWeight = flight.baggageAllowance.weight;
  String baggageUnit = flight.baggageAllowance.unit;
  
  if (fareOption != null && fareOption.baggageAllowance.isNotEmpty) {
    // Parse baggage allowance string (e.g., "20 KGS", "30 KGS", "No Baggage")
    final baggageStr = fareOption.baggageAllowance.trim();
    if (baggageStr.toLowerCase() != 'no baggage') {
      // Extract weight and unit from string like "20 KGS" or "30 KGS"
      final regex = RegExp(r'(\d+(?:\.\d+)?)\s*([A-Z]+)?', caseSensitive: false);
      final match = regex.firstMatch(baggageStr);
      if (match != null) {
        baggageWeight = double.tryParse(match.group(1) ?? '20') ?? 20;
        baggageUnit = match.group(2)?.toUpperCase() ?? 'KGS';
      }
    } else {
      baggageWeight = 0;
      baggageUnit = 'KGS';
    }
  }
  
  return {
    'legSchedules': flight.legSchedules,
    'stopSchedules': flight.stopSchedules,
    'flightNumber': flight.stopSchedules.isNotEmpty 
        ? '${flight.stopSchedules.first['carrier']?['marketing']}-${flight.stopSchedules.first['carrier']?['marketingFlightNumber']}'
        : '',
    'cabin': fareOption?.cabinName ?? flight.fareOptions?.first.cabinName ?? 'ECONOMY',
    'cabinName': fareOption?.cabinName ?? flight.fareOptions?.first.cabinName ?? 'ECONOMY',
    'baggageAllowance': {
      'weight': baggageWeight,
      'unit': baggageUnit,
    },
  };
}

Map<String, dynamic> _emiratesToCommon(EmiratesFlight flight) {
  return {
    'legSchedules': flight.legSchedules,
    'flightNumber': flight.flightNumber,
    'cabin': flight.cabinClass,
    'cabinName': flight.cabinName,
    'baggageAllowance': {
      'weight': flight.baggageAllowance.weight,
      'unit': flight.baggageAllowance.unit,
    },
  };
}

Map<String, dynamic> _flyDubaiToCommon(FlydubaiFlight flight) {
  return {
    'legSchedules': flight.legSchedules.map((leg) => {
      'departure': {
        'airport': leg['departure']['airport'],
        'time': leg['departure']['time'],
      },
      'arrival': {
        'airport': leg['arrival']['airport'],
        'time': leg['arrival']['time'],
      },
    }).toList(),
    'flightNumber': flight.flightSegment.flightNumber,
    'cabin': flight.fareOptions?.first.cabin ?? 'ECONOMY',
    'cabinName': flight.fareOptions?.first.cabin ?? 'ECONOMY',
    'baggageAllowance': {
      'weight': flight.baggageAllowance.weight,
      'unit': flight.baggageAllowance.unit,
    },
  };
}

Map<String, dynamic> _sabreToCommon(SabreFlight flight) {
  return {
    'legSchedules': flight.legSchedules,
    'stopSchedules': flight.stopSchedules,
    'flightNumber': flight.flightNumber,
    'cabin': 'ECONOMY',
    'cabinName': 'ECONOMY',
    'baggageAllowance': {
      'weight': flight.baggageAllowance.weight,
      'unit': flight.baggageAllowance.unit,
    },
  };
}

String? _getFlyDubaiConfirmation(Map<String, dynamic>? pnrResponse) {
  if (pnrResponse == null) return null;
  
  return pnrResponse['confirmationNumber'] ??
         pnrResponse['ConfirmationNumber'] ??
         pnrResponse['commitData']?['ConfirmationNumber'] ??
         pnrResponse['commitData']?['ReservationInfo']?['ConfirmationNumber'] ??
         pnrResponse['commitData']?['reservationInfo']?['confirmationNumber'] ??
         pnrResponse['commitData']?['confirmationNumber'];
}

String? _getSabrePNR(Map<String, dynamic>? pnrResponse) {
  if (pnrResponse == null) return null;
  
  try {
    final pnrData = pnrResponse['CreatePassengerNameRecordRS'];
    if (pnrData != null) {
      final itineraryRef = pnrData['ItineraryRef'];
      if (itineraryRef != null && itineraryRef['ID'] != null) {
        return itineraryRef['ID'].toString();
      }
    }
    
    final order = pnrResponse['order'];
    if (order != null && order['pnrLocator'] != null) {
      return order['pnrLocator'].toString();
    }
    
    return null;
  } catch (e) {
    return null;
  }
}

