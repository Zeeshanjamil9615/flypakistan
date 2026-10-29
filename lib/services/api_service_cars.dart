import 'dart:convert';

import 'package:dio/dio.dart';

import '../views/cars/car_model.dart';

/// Failure with a message that can be shown to the user as-is.
class CarsApiException implements Exception {
  final String message;

  const CarsApiException(this.message);

  @override
  String toString() => message;
}

/// Rental cars plus the cities that have them, in the API's order.
class CarsResponse {
  final List<CarModel> cars;
  final List<String> cities;

  const CarsResponse({required this.cars, required this.cities});
}

/// One car plus the other cars in its city.
class CarDetailsResponse {
  final CarModel car;
  final List<CarModel> otherCars;

  const CarDetailsResponse({required this.car, required this.otherCars});
}

class ApiServiceCars {
  static const String _url = 'https://flypakistan.pk/api/fetch-cars';
  static const String _detailsUrl = 'https://flypakistan.pk/api/car-details';

  /// Fetches all rental cars. Throws [CarsApiException] on any failure.
  Future<CarsResponse> fetchCars() async {
    try {
      print('━━━ fetchCars REQUEST ━━━');
      print('URL: $_url');

      final response = await Dio().request(
        _url,
        options: Options(method: 'GET'),
      );

      print('━━━ fetchCars RESPONSE ━━━');
      print('Status: ${response.statusCode}');

      var data = response.data;
      if (data is String) {
        data = json.decode(data);
      }

      if (data is! Map || data['cars'] is! List) {
        final message = data is Map ? data['message']?.toString() : null;
        throw CarsApiException(
          (message != null && message.isNotEmpty)
              ? message
              : 'No cars available right now.',
        );
      }

      final List<CarModel> cars =
          (data['cars'] as List)
              .whereType<Map>()
              .map((car) => CarModel.fromJson(Map<String, dynamic>.from(car)))
              .where((car) => car.name.isNotEmpty)
              .toList();

      // The API's city list first, then any city it left out; only cities
      // that actually have cars are kept.
      final List<String> cities =
          [
                if (data['cities'] is List)
                  ...(data['cities'] as List).map((c) => c.toString().trim()),
                ...cars.map((car) => car.city),
              ]
              .where((city) => cars.any((car) => car.city == city))
              .toSet()
              .toList();

      print('Cars: ${cars.length}, Cities: ${cities.length}');
      return CarsResponse(cars: cars, cities: cities);
    } on CarsApiException {
      rethrow;
    } on DioException catch (e) {
      print('━━━ fetchCars DIO ERROR ━━━');
      print('Message: ${e.message}');
      throw const CarsApiException(
        'Could not load cars. Please check your internet connection.',
      );
    } catch (e) {
      print('━━━ fetchCars ERROR ━━━');
      print('$e');
      throw const CarsApiException('Could not load cars. Please try again.');
    }
  }

  /// Fetches one car with its color, capacity and transmission, plus the
  /// other cars in the same city. Throws [CarsApiException] on any failure.
  Future<CarDetailsResponse> fetchCarDetails(String id) async {
    try {
      final Map<String, dynamic> body = {'id': int.tryParse(id) ?? id};

      print('━━━ fetchCarDetails REQUEST ━━━');
      print('URL: $_detailsUrl');
      print('Body: ${json.encode(body)}');

      final response = await Dio().request(
        _detailsUrl,
        options: Options(
          method: 'POST',
          headers: {'Content-Type': 'application/json'},
        ),
        data: json.encode(body),
      );

      print('━━━ fetchCarDetails RESPONSE ━━━');
      print('Status: ${response.statusCode}');

      var data = response.data;
      if (data is String) {
        data = json.decode(data);
      }

      if (data is! Map || data['car'] is! Map) {
        final message = data is Map ? data['message']?.toString() : null;
        throw CarsApiException(
          (message != null && message.isNotEmpty)
              ? message
              : 'Car details are not available right now.',
        );
      }

      final CarModel car = CarModel.fromJson(
        Map<String, dynamic>.from(data['car'] as Map),
      );
      final List<CarModel> otherCars =
          data['other_cars'] is List
              ? (data['other_cars'] as List)
                  .whereType<Map>()
                  .map((c) => CarModel.fromJson(Map<String, dynamic>.from(c)))
                  .where((c) => c.name.isNotEmpty && c.id != car.id)
                  .toList()
              : <CarModel>[];

      print('Car: ${car.name}, Other cars: ${otherCars.length}');
      return CarDetailsResponse(car: car, otherCars: otherCars);
    } on CarsApiException {
      rethrow;
    } on DioException catch (e) {
      print('━━━ fetchCarDetails DIO ERROR ━━━');
      print('Message: ${e.message}');
      // e.g. 404 {"message": "Car not found."}
      final dynamic errorData = e.response?.data;
      final String? message =
          errorData is Map ? errorData['message']?.toString() : null;
      throw CarsApiException(
        (message != null && message.isNotEmpty)
            ? message
            : 'Could not load car details. Please check your internet connection.',
      );
    } catch (e) {
      print('━━━ fetchCarDetails ERROR ━━━');
      print('$e');
      throw const CarsApiException(
        'Could not load car details. Please try again.',
      );
    }
  }
}
