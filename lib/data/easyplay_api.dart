import '../core/api_client.dart';
import 'models.dart';

/// Typed wrappers over the EasyPlay REST endpoints the app uses.
class EasyPlayApi {
  EasyPlayApi(this._c);
  final ApiClient _c;

  // Auth / profile
  String get googleSignInUrl => '$apiBaseUrl/auth/oauth/google?redirect=true';

  Future<Profile> me() async => Profile((await _c.get('/auth/me'))['user']);

  Future<Profile> updateMe({String? fullName, String? city, String? phone, List<String>? preferredSports}) async {
    final body = <String, Object?>{
      'full_name': ?fullName,
      'city': ?city,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'preferred_sports': ?preferredSports,
    };
    return Profile((await _c.patch('/auth/me', body))['user']);
  }

  Future<void> logout() => _c.post('/auth/logout');

  // Catalog
  Future<List<CatalogItem>> sports() async =>
      ((await _c.get('/sports'))['sports'] as List).cast<Json>().map(CatalogItem.new).toList();

  Future<List<String>> cities() async =>
      ((await _c.get('/venues/cities'))['cities'] as List).cast<Json>().map((c) => c['city'] as String).toList();

  // Venues
  Future<List<VenueSearchResult>> searchVenues({String? city, String? sport, String? q, int page = 1}) async {
    final res = await _c.get('/venues', query: {'city': city, 'sport': sport, 'q': q, 'page': page, 'limit': 20});
    return (res['venues'] as List).cast<Json>().map(VenueSearchResult.new).toList();
  }

  Future<PublicVenue> venue(String idOrSlug) async => PublicVenue((await _c.get('/venues/$idOrSlug'))['venue']);

  Future<Availability> availability(String idOrSlug, String date) async =>
      Availability(await _c.get('/venues/$idOrSlug/availability', query: {'date': date}));

  // Favourites
  Future<Set<String>> favouriteIds() async =>
      ((await _c.get('/me/favourites'))['favourites'] as List).cast<Json>().map((f) => f['id'] as String).toSet();
  Future<void> addFavourite(String venueId) => _c.put('/me/favourites/$venueId');
  Future<void> removeFavourite(String venueId) => _c.delete('/me/favourites/$venueId');

  // Bookings
  Map<String, Object?> _bookingBody(String courtId, String date, String start, int minutes, String method) => {
        'court_id': courtId,
        'date': date,
        'start': start,
        'duration_minutes': minutes,
        'payment_method': method,
      };

  Future<Quote> quote(String courtId, String date, String start, int minutes, String method) async =>
      Quote((await _c.post('/bookings/quote', _bookingBody(courtId, date, start, minutes, method)))['quote']);

  Future<Booking> book(String courtId, String date, String start, int minutes, String method) async =>
      Booking((await _c.post('/bookings', _bookingBody(courtId, date, start, minutes, method)))['booking']);

  Future<List<Booking>> myBookings({String scope = 'upcoming'}) async =>
      ((await _c.get('/me/bookings', query: {'scope': scope}))['bookings'] as List).cast<Json>().map(Booking.new).toList();

  Future<Booking> myBooking(String id) async => Booking((await _c.get('/me/bookings/$id'))['booking']);

  Future<void> cancelBooking(String id, {String? reason}) =>
      _c.post('/me/bookings/$id/cancel', {'reason': ?reason});
}
