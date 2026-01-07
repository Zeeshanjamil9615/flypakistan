// ignore_for_file: depend_on_referenced_packages, non_constant_identifier_names, empty_catches

import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'api_client.dart';
import '../views/flight/booking_flight/booking_flight_controller.dart';
import '../views/flight/search_flights/airblue/airblue_flight_model.dart';
import '../views/flight/search_flights/airblue/airblue_pnr_pricing.dart';
import '../views/flight/search_flights/sabre/sabre_flight_models.dart';
import 'margin_service_flight.dart';

class AirBlueFlightApiService {
  final String link = 'https://ota2.zapways.com/v3.0/OTAAPI.asmx';
  
  // API Credentials
  final String ERSP_UserID = '2032/A419665871F6EF748748BD6BEA6429FD07';
  final String ID = 'travelocityota';
  final String MessagePassword = 'CT9ip@Z@7c#iXQX';
  final String Target = 'Production';
  final String Version = '1.04';
  final String Type = '29';

  // ApiClient instance
  final ApiClient _apiClient = ApiClient();

  // Cache for margin data so we can reuse it between search and booking
  Map<String, dynamic>? _cachedMarginData;

  // Expose a safe setter so other layers (e.g. controllers) can inject margin data
  void setMarginData(Map<String, dynamic> margin) {
    _cachedMarginData = Map<String, dynamic>.from(margin);
  }

  /// Search AirBlue flights
  Future<Map<String, dynamic>> airBlueFlightSearch({
    required int type,
    required String origin,
    required String destination,
    required String depDate,
    required int adult,
    required int child,
    required int infant,
    required String stop,
    required String cabin,
    bool printRequest = false,
    bool printResponse = false,
  }) async {
    // Process input parameters
    final originArray = origin.split(",");
    final destinationArray = destination.split(",");
    final depDateArray = depDate.split(",");

    String originDestination = "";

    // Build origin destination XML
    if (type == 0) {
      // One-way trip
      originDestination = '''
  <OriginDestinationInformation RPH="1">
    <DepartureDateTime>${depDateArray[1]}T00:00:00</DepartureDateTime>
    <OriginLocation LocationCode="${originArray[1].toUpperCase()}"></OriginLocation>
    <DestinationLocation LocationCode="${destinationArray[1].toUpperCase()}"></DestinationLocation>
  </OriginDestinationInformation>''';
    } else if (type == 1) {
      // Round trip
      originDestination = '''
  <OriginDestinationInformation RPH="1">
    <DepartureDateTime>${depDateArray[1]}T00:00:00</DepartureDateTime>
    <OriginLocation LocationCode="${originArray[1].toUpperCase()}"></OriginLocation>
    <DestinationLocation LocationCode="${destinationArray[1].toUpperCase()}"></DestinationLocation>
  </OriginDestinationInformation>
  <OriginDestinationInformation RPH="2">
    <DepartureDateTime>${depDateArray[2]}T00:00:00</DepartureDateTime>
    <OriginLocation LocationCode="${destinationArray[1].toUpperCase()}"></OriginLocation>
    <DestinationLocation LocationCode="${originArray[1].toUpperCase()}"></DestinationLocation>
  </OriginDestinationInformation>''';
    } else if (type == 2) {
      // Multi-city trip
      final loopCount = originArray.length;
      for (int i = 1; i < loopCount; i++) {
        originDestination += '''
  <OriginDestinationInformation RPH="$i">
    <DepartureDateTime>${depDateArray[i]}T00:00:00</DepartureDateTime>
    <OriginLocation LocationCode="${originArray[i].toUpperCase()}"></OriginLocation>
    <DestinationLocation LocationCode="${destinationArray[i].toUpperCase()}"></DestinationLocation>
  </OriginDestinationInformation>''';
      }
    }

    // Build passenger XML
    String passengerArray = '';
    if (adult != 0) {
      passengerArray +=
          '<PassengerTypeQuantity Code="ADT" Quantity="$adult"></PassengerTypeQuantity>';
    }
    if (child != 0) {
      passengerArray +=
          '<PassengerTypeQuantity Code="CHD" Quantity="$child"></PassengerTypeQuantity>';
    }
    if (infant != 0) {
      passengerArray +=
          '<PassengerTypeQuantity Code="INF" Quantity="$infant"></PassengerTypeQuantity>';
    }

    final randomString = "-8586704355136787339";

    // Build the complete XML request
    final request = '''<Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/">
  <Header/>
  <Body>
    <AirLowFareSearch xmlns="http://zapways.com/air/ota/3.0">
      <airLowFareSearchRQ EchoToken="$randomString" Target="$Target" Version="$Version" xmlns="http://www.opentravel.org/OTA/2003/05">
        <POS>
          <Source ERSP_UserID="$ERSP_UserID">
            <RequestorID Type="$Type" ID="$ID" MessagePassword="$MessagePassword" />
          </Source>
        </POS>
        $originDestination
        <TravelerInfoSummary>
          <AirTravelerAvail>
            $passengerArray
          </AirTravelerAvail>
        </TravelerInfoSummary>
      </airLowFareSearchRQ>
    </AirLowFareSearch>
  </Body>
</Envelope>''';

    // Make the API call using ApiClient
    final response = await _apiClient.request(
      url: link,
      method: HttpMethod.POST,
      serviceName: 'AIRBLUE SEARCH',
      body: request,
      contentType: ContentType.XML,
      useSSL: true,
      convertXmlToJson: true,
      printRequestBody: printRequest,
      printResponseBody: printResponse,
    );

    if (response.isSuccess && response.responseJson != null) {
      return response.responseJson!;
    } else {
      throw ApiException(
        message: response.message,
        statusCode: response.statusCode,
        errors: {},
      );
    }
  }

