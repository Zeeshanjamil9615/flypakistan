import 'sabre_package_modal.dart';

class SabreFlight {
  final String imgPath;
  final String airline;
  final String airlineCode;
  final String flightNumber;
  final double price; // Selling price (display price) - with margin applied
  final double buyingPrice; // Buying price (without margin) - for PNR creation
  final double sellingPrice; // Selling price (with margin) - same as price for backward compatibility
  final bool isRefundable;
  final bool isNonStop;
  final BaggageAllowance baggageAllowance;
  final List<FlightPackageInfo> packages;
  final List<Map<String, dynamic>> stopSchedules;
  final int? legElapsedTime; // Total elapsed time from the leg
  final String mealCode;
  final String? groupId; // To group related flights together
  final List<Map<String, dynamic>> legSchedules;
  final List<FlightSegmentInfo> segmentInfo;
  final List<Map<String, dynamic>> pricingInforArray;
  final bool isNDC;

  SabreFlight({
    required this.imgPath,
    required this.airline,
    required this.airlineCode,
    required this.flightNumber,
    required this.price, // Selling price (display)
    required this.buyingPrice, // Buying price (for PNR)
    required this.sellingPrice, // Selling price (with margin)
    required this.isRefundable,
    required this.isNonStop,
    required this.baggageAllowance,
    required this.packages,
    required this.legSchedules,
    required this.segmentInfo,
    required this.stopSchedules,
    this.legElapsedTime = 0,
    required this.mealCode,
    this.groupId,
    required this.pricingInforArray,
    required this.isNDC,
  });
}


// Helper functions
class AirlineInfo {
  final String name;
  final String logoPath;

  AirlineInfo(this.name, this.logoPath);
}


class BaggageAllowance {
  final int pieces;
  final double weight;
  final String unit;
  final String type;

  BaggageAllowance({
    required this.pieces,
    required this.weight,
    required this.unit,
    required this.type,
  });
}

class FlightSegmentInfo {
  final String bookingCode;
  final String cabinCode;
  final String mealCode;
  final String seatsAvailable;
  final String fareBasisCode; // Added fareBasisCode

  FlightSegmentInfo({
    required this.bookingCode,
    required this.cabinCode,
    required this.mealCode,
    required this.seatsAvailable,
    this.fareBasisCode = '', // Default empty string
  });
}
