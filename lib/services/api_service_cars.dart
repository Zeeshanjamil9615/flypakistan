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

class ApiServiceCars {
  static const String _url = 'https://flypakistan.pk/api/fetch-cars';

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
}
