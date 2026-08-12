/// Merging of our own-database hotels with the third-party (Arabian) hotel
/// results, so the listing screen can render both from a single list.
///
/// Both sides are normalized into the same card shape before they get here
/// (see `ApiServiceHotel.fetchHotels` / `ApiServiceHotel.fetchOwnDbHotels`):
/// name, price, address, image, rating, latitude, longitude, hotelCode,
/// hotelCity — plus a `source` flag added by [mergeHotelLists].
library;

/// Card came from our own database.
const String kHotelSourceOwn = 'own';

/// Card came from the third-party Arabian Hotels API.
const String kHotelSourceThirdParty = 'third_party';

/// True when this card is rendered from our own database data.
/// Own-DB cards say "Request Now", are listed below the third-party ones and
/// skip the third-party availability check.
bool isOwnHotel(Map<dynamic, dynamic> hotel) =>
    hotel['source']?.toString() == kHotelSourceOwn;

String _hotelIdOf(Map<String, dynamic> hotel) =>
    hotel['hotelCode']?.toString().trim() ?? '';

/// Comparison key for "the same hotel from both sources": the name with case,
/// punctuation and spacing removed. Search results are always for one city, so
/// the name alone identifies a hotel well enough.
String _nameKeyOf(Map<String, dynamic> hotel) => hotel['name']
    ?.toString()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]'), '') ??
    '';

double priceOfHotel(Map<dynamic, dynamic> hotel) =>
    double.tryParse(
      hotel['price']?.toString().replaceAll(',', '').trim() ?? '',
    ) ??
    0.0;

/// True when the card must show "Price on call" instead of an amount: either
/// our database flags the hotel as price-on-call, or no price came back at all.
bool isPriceOnCall(Map<dynamic, dynamic> hotel) {
  final flag = hotel['priceOnCall'];
  if (flag == true || flag == 1 || flag?.toString() == '1') return true;
  return priceOfHotel(hotel) <= 0;
}

/// Merges the third-party list with our own-DB list.
///
/// * The third-party (Arabian) hotels come FIRST, in their original order and
///   completely untouched.
/// * Our own-DB hotels are appended BELOW them, and any own hotel that is also
///   in the third-party list is dropped — the Arabian record wins. A duplicate
///   is detected by hotel id (`hotelCode` / `hotel_id`) or by hotel name.
///
/// Every returned card carries `source`: [kHotelSourceOwn] or
/// [kHotelSourceThirdParty]. Own records without an id are skipped: they cannot
/// be deduped, image-loaded or opened.
List<Map<String, dynamic>> mergeHotelLists({
  required List<Map<String, dynamic>> thirdPartyHotels,
  required List<Map<String, dynamic>> ownHotels,
}) {
  final List<Map<String, dynamic>> merged = [];
  final Set<String> seenIds = {};
  final Set<String> seenNames = {};

  for (final thirdParty in thirdPartyHotels) {
    merged.add(<String, dynamic>{
      ...thirdParty,
      'source': kHotelSourceThirdParty,
    });

    final String id = _hotelIdOf(thirdParty);
    if (id.isNotEmpty) seenIds.add(id);
    final String nameKey = _nameKeyOf(thirdParty);
    if (nameKey.isNotEmpty) seenNames.add(nameKey);
  }

  for (final own in ownHotels) {
    final String id = _hotelIdOf(own);
    if (id.isEmpty) continue;

    final String nameKey = _nameKeyOf(own);
    // Already served by the third-party API (or listed twice in our own DB).
    if (seenIds.contains(id)) continue;
    if (nameKey.isNotEmpty && seenNames.contains(nameKey)) continue;

    seenIds.add(id);
    if (nameKey.isNotEmpty) seenNames.add(nameKey);

    merged.add(<String, dynamic>{...own, 'source': kHotelSourceOwn});
  }

  return merged;
}
