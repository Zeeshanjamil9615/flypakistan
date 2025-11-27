// services/api_service_emirates.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart' as xml;

class _EmiratesSegment {
  final String origin;
  final String destination;
  final String date;

  const _EmiratesSegment({
    required this.origin,
    required this.destination,
    required this.date,
  });
}

class OfferPricingItem {
  final String offerItemId;
  final String passengerRefs;

  const OfferPricingItem({
    required this.offerItemId,
    required this.passengerRefs,
  });
}

class OfferPricingEntry {
  final String offerId;
  final String owner;
  final String responseId;
  final List<OfferPricingItem> items;

  const OfferPricingEntry({
    required this.offerId,
    required this.owner,
    required this.responseId,
    required this.items,
  });
}

class ApiServiceEmirates {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (status) => status! < 500,
    ),
  );

  Future<Map<String, dynamic>> searchFlights({
    required int type,
    required String origin,
    required String destination,
    required String depDate,
    required int adult,
    required int child,
    required int infant,
    required String cabin,
    List<Map<String, String>>? multiCitySegments,
  }) async {
    try {
      final segments = <_EmiratesSegment>[];

      if (multiCitySegments != null && multiCitySegments.isNotEmpty) {
        for (final segment in multiCitySegments) {
          final originCode =
              (segment['origin'] ?? segment['from'] ?? segment['departure'] ?? '').trim().toUpperCase();
          final destinationCode =
              (segment['destination'] ?? segment['to'] ?? segment['arrival'] ?? '').trim().toUpperCase();
          final dateValue =
              (segment['date'] ?? segment['departureDate'] ?? segment['depDate'] ?? '').trim();

          if (originCode.isEmpty || destinationCode.isEmpty || dateValue.isEmpty) {
            print(
                '⚠️ Emirates search: Skipping incomplete multi-city segment -> origin: "$originCode", destination: "$destinationCode", date: "$dateValue"');
            continue;
          }

          segments.add(
            _EmiratesSegment(
              origin: originCode,
              destination: destinationCode,
              date: dateValue,
            ),
          );
        }
      }

      if (segments.isEmpty) {
        final originsList = origin
            .split(',')
            .map((code) => code.trim().toUpperCase())
            .where((code) => code.isNotEmpty)
            .toList();
        final destinationsList = destination
            .split(',')
            .map((code) => code.trim().toUpperCase())
            .where((code) => code.isNotEmpty)
            .toList();
        final datesList = depDate
            .split(',')
            .map((date) => date.trim())
            .where((date) => date.isNotEmpty)
            .toList();

        int segmentCount = 0;
        if (originsList.isNotEmpty && destinationsList.isNotEmpty && datesList.isNotEmpty) {
          segmentCount = originsList.length;
          if (destinationsList.length < segmentCount) {
            segmentCount = destinationsList.length;
          }
          if (datesList.length < segmentCount) {
            segmentCount = datesList.length;
          }
        }

        if (segmentCount == 0) {
          throw Exception('No valid travel segments provided for Emirates search');
        }

        if (originsList.length != segmentCount ||
            destinationsList.length != segmentCount ||
            datesList.length != segmentCount) {
          print(
              '⚠️ Emirates search: Segment data length mismatch (origins: ${originsList.length}, destinations: ${destinationsList.length}, dates: ${datesList.length}). Using first $segmentCount segment(s).');
        }

        for (int i = 0; i < segmentCount; i++) {
          segments.add(
            _EmiratesSegment(
              origin: originsList[i],
              destination: destinationsList[i],
              date: datesList[i],
            ),
          );
        }
      }

      if (segments.isEmpty) {
        throw Exception('Failed to prepare Emirates travel segments');
      }

      // print(
      //     '🛫 Emirates search segments (${segments.length}): ${segments.map((s) => '${s.origin}->${s.destination} (${s.date})').join(', ')}');

      final originDestinationsBuffer = StringBuffer();
      for (int i = 0; i < segments.length; i++) {
        final segment = segments[i];
        originDestinationsBuffer.writeln('''
      <OriginDestination OriginDestinationKey="OD${i + 1}">
        <Departure>
          <AirportCode>${segment.origin}</AirportCode>
          <Date>${segment.date}</Date>
        </Departure>
        <Arrival>
          <AirportCode>${segment.destination}</AirportCode>
        </Arrival>
      </OriginDestination>''');
      }
      final originDestinationsXml = originDestinationsBuffer.toString();

      final sectorDetailBuffer = StringBuffer();
      for (int i = 0; i < segments.length; i++) {
        sectorDetailBuffer.writeln(
            '                <OriginDestinationReferences>OD${i + 1}</OriginDestinationReferences>');
      }
      final sectorDetail = sectorDetailBuffer.toString();

      String cabinCode = cabin == 'Economy' ? 'Y' : cabin == 'Business' ? 'J' : 'F';

      String passengerListXml = '';
      
      if (adult != 0) {
        for (int i = 1; i <= adult; i++) {
          passengerListXml += '''
      <Passenger PassengerID="T$i">
        <PTC>ADT</PTC>
      </Passenger>''';
          
          if (infant >= i) {
            passengerListXml += '''
      <Passenger PassengerID="T$i.1">
        <PTC>INF</PTC>
      </Passenger>''';
          }
        }
      }
      
      if (child != 0) {
        for (int j = 1; j <= child; j++) {
          int i = adult + j;
          passengerListXml += '''
      <Passenger PassengerID="T$i">
        <PTC>CNN</PTC>
      </Passenger>''';
        }
      }

      const endpoint = 'https://ek.farelogix.com:443/prod/oc';

      final xmlData = '''<?xml version="1.0"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
  <SOAP-ENV:Header>
    <t:TransactionControl>
      <tc>
        <app version="5.0.0" language="en-US">SOAP</app>
        <iden u="emiratestoc" p="4H3irGhQ1vb9" pseudocity="EPAO" agt="travelocityemir" agtpwd="k34teTgZ0345" agtrole="Ticketing Agent" agy="27304023"/>
        <agent user="travelocityemir"/>
        <trace>EPAO_ek</trace>
        <script engine="FLXDM" name="Travelocity-ek-dispatch.flxdm"/>
      </tc>
    </t:TransactionControl>
  </SOAP-ENV:Header>
  <SOAP-ENV:Body>
    <ns1:XXTransaction>
      <REQ>
        <AirShoppingRQ Version="17.2" TransactionIdentifier="${_generateTransactionId()}">
          <Document id="document"/>
          <Party>
            <Sender>
              <TravelAgencySender>
                <PseudoCity>EPAO</PseudoCity>
                <AgencyID>27304023</AgencyID>
              </TravelAgencySender>
            </Sender>
          </Party>
          <CoreQuery>
            <OriginDestinations>$originDestinationsXml
            </OriginDestinations>
          </CoreQuery>
          <Qualifier>
            <SpecialFareQualifiers>
              <AirlineID>EK</AirlineID>
              <Account/>
            </SpecialFareQualifiers>
          </Qualifier>
          <Preference>
            <FarePreferences>
              <Types>
                <Type>70J</Type>
                <Type>749</Type>
              </Types>
              <Exclusion>
                <NoMinStayInd>false</NoMinStayInd>
                <NoMaxStayInd>false</NoMaxStayInd>
                <NoAdvPurchaseInd>false</NoAdvPurchaseInd>
                <NoPenaltyInd>false</NoPenaltyInd>
              </Exclusion>
            </FarePreferences>
            <CabinPreferences>
              <CabinType>
                <Code>$cabinCode</Code>
$sectorDetail
              </CabinType>
            </CabinPreferences>
          </Preference>
          <DataLists>
            <PassengerList>$passengerListXml
            </PassengerList>
          </DataLists>
        </AirShoppingRQ>
      </REQ>
    </ns1:XXTransaction>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>''';

      final headers = {
        'Ocp-Apim-Subscription-Key': '0d3150002a8b417082aab2be54bb963a',
        'SOAPAction': 'AirShoppingRQ',
        'Agency': 'travelocityemir',
        'IATA': '27304023',
        'PCC': 'EPAO',
        'apiTraceId': '77d1147a-e370-16e4-d5db-24cf01b61f19',
        'clientIp': '91.108.109.86',
        'contEnc': '',
        'agencyName': '',
        'Content-Type': 'application/xml',
      };
      //
      // print("===============================================");
      // print("EMIRATES SOAP REQUEST");
      // print("===============================================");
      // print("URL: $endpoint");
      // print("Headers:");
      // headers.forEach((key, value) {
      //   print("  $key: $value");
      // });
      // print("XML Body:");
      // print(xmlData);
      // print("===============================================");

      final response = await _dio.request(
        endpoint,
        options: Options(
          method: 'POST',
          headers: headers,
          responseType: ResponseType.plain,
        ),
        data: xmlData,
      );

      // print("===============================================");
      // print("EMIRATES SOAP RESPONSE - RAW XML");
      // print("===============================================");
      // print("Status Code: ${response.statusCode}");
      // print("Response Length: ${response.data.toString().length} characters");
      // print("===============================================");
      //
      // // Print the entire raw XML response in chunks
      // _printLargeText(response.data.toString(), "RAW XML RESPONSE");
      //
      // print("===============================================");

      if (response.statusCode == 200) {
        // print("✅ Emirates response received - Starting parsing...");
        var data = _parseXmlResponse(response.data.toString());
        
        // // Print the parsed structured data
        // print("\n===============================================");
        // print("PARSED STRUCTURED DATA (JSON FORMAT)");
        // print("===============================================");
        // printJsonPretty(data);
        // print("===============================================\n");
        //
        return data;
      } else {
        throw Exception('Failed to load Emirates flights: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('===============================================');
      print('ERROR IN EMIRATES API');
      print('===============================================');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      print('===============================================');
      
      return {
        'success': false,
        'error': 'Error: ${e.toString()}',
      };
    }
  }
            
  // Helper method to print large text in chunks
  void _printLargeText(String text, String label) {
    const int chunkSize = 800; // Android Studio console limit per print
    final int length = text.length;
    
    // print("📄 $label (Total: $length characters)");
    // print("───────────────────────────────────────────────");
    //
    // for (int i = 0; i < length; i += chunkSize) {
    //   final end = (i + chunkSize < length) ? i + chunkSize : length;
    //   final chunk = text.substring(i, end);
    //   print(chunk);
    // }
    //
    // print("───────────────────────────────────────────────");
    // print("✅ End of $label\n");
  }

  String _generateTransactionId() {
    return DateTime.now().millisecondsSinceEpoch.toRadixString(16);
  }

  Map<String, dynamic> _parseXmlResponse(String xmlResponse) {
    try {
      // print('=== PARSING XML RESPONSE ===');
      // print('XML Length: ${xmlResponse.length} characters');
      // print('===========================');
      //
      if (xmlResponse.contains('<Error>') || xmlResponse.contains('error')) {
        print('⚠️ Error detected in XML response');
        return {
          'success': false,
          'error': 'Emirates API returned an error',
          'raw_xml': xmlResponse,
        };
      }
      
      // Parse XML
      print('📋 Parsing XML document...');
      final document = xml.XmlDocument.parse(xmlResponse);
      print('✅ XML document parsed successfully');
      
      // Extract the structured data we need
      print('🔍 Extracting structured data...');
      final structuredData = _extractStructuredData(document);
      
      print('✅ Structured data extracted successfully');
      print('Found ${structuredData['offers']?.length ?? 0} offers');
      
      // Print detailed offer information
      if (structuredData['offers'] != null) {
        print('\n🎫 OFFERS SUMMARY:');
        print('─────────────────────────────────────');
        final offers = structuredData['offers'] as List;
        for (int i = 0; i < offers.length; i++) {
          print('Offer ${i + 1}/${offers.length}:');
          print('  OfferID: ${offers[i]['OfferID'] ?? 'N/A'}');
          print('  Total Price: ${_extractTotalPrice(offers[i])}');
          print('  OfferItems: ${_countOfferItems(offers[i])}');
        }
        print('─────────────────────────────────────\n');
      }
      
      return {
        'success': true,
        'data': structuredData,
        'raw_xml': xmlResponse,
        'message': 'XML successfully parsed',
      };
    } catch (e, stackTrace) {
      print('❌ ERROR parsing XML: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'error': 'Failed to parse XML response: $e',
        'raw_xml': xmlResponse,
      };
    }
  }

  String _extractTotalPrice(Map<String, dynamic> offer) {
    try {
      if (offer['TotalPrice'] != null) {
        final totalPrice = offer['TotalPrice'];
        if (totalPrice is Map && totalPrice['SimpleCurrencyPrice'] != null) {
          final price = totalPrice['SimpleCurrencyPrice'];
          if (price is Map) {
            return '${price['Code'] ?? ''} ${price['\$t'] ?? price['value'] ?? ''}';
          }
        }
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  int _countOfferItems(Map<String, dynamic> offer) {
    try {
      if (offer['OfferItem'] != null) {
        final offerItem = offer['OfferItem'];
        if (offerItem is List) {
          return offerItem.length;
        } else if (offerItem is Map) {
          return 1;
        }
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Map<String, dynamic> _extractStructuredData(xml.XmlDocument document) {
    final result = <String, dynamic>{};
    
    try {
      print('🔎 Looking for AirShoppingRS element...');
      // Navigate to AirShoppingRS
      final airShoppingRS = document.findAllElements('AirShoppingRS').firstOrNull;
      
      if (airShoppingRS == null) {
        print('❌ AirShoppingRS not found');
        return result;
      }
      print('✅ AirShoppingRS found');

      // Extract DataLists first (needed for offer enrichment)
      print('📊 Extracting DataLists...');
      final dataLists = _extractDataLists(airShoppingRS);
      result['DataLists'] = dataLists;
      print('✅ DataLists extracted');
      
      // Print DataLists summary
      print('\n📋 DATA LISTS SUMMARY:');
      print('─────────────────────────────────────');
      if (dataLists['FlightSegmentList'] != null) {
        final segments = dataLists['FlightSegmentList']['FlightSegment'];
        print('Flight Segments: ${segments is Map ? segments.length : 0}');
      }
      if (dataLists['BaggageAllowanceList'] != null) {
        final baggage = dataLists['BaggageAllowanceList']['BaggageAllowance'];
        print('Baggage Allowances: ${baggage is Map ? baggage.length : 0}');
      }
      if (dataLists['PriceClassList'] != null) {
        final priceClasses = dataLists['PriceClassList']['PriceClass'];
        print('Price Classes: ${priceClasses is Map ? priceClasses.length : 0}');
      }
      print('─────────────────────────────────────\n');
      
      // Extract Offers
      print('🎯 Extracting Offers...');
      final offersGroup = airShoppingRS.findElements('OffersGroup').firstOrNull;
      if (offersGroup != null) {
        final airlineOffers = offersGroup.findElements('AirlineOffers').firstOrNull;
        if (airlineOffers != null) {
          final offers = <Map<String, dynamic>>[];
          
          for (var offerElement in airlineOffers.findElements('Offer')) {
            final offer = _extractOffer(offerElement, dataLists);
            offers.add(offer);
          }
          
          result['offers'] = offers;
          print('✅ Extracted ${offers.length} offers');
        } else {
          print('⚠️ AirlineOffers not found');
        }
      } else {
        print('⚠️ OffersGroup not found');
      }
      
    } catch (e, stackTrace) {
      print('❌ Error extracting structured data: $e');
      print('Stack trace: $stackTrace');
    }
    
    return result;
  }

  Map<String, dynamic> _extractDataLists(xml.XmlElement airShoppingRS) {
    final dataLists = <String, dynamic>{};
    
    try {
      final dataListsElement = airShoppingRS.findElements('DataLists').firstOrNull;
      if (dataListsElement == null) return dataLists;

      // Extract FlightSegmentList
      final flightSegmentList = <String, dynamic>{};
      final flightSegments = dataListsElement.findElements('FlightSegmentList').firstOrNull;
      if (flightSegments != null) {
        for (var segment in flightSegments.findElements('FlightSegment')) {
          final segmentKey = segment.getAttribute('SegmentKey') ?? '';
          flightSegmentList[segmentKey] = _xmlElementToMap(segment);
        }
      }
      dataLists['FlightSegmentList'] = {'FlightSegment': flightSegmentList};

      // Extract BaggageAllowanceList
      final baggageList = <String, dynamic>{};
      final baggageAllowances = dataListsElement.findElements('BaggageAllowanceList').firstOrNull;
      if (baggageAllowances != null) {
        for (var baggage in baggageAllowances.findElements('BaggageAllowance')) {
          final baggageId = baggage.getAttribute('BaggageAllowanceID') ?? '';
          baggageList[baggageId] = _xmlElementToMap(baggage);
        }
      }
      dataLists['BaggageAllowanceList'] = {'BaggageAllowance': baggageList};

      // Extract PriceClassList
      final priceClassList = <String, dynamic>{};
      final priceClasses = dataListsElement.findElements('PriceClassList').firstOrNull;
      if (priceClasses != null) {
        for (var priceClass in priceClasses.findElements('PriceClass')) {
          final priceClassId = priceClass.getAttribute('PriceClassID') ?? '';
          priceClassList[priceClassId] = _xmlElementToMap(priceClass);
        }
      }
      dataLists['PriceClassList'] = {'PriceClass': priceClassList};

      // Extract PassengerList
      final passengerList = dataListsElement.findElements('PassengerList').firstOrNull;
      if (passengerList != null) {
        dataLists['PassengerList'] = _xmlElementToMap(passengerList);
      }

      // Extract FlightList
      final flightList = dataListsElement.findElements('FlightList').firstOrNull;
      if (flightList != null) {
        dataLists['FlightList'] = _xmlElementToMap(flightList);
      }

    } catch (e) {
      print('Error extracting DataLists: $e');
    }
    
    return dataLists;
  }

  Map<String, dynamic> _extractOffer(xml.XmlElement offerElement, Map<String, dynamic> dataLists) {
    final offer = _xmlElementToMap(offerElement);
    
    // Add DataLists reference to the offer for easy access
    offer['DataLists'] = dataLists;
    
    return offer;
  }

  Map<String, dynamic> _xmlElementToMap(xml.XmlElement element) {
    final map = <String, dynamic>{};
    
    // Add attributes
    for (var attr in element.attributes) {
      map[attr.name.local] = attr.value;
    }
    
    // Process child elements
    final childElements = element.children.whereType<xml.XmlElement>();
    
    for (var child in childElements) {
      final key = child.name.local;
      final value = _processXmlNode(child);
      
      if (map.containsKey(key)) {
        // Handle multiple elements with same name
        if (map[key] is List) {
          (map[key] as List).add(value);
        } else {
          map[key] = [map[key], value];
        }
      } else {
        map[key] = value;
      }
    }
    
    // If no children, add text content
    if (childElements.isEmpty && element.text.trim().isNotEmpty) {
      map['\$t'] = element.text.trim();
    }
    
    return map;
  }

  dynamic _processXmlNode(xml.XmlElement element) {
    final childElements = element.children.whereType<xml.XmlElement>();
    
    if (childElements.isEmpty) {
      // Leaf node - return text or map with attributes
      if (element.attributes.isEmpty) {
        return element.text.trim();
      } else {
        final map = <String, dynamic>{};
        for (var attr in element.attributes) {
          map[attr.name.local] = attr.value;
        }
        if (element.text.trim().isNotEmpty) {
          map['\$t'] = element.text.trim();
        }
        return map;
      }
    } else {
      // Has children - return as map
      return _xmlElementToMap(element);
    }
  }

  List<Map<String, dynamic>> extractOffersFromResponse(Map<String, dynamic> response) {
    final offers = <Map<String, dynamic>>[];
    
    try {
      debugPrint('🔍 Extracting offers from response...');
      
      // Get the data from the response
      final data = response['data'] ?? response;
      
      // Check if we have the offers array
      if (data.containsKey('offers') && data['offers'] is List) {
        final offersList = data['offers'] as List;
        debugPrint('✅ Found ${offersList.length} offers in structured data');
        
        for (var offer in offersList) {
          if (offer is Map<String, dynamic>) {
            offers.add(offer);
          }
        }
      } else {
        debugPrint('⚠️ No offers found in structured format, trying alternative extraction...');
        // Fallback to deep search
        offers.addAll(_deepSearchOffers(data));
      }
      
      debugPrint('📦 Total offers extracted: ${offers.length}');
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error extracting offers: $e');
      debugPrint('Stack trace: $stackTrace');
    }
    
    return offers;
  }

  List<Map<String, dynamic>> _deepSearchOffers(Map<String, dynamic> data) {
    final offers = <Map<String, dynamic>>[];
    
    void search(dynamic obj, [String path = '']) {
      if (obj is Map) {
        obj.forEach((key, value) {
          final currentPath = path.isEmpty ? key : '$path.$key';
          
          if (key == 'Offer' || key == 'offer') {
            debugPrint('🎯 Found offer at path: $currentPath');
            if (value is Map) {
              offers.add(Map<String, dynamic>.from(value));
            } else if (value is List) {
              for (var item in value) {
                if (item is Map) {
                  offers.add(Map<String, dynamic>.from(item));
                }
              }
            }
          } else {
            search(value, currentPath);
          }
        });
      } else if (obj is List) {
        for (var item in obj) {
          search(item, path);
        }
      }
    }
    
    search(data);
    debugPrint('🔍 Deep search found ${offers.length} offers');
    return offers;
  }

  void printJsonPretty(dynamic jsonData) {
    const int chunkSize = 800;
    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
    final int totalLength = jsonString.length;
    
    // print('📊 JSON Output (Total: $totalLength characters)');
    // print('═══════════════════════════════════════════════');
    //
    // for (int i = 0; i < totalLength; i += chunkSize) {
    //   final chunk = jsonString.substring(
    //     i,
    //     i + chunkSize < totalLength ? i + chunkSize : totalLength,
    //   );
    //   if (kDebugMode) {
    //     print(chunk);
    //   }
    // }
    //
    // print('═══════════════════════════════════════════════');
    // print('✅ End of JSON Output\n');
  }
  // Add this method to your existing ApiServiceEmirates class

Future<Map<String, dynamic>> createEmiratesNdcPnr({
  required List<Map<String, dynamic>> selectedOffers,
  required dynamic bookingController,
}) async {
  try {
    if (selectedOffers.isEmpty) {
      debugPrint('❌ createEmiratesNdcPnr called without offers.');
      return {
        'success': false,
        'error': 'No offers provided for PNR creation.',
      };
    }

    debugPrint('createEmiratesNdcPnr -> Start');
    debugPrint('Selected offer count: ${selectedOffers.length}');

    // Build passenger list XML with proper infant linking (matching PHP logic)
    String passengerListXml = '';
    int passengerIndex = 1;
    final passengerRefsOrdered = <String>[];
    final validPassengerIds = <String>{};

    debugPrint('Building passenger XML...');

    final int adultCount = bookingController.adults.length;
    final int childCount = bookingController.children.length;
    final int infantCount = bookingController.infants.length;

    // Add adults with optional linked infants
    for (int i = 0; i < adultCount; i++) {
      final adult = bookingController.adults[i];

      final currentRef = 'T$passengerIndex';
      passengerRefsOrdered.add(currentRef);
      validPassengerIds.add(currentRef);

      final adultNationalityCode = adult.nationalityCountry.value?.countryCode ?? 'PK';
      final adultIdentityDocumentXml = _buildIdentityDocumentBlock(
        documentNumber: adult.passportCnicController.text.trim(),
        expiryDate: adult.passportExpiryController.text.trim(),
        issuingCountry: adultNationalityCode,
        nationalityCountry: adultNationalityCode,
      );

      String infantRef = '';
      String infantDetails = '';

      if (i < infantCount) {
        final infant = bookingController.infants[i];
        final infantId = '$currentRef.1';
        validPassengerIds.add(infantId);

        infantDetails = '''
                    <Passenger PassengerID="$infantId">
                        <PTC>INF</PTC>
                        <ResidenceCountryCode>${infant.nationalityCountry.value?.countryCode ?? 'PK'}</ResidenceCountryCode>
                        <Individual>
                            <Birthdate>${infant.dateOfBirthController.text}</Birthdate>
                            <Gender>${infant.genderController.text}</Gender>
                            <GivenName>${infant.firstNameController.text}</GivenName>
                            <Surname>${infant.lastNameController.text}</Surname>
                        </Individual>
                    </Passenger>''';

        infantRef = '<InfantRef>$infantId</InfantRef>';
        debugPrint('Linked infant to adult index $i with ID $infantId');
      }

      passengerListXml += '''
                <Passenger PassengerID="$currentRef">
                         <PTC>ADT</PTC>
                         <ResidenceCountryCode>$adultNationalityCode</ResidenceCountryCode>
                         <Individual>
                             <Birthdate>${adult.dateOfBirthController.text}</Birthdate>
                             <Gender>${adult.genderController.text}</Gender>
                             <NameTitle>${adult.titleController.text}</NameTitle>
                             <GivenName>${adult.firstNameController.text}</GivenName>
                             <Surname>${adult.lastNameController.text}</Surname>
                         </Individual>''';

      if (adultIdentityDocumentXml.isNotEmpty) {
        passengerListXml += adultIdentityDocumentXml;
      }

      if (i == 0) {
        passengerListXml += '''
                         <ContactInfoRef>CID1</ContactInfoRef>''';
      }

      passengerListXml += '''
                         $infantRef
                     </Passenger>''';

      passengerListXml += infantDetails;

      debugPrint(
          'Added adult passenger: ${adult.firstNameController.text} ${adult.lastNameController.text}');

      passengerIndex++;
    }

    // Add children
    for (int i = 0; i < childCount; i++) {
      final child = bookingController.children[i];
      final currentRef = 'T$passengerIndex';
      passengerRefsOrdered.add(currentRef);
      validPassengerIds.add(currentRef);

      final childNationalityCode = child.nationalityCountry.value?.countryCode ?? 'PK';
      final childIdentityDocumentXml = _buildIdentityDocumentBlock(
        documentNumber: child.passportCnicController.text.trim(),
        expiryDate: child.passportExpiryController.text.trim(),
        issuingCountry: childNationalityCode,
        nationalityCountry: childNationalityCode,
      );

      passengerListXml += '''
                <Passenger PassengerID="$currentRef">
                         <PTC>CNN</PTC>
                         <ResidenceCountryCode>$childNationalityCode</ResidenceCountryCode>
                         <Individual>
                             <Birthdate>${child.dateOfBirthController.text}</Birthdate>
                             <Gender>${child.genderController.text}</Gender>
                             <NameTitle>${child.titleController.text}</NameTitle>
                             <GivenName>${child.firstNameController.text}</GivenName>
                             <Surname>${child.lastNameController.text}</Surname>
                         </Individual>''';

      if (childIdentityDocumentXml.isNotEmpty) {
        passengerListXml += childIdentityDocumentXml;
      }

      passengerListXml += ''' 
                     </Passenger>''';
      debugPrint(
          'Added child passenger: ${child.firstNameController.text} ${child.lastNameController.text}');
      passengerIndex++;
    }

    final defaultPassengerRefs =
        passengerRefsOrdered.isNotEmpty ? passengerRefsOrdered.join(' ') : 'T1';

    debugPrint('PassengerRefs (default): $defaultPassengerRefs');
    debugPrint('Total Adults: $adultCount, Children: $childCount, Infants: $infantCount');

    final resolvedOffers = <Map<String, dynamic>>[];
    final seenOfferKeys = <String>{};

    for (int index = 0; index < selectedOffers.length; index++) {
      final rawEntry = selectedOffers[index];
      final offerData = _coerceOfferDataMap(
        rawEntry['offerData'] ??
            rawEntry['data'] ??
            rawEntry['rawFlightData'] ??
            rawEntry,
      );
      final offerIdFromEntry = rawEntry['offerId']?.toString() ?? '';
      final extractedOfferId = _extractNodeText(offerData['OfferID']);
      final resolvedOfferId =
          extractedOfferId.isNotEmpty ? extractedOfferId : offerIdFromEntry;

      if (resolvedOfferId.isEmpty) {
        debugPrint('⚠️ Skipping offer[$index]: Unable to resolve OfferID.');
        continue;
      }

      final owner = offerData['Owner']?.toString() ?? 'EK';
      final responseId = _resolveResponseId(offerData, resolvedOfferId);

      if (responseId.isEmpty) {
        debugPrint('⚠️ Skipping offer[$index]: Unable to resolve ResponseID for $resolvedOfferId.');
        continue;
      }

      final offerItemsRaw = _normalizeOfferItems(offerData['OfferItem']);
      final resolvedItems = <Map<String, String>>[];

      for (final item in offerItemsRaw) {
        final itemId = _extractNodeText(item['OfferItemID']);
        if (itemId.isEmpty) continue;

        var passengerRefsTokens =
            _extractPassengerIdsFromNode(item['PassengerRefs'], validPassengerIds);
        if (passengerRefsTokens.isEmpty) {
          passengerRefsTokens =
              _extractPassengerIdsFromNode(item['Service'], validPassengerIds);
        }

        final passengerRefsForItem = passengerRefsTokens.isNotEmpty
            ? passengerRefsTokens.join(' ')
            : defaultPassengerRefs;

        resolvedItems.add({
          'id': itemId,
          'passengerRefs': passengerRefsForItem,
        });
      }

      if (resolvedItems.isEmpty) {
        final fallbackItemId = '$resolvedOfferId-1';
        debugPrint(
            '⚠️ Offer $resolvedOfferId has no OfferItem data; using fallback OfferItemID $fallbackItemId');
        resolvedItems.add({
          'id': fallbackItemId,
          'passengerRefs': defaultPassengerRefs,
        });
      }

      final dedupeKey = '${resolvedOfferId}::${resolvedItems.map((e) => e['id']).join(',')}';
      if (seenOfferKeys.contains(dedupeKey)) {
        debugPrint('⚠️ Skipping duplicate offer entry for $resolvedOfferId');
        continue;
      }
      seenOfferKeys.add(dedupeKey);

      resolvedOffers.add({
        'offerId': resolvedOfferId,
        'owner': owner,
        'responseId': responseId,
        'items': resolvedItems,
      });
    }

    if (resolvedOffers.isEmpty) {
      return {
        'success': false,
        'error': 'Unable to resolve offer data for PNR creation.',
      };
    }

    debugPrint('Resolved offers for OrderCreate:');
    for (final offer in resolvedOffers) {
      final items = offer['items'] as List<Map<String, String>>;
      debugPrint(
          '  Offer ${offer['offerId']} (ResponseID: ${offer['responseId']}, Owner: ${offer['owner']}) -> ${items.length} item(s)');
      for (final item in items) {
        debugPrint(
            '    - OfferItem ${item['id']} | PassengerRefs: ${item['passengerRefs']}');
      }
    }

    final offersXmlBuffer = StringBuffer();
    for (final offer in resolvedOffers) {
      offersXmlBuffer.writeln(
          '            <Offer OfferID="${offer['offerId']}" Owner="${offer['owner']}" ResponseID="${offer['responseId']}">');
      for (final item in offer['items'] as List<Map<String, String>>) {
        offersXmlBuffer.writeln('              <OfferItem OfferItemID="${item['id']}">');
        offersXmlBuffer.writeln(
            '                <PassengerRefs>${item['passengerRefs']}</PassengerRefs>');
        offersXmlBuffer.writeln('              </OfferItem>');
      }
      offersXmlBuffer.writeln('            </Offer>');
    }

    final offersXml = offersXmlBuffer.toString();

    // ✅ Using EPAO/travelocity credentials (PROD) to match working PHP implementation
    final xmlData =
        '''<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
  <SOAP-ENV:Header>
    <t:TransactionControl>
      <tc>
        <app version="5.0.0" language="en-US">SOAP</app>
        <iden u="emiratestoc" p="4H3irGhQ1vb9" pseudocity="EPAO" agy="27304023" agt="travelocityemir" agtpwd="k34teTgZ0345" agtrole="Ticketing Agent"/>
        <agent user="travelocityemir"/>
        <trace>EPAO_ek</trace>
        <script engine="FLXDM" name="Travelocity-ek-dispatch.flxdm"/>
      </tc>
    </t:TransactionControl>
  </SOAP-ENV:Header>
  <SOAP-ENV:Body>
    <ns1:XXTransaction>
      <REQ>
        <OrderCreateRQ Version="17.2" TransactionIdentifier="${_generateTransactionId()}">
          <Document id="document"/>
          <Party>
            <Sender>
              <TravelAgencySender>
                <PseudoCity>EPAO</PseudoCity>
                <AgencyID>27304023</AgencyID>
              </TravelAgencySender>
            </Sender>
          </Party>
          <Query>
            <Order>
$offersXml
            </Order>
            <Commission>
              <Amount Code="PKR">0</Amount>
            </Commission>
            <DataLists>
              <PassengerList>
$passengerListXml
              </PassengerList>
              <ContactList>
                <ContactInformation ContactID="CID1">
                  <PostalAddress>
                    <Label>  </Label>
                    <Street></Street>
                    <PostalCode></PostalCode>
                    <CityName></CityName>
                    <CountrySubdivisionName></CountrySubdivisionName>
                    <CountryCode></CountryCode>
                  </PostalAddress>
                  <ContactProvided>
                    <EmailAddress>
                      <Label>Personal</Label>
                      <EmailAddressValue>${bookingController.emailController.text}</EmailAddressValue>
                    </EmailAddress>
                  </ContactProvided>
                  <ContactProvided>
                    <Phone>
                      <Label>Home</Label>
                      <CountryDialingCode>${bookingController.bookerPhoneCountry.value?.phoneCode ?? '92'}</CountryDialingCode>
                      <PhoneNumber>${bookingController.phoneController.text}</PhoneNumber>
                    </Phone>
                  </ContactProvided>
                </ContactInformation>
              </ContactList>
            </DataLists>
            <Metadata>
            </Metadata>
          </Query>
        </OrderCreateRQ>
      </REQ>
    </ns1:XXTransaction>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>''';

    debugPrint('XML payload prepared (length: ${xmlData.length})');

    // ✅ Matching headers with EPAO/travelocity credential set
    final headers = {
      'Ocp-Apim-Subscription-Key': '0d3150002a8b417082aab2be54bb963a',
      'SOAPAction': 'OrderCreateRQ',
      'Agency': 'travelocityemir',
      'IATA': '27304023',
      'PCC': 'EPAO',
      'apiTraceId': '77d1147a-e370-16e4-d5db-24cf01b61f19',
      'clientIp': '91.108.109.86',
      'contEnc': '',
      'agencyName': '',
      'Content-Type': 'application/xml',
    };

    debugPrint('Headers set: $headers');

    // ✅ Use production endpoint (same as PHP script)
    final response = await _dio.request(
      'https://ek.farelogix.com:443/prod/oc',
      options: Options(
        method: 'POST',
        headers: headers,
        responseType: ResponseType.plain,
        validateStatus: (status) => status! < 600,
      ),
      data: xmlData,
    );

    // debugPrint('Response received with status code: ${response.statusCode}');
    //
    // debugPrint("===============================================");
    // debugPrint("EMIRATES ORDER CREATE RESPONSE");
    // debugPrint("===============================================");
    // debugPrint("Status Code: ${response.statusCode}");
    // debugPrint("Response Length: ${response.data.toString().length} characters");
    // _printLargeText(response.data.toString(), "ORDER CREATE RAW XML");
    // debugPrint("===============================================\n");

    if (response.statusCode == 200) {
      final parsedResponse = _parsePnrResponse(response.data.toString());

      debugPrint("\n📋 === PNR PARSING RESULT ===");
      debugPrint("Success: ${parsedResponse['success']}");
      if (parsedResponse['success']) {
        debugPrint("PNR: ${parsedResponse['pnr']}");
        debugPrint("Order ID: ${parsedResponse['orderId']}");
        debugPrint("Total Price: ${parsedResponse['totalPrice']}");
      } else {
        debugPrint("Error: ${parsedResponse['error']}");
      }
      debugPrint("============================\n");

      return parsedResponse;
    } else {
      debugPrint("\n❌ SERVER ERROR RESPONSE:");
      debugPrint("Status: ${response.statusCode}");
      debugPrint("Response: ${response.data}");

      return {
        'success': false,
        'error': 'Server error ${response.statusCode}: ${response.data}',
      };
    }
  } catch (e, stackTrace) {
    debugPrint('❌ ERROR creating Emirates PNR: $e');
    debugPrint('Stack trace: $stackTrace');
    return {
      'success': false,
      'error': 'Error: ${e.toString()}',
    };
  }
}

Map<String, dynamic> _coerceOfferDataMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _normalizeOfferItems(dynamic node) {
  if (node is List) {
    return node
        .whereType<Map>()
        .map((item) => _coerceOfferDataMap(item))
        .toList();
  }
  if (node is Map) {
    return [_coerceOfferDataMap(node)];
  }
  return const [];
}

List<String> _extractPassengerIdsFromNode(
  dynamic node,
  Set<String> validPassengerIds,
) {
  if (node == null) return const [];

  final collected = <String>[];

  bool isValidId(String value) {
    if (value.isEmpty) return false;
    if (validPassengerIds.isNotEmpty) {
      return validPassengerIds.contains(value);
    }
    return value.startsWith('T');
  }

  void collect(dynamic current) {
    if (current == null) return;

    if (current is String) {
      for (final token in current.split(RegExp(r'\s+'))) {
        final trimmed = token.trim();
        if (isValidId(trimmed)) {
          collected.add(trimmed);
        }
      }
      return;
    }

    if (current is Map) {
      if (current.containsKey('\$t')) {
        collect(current['\$t']);
        return;
      }
      if (current.containsKey('value')) {
        collect(current['value']);
        return;
      }
      if (current.containsKey('PassengerRefs')) {
        collect(current['PassengerRefs']);
      }
      for (final value in current.values) {
        collect(value);
      }
      return;
    }

    if (current is Iterable) {
      for (final value in current) {
        collect(value);
      }
      return;
    }

    collect(current.toString());
  }

  collect(node);

  final seen = <String>{};
  final ordered = <String>[];
  for (final id in collected) {
    if (seen.add(id)) {
      ordered.add(id);
    }
  }
  return ordered;
}

String _resolveResponseId(Map<String, dynamic> offerData, String offerId) {
  var responseId = _extractNodeText(offerData['ResponseID']);

  if (responseId.isEmpty && offerData['ShoppingResponseID'] != null) {
    final shoppingResponse = offerData['ShoppingResponseID'];
    if (shoppingResponse is Map) {
      responseId = _extractNodeText(shoppingResponse['ResponseID']);
    }
  }

  if (responseId.isEmpty) {
    responseId = _deepSearchForResponseId(offerData);
  }

  if (responseId.isEmpty && offerId.isNotEmpty) {
    final lastDash = offerId.lastIndexOf('-');
    responseId = lastDash > 0 ? offerId.substring(0, lastDash) : offerId;
  }

  return responseId;
}

String _deepSearchForResponseId(dynamic node) {
  if (node == null) return '';

  if (node is Map) {
    if (node.containsKey('ResponseID')) {
      final extracted = _extractNodeText(node['ResponseID']);
      if (extracted.isNotEmpty) return extracted;
    }
    for (final entry in node.entries) {
      final found = _deepSearchForResponseId(entry.value);
      if (found.isNotEmpty) return found;
    }
    return '';
  }

  if (node is Iterable) {
    for (final item in node) {
      final found = _deepSearchForResponseId(item);
      if (found.isNotEmpty) return found;
    }
    return '';
  }

  return '';
}

  Future<Map<String, dynamic>> priceEmiratesOffer({
    required List<OfferPricingEntry> offers,
    required List<Map<String, String>> passengerDetails,
  }) async {
    try {
      final passengerListXml = _buildPassengerListXml(passengerDetails);
      final sanitizedOffers = offers
          .map((offer) {
            final cleanedItems = offer.items
                .where((item) => item.offerItemId.trim().isNotEmpty)
                .toList();
            if (cleanedItems.isEmpty) {
              return null;
            }
            return OfferPricingEntry(
              offerId: offer.offerId,
              owner: offer.owner,
              responseId: offer.responseId,
              items: cleanedItems,
            );
          })
          .whereType<OfferPricingEntry>()
          .toList();

      if (sanitizedOffers.isEmpty) {
        return {
          'success': false,
          'error': 'No valid offers provided for pricing.',
        };
      }

      final credential = OfferPriceCredential(
        credentialName: 'EPAO/travelocity-prod',
        endpoint: 'https://ek.farelogix.com:443/prod/oc',
        subscriptionKey: '0d3150002a8b417082aab2be54bb963a',
        agencyHeader: 'travelocityemir',
        iataHeader: '27304023',
        pccHeader: 'EPAO',
        idenUser: 'emiratestoc',
        idenPassword: '4H3irGhQ1vb9',
        pseudoCity: 'EPAO',
        agencyId: '27304023',
        agt: 'travelocityemir',
        agtPassword: 'k34teTgZ0345',
        agtRole: 'Ticketing Agent',
        agentUser: 'travelocityemir',
        trace: 'EPAO_ek',
        traceAdmin: false,
        scriptName: 'Travelocity-ek-dispatch.flxdm',
        scriptEngine: 'FLXDM',
      );

        final xmlData = _buildOfferPriceEnvelope(
          credential: credential,
          offers: sanitizedOffers,
          passengerListXml: passengerListXml,
        );

        final headers = _buildOfferPriceHeaders(credential);

        debugPrint("===============================================");
        debugPrint("EMIRATES OFFER PRICE REQUEST (${credential.credentialName})");
        debugPrint("===============================================");
        debugPrint("URL: ${credential.endpoint}");
        debugPrint("Headers:");
        headers.forEach((key, value) {
          debugPrint("  $key: $value");
        });
        debugPrint("XML Body:");
        _printLargeText(xmlData, "OFFER PRICE REQUEST XML");
        debugPrint("===============================================\n");

      Map<String, dynamic>? lastError;

        try {
          final response = await _dio.request(
            credential.endpoint,
            options: Options(
              method: 'POST',
              headers: headers,
              responseType: ResponseType.plain,
              validateStatus: (status) => status! < 600,
            ),
            data: xmlData,
          );

          debugPrint("===============================================");
          debugPrint("EMIRATES OFFER PRICE RESPONSE (${credential.credentialName})");
          debugPrint("===============================================");
          debugPrint("Status Code: ${response.statusCode}");
          debugPrint("Response Length: ${response.data.toString().length} characters");
          _printLargeText(response.data.toString(), "OFFER PRICE RESPONSE XML");
          debugPrint("===============================================\n");

          if (response.statusCode == 200) {
            final parsedResponse = _parseOfferPriceResponse(response.data.toString());
            parsedResponse['credential'] = credential.credentialName;
            return parsedResponse;
          }

          final errorMap = {
            'success': false,
            'error': 'Server error ${response.statusCode}: ${response.data}',
            'raw_xml': response.data.toString(),
            'credential': credential.credentialName,
          };

          lastError = errorMap;
        } catch (e, stackTrace) {
          debugPrint('❌ ERROR pricing Emirates offer with ${credential.credentialName}: $e');
          debugPrint('Stack trace: $stackTrace');
          lastError = {
            'success': false,
            'error': 'Error (${credential.credentialName}): ${e.toString()}',
          };
        }

      return lastError ??
          {
            'success': false,
            'error': 'Offer pricing failed',
          };
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR pricing Emirates offer: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'success': false,
        'error': 'Error: ${e.toString()}',
      };
    }
  }

String _buildOfferPriceEnvelope({
  required OfferPriceCredential credential,
  required List<OfferPricingEntry> offers,
  required String passengerListXml,
}) {
    final traceAttribute = credential.traceAdmin ? ' admin="Y"' : '';
    final transactionId = _generateTransactionId();

    final offersXml = offers.map((entry) {
      final offerItemsXml = _buildOfferItemsXml(entry.items);
      return '''
            <Offer OfferID="${entry.offerId}" Owner="${entry.owner}" ResponseID="${entry.responseId}">
$offerItemsXml
            </Offer>''';
    }).join();

    return '''<?xml version="1.0"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
  <SOAP-ENV:Header>
    <t:TransactionControl>
      <tc>
        <app version="5.0.0" language="en-US">SOAP</app>
        <iden u="${credential.idenUser}" p="${credential.idenPassword}" pseudocity="${credential.pseudoCity}" agy="${credential.agencyId}" agt="${credential.agt}" agtpwd="${credential.agtPassword}" agtrole="${credential.agtRole}"/>
        <agent user="${credential.agentUser}"/>
        <trace$traceAttribute>${credential.trace}</trace>
        <script engine="${credential.scriptEngine}" name="${credential.scriptName}"/>
      </tc>
    </t:TransactionControl>
  </SOAP-ENV:Header>
  <SOAP-ENV:Body>
    <ns1:XXTransaction>
      <REQ>
        <OfferPriceRQ Version="17.2" TransactionIdentifier="$transactionId">
          <Document id="document"/>
          <Party>
            <Sender>
              <TravelAgencySender>
                <PseudoCity>${credential.pseudoCity}</PseudoCity>
                <AgencyID>${credential.agencyId}</AgencyID>
              </TravelAgencySender>
            </Sender>
          </Party>
          <Query>
            $offersXml
          </Query>
          <Preference>
            <FarePreferences>
              <Types>
                <Type>70J</Type>
                <Type>749</Type>
              </Types>
              <Exclusion>
                <NoMinStayInd>false</NoMinStayInd>
                <NoMaxStayInd>false</NoMaxStayInd>
                <NoAdvPurchaseInd>false</NoAdvPurchaseInd>
                <NoPenaltyInd>false</NoPenaltyInd>
              </Exclusion>
            </FarePreferences>
            <PricingMethodPreference>
              <BestPricingOption>N</BestPricingOption>
            </PricingMethodPreference>
          </Preference>
          <DataLists>
            <PassengerList>
$passengerListXml
            </PassengerList>
          </DataLists>
        </OfferPriceRQ>
      </REQ>
    </ns1:XXTransaction>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>''';
  }

Map<String, String> _buildOfferPriceHeaders(OfferPriceCredential credential) {
    return {
      'Ocp-Apim-Subscription-Key': credential.subscriptionKey,
      'SOAPAction': 'OfferPriceRQ',
      'Agency': credential.agencyHeader,
      'IATA': credential.iataHeader,
      'PCC': credential.pccHeader,
      'apiTraceId': '77d1147a-e370-16e4-d5db-24cf01b61f19',
      'clientIp': '91.108.109.86',
      'contEnc': '',
      'agencyName': '',
      'Content-Type': 'application/xml',
    };
  }

String _buildPassengerListXml(List<Map<String, String>> passengerDetails) {
    if (passengerDetails.isEmpty) {
      return '''
              <Passenger PassengerID="T1">
                <PTC>ADT</PTC>
              </Passenger>''';
    }

    final buffer = StringBuffer();
    for (final passenger in passengerDetails) {
      final id = passenger['id'] ?? '';
      final ptc = passenger['ptc'] ?? 'ADT';
      if (id.isEmpty) continue;
      buffer.writeln('              <Passenger PassengerID="$id">');
      buffer.writeln('                <PTC>${ptc.isEmpty ? 'ADT' : ptc}</PTC>');
      buffer.writeln('              </Passenger>');
    }
    final xml = buffer.toString();
    return xml.isEmpty
        ? '''
              <Passenger PassengerID="T1">
                <PTC>ADT</PTC>
              </Passenger>'''
        : xml;
  }

String _extractNodeText(dynamic value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is Map) {
    for (final key in ['\$t', 'value', 'text', '_text']) {
      if (value.containsKey(key)) {
        final inner = _extractNodeText(value[key]);
        if (inner.isNotEmpty) return inner;
      }
    }
    if (value.length == 1) {
      return _extractNodeText(value.values.first);
    }
    for (final entry in value.entries) {
      final extracted = _extractNodeText(entry.value);
      if (extracted.isNotEmpty) return extracted;
    }
    return '';
  }
  if (value is Iterable) {
    for (final item in value) {
      final extracted = _extractNodeText(item);
      if (extracted.isNotEmpty) return extracted;
    }
    return '';
  }
  return value.toString().trim();
}

String _buildOfferItemsXml(
  List<OfferPricingItem> items,
) {
  final buffer = StringBuffer();

  for (final item in items) {
    final passengerRefs = item.passengerRefs.trim();
    buffer.writeln('              <OfferItem OfferItemID="${item.offerItemId}">');
    if (passengerRefs.isNotEmpty) {
      buffer.writeln('                <PassengerRefs>$passengerRefs</PassengerRefs>');
    }
    buffer.writeln('              </OfferItem>');
  }

  return buffer.toString();
}

Map<String, dynamic> _parseOfferPriceResponse(String xmlResponse) {
  try {
    final document = xml.XmlDocument.parse(xmlResponse);

    final errors = document.findAllElements('Error');
    if (errors.isNotEmpty) {
      final errorMsg = errors.first.text;
      return {
        'success': false,
        'error': errorMsg,
        'raw_xml': xmlResponse,
      };
    }

    final offerPriceRS = document.findAllElements('OfferPriceRS').firstOrNull;
    if (offerPriceRS == null) {
      return {
        'success': false,
        'error': 'OfferPriceRS not found in response',
        'raw_xml': xmlResponse,
      };
    }

    final result = <String, dynamic>{};

    final shoppingResponse = offerPriceRS.findElements('ShoppingResponseID').firstOrNull;
    if (shoppingResponse != null) {
      result['ShoppingResponseID'] = _xmlElementToMap(shoppingResponse);
    }

    final pricedOffer = offerPriceRS.findElements('PricedOffer').firstOrNull;
    if (pricedOffer != null) {
      final mapped = _xmlElementToMap(pricedOffer);
      result['PricedOffer'] = mapped;
    }

    final dataLists = offerPriceRS.findElements('DataLists').firstOrNull;
    if (dataLists != null) {
      result['DataLists'] = _xmlElementToMap(dataLists);
    }

    if (!result.containsKey('PricedOffer')) {
      return {
        'success': false,
        'error': 'PricedOffer element not found in response',
        'raw_xml': xmlResponse,
      };
    }

    final shoppingResponseId = result['ShoppingResponseID'];
    String responseId = '';
    if (shoppingResponseId is Map && shoppingResponseId['ResponseID'] != null) {
      responseId = _extractNodeText(shoppingResponseId['ResponseID']);
    }

    final pricedOfferData = result['PricedOffer'];
    final pricedOffers = <Map<String, dynamic>>[];
    if (pricedOfferData is List) {
      for (final item in pricedOfferData) {
        if (item is Map<String, dynamic>) {
          pricedOffers.add(item);
        }
      }
    } else if (pricedOfferData is Map<String, dynamic>) {
      pricedOffers.add(pricedOfferData);
    }
    result['pricedOffers'] = pricedOffers;

    return {
      'success': true,
      'pricedOffer': result['PricedOffer'],
      'pricedOffers': pricedOffers,
      'shoppingResponse': shoppingResponseId,
      'responseId': responseId,
      'dataLists': result['DataLists'],
      'raw_xml': xmlResponse,
      'message': 'Offer priced successfully',
    };
  } catch (e, stackTrace) {
    debugPrint('❌ ERROR parsing OfferPrice response: $e');
    debugPrint('Stack trace: $stackTrace');
    return {
      'success': false,
      'error': 'Failed to parse OfferPrice response: $e',
      'raw_xml': xmlResponse,
    };
  }
}

Map<String, dynamic> _parsePnrResponse(String xmlResponse) {
  try {
    final document = xml.XmlDocument.parse(xmlResponse);
    
    // Check for errors first
    final errors = document.findAllElements('Error');
    if (errors.isNotEmpty) {
      final errorMsg = errors.first.text;
      return {
        'success': false,
        'error': errorMsg,
      };
    }
    
    // Look for OrderViewRS
    final orderViewRS = document.findAllElements('OrderViewRS').firstOrNull;
    if (orderViewRS == null) {
      return {
        'success': false,
        'error': 'OrderViewRS not found in response',
      };
    }
    
    // Extract Success element
    final success = orderViewRS.findElements('Success').firstOrNull;
    if (success == null) {
      return {
        'success': false,
        'error': 'Success element not found in response',
      };
    }
    
    // Extract Order information
    final response = orderViewRS.findElements('Response').firstOrNull;
    if (response == null) {
      return {
        'success': false,
        'error': 'Response element not found',
      };
    }
    
    final order = response.findElements('Order').firstOrNull;
    if (order == null) {
      return {
        'success': false,
        'error': 'Order element not found',
      };
    }
    
    // Extract PNR from BookingReferences
    String pnr = '';
    final bookingReferences = order.findElements('BookingReferences').firstOrNull;
    if (bookingReferences != null) {
      final bookingRefElements = bookingReferences.findElements('BookingReference').toList();
      if (bookingRefElements.isNotEmpty) {
        final firstId = bookingRefElements.first.findElements('ID').firstOrNull;
        if (firstId != null && firstId.text.trim().isNotEmpty) {
          pnr = firstId.text.trim();
        } else {
          for (var bookingRef in bookingRefElements) {
            final fallbackId = bookingRef.findElements('ID').firstOrNull;
            if (fallbackId != null && fallbackId.text.trim().isNotEmpty) {
              pnr = fallbackId.text.trim();
              break;
            }
          }
        }
      }
    }
    
    // Extract Order ID
    final orderId = order.getAttribute('OrderID') ?? '';
    
    // Extract Total Price
    String totalPrice = '';
    String currency = '';
    final totalOrderPrice = order.findElements('TotalOrderPrice').firstOrNull;
    if (totalOrderPrice != null) {
      final detailCurrencyPrice = totalOrderPrice.findElements('DetailCurrencyPrice').firstOrNull;
      if (detailCurrencyPrice != null) {
        final total = detailCurrencyPrice.findElements('Total').firstOrNull;
        if (total != null) {
          totalPrice = total.text;
          currency = total.getAttribute('Code') ?? '';
        }
      }
    }
    
    return {
      'success': true,
      'pnr': pnr,
      'orderId': orderId,
      'totalPrice': totalPrice,
      'currency': currency,
      'rawResponse': xmlResponse,
    };
  } catch (e, stackTrace) {
    debugPrint('❌ Error parsing PNR response: $e');
    debugPrint('Stack trace: $stackTrace');
    return {
      'success': false,
      
      'error': 'Failed to parse PNR response: $e',
    };
  }
}

String _buildIdentityDocumentBlock({
  required String documentNumber,
  required String expiryDate,
  required String issuingCountry,
  required String nationalityCountry,
}) {
  final docNumber = documentNumber.trim();
  final docExpiry = expiryDate.trim();
  final issuing = issuingCountry.trim().isEmpty ? 'PK' : issuingCountry.trim();
  final nationality = nationalityCountry.trim().isEmpty ? issuing : nationalityCountry.trim();

  if (docNumber.isEmpty || docExpiry.isEmpty) {
    return '';
  }

  return '''
                         <IdentityDocument>
                             <IdentityDocumentNumber>$docNumber</IdentityDocumentNumber>
                             <IdentityDocumentType>PT</IdentityDocumentType>
                             <ExpiryDate>$docExpiry</ExpiryDate>
                             <IssuingCountryCode>$issuing</IssuingCountryCode>
                             <NationalityCountryCode>$nationality</NationalityCountryCode>
                         </IdentityDocument>''';
}

}

class OfferPriceCredential {
  final String credentialName;
  final String endpoint;
  final String subscriptionKey;
  final String agencyHeader;
  final String iataHeader;
  final String pccHeader;
  final String idenUser;
  final String idenPassword;
  final String pseudoCity;
  final String agencyId;
  final String agt;
  final String agtPassword;
  final String agtRole;
  final String agentUser;
  final String trace;
  final bool traceAdmin;
  final String scriptName;
  final String scriptEngine;

  const OfferPriceCredential({
    required this.credentialName,
    required this.endpoint,
    required this.subscriptionKey,
    required this.agencyHeader,
    required this.iataHeader,
    required this.pccHeader,
    required this.idenUser,
    required this.idenPassword,
    required this.pseudoCity,
    required this.agencyId,
    required this.agt,
    required this.agtPassword,
    required this.agtRole,
    required this.agentUser,
    required this.trace,
    required this.traceAdmin,
    required this.scriptName,
    required this.scriptEngine,
  });
}