  /// Save AirBlue booking to backend
  Future<Map<String, dynamic>> saveAirBlueBooking({
    required BookingFlightController bookingController,
    required AirBlueFlight flight,
    required AirBlueFlight? returnFlight,
    required List<AirBlueFlight>? multicityFlights,
    required String token,
    required String pnr,
    required String finalPrice,
    required int pnrStatus,
    bool printRequest = true,
    bool printResponse = false,
  }) async {
    try {
      // Prepare booking info
      final bookingInfo = {
        "bfname": bookingController.firstNameController.text,
        "blname": bookingController.lastNameController.text,
        "bemail": bookingController.emailController.text,
        "bphno": bookingController.phoneController.text,
        "badd": "b",
        "bcity": "a",
        "final_price": flight.price.toString(),
        "client_email": bookingController.emailController.text,
        "client_phone": bookingController.phoneController.text,
      };

      // Prepare adults data
      final adults = bookingController.adults.map((adult) {
        return {
          "title": adult.titleController.text,
          "first_name": adult.firstNameController.text,
          "last_name": adult.lastNameController.text,
          "dob": adult.dateOfBirthController.text,
          "nationality": adult.nationalityController.text,
          "passport": adult.passportCnicController.text,
          "passport_expiry": adult.passportExpiryController.text,
          "cnic": adult.passportCnicController.text,
          "pnr": pnr
        };
      }).toList();

      // Prepare children data
      final children = bookingController.children.map((child) {
        return {
          "title": child.titleController.text,
          "first_name": child.firstNameController.text,
          "last_name": child.lastNameController.text,
          "dob": child.dateOfBirthController.text,
          "nationality": child.nationalityController.text,
          "passport": child.passportCnicController.text,
          "passport_expiry": child.passportExpiryController.text,
          "cnic": child.passportCnicController.text,
        };
      }).toList();

      // Prepare infants data
      final infants = bookingController.infants.map((infant) {
        return {
          "title": infant.titleController.text,
          "first_name": infant.firstNameController.text,
          "last_name": infant.lastNameController.text,
          "dob": infant.dateOfBirthController.text,
          "nationality": infant.nationalityController.text,
          "passport": "a",
          "passport_expiry": "a",
          "cnic": "a",
        };
      }).toList();

      // Prepare flights data
      final flights = <Map<String, dynamic>>[];

      // Only add outbound flight if it's not a multicity trip
      if (multicityFlights == null || multicityFlights.isEmpty) {
        flights.add(_prepareFlightData(flight, "One-Way"));
      }
      // Add return flight if exists
      if (returnFlight != null) {
        flights.add(_prepareFlightData(returnFlight, "Return"));
      }

      // Add multicity flights if exists
      if (multicityFlights != null && multicityFlights.isNotEmpty) {
        for (var i = 0; i < multicityFlights.length; i++) {
          flights.add(_prepareFlightData(multicityFlights[i], "Flight ${i + 1}"));
        }
      }
      final ApiServiceMargin apiServiceMargin = Get.put(ApiServiceMargin());
       // Prefer cached margin data if available (set during search in controller)
      Map<String, dynamic> marginData = _cachedMarginData ?? {};
      if (marginData.isEmpty) {
        try {

          marginData = await apiServiceMargin.getMargin('PA', 'blue', "Air Blue");
        } catch (e) {
          // Margin fetch failed, using defaults
        }
      }
      final calculatedSellingPrice = apiServiceMargin.calculatePriceWithMargin(double.parse(finalPrice), marginData);



      // Prepare final request body
      final requestBody = {
        "booking_info": bookingInfo,
        "adults": adults,
        "children": children,
        "infants": infants,
        "flights": flights,
        "pnr": pnr,
        "buyingPrice": finalPrice,
        "sellingPrice": calculatedSellingPrice,
        "pnrStatus": pnrStatus,
        "booking_from": "1",
        "gds": "blue"
      };

      // Make the API call using ApiClient
      final response = await _apiClient.request(
        url: 'https://readyflights.pk/api/flight-booking',
        method: HttpMethod.POST,
        serviceName: 'AIRBLUE SAVE BOOKING',
        body: jsonEncode(requestBody),
        headers: {
          'Authorization': 'Bearer $token',
        },
        contentType: ContentType.JSON,
        printRequestBody: printRequest,
        printResponseBody: printResponse,
      );

      if (response.isSuccess) {
        if (response.responseJson != null) {
          return response.responseJson!;
        }
        return {'status': 'success'};
      } else {
        throw ApiException(
          message: response.message,
          statusCode: response.statusCode,
          errors: {},
        );
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error occurred';
      if (e.response != null) {
        try {
          final errorData = e.response!.data is String
              ? jsonDecode(e.response!.data)
              : e.response!.data;

          if (errorData is Map && errorData['errors'] != null) {
            errorMessage = (errorData['errors'] as Map)
                .entries
                .map((e) => '${e.key}: ${e.value}')
                .join('\n');
          } else if (errorData is Map && errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (_) {
          errorMessage = e.response?.data?.toString() ?? 'Unknown error';
        }
      }
      throw ApiException(
        message: errorMessage,
        statusCode: e.response?.statusCode,
        errors: {},
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: e.toString(), statusCode: null, errors: {});
    }
  }

  /// Create AirBlue PNR
  Future<Map<String, dynamic>> createAirBluePNR({
    required AirBlueFlight flight,
    required AirBlueFlight? returnFlight,
    required List<AirBlueFlight>? multicityFlights,
    required BookingFlightController bookingController,
    required String clientEmail,
    required String clientPhone,
    required bool isDomestic,
    required AirBlueFareOption? outboundFareOption,
    required AirBlueFareOption? returnFareOption,
    required List<AirBlueFareOption?>? multicityFareOptions,
    bool printRequest = false,
    bool printResponse = false,
  }) async {
    try {
      // Prepare booking class array (selected flights)
      final bookingClass = <Map<String, dynamic>>[];

      // Only add outbound flight if it's not a multicity trip
      if (multicityFlights == null || multicityFlights.isEmpty) {
        bookingClass.add(outboundFareOption!.rawData);
      }

      // Add return flight if exists
      if (returnFlight != null) {
        bookingClass.add(returnFareOption!.rawData);
      }

      // Add multicity flights if exists
      if (multicityFlights != null && multicityFlights.isNotEmpty) {
        for (var multicityFlight in multicityFareOptions!) {
          bookingClass.add(multicityFlight!.rawData);
        }
      }

      // Prepare adults, children, infants data
      final adults = bookingController.adults
          .map((adult) => _prepareTravelerData(adult, 'ADT', clientEmail, clientPhone))
          .toList();

      final children = bookingController.children
          .map((child) => _prepareTravelerData(child, 'CHD', clientEmail, clientPhone))
          .toList();

      final infants = bookingController.infants
          .map((infant) => _prepareTravelerData(infant, 'INF', clientEmail, clientPhone))
          .toList();

      // Generate random string for EchoToken
      final randomString = _generateRandomString(32);

      // Build the destination XML for each flight
      String destinationXml = '';
      String ptcText = '';
      int rphCounter = 1;

      for (var flightData in bookingClass) {
        final originDestOption = flightData['AirItinerary']['OriginDestinationOptions']['OriginDestinationOption'];
        final flightSegment = originDestOption['FlightSegment'];

        // Get the selected fare option for this flight
        AirBlueFareOption? selectedFareOption;

        // For outbound flight (first flight in bookingClass)
        if (flightData == bookingClass.first && outboundFareOption != null) {
          selectedFareOption = outboundFareOption;
        }
        // For return flight (second flight in bookingClass)
        else if (returnFlight != null && flightData == bookingClass[1] && returnFareOption != null) {
          selectedFareOption = returnFareOption;
        }
        // For multicity flights
        else if (multicityFareOptions != null && multicityFareOptions.isNotEmpty) {
          final index = bookingClass.indexOf(flightData);
          if (index < multicityFareOptions.length) {
            selectedFareOption = multicityFareOptions[index];
          }
        }

        // Build destination XML
        destinationXml += '''
<OriginDestinationOption RPH="$rphCounter">
  <FlightSegment 
    DepartureDateTime="${flightSegment['DepartureDateTime']}" 
    ArrivalDateTime="${flightSegment['ArrivalDateTime']}" 
    StopQuantity="${flightSegment['StopQuantity']}" 
    RPH="$rphCounter" 
    FlightNumber="${flightSegment['FlightNumber']}" 
    ResBookDesigCode="${flightSegment['ResBookDesigCode']}" 
    Status="${flightSegment['Status']}">
    <DepartureAirport LocationCode="${flightSegment['DepartureAirport']['LocationCode']}"/>
    <ArrivalAirport LocationCode="${flightSegment['ArrivalAirport']['LocationCode']}"/>
    <OperatingAirline Code="${flightSegment['OperatingAirline']['Code']}"/>
    <Equipment AirEquipType="${flightSegment['Equipment']['AirEquipType']}"/>
    <MarketingAirline Code="${flightSegment['MarketingAirline']['Code']}"/>
  </FlightSegment>
</OriginDestinationOption>''';

        // Build PTC_FareBreakdown XML from the original flight data
        final pricingInfo = flightData['AirItineraryPricingInfo'];
        final ptcBreakdowns = pricingInfo['PTC_FareBreakdowns']['PTC_FareBreakdown'];

        // Handle single or multiple PTC breakdowns
        final List<dynamic> ptcList = ptcBreakdowns is List ? ptcBreakdowns : [ptcBreakdowns];

        for (var ptc in ptcList) {
          final ptcCode = ptc['PassengerTypeQuantity']['Code'];
          final ptcQty = ptc['PassengerTypeQuantity']['Quantity'];
          final baseFare = ptc['PassengerFare']['BaseFare'];

          // Build taxes XML if exists
          String taxesXml = '';
          String taxesAmountAttr = '';
          if (ptc['PassengerFare']['Taxes'] != null) {
            final taxes = ptc['PassengerFare']['Taxes'];
            taxesAmountAttr = 'Amount="${taxes['Amount']}"';

            final taxList = taxes['Tax'] is List ? taxes['Tax'] : [taxes['Tax']];
            for (var tax in taxList) {
              if (tax != null) {
                taxesXml += '''
<Tax TaxCode="${tax['TaxCode']}" CurrencyCode="${tax['CurrencyCode']}" Amount="${tax['Amount']}" />''';
              }
            }
          }

          // Build fees XML if exists
          String feesXml = '';
          String feesAmountAttr = '';
          if (ptc['PassengerFare']['Fees'] != null) {
            final fees = ptc['PassengerFare']['Fees'];
            feesAmountAttr = 'Amount="${fees['Amount']}"';

            final feeList = fees['Fee'] is List ? fees['Fee'] : [fees['Fee']];
            for (var fee in feeList) {
              if (fee != null) {
                feesXml += '''
<Fee FeeCode="${fee['FeeCode']}" CurrencyCode="${fee['CurrencyCode']}" Amount="${fee['Amount']}" />''';
              }
            }
          }

          // Build fare info XML
          String fareInfoXml = '';
          dynamic fareInfo;
          if (selectedFareOption != null) {
            final allFareInfos = ptc['FareInfo'] is List ? ptc['FareInfo'] : [ptc['FareInfo']];
            for (var info in allFareInfos) {
              if (info['FareInfo']?['FareBasisCode'] == selectedFareOption.fareBasisCode) {
                fareInfo = info;
                break;
              }
            }
          }

          // Fallback to first fare info if no match found
          fareInfo ??= ptc['FareInfo'] is List ? ptc['FareInfo'][0] : ptc['FareInfo'];

          if (fareInfo != null) {
            // Build fare info taxes if exists
            String fareInfoTaxesXml = '';
            String fareInfoTaxesAmountAttr = '';
            if (fareInfo['PassengerFare']?['Taxes'] != null) {
              final fareInfoTaxes = fareInfo['PassengerFare']['Taxes'];
              fareInfoTaxesAmountAttr = 'Amount="${fareInfoTaxes['Amount']}"';

              final fareInfoTaxList = fareInfoTaxes['Tax'] is List
                  ? fareInfoTaxes['Tax']
                  : [fareInfoTaxes['Tax']];
              for (var tax in fareInfoTaxList) {
                if (tax != null) {
                  fareInfoTaxesXml += '''
<Tax TaxCode="${tax['TaxCode']}" CurrencyCode="${tax['CurrencyCode']}" Amount="${tax['Amount']}" />''';
                }
              }
            }

            // Build fare info fees if exists
            String fareInfoFeesXml = '';
            String fareInfoFeesAmountAttr = '';
            if (fareInfo['PassengerFare']?['Fees'] != null) {
              final fareInfoFees = fareInfo['PassengerFare']['Fees'];
              fareInfoFeesAmountAttr = 'Amount="${fareInfoFees['Amount']}"';

              final fareInfoFeeList = fareInfoFees['Fee'] is List
                  ? fareInfoFees['Fee']
                  : [fareInfoFees['Fee']];
              for (var fee in fareInfoFeeList) {
                if (fee != null) {
                  fareInfoFeesXml += '''
<Fee FeeCode="${fee['FeeCode']}" CurrencyCode="${fee['CurrencyCode']}" Amount="${fee['Amount']}" />''';
                }
              }
            }

            fareInfoXml = '''
<FareInfo>
  <DepartureDate>${fareInfo['DepartureDate']?['\$t'] ?? flightSegment['DepartureDateTime']}</DepartureDate>
  <DepartureAirport LocationCode="${fareInfo['DepartureAirport']?['LocationCode'] ?? flightSegment['DepartureAirport']['LocationCode']}"/>
  <ArrivalAirport LocationCode="${fareInfo['ArrivalAirport']?['LocationCode'] ?? flightSegment['ArrivalAirport']['LocationCode']}"/>
  <FareInfo FareBasisCode="${selectedFareOption?.fareInfoRawData['FareInfo']?['FareBasisCode'] ?? flightSegment['ResBookDesigCode']}"/>
  <PassengerFare>
    <BaseFare CurrencyCode="${fareInfo['PassengerFare']?['BaseFare']?['CurrencyCode'] ?? baseFare['CurrencyCode']}" 
              Amount="${fareInfo['PassengerFare']?['BaseFare']?['Amount'] ?? baseFare['Amount']}" />''';

            if (fareInfoTaxesAmountAttr.isNotEmpty) {
              fareInfoXml += '''
    <Taxes $fareInfoTaxesAmountAttr>
      $fareInfoTaxesXml
    </Taxes>''';
            }

            if (fareInfoFeesAmountAttr.isNotEmpty) {
              fareInfoXml += '''
    <Fees $fareInfoFeesAmountAttr>
      $fareInfoFeesXml
    </Fees>''';
            }

            fareInfoXml += '''
    <TotalFare CurrencyCode="${fareInfo['PassengerFare']?['TotalFare']?['CurrencyCode'] ?? ptc['PassengerFare']['TotalFare']['CurrencyCode']}" 
               Amount="${fareInfo['PassengerFare']?['TotalFare']?['Amount'] ?? ptc['PassengerFare']['TotalFare']['Amount']}" />
  </PassengerFare>                 
</FareInfo>''';
          }

          ptcText += '''
<PTC_FareBreakdown>
  <PassengerTypeQuantity Code="$ptcCode" Quantity="$ptcQty"/>
  <PassengerFare>
    <BaseFare CurrencyCode="${baseFare['CurrencyCode']}" Amount="${baseFare['Amount']}" />''';

          if (taxesAmountAttr.isNotEmpty) {
            ptcText += '''
    <Taxes $taxesAmountAttr>
      $taxesXml
    </Taxes>''';
          }

          if (feesAmountAttr.isNotEmpty) {
            ptcText += '''
    <Fees $feesAmountAttr>
      $feesXml
    </Fees>''';
          }

          ptcText += '''
    <TotalFare CurrencyCode="${ptc['PassengerFare']['TotalFare']['CurrencyCode']}" 
               Amount="${ptc['PassengerFare']['TotalFare']['Amount']}"/>
  </PassengerFare>
  $fareInfoXml
</PTC_FareBreakdown>''';
        }

        rphCounter++;
      }

      // Build travelers XML
      String paxXml = '';
      int paxItr = 0;
      String doctype = isDomestic ? "5" : "2";

      // Add adults
      for (var adult in adults) {
        paxItr++;
        paxXml += '''
<AirTraveler BirthDate="${adult['birthDate']}">
  <PersonName>
    <GivenName>${adult['firstName']}</GivenName>
    <Surname>${adult['lastName']}</Surname>
    <NameTitle>${adult['title']}</NameTitle>
  </PersonName>
  <Telephone PhoneLocationType="10" CountryAccessCode="92" PhoneNumber="$clientPhone" />
  <Email>$clientEmail</Email>
  <CustLoyalty />
  <Document DocID="${adult['passport']}" DocType="$doctype" 
            BirthDate="${adult['birthDate']}" 
            ExpireDate="${adult['passportExpiry']}" 
            DocIssueCountry="PK" 
            DocHolderNationality="PK" />
  <PassengerTypeQuantity Code="ADT" Quantity="1" />
  <TravelerRefNumber RPH="$paxItr" />
</AirTraveler>''';
      }

      // Add children
      for (var child in children) {
        paxItr++;
        paxXml += '''
<AirTraveler BirthDate="${child['birthDate']}">
  <PersonName>
    <GivenName>${child['firstName']}</GivenName>
    <Surname>${child['lastName']}</Surname>
    <NameTitle>${child['title']}</NameTitle>
  </PersonName>
  <Telephone PhoneLocationType="10" CountryAccessCode="92" PhoneNumber="$clientPhone" />
  <Email>$clientEmail</Email>
  <CustLoyalty />
  <Document DocID="${child['passport']}" DocType="$doctype" 
            BirthDate="${child['birthDate']}" 
            ExpireDate="${child['passportExpiry']}" 
            DocIssueCountry="PK" 
            DocHolderNationality="PK" />
  <PassengerTypeQuantity Code="CHD" Quantity="1" />
  <TravelerRefNumber RPH="$paxItr" />
</AirTraveler>''';
      }

      // Add infants
      for (var infant in infants) {
        paxItr++;
        paxXml += '''
<AirTraveler BirthDate="${infant['birthDate']}">
  <PersonName>
    <GivenName>${infant['firstName']}</GivenName>
    <Surname>${infant['lastName']}</Surname>
    <NameTitle></NameTitle>
  </PersonName>
  <Telephone PhoneLocationType="10" CountryAccessCode="92" PhoneNumber="$clientPhone" />
  <Email>$clientEmail</Email>
  <CustLoyalty />
  <Document DocID="${infant['passport']}" DocType="$doctype" 
            BirthDate="${infant['birthDate']}" 
            ExpireDate="${infant['passportExpiry']}" 
            DocIssueCountry="PK" 
            DocHolderNationality="PK" />
  <PassengerTypeQuantity Code="INF" Quantity="1" />
  <TravelerRefNumber RPH="$paxItr" />
</AirTraveler>''';
      }

      // Build complete XML request
      final request = '''<Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/">
  <Header/>
  <Body>
    <AirBook xmlns="http://zapways.com/air/ota/3.0">
      <airBookRQ EchoToken="$randomString" Target="$Target" Version="$Version" xmlns="http://www.opentravel.org/OTA/2003/05">
        <POS>
          <Source ERSP_UserID="$ERSP_UserID">
            <RequestorID Type="$Type" ID="$ID" MessagePassword="$MessagePassword" />
          </Source>
        </POS>
        <AirItinerary>
          <OriginDestinationOptions>
            $destinationXml
          </OriginDestinationOptions>
        </AirItinerary>
        <PriceInfo>
          <PTC_FareBreakdowns>
            $ptcText
          </PTC_FareBreakdowns>
        </PriceInfo>
        <TravelerInfo>
          $paxXml
        </TravelerInfo>
      </airBookRQ>
    </AirBook>
  </Body>
</Envelope>''';

      // Make the API call using ApiClient
      final response = await _apiClient.request(
        url: link,
        method: HttpMethod.POST,
        serviceName: 'AIRBLUE CREATE PNR',
        body: request,
        contentType: ContentType.XML,
        useSSL: true,
        convertXmlToJson: true,
        printRequestBody: printRequest,
        printResponseBody: printResponse,
      );

      if (!response.isSuccess || response.responseJson == null) {
        throw ApiException(
          message: response.message,
          statusCode: response.statusCode,
          errors: {},
        );
      }

      final jsonResponse = response.responseJson!;

      // Parse the pricing information
      List<AirBluePNRPricing> pnrPricing = [];
      try {
        final airReservation = jsonResponse['soap\$Envelope']?['soap\$Body']?['AirBookResponse']
            ?['AirBookResult']?['AirReservation'];

        if (airReservation != null) {
          final priceInfo = airReservation['PriceInfo'];
          if (priceInfo != null) {
            final ptcBreakdowns = priceInfo['PTC_FareBreakdowns']?['PTC_FareBreakdown'];

            if (ptcBreakdowns != null) {
              if (ptcBreakdowns is List) {
                for (var breakdown in ptcBreakdowns) {
                  pnrPricing.add(AirBluePNRPricing.fromJson(breakdown));
                }
              } else if (ptcBreakdowns is Map) {
                pnrPricing.add(AirBluePNRPricing.fromJson(ptcBreakdowns));
              }
            }
          }
        }
      } catch (e) {}

      // Safely extract PNR and Instance
      String? pnr;
      String? Instance;
      try {
        final airReservation = jsonResponse['soap\$Envelope']?['soap\$Body']?['AirBookResponse']
            ?['AirBookResult']?['AirReservation'];

        if (airReservation != null) {
          final bookingRefs = airReservation['BookingReferenceID'];
          if (bookingRefs != null) {
            final bookingRef = (bookingRefs is List) ? bookingRefs[0] : bookingRefs;
            if (bookingRef != null) {
              pnr = bookingRef['ID']?.toString();
              Instance = bookingRef['Instance']?.toString();
            }
          }
        }
      } catch (e) {}

      // Safely extract ticketing information
      String? timeLimit;
      try {
        final airReservation = jsonResponse['soap\$Envelope']?['soap\$Body']?['AirBookResponse']
            ?['AirBookResult']?['AirReservation'];

        if (airReservation != null) {
          final ticketing = airReservation['Ticketing'];
          if (ticketing != null) {
            if (ticketing is List && ticketing.isNotEmpty) {
              timeLimit = ticketing[0]?['TicketTimeLimit']?.toString();
            } else if (ticketing is Map) {
              timeLimit = ticketing['TicketTimeLimit']?.toString();
            }
          }
        }
      } catch (e) {}

      // Extract total fare safely
      String? totalFare;
      try {
        final airReservation = jsonResponse['soap\$Envelope']?['soap\$Body']?['AirBookResponse']
            ?['AirBookResult']?['AirReservation'];

        if (airReservation != null) {
          final priceInfo = airReservation['PriceInfo'];
          if (priceInfo != null) {
            totalFare = priceInfo['ItinTotalFare']?['TotalFare']?['Amount']?.toString();
          }
        }
      } catch (e) {}

      // Determine booking status (1 for success, 0 for failure)
      final successElement = jsonResponse['soap\$Envelope']?['soap\$Body']?['AirBookResponse']
          ?['AirBookResult']?['Success'];
      final status = (successElement != null && pnr != null && pnr.isNotEmpty) ? 1 : 0;

      // Add the pricing info to the return map
      final result = {
        ...jsonResponse,
        'pnrPricing': pnrPricing.map((p) => p.toJson()).toList(),
        'rawPricingObjects': pnrPricing,
        'pnr': pnr,
        "Instance": Instance,
        'timeLimit': timeLimit,
        'pnrJson': jsonResponse,
        'finalPrice': totalFare,
        'status': status,
      };

      return result;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to create PNR: $e',
        statusCode: null,
        errors: {},
      );
    }
  }

  /// Get AirBlue seat map
  Future<Map<String, dynamic>> getAirBlueSeatMap({
    required String departureDateTime,
    required String flightNumber,
    required String departureAirport,
    required String arrivalAirport,
    required String operatingAirlineCode,
    required String pnr,
    required String instance,
    required String fareType,
    required String resBookDesigCode,
    required String cabinClass,
    bool printRequest = false,
    bool printResponse = false,
  }) async {
    // Extract date and time, keeping original time instead of forcing 00:00:00
    String formattedDateTime;
    if (departureDateTime.contains('T')) {
      formattedDateTime = departureDateTime;
    } else {
      formattedDateTime = '${departureDateTime}T00:00:00';
    }

    final request = '''<?xml version="1.0"?>
<Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/">
  <Header/>
  <Body>
    <AirSeatMap xmlns="http://zapways.com/air/ota/3.0">
      <airSeatMapRQ xmlns="http://www.opentravel.org/OTA/2003/05" Target="$Target" Version="$Version">
        <POS>
          <Source ERSP_UserID="$ERSP_UserID">
            <RequestorID Type="$Type" ID="$ID" MessagePassword="$MessagePassword"/>
          </Source>
        </POS>
        <SeatMapRequests>
          <SeatMapRequest>
            <FlightSegmentInfo DepartureDateTime="$formattedDateTime" FlightNumber="$flightNumber" FareType="$fareType" ResBookDesigCode="$resBookDesigCode" CabinClass="$cabinClass">
              <DepartureAirport LocationCode="$departureAirport"/>
              <ArrivalAirport LocationCode="$arrivalAirport"/>
              <OperatingAirline Code="$operatingAirlineCode" FlightNumber="$flightNumber"/>
            </FlightSegmentInfo>
          </SeatMapRequest>
        </SeatMapRequests>
        <BookingReferenceID Instance="$instance" ID="$pnr"/>
      </airSeatMapRQ>
    </AirSeatMap>
  </Body>
</Envelope>''';

    // Make the API call using ApiClient
    final response = await _apiClient.request(
      url: link,
      method: HttpMethod.POST,
      serviceName: 'AIRBLUE SEAT MAP',
      body: request,
      contentType: ContentType.XML,
      useSSL: true,
      convertXmlToJson: true,
      printRequestBody: printRequest,
      printResponseBody: printResponse,
    );

    if (response.isSuccess && response.responseJson != null) {
      return response.responseJson!;
    } else {
      throw ApiException(
        message: 'Failed to get seat map: ${response.message}',
        statusCode: response.statusCode,
        errors: {},
      );
    }
  }

  /// Update AirBlue seats
  Future<Map<String, dynamic>> updateAirBlueSeats({
    required String pnr,
    required String instance,
    required List<Map<String, dynamic>> seatRequests,
    Map<String, dynamic>? pnrResponse,
    bool printRequest = false,
    bool printResponse = false,
  }) async {
    // Extract TravelerRefNumber RPH tokens from PNR response
    Map<int, String> travelerRPHTokens = {};
    if (pnrResponse != null) {
      try {
        final airReservation = pnrResponse['soap\$Envelope']?['soap\$Body']?['AirBookResponse']?['AirBookResult']?['AirReservation'] ??
            pnrResponse['AirReservation'] ??
            pnrResponse;

        final travelerInfo = airReservation['TravelerInfo'];
        if (travelerInfo != null) {
          final airTravelers = travelerInfo['AirTraveler'];
          if (airTravelers != null) {
            // Handle both single traveler and multiple travelers
            final travelersList = airTravelers is List ? airTravelers : [airTravelers];

            for (int i = 0; i < travelersList.length; i++) {
              final traveler = travelersList[i];
              final travelerRefNumber = traveler['TravelerRefNumber'];

              if (travelerRefNumber != null) {
                // Handle both single TravelerRefNumber and array
                final refNumberList = travelerRefNumber is List ? travelerRefNumber : [travelerRefNumber];

                for (var refNum in refNumberList) {
                  final rph = refNum['RPH']?.toString();
                  if (rph != null && rph.isNotEmpty) {
                    travelerRPHTokens[i] = rph;
                    break;
                  }
                }
              }
            }
          }
        }
      } catch (e) {}
    }

    String seatRequestsXml = '';
    for (var seatRequest in seatRequests) {
      // Get traveler index (convert from 1-based to 0-based)
      final travelerIndex = (int.tryParse(seatRequest['travelerRefNumber'].toString()) ?? 1) - 1;

      final travelerRPH = seatRequest['travelerRefNumberRPH'] ??
          travelerRPHTokens[travelerIndex] ??
          seatRequest['travelerRefNumber'].toString();

      final fullSeatNumber = seatRequest['seatNumber'].toString();
      final seatLetter = fullSeatNumber.replaceAll(RegExp(r'[0-9]'), '');

      seatRequestsXml += '''
                <SeatRequest SeatNumber="$seatLetter" RowNumber="${seatRequest['rowNumber']}" TravelerRefNumberRPHList="$travelerRPH" FlightRefNumberRPHList="${seatRequest['flightRefNumber']}"/>''';
    }

    final request = '''<Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/">
  <Header/>
  <Body>
    <AirBookModify xmlns="http://zapways.com/air/ota/3.0">
      <airBookModifyRQ Target="$Target" Version="$Version" xmlns="http://www.opentravel.org/OTA/2003/05">
        <POS>
          <Source ERSP_UserID="$ERSP_UserID">
            <RequestorID Type="$Type" ID="$ID" MessagePassword="$MessagePassword"/>
          </Source>
        </POS>
        <AirBookModifyRQ ModificationType="5">
          <TravelerInfo>
            <SpecialReqDetails>
              <SeatRequests>
                $seatRequestsXml
              </SeatRequests>
            </SpecialReqDetails>
          </TravelerInfo>
        </AirBookModifyRQ>
        <AirReservation>
          <BookingReferenceID Instance="$instance" ID="$pnr"/>
        </AirReservation>
      </airBookModifyRQ>
    </AirBookModify>
  </Body>
</Envelope>''';

    // Make the API call using ApiClient
    final response = await _apiClient.request(
      url: link,
      method: HttpMethod.POST,
      serviceName: 'AIRBLUE UPDATE SEATS',
      body: request,
      contentType: ContentType.XML,
      useSSL: true,
      convertXmlToJson: true,
      printRequestBody: printRequest,
      printResponseBody: printResponse,
    );

    if (response.isSuccess && response.responseJson != null) {
      return response.responseJson!;
    } else {
      throw ApiException(
        message: 'Failed to update seats: ${response.message}',
        statusCode: response.statusCode,
        errors: {},
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // HELPER METHODS
  // ─────────────────────────────────────────────────────────────────────────────

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  Map<String, dynamic> _prepareTravelerData(
    TravelerInfo traveler,
    String type,
    String clientEmail,
    String clientPhone,
  ) {
    return {
      'title': traveler.titleController.text,
      'firstName': traveler.firstNameController.text,
      'lastName': traveler.lastNameController.text,
      'birthDate': traveler.dateOfBirthController.text,
      'passport': traveler.passportCnicController.text,
      'passportExpiry': traveler.passportExpiryController.text,
      'type': type,
    };
  }

  Map<String, dynamic> _prepareFlightData(AirBlueFlight flight, String type) {
    // Handle all segments (not just first one)
    final segments = flight.segmentInfo.isNotEmpty
        ? flight.segmentInfo
        : [
            FlightSegmentInfo(
              bookingCode: 'Y',
              cabinCode: 'Y',
              mealCode: 'M',
              seatsAvailable: '',
            )
          ];

    // Handle all legs (not just first one)
    final legs = flight.legSchedules.isNotEmpty
        ? flight.legSchedules
        : [
            {
              'departure': {'airport': '', 'time': '', 'dateTime': ''},
              'arrival': {'airport': '', 'time': '', 'dateTime': ''},
            }
          ];

    // For multicity, we need to include all flight segments in the data
    if (type.startsWith('Flight')) {
      return {
        "segments": legs.map((leg) {
          final departureDateTime = DateTime.parse(leg['departure']['dateTime']);
          final arrivalDateTime = DateTime.parse(leg['arrival']['dateTime']);
          final duration = arrivalDateTime.difference(departureDateTime);
          final segment = segments.length > legs.indexOf(leg) ? segments[legs.indexOf(leg)] : segments.first;

          return {
            "departure": {
              "airport": leg['departure']['airport'],
              "date": departureDateTime.toIso8601String().split('T')[0],
              "time":
                  "${departureDateTime.hour.toString().padLeft(2, '0')}:${departureDateTime.minute.toString().padLeft(2, '0')}",
              "terminal": leg['departure']['terminal'] ?? 'Main',
            },
            "arrival": {
              "airport": leg['arrival']['airport'],
              "date": arrivalDateTime.toIso8601String().split('T')[0],
              "time":
                  "${arrivalDateTime.hour.toString().padLeft(2, '0')}:${arrivalDateTime.minute.toString().padLeft(2, '0')}",
              "terminal": leg['arrival']['terminal'] ?? 'Main',
            },
            "flight_number": flight.id.split('-').first,
            "airline_code": flight.airlineCode,
            "operating_flight_number": flight.id.split('-').first,
            "operating_airline_code": flight.airlineCode,
            "cabin_class": _getCabinClassName(segment.cabinCode),
            "sub_class": segment.cabinCode,
            "hand_baggage": "7kg",
            "check_baggage": "${flight.baggageAllowance.weight} ${flight.baggageAllowance.unit}",
            "meal": segment.mealCode == 'M' ? 'Meal' : 'None',
            "layover": legs.length > 1 ? "Yes" : "None",
            "duration": "${duration.inHours}h ${duration.inMinutes.remainder(60)}m",
          };
        }).toList(),
        "type": type,
      };
    } else {
      // For one-way/return flights, maintain backward compatibility
      final firstLeg = legs.first;
      final departureDateTime = DateTime.parse(firstLeg['departure']['dateTime']);
      final arrivalDateTime = DateTime.parse(firstLeg['arrival']['dateTime']);
      final duration = arrivalDateTime.difference(departureDateTime);
      final segment = segments.first;

      return {
        "departure": {
          "airport": firstLeg['departure']['airport'],
          "date": departureDateTime.toIso8601String().split('T')[0],
          "time":
              "${departureDateTime.hour.toString().padLeft(2, '0')}:${departureDateTime.minute.toString().padLeft(2, '0')}",
          "terminal": firstLeg['departure']['terminal'] ?? 'Main',
        },
        "arrival": {
          "airport": firstLeg['arrival']['airport'],
          "date": arrivalDateTime.toIso8601String().split('T')[0],
          "time":
              "${arrivalDateTime.hour.toString().padLeft(2, '0')}:${arrivalDateTime.minute.toString().padLeft(2, '0')}",
          "terminal": firstLeg['arrival']['terminal'] ?? 'Main',
        },
        "flight_number": flight.id.split('-').first,
        "airline_code": flight.airlineCode,
        "operating_flight_number": flight.id.split('-').first,
        "operating_airline_code": flight.airlineCode,
        "cabin_class": _getCabinClassName(segment.cabinCode),
        "sub_class": segment.cabinCode,
        "hand_baggage": "7kg",
        "check_baggage": "${flight.baggageAllowance.weight} ${flight.baggageAllowance.unit}",
        "meal": segment.mealCode == 'M' ? 'Meal' : 'None',
        "layover": legs.length > 1 ? "Yes" : "None",
        "duration": "${duration.inHours}h ${duration.inMinutes.remainder(60)}m",
        "type": type,
      };
    }
  }

  String _getCabinClassName(String cabinCode) {
    switch (cabinCode.toUpperCase()) {
      case 'F':
        return 'First Class';
      case 'C':
        return 'Business Class';
      case 'J':
        return 'Premium Business';
      case 'W':
        return 'Premium Economy';
      case 'S':
        return 'Premium Economy';
      case 'Y':
        return 'Economy';
      default:
        return 'Economy';
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic> errors;

  ApiException({required this.message, this.statusCode, required this.errors});

  @override
  String toString() => message;
}
