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
/// Used only to style the Book Now button — never to change behaviour.
bool isOwnHotel(Map<dynamic, dynamic> hotel) =>
    hotel['source']?.toString() == kHotelSourceOwn;

String _hotelIdOf(Map<String, dynamic> hotel) =>
    hotel['hotelCode']?.toString().trim() ?? '';

double _priceOf(Map<String, dynamic> hotel) =>
    double.tryParse(hotel['price']?.toString().replaceAll(',', '').trim() ?? '') ??
    0.0;

/// Merges the third-party list with our own-DB list, matching on hotel id
/// (`hotelCode`, which is `hotel_id` on the own-DB side).
///
/// * id in BOTH lists  -> our own record wins and replaces the third-party one,
///   keeping the third-party position so existing ordering is undisturbed.
/// * id only in the third-party list -> passed through untouched.
/// * id only in our own DB -> appended to the list.
///
/// Every returned card carries `source`: [kHotelSourceOwn] or
/// [kHotelSourceThirdParty]. Own records without an id are skipped: they cannot
/// be deduped, image-loaded or opened.
List<Map<String, dynamic>> mergeHotelLists({
  required List<Map<String, dynamic>> thirdPartyHotels,
  required List<Map<String, dynamic>> ownHotels,
}) {
  final Map<String, Map<String, dynamic>> ownById = {};
  for (final hotel in ownHotels) {
    final String id = _hotelIdOf(hotel);
    if (id.isEmpty) continue;
    ownById[id] = <String, dynamic>{...hotel, 'source': kHotelSourceOwn};
  }

  final List<Map<String, dynamic>> merged = [];
  final Set<String> overriddenIds = {};

  for (final thirdParty in thirdPartyHotels) {
    final String id = _hotelIdOf(thirdParty);
    final Map<String, dynamic>? own = id.isEmpty ? null : ownById[id];

    if (own == null) {
      merged.add(<String, dynamic>{
        ...thirdParty,
        'source': kHotelSourceThirdParty,
      });
      continue;
    }

    overriddenIds.add(id);
    merged.add(_withPriceFallback(own: own, thirdParty: thirdParty));
  }

  for (final entry in ownById.entries) {
    if (overriddenIds.contains(entry.key)) continue;
    merged.add(entry.value);
  }

  return merged;
}

/// Our own record wins, but "price on call" hotels come back with a 0 price.
/// When we are overriding a third-party entry that does have a price, keep that
/// price so the card never renders "PKR 0". Everything else stays own-DB data.
Map<String, dynamic> _withPriceFallback({
  required Map<String, dynamic> own,
  required Map<String, dynamic> thirdParty,
}) {
  if (_priceOf(own) > 0) return own;

  final double thirdPartyPrice = _priceOf(thirdParty);
  if (thirdPartyPrice <= 0) return own;

  return <String, dynamic>{...own, 'price': thirdPartyPrice};
}
