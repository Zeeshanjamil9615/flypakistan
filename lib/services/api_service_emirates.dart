// services/api_service_emirates.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:xml/xml.dart' as xml;
import 'api_client.dart';
import '../views/flight/search_flights/sabre/sabre_flight_models.dart';
import '../views/flight/search_flights/search_flight_utils/helper_functions.dart';
import 'api_service_airblue.dart';
import 'margin_service_flight.dart';

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
  // ApiClient instance
  final ApiClient _apiClient = ApiClient();

  // Airline map for airline name lookup
  static Map<String, AirlineInfo>? _airlineMap;

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
    bool printRequest = false,
    bool printResponse = false,
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
          throw ApiException(
            message: 'No valid travel segments provided for Emirates search',
            statusCode: null,
            errors: {},
          );
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
        throw ApiException(
          message: 'Failed to prepare Emirates travel segments',
          statusCode: null,
          errors: {},
        );
      }

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
      };

      final response = await _apiClient.request(
        url: 'https://ek.farelogix.com:443/prod/oc',
        method: HttpMethod.POST,
        serviceName: 'EMIRATES SEARCH',
        body: xmlData,
        headers: headers,
        contentType: ContentType.XML,
        convertXmlToJson: false,
        printRequestBody: printRequest,
        printResponseBody: printResponse,
      );

      if (response.isSuccess) {
        return _parseXmlResponse(response.responseBody);
      } else {
        throw ApiException(
          message: response.message,
          statusCode: response.statusCode,
          errors: {},
        );
      }
    } catch (e, stackTrace) {
      if (e is ApiException) rethrow;
      return {
        'success': false,
        'error': 'Error: ${e.toString()}',
      };
    }
  }

  String _generateTransactionId() {
    return DateTime.now().millisecondsSinceEpoch.toRadixString(16);
  }

  Map<String, dynamic> _parseXmlResponse(String xmlResponse) {
    try {
      if (xmlResponse.contains('<Error>') || xmlResponse.contains('error')) {
        return {
          'success': false,
          'error': 'Emirates API returned an error',
          'raw_xml': xmlResponse,
        };
      }

      final document = xml.XmlDocument.parse(xmlResponse);
      final structuredData = _extractStructuredData(document);

      return {
        'success': true,
        'data': structuredData,
        'raw_xml': xmlResponse,
        'message': 'XML successfully parsed',
      };
    } catch (e, stackTrace) {
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
      final airShoppingRS = document.findAllElements('AirShoppingRS').firstOrNull;

      if (airShoppingRS == null) {
        return result;
      }

      final dataLists = _extractDataLists(airShoppingRS);
      result['DataLists'] = dataLists;

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
        }
      }

    } catch (e, stackTrace) {
      // Error extracting structured data
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
      // Error extracting DataLists
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
      final data = response['data'] ?? response;

      if (data.containsKey('offers') && data['offers'] is List) {
        final offersList = data['offers'] as List;

        for (var offer in offersList) {
          if (offer is Map<String, dynamic>) {
            offers.add(offer);
          }
        }
      } else {
        offers.addAll(_deepSearchOffers(data));
      }

    } catch (e, stackTrace) {
      // Error extracting offers
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
    return offers;
  }

  Future<Map<String, dynamic>> createEmiratesNdcPnr({
    required List<Map<String, dynamic>> selectedOffers,
    required dynamic bookingController,
    bool printRequest = false,
    bool printResponse = false,
  }) async {
    try {
      if (selectedOffers.isEmpty) {
        return {
          'success': false,
          'error': 'No offers provided for PNR creation.',
        };
      }

      String passengerListXml = '';
      int passengerIndex = 1;
      final passengerRefsOrdered = <String>[];
      final validPassengerIds = <String>{};

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
        passengerIndex++;
      }

      final defaultPassengerRefs =
      passengerRefsOrdered.isNotEmpty ? passengerRefsOrdered.join(' ') : 'T1';

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
          continue;
        }

        final owner = offerData['Owner']?.toString() ?? 'EK';
        final responseId = _resolveResponseId(offerData, resolvedOfferId);

        if (responseId.isEmpty) {
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
          resolvedItems.add({
            'id': fallbackItemId,
            'passengerRefs': defaultPassengerRefs,
          });
        }

        final dedupeKey = '${resolvedOfferId}::${resolvedItems.map((e) => e['id']).join(',')}';
        if (seenOfferKeys.contains(dedupeKey)) {
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
      };

      final response = await _apiClient.request(
        url: 'https://ek.farelogix.com:443/prod/oc',
        method: HttpMethod.POST,
        serviceName: 'EMIRATES CREATE PNR',
        body: xmlData,
        headers: headers,
        contentType: ContentType.XML,
        convertXmlToJson: false,
        printRequestBody: printRequest,
        printResponseBody: printResponse,
      );

      Map<String, dynamic> parsedResponse;

      if (response.isSuccess) {
        parsedResponse = _parsePnrResponse(response.responseBody);
      } else {
        parsedResponse = {
          'success': false,
          'error': 'Server error ${response.statusCode}: ${response.responseBody}',
        };
      }

      // Save booking regardless of PNR success/failure
      try {
        await saveEmiratesBooking(
          selectedOffers: selectedOffers,
          pnrResponse: parsedResponse,
          bookingController: bookingController,
        );
      } catch (saveError) {
        // Don't throw - continue with PNR response
      }

      return parsedResponse;
    } catch (e, stackTrace) {
      final errorResponse = {
        'success': false,
        'error': 'Error: ${e.toString()}',
      };

      // Even if PNR fails, try to save the booking
      try {
        await saveEmiratesBooking(
          selectedOffers: selectedOffers,
          pnrResponse: errorResponse,
          bookingController: bookingController,
        );
      } catch (saveError) {
        // Ignore save error
      }

      return errorResponse;
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
    bool printRequest = false,
    bool printResponse = false,
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

      Map<String, dynamic>? lastError;

      try {
        final response = await _apiClient.request(
          url: credential.endpoint,
          method: HttpMethod.POST,
          serviceName: 'EMIRATES PRICE OFFER',
          body: xmlData,
          headers: headers,
          contentType: ContentType.XML,
          convertXmlToJson: false,
          printRequestBody: printRequest,
          printResponseBody: printResponse,
        );

        if (response.isSuccess) {
          final parsedResponse = _parseOfferPriceResponse(response.responseBody);
          parsedResponse['credential'] = credential.credentialName;
          return parsedResponse;
        }

        final errorMap = {
          'success': false,
          'error': 'Server error ${response.statusCode}: ${response.responseBody}',
          'raw_xml': response.responseBody,
          'credential': credential.credentialName,
        };

        lastError = errorMap;
      } catch (e, stackTrace) {
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

  String _buildOfferItemsXml(List<OfferPricingItem> items) {
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


  // Helper method to extract total price from selected offers
 double _extractTotalPriceFromOffers(List<Map<String, dynamic>> selectedOffers) {
    double totalPrice = 0.0;
    try {
      for (var offer in selectedOffers) {
        final offerData = offer['offerData'] ?? offer['data'] ?? offer['rawFlightData'] ?? offer;
        final possiblePriceNodes = [
          offerData['TotalPrice'],
          offerData['OfferPrice'],
          offerData['PricedOffer']?['TotalPrice'],
          offerData['PricedOffer']?['OfferPrice'],
        ];

        double priceForOffer = 0.0;
        for (final node in possiblePriceNodes) {
          priceForOffer = _extractPriceValue(node);
          if (priceForOffer > 0) break;
        }

        totalPrice += priceForOffer;
      }
    } catch (e) {
      // Error extracting total price
    }
    return totalPrice > 0 ? totalPrice : 0.0;
  }

  double _extractPriceValue(dynamic node) {
    if (node == null) return 0.0;

    if (node is num) return node.toDouble();

    if (node is String) {
      final cleaned = node.replaceAll(',', '');
      final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(cleaned);
      return match != null ? double.tryParse(match.group(0)!) ?? 0.0 : 0.0;
    }

    if (node is List) {
      double sum = 0.0;
      for (final item in node) {
        sum += _extractPriceValue(item);
      }
      return sum;
    }

    if (node is Map) {
      // Direct numeric/text fields
      if (node.containsKey('\$t')) {
        final value = _extractPriceValue(node['\$t']);
        if (value > 0) return value;
      }
      if (node.containsKey('value')) {
        final value = _extractPriceValue(node['value']);
        if (value > 0) return value;
      }
      if (node.containsKey('text')) {
        final value = _extractPriceValue(node['text']);
        if (value > 0) return value;
      }
      if (node.containsKey('_text')) {
        final value = _extractPriceValue(node['_text']);
        if (value > 0) return value;
      }

      // Common price blocks
      if (node.containsKey('SimpleCurrencyPrice')) {
        final value = _extractPriceValue(node['SimpleCurrencyPrice']);
        if (value > 0) return value;
      }
      if (node.containsKey('DetailCurrencyPrice')) {
        final value = _extractPriceValue(node['DetailCurrencyPrice']);
        if (value > 0) return value;
      }
      if (node.containsKey('Total')) {
        final value = _extractPriceValue(node['Total']);
        if (value > 0) return value;
      }

      // Fallback: scan remaining map values
      for (final value in node.values) {
        final extracted = _extractPriceValue(value);
        if (extracted > 0) return extracted;
      }
    }

    return 0.0;
  }


  // Replace the saveEmiratesBooking method in api_service_emirates.dart

  Future<Map<String, dynamic>> saveEmiratesBooking({
    required List<Map<String, dynamic>> selectedOffers,
    required Map<String, dynamic> pnrResponse,
    required dynamic bookingController,
    bool printRequest = true,
    bool printResponse = false,
  }) async {
    try {
      // Extract flights data from PNR response
      final flights = await _extractFlightsFromPnrResponse(pnrResponse);

      // Extract deadline time from PNR response
      final deadlineTime = _extractDeadlineFromPnrResponse(pnrResponse);

      debugPrint('✅ Extracted ${flights.length} flights from PNR response');
      debugPrint('✅ Extracted deadline time: $deadlineTime');

      final bookingInfo = {
        "bfname": bookingController.firstNameController.text,
        "blname": bookingController.lastNameController.text,
        "bemail": bookingController.emailController.text,
        "bphno": bookingController.phoneController.text,
        "badd": "b",
        "bcity": "a",
        "final_price": _extractTotalPriceFromOffers(selectedOffers).toString(),
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
          "nationality": adult.nationalityCountry.value?.countryCode ?? 'PK',
          "passport": adult.passportCnicController.text,
          "passport_expiry": adult.passportExpiryController.text,
          "cnic": adult.passportCnicController.text,
        };
      }).toList();

      // Prepare children data
      final children = bookingController.children.map((child) {
        return {
          "title": child.titleController.text,
          "first_name": child.firstNameController.text,
          "last_name": child.lastNameController.text,
          "dob": child.dateOfBirthController.text,
          "nationality": child.nationalityCountry.value?.countryCode ?? 'PK',
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
          "nationality": infant.nationalityCountry.value?.countryCode ?? 'PK',
          "passport": "a",
          "passport_expiry": "a",
          "cnic": "a",
        };
      }).toList();

      // Determine PNR status (1 for success, 0 for failure)
      final pnrStatus = pnrResponse['success'] == true ? 1 : 0;
      final pnr = pnrResponse['pnr']?.toString() ?? '';

      // Calculate total price
      final totalPrice = _extractTotalPriceFromOffers(selectedOffers);

      final ApiServiceMargin apiServiceMargin = Get.put(ApiServiceMargin());
      Map<String, dynamic> marginData = {};
      try {
        marginData = await apiServiceMargin.getMargin('EK', 'Emirates', "Emirates NDC");
      } catch (e) {
        debugPrint('⚠️ Error fetching margin: $e');
      }

      final calculatedSellingPrice = apiServiceMargin.calculatePriceWithMargin(totalPrice, marginData);

      // Prepare final request body
      final requestBody = {
        "booking_info": bookingInfo,
        "adults": adults,
        "children": children,
        "infants": infants,
        "flights": flights,
        "pnr": pnr,
        "buyingPrice": totalPrice.toStringAsFixed(0),
        "sellingPrice": calculatedSellingPrice,
        "pnrStatus": pnrStatus,
        "booking_from": "1",
        "gds": "Emirates",
        "deadline_time": deadlineTime, // Add deadline time
      };

      final response = await _apiClient.request(
        url: 'https://readyflights.pk/api/flight-booking',
        method: HttpMethod.POST,
        serviceName: 'EMIRATES SAVE BOOKING',
        body: jsonEncode(requestBody),
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
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving Emirates booking: $e');
      debugPrint('Stack trace: $stackTrace');
      if (e is ApiException) rethrow;
      return {
        'success': false,
        'error': 'Error saving booking: ${e.toString()}',
      };
    }
  }

// Extract flights from PNR response
  Future<List<Map<String, dynamic>>> _extractFlightsFromPnrResponse(
      Map<String, dynamic> pnrResponse) async {
    final flights = <Map<String, dynamic>>[];

    try {
      // Parse the raw XML response if available
      String? rawXml = pnrResponse['rawResponse'];

      if (rawXml == null || rawXml.isEmpty) {
        debugPrint('⚠️ No raw XML in PNR response');
        return flights;
      }

      final document = xml.XmlDocument.parse(rawXml);

      // Navigate to DataLists > FlightSegmentList
      final dataLists = document.findAllElements('DataLists').firstOrNull;
      if (dataLists == null) {
        debugPrint('⚠️ DataLists not found in PNR response');
        return flights;
      }

      final flightSegmentList = dataLists.findElements('FlightSegmentList').firstOrNull;
      if (flightSegmentList == null) {
        debugPrint('⚠️ FlightSegmentList not found');
        return flights;
      }

      // Extract OrderItems to get cabin class info
      final orderItems = document.findAllElements('OrderItem').toList();
      String cabinClass = 'Economy';
      String cabinCode = 'Y';

      if (orderItems.isNotEmpty) {
        final fareDetail = orderItems.first.findElements('FareDetail').firstOrNull;
        if (fareDetail != null) {
          final fareComponent = fareDetail.findElements('FareComponent').firstOrNull;
          if (fareComponent != null) {
            final fareBasis = fareComponent.findElements('FareBasis').firstOrNull;
            if (fareBasis != null) {
              final cabinType = fareBasis.findElements('CabinType').firstOrNull;
              if (cabinType != null) {
                final cabinTypeCode = cabinType.findElements('CabinTypeCode').firstOrNull;
                final cabinTypeName = cabinType.findElements('CabinTypeName').firstOrNull;

                if (cabinTypeCode != null && cabinTypeCode.text.isNotEmpty) {
                  cabinCode = cabinTypeCode.text.trim();
                }
                if (cabinTypeName != null && cabinTypeName.text.isNotEmpty) {
                  cabinClass = cabinTypeName.text.trim();
                }
              }
            }
          }
        }
      }

      // Process each flight segment
      for (var segmentElement in flightSegmentList.findElements('FlightSegment')) {
        try {
          // Extract departure info
          final departure = segmentElement.findElements('Departure').firstOrNull;
          if (departure == null) continue;

          final depAirportCode = departure.findElements('AirportCode').firstOrNull?.text.trim() ?? '';
          final depDate = departure.findElements('Date').firstOrNull?.text.trim() ?? '';
          final depTime = departure.findElements('Time').firstOrNull?.text.trim() ?? '';
          final depTerminalElement = departure.findElements('Terminal').firstOrNull;
          final depTerminal = depTerminalElement?.findElements('Name').firstOrNull?.text.trim() ?? 'Main';

          // Extract arrival info
          final arrival = segmentElement.findElements('Arrival').firstOrNull;
          if (arrival == null) continue;

          final arrAirportCode = arrival.findElements('AirportCode').firstOrNull?.text.trim() ?? '';
          final arrDate = arrival.findElements('Date').firstOrNull?.text.trim() ?? '';
          final arrTime = arrival.findElements('Time').firstOrNull?.text.trim() ?? '';
          final arrTerminalElement = arrival.findElements('Terminal').firstOrNull;
          final arrTerminal = arrTerminalElement?.findElements('Name').firstOrNull?.text.trim() ?? 'Main';

          // Validate essential data
          if (depAirportCode.isEmpty || arrAirportCode.isEmpty ||
              depDate.isEmpty || arrDate.isEmpty) {
            debugPrint('⚠️ Missing essential flight data, skipping segment');
            continue;
          }

          // Extract marketing carrier info
          final marketingCarrier = segmentElement.findElements('MarketingCarrier').firstOrNull;
          final airlineCode = marketingCarrier?.findElements('AirlineID').firstOrNull?.text.trim() ?? 'EK';
          final airlineName = marketingCarrier?.findElements('Name').firstOrNull?.text.trim() ?? 'Emirates';
          final flightNumber = marketingCarrier?.findElements('FlightNumber').firstOrNull?.text.trim() ?? '';

          // Extract operating carrier (if different from marketing)
          final operatingCarrier = segmentElement.findElements('OperatingCarrier').firstOrNull;
          final operatingAirlineCode = operatingCarrier?.findElements('AirlineID').firstOrNull?.text.trim() ?? airlineCode;
          final operatingAirlineName = operatingCarrier?.findElements('Name').firstOrNull?.text.trim() ?? airlineName;

          // Get airline names from API
          final marketingAirlineNameFromApi = await _getAirlineNameFromCode(airlineCode);
          final operatingAirlineNameFromApi = await _getAirlineNameFromCode(operatingAirlineCode);

          // Extract equipment
          final equipment = segmentElement.findElements('Equipment').firstOrNull;
          final aircraftCode = equipment?.findElements('AircraftCode').firstOrNull?.text.trim() ?? 'Unknown';

          // Extract flight details for duration
          final flightDetail = segmentElement.findElements('FlightDetail').firstOrNull;
          String durationString = '';
          int durationMinutes = 0;

          if (flightDetail != null) {
            final flightDuration = flightDetail.findElements('FlightDuration').firstOrNull;
            if (flightDuration != null) {
              final durationValue = flightDuration.findElements('Value').firstOrNull?.text.trim() ?? '';
              if (durationValue.startsWith('PT')) {
                final hoursMatch = RegExp(r'(\d+)H').firstMatch(durationValue);
                final minutesMatch = RegExp(r'(\d+)M').firstMatch(durationValue);
                final hours = hoursMatch != null ? int.parse(hoursMatch.group(1)!) : 0;
                final minutes = minutesMatch != null ? int.parse(minutesMatch.group(1)!) : 0;
                durationMinutes = hours * 60 + minutes;
                durationString = '${hours}h ${minutes}m';
              }
            }
          }

          // If no duration found, calculate from times
          if (durationMinutes == 0) {
            try {
              final depDateTime = DateTime.parse('${depDate}T$depTime');
              final arrDateTime = DateTime.parse('${arrDate}T$arrTime');
              final duration = arrDateTime.difference(depDateTime);
              durationMinutes = duration.inMinutes;
              durationString = '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
            } catch (e) {
              durationString = 'N/A';
            }
          }

          // Build flight object
          flights.add({
            "departure": {
              "airport": depAirportCode,
              "city": depAirportCode,
              "date": depDate,
              "time": depTime,
              "terminal": depTerminal,
            },
            "arrival": {
              "airport": arrAirportCode,
              "city": arrAirportCode,
              "date": arrDate,
              "time": arrTime,
              "terminal": arrTerminal,
            },
            "flight_number": flightNumber,
            "airline_code": airlineCode,
            "airline_name": marketingAirlineNameFromApi.isNotEmpty ? marketingAirlineNameFromApi : airlineName,
            "operating_flight_number": flightNumber,
            "operating_airline_code": operatingAirlineCode,
            "operating_airline_name": operatingAirlineNameFromApi.isNotEmpty ? operatingAirlineNameFromApi : operatingAirlineName,
            "cabin_class": cabinClass,
            "sub_class": cabinCode,
            "booking_class": cabinCode,
            "hand_baggage": "7kg",
            "check_baggage": "30kg",
            "meal": "Meal",
            "layover": flights.isNotEmpty ? "Yes" : "None",
            "duration": durationString,
            "duration_minutes": durationMinutes,
            "type": flights.isEmpty ? "One-Way" : "Return",
            "fare_basis": "",
            "seats_available": "",
            "is_refundable": true,
            "aircraft_type": aircraftCode,
          });

          debugPrint('✅ Added flight: $depAirportCode -> $arrAirportCode on $depDate at $depTime');

        } catch (e, stackTrace) {
          debugPrint('❌ Error processing flight segment: $e');
          continue;
        }
      }

    } catch (e, stackTrace) {
      debugPrint('❌ Error extracting flights from PNR: $e');
      debugPrint('Stack trace: $stackTrace');
    }

    if (flights.isEmpty) {
      debugPrint('⚠️ No flights were extracted from PNR response');
    } else {
      debugPrint('✅ Successfully extracted ${flights.length} flight segments from PNR');
    }

    return flights;
  }

// Extract deadline time from PNR response
  String _extractDeadlineFromPnrResponse(Map<String, dynamic> pnrResponse) {
    try {
      String? rawXml = pnrResponse['rawResponse'];

      if (rawXml == null || rawXml.isEmpty) {
        debugPrint('⚠️ No raw XML for deadline extraction');
        return '';
      }

      final document = xml.XmlDocument.parse(rawXml);

      // Look for TimeLimits > PaymentTimeLimit or TicketingTimeLimits
      final timeLimits = document.findAllElements('TimeLimits').firstOrNull;

      if (timeLimits != null) {
        // Try PaymentTimeLimit first
        final paymentTimeLimit = timeLimits.findElements('PaymentTimeLimit').firstOrNull;
        if (paymentTimeLimit != null) {
          final timestamp = paymentTimeLimit.getAttribute('Timestamp');
          if (timestamp != null && timestamp.isNotEmpty) {
            return _formatDeadlineTimestamp(timestamp);
          }
        }

        // Fallback to TicketingTimeLimits
        final ticketingTimeLimit = timeLimits.findElements('TicketingTimeLimits').firstOrNull;
        if (ticketingTimeLimit != null) {
          final timestamp = ticketingTimeLimit.getAttribute('Timestamp');
          if (timestamp != null && timestamp.isNotEmpty) {
            return _formatDeadlineTimestamp(timestamp);
          }
        }
      }

      // Alternative: Look for Warning messages with deadline info
      final warnings = document.findAllElements('Warning').toList();
      for (var warning in warnings) {
        final shortText = warning.getAttribute('ShortText');
        if (shortText != null && shortText.contains('BY')) {
          try {
            // Parse format like "BOOK BY 15FEB 0320"
            final parts = shortText.split('BY');
            if (parts.length > 1) {
              final dateParts = parts[1].trim().split(' ');
              if (dateParts.length >= 2) {
                final day = dateParts[0].substring(0, 2);
                final month = dateParts[0].substring(2, 5);
                final time = dateParts[1].replaceAll(':', '');
                final timeFormatted = '${time.substring(0, 2)}:${time.substring(2, 4)}';

                final year = DateTime.now().year;
                final dateString = '$year-$month-$day $timeFormatted';

                try {
                  // Use replaceAllMapped so we can provide a function that maps Match -> String
                  final normalizedDateString = dateString.replaceAllMapped(
                    RegExp(r'[A-Z]{3}'),
                    _getMonthNumber,
                  );
                  final dateTime = DateTime.parse(normalizedDateString);
                  return dateTime.toIso8601String().replaceAll('T', ' ').substring(0, 19);
                } catch (e) {
                  debugPrint('⚠️ Error parsing deadline from warning: $e');
                }
              }
            }
          } catch (e) {
            debugPrint('⚠️ Error processing warning text: $e');
          }
        }
      }

      debugPrint('⚠️ No deadline time found in PNR response');
      return '';

    } catch (e, stackTrace) {
      debugPrint('❌ Error extracting deadline: $e');
      debugPrint('Stack trace: $stackTrace');
      return '';
    }
  }

// Format deadline timestamp from ISO format to Y-m-d H:i:s
  String _formatDeadlineTimestamp(String timestamp) {
    try {
      // Parse ISO 8601 format: 2026-02-15T03:20:00
      final dateTime = DateTime.parse(timestamp);
      // Format as: 2026-02-15 03:20:00
      return '${dateTime.year.toString().padLeft(4, '0')}-'
          '${dateTime.month.toString().padLeft(2, '0')}-'
          '${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:'
          '${dateTime.minute.toString().padLeft(2, '0')}:'
          '${dateTime.second.toString().padLeft(2, '0')}';
    } catch (e) {
      debugPrint('⚠️ Error formatting deadline timestamp: $e');
      return '';
    }
  }

// Helper to convert month name to number
  String _getMonthNumber(Match match) {
    final months = {
      'JAN': '01', 'FEB': '02', 'MAR': '03', 'APR': '04',
      'MAY': '05', 'JUN': '06', 'JUL': '07', 'AUG': '08',
      'SEP': '09', 'OCT': '10', 'NOV': '11', 'DEC': '12',
    };
    return months[match.group(0)] ?? '01';
  }


  // Fetch airline data from API
  Future<Map<String, AirlineInfo>> _fetchAirlineData() async {
    if (_airlineMap != null) {
      return _airlineMap!;
    }

    Map<String, AirlineInfo> tempAirlineMap = {};

    try {
      final response = await _apiClient.request(
        url: 'https://agent1.pk/api.php?type=airlines',
        method: HttpMethod.GET,
        serviceName: 'AIRLINES DATA',
        contentType: ContentType.JSON,
        printRequestBody: false,
        printResponseBody: false,
      );

      if (response.isSuccess && response.responseJson != null) {
        var data = response.responseJson!['data'];
        for (var item in data) {
          String logoUrl = item['logo'];
          logoUrl = logoUrl.replaceAll(RegExp(r'^\t+'), '');

          tempAirlineMap[item['code']] = AirlineInfo(
            item['name'],
            logoUrl,
          );
        }
        _airlineMap = tempAirlineMap;
      }
    } catch (e) {
      // Error fetching airline data
    }

    return tempAirlineMap;
  }

  // Helper method to get airline name from carrier code using API
  Future<String> _getAirlineNameFromCode(String carrierCode) async {
    final airlineMap = await _fetchAirlineData();
    final airlineInfo = getAirlineInfo(carrierCode.toUpperCase(), airlineMap);
    return airlineInfo.name;
  }

  // Helper method to prepare Emirates flight data
  Future<List<Map<String, dynamic>>> _prepareEmiratesFlightData(
      List<Map<String, dynamic>> selectedOffers) async {
    final flights = <Map<String, dynamic>>[];

    try {
      for (var offer in selectedOffers) {
        final offerData = offer['offerData'] ?? offer['data'] ?? offer['rawFlightData'] ?? offer;
        final dataLists = offerData['DataLists'] ?? {};
        final flightSegmentList = dataLists['FlightSegmentList']?['FlightSegment'] ?? {};
        final offerItems = offerData['OfferItem'] ?? [];

        // Handle single or multiple offer items
        final offerItemsList = offerItems is List ? offerItems : [offerItems];

        for (var offerItem in offerItemsList) {
          if (offerItem is! Map) continue;

          // Get FareDetail to access FareComponent
          final fareDetail = offerItem['FareDetail'];
          if (fareDetail == null) continue;

          final fareComponentRaw = fareDetail['FareComponent'];
          if (fareComponentRaw == null) continue;

          final fareComponents = fareComponentRaw is List ? fareComponentRaw : [fareComponentRaw];

          for (var fareComponent in fareComponents) {
            if (fareComponent is! Map) continue;

            // Extract segment references
            final segmentRefsNode = fareComponent['SegmentRefs'] ??
                fareComponent['SegmentRef'] ??
                fareComponent['SegmentReference'];

            final segmentKeys = _extractStringValues(segmentRefsNode);

            for (var segmentKey in segmentKeys) {
              if (segmentKey.isEmpty) continue;

              // Get the flight segment data
              final flightSegment = flightSegmentList is Map ? flightSegmentList[segmentKey] : null;
              if (flightSegment == null || flightSegment is! Map) continue;

              // Extract flight details with proper null checks
              final departure = flightSegment['Departure'] ?? {};
              final arrival = flightSegment['Arrival'] ?? {};
              final operatingCarrier = flightSegment['OperatingCarrier'] ?? {};
              final marketingCarrier = flightSegment['MarketingCarrier'] ?? {};

              // Extract airport codes
              final depAirportCode = _extractNodeText(departure['AirportCode']);
              final arrAirportCode = _extractNodeText(arrival['AirportCode']);

              if (depAirportCode.isEmpty || arrAirportCode.isEmpty) {
                debugPrint('⚠️ Skipping segment - missing airport codes');
                continue;
              }

              // Extract dates and times
              final depDate = _extractNodeText(departure['Date']);
              final depTime = _extractNodeText(departure['Time']) ?? '00:00';
              final arrDate = _extractNodeText(arrival['Date']);
              final arrTime = _extractNodeText(arrival['Time']) ?? '00:00';

              if (depDate.isEmpty || arrDate.isEmpty) {
                debugPrint('⚠️ Skipping segment - missing dates');
                continue;
              }

              // Extract flight number
              final flightNumber = _extractNodeText(flightSegment['FlightNumber']);

              // Extract carrier codes
              final operatingCarrierCode = _extractNodeText(operatingCarrier['AirlineID']);
              final marketingCarrierCode = _extractNodeText(marketingCarrier['AirlineID']);

              // Get airline names from carrier codes using API
              final effectiveMarketingCode = marketingCarrierCode.isNotEmpty ? marketingCarrierCode : 'EK';
              final effectiveOperatingCode = operatingCarrierCode.isNotEmpty ? operatingCarrierCode : effectiveMarketingCode;

              final marketingAirlineName = await _getAirlineNameFromCode(effectiveMarketingCode);
              final operatingAirlineName = await _getAirlineNameFromCode(effectiveOperatingCode);

              // Parse dates and times properly
              DateTime? depDateTime;
              DateTime? arrDateTime;

              try {
                // Try parsing full datetime
                depDateTime = DateTime.parse('${depDate}T$depTime');
              } catch (e) {
                try {
                  // Fallback: parse just date
                  depDateTime = DateTime.parse(depDate);
                } catch (_) {
                  debugPrint('⚠️ Could not parse departure date: $depDate');
                  continue;
                }
              }

              try {
                // Try parsing full datetime
                arrDateTime = DateTime.parse('${arrDate}T$arrTime');
              } catch (e) {
                try {
                  // Fallback: parse just date
                  arrDateTime = DateTime.parse(arrDate);
                } catch (_) {
                  debugPrint('⚠️ Could not parse arrival date: $arrDate');
                  continue;
                }
              }

              // Calculate duration
              final duration = arrDateTime.difference(depDateTime);
              final durationString = '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';

              // Get cabin class from PriceClass
              String cabinClass = 'Economy';
              String cabinCode = 'Y';

              final priceClassRefs = offerItem['Service']?['PriceClassRefs'] ??
                  fareComponent['PriceClassRef'] ?? [];

              if (priceClassRefs is List && priceClassRefs.isNotEmpty) {
                final priceClassId = _extractNodeText(priceClassRefs[0]);
                final priceClassList = dataLists['PriceClassList']?['PriceClass'] ?? {};

                if (priceClassList is Map) {
                  final priceClass = priceClassList[priceClassId];
                  if (priceClass is Map) {
                    final name = _extractNodeText(priceClass['Name']);
                    cabinClass = name.isNotEmpty ? name : cabinClass;
                    final code = _extractNodeText(priceClass['Code']);
                    cabinCode = code.isNotEmpty ? code : cabinCode;
                  }
                }
              } else if (priceClassRefs is String && priceClassRefs.isNotEmpty) {
                final priceClassList = dataLists['PriceClassList']?['PriceClass'] ?? {};
                if (priceClassList is Map) {
                  final priceClass = priceClassList[priceClassRefs];
                  if (priceClass is Map) {
                    final name = _extractNodeText(priceClass['Name']);
                    cabinClass = name.isNotEmpty ? name : cabinClass;
                    final code = _extractNodeText(priceClass['Code']);
                    cabinCode = code.isNotEmpty ? code : cabinCode;
                  }
                }
              }

              // Extract terminals
              final depTerminal = _extractNodeText(departure['Terminal']?['Name']) ?? 'Main';
              final arrTerminal = _extractNodeText(arrival['Terminal']?['Name']) ?? 'Main';

              // Build the flight object
              flights.add({
                "departure": {
                  "airport": depAirportCode,
                  "city": depAirportCode, // Will be resolved by backend
                  "date": depDate,
                  "time": depTime.length == 5 ? depTime : '${depTime.padLeft(5, '0')}',
                  "terminal": depTerminal,
                },
                "arrival": {
                  "airport": arrAirportCode,
                  "city": arrAirportCode, // Will be resolved by backend
                  "date": arrDate,
                  "time": arrTime.length == 5 ? arrTime : '${arrTime.padLeft(5, '0')}',
                  "terminal": arrTerminal,
                },
                "flight_number": flightNumber,
                "airline_code": effectiveMarketingCode,
                "airline_name": marketingAirlineName,
                "operating_flight_number": flightNumber,
                "operating_airline_code": effectiveOperatingCode,
                "operating_airline_name": operatingAirlineName,
                "cabin_class": _getCabinClassName(cabinCode),
                "sub_class": cabinCode,
                "booking_class": cabinCode,
                "hand_baggage": "7kg",
                "check_baggage": "30kg",
                "meal": "Meal",
                "layover": flights.isNotEmpty ? "Yes" : "None",
                "duration": durationString,
                "duration_minutes": duration.inMinutes,
                "type": flights.isEmpty ? "One-Way" : "Return",
                "fare_basis": "",
                "seats_available": "",
                "is_refundable": true,
                "aircraft_type": _extractNodeText(flightSegment['Equipment']?['AircraftCode']) ?? "Unknown",
              });

              debugPrint('✅ Added flight: $depAirportCode -> $arrAirportCode on $depDate at $depTime');
            }
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error preparing Emirates flight data: $e');
      debugPrint('Stack trace: $stackTrace');
    }

    if (flights.isEmpty) {
      debugPrint('⚠️ No flights were extracted from offers');
    } else {
      debugPrint('✅ Successfully prepared ${flights.length} flight segments');
    }

    return flights;
  }

  // Helper method to extract string values from various node types
  List<String> _extractStringValues(dynamic node) {
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

  String _getCabinClassName(String cabinCode) {
    switch (cabinCode.toUpperCase()) {
      case 'F':
        return 'First Class';
      case 'C':
      case 'J':
        return 'Business Class';
      case 'W':
      case 'S':
        return 'Premium Economy';
      case 'Y':
      default:
        return 'Economy';
    }
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

