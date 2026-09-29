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

  Future<List<CatalogItem>> amenities() async =>
      ((await _c.get('/amenities'))['amenities'] as List).cast<Json>().map(CatalogItem.new).toList();

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

  // Favourites (list)
  Future<List<Favourite>> favourites() async =>
      ((await _c.get('/me/favourites'))['favourites'] as List).cast<Json>().map(Favourite.new).toList();

  // Reviews
  Future<ReviewPage> venueReviews(String idOrSlug, {String sort = 'newest', int limit = 20}) async =>
      ReviewPage(await _c.get('/venues/$idOrSlug/reviews', query: {'sort': sort, 'limit': limit}));

  Future<Review?> myReviewFor(String venueId) async {
    final list = ((await _c.get('/me/reviews'))['reviews'] as List).cast<Json>();
    final match = list.where((r) => r['venue_id'] == venueId);
    return match.isEmpty ? null : Review(match.first);
  }

  Future<void> saveReview(String venueId, int rating, String comment) =>
      _c.put('/me/reviews/$venueId', {'rating': rating, 'comment': comment});

  Future<void> deleteReview(String venueId) => _c.delete('/me/reviews/$venueId');

  // Notifications
  Future<(List<AppNotification>, int unread)> notifications() async {
    final res = await _c.get('/me/notifications', query: {'limit': 50});
    return (
      (res['notifications'] as List).cast<Json>().map(AppNotification.new).toList(),
      (res['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<int> unreadCount() async =>
      ((await _c.get('/me/notifications', query: {'unread': true, 'limit': 1}))['unread_count'] as num?)?.toInt() ?? 0;

  Future<void> markNotificationRead(String id) => _c.post('/me/notifications/$id/read');
  Future<void> markAllNotificationsRead() => _c.post('/me/notifications/read-all');

  // Reminders
  Future<List<Reminder>> reminders() async =>
      ((await _c.get('/me/reminders', query: {'status': 'pending'}))['reminders'] as List)
          .cast<Json>()
          .map(Reminder.new)
          .toList();

  Future<void> addReminder(String courtId, String date, String slotStart) =>
      _c.post('/me/reminders', {'court_id': courtId, 'date': date, 'slot_start': slotStart});

  Future<void> cancelReminder(String id) => _c.delete('/me/reminders/$id');

  // Owner application
  Future<OwnerApplication?> myOwnerApplication() async {
    try {
      return OwnerApplication((await _c.get('/owner-applications/me'))['application']);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<OwnerApplication> applyAsOwner(String businessName, String businessPhone, String? gstin) async =>
      OwnerApplication((await _c.post('/owner-applications/me', {
        'business_name': businessName,
        'business_phone': businessPhone,
        if (gstin != null && gstin.isNotEmpty) 'gstin': gstin,
      }))['application']);

  // ---------------------------------------------------------------------------
  // Venue management

  Future<List<VenueSummary>> myVenues() async {
    final res = await _c.get('/venues/mine');
    return [
      for (final v in (res['owned'] as List? ?? const []).cast<Json>()) VenueSummary(v),
      for (final s in (res['staff'] as List? ?? const []).cast<Json>()) VenueSummary(s['venue'], role: s['role']),
    ];
  }

  Future<ManagedVenue> managedVenue(String venueId) async {
    final res = await _c.get('/venues/$venueId/manage');
    return ManagedVenue(res['venue'], res['access'] ?? 'staff');
  }

  Future<String> createVenue(Json body) async => ((await _c.post('/venues', body))['venue'] as Json)['id'];
  Future<void> updateVenue(String venueId, Json body) => _c.patch('/venues/$venueId', body);
  Future<void> deleteVenue(String venueId) => _c.delete('/venues/$venueId');
  Future<void> submitVenue(String venueId) => _c.post('/venues/$venueId/submit');
  Future<void> unpublishVenue(String venueId) => _c.post('/venues/$venueId/unpublish');

  // Courts
  Future<List<Court>> courts(String venueId) async =>
      ((await _c.get('/venues/$venueId/courts'))['courts'] as List).cast<Json>().map(Court.new).toList();
  Future<void> createCourt(String venueId, Json body) => _c.post('/venues/$venueId/courts', body);
  Future<void> updateCourt(String venueId, String courtId, Json body) =>
      _c.patch('/venues/$venueId/courts/$courtId', body);
  Future<void> deleteCourt(String venueId, String courtId) => _c.delete('/venues/$venueId/courts/$courtId');

  // Photos
  Future<List<Photo>> photos(String venueId) async =>
      ((await _c.get('/venues/$venueId/photos'))['photos'] as List).cast<Json>().map(Photo.new).toList();
  Future<void> uploadPhoto(String venueId, String filePath) => _c.upload('/venues/$venueId/photos', 'photo', filePath);
  Future<void> setCoverPhoto(String venueId, String photoId) => _c.put('/venues/$venueId/photos/$photoId/cover');
  Future<void> deletePhoto(String venueId, String photoId) => _c.delete('/venues/$venueId/photos/$photoId');

  // Hours & pricing
  Future<List<HoursRange>> venueHours(String venueId) async =>
      ((await _c.get('/venues/$venueId/hours'))['venue'] as List).cast<Json>().map(HoursRange.fromJson).toList();
  Future<void> saveVenueHours(String venueId, List<HoursRange> hours) =>
      _c.put('/venues/$venueId/hours', {'hours': hours.map((h) => h.toJson()).toList()});

  Future<List<PriceRule>> priceRules(String venueId, String courtId) async =>
      ((await _c.get('/venues/$venueId/courts/$courtId/pricing'))['rules'] as List)
          .cast<Json>()
          .map(PriceRule.fromJson)
          .toList();
  Future<void> savePriceRules(String venueId, String courtId, List<PriceRule> rules) =>
      _c.put('/venues/$venueId/courts/$courtId/pricing', {'rules': rules.map((r) => r.toJson()).toList()});

  // Blocks
  Future<List<Block>> blocks(String venueId) async =>
      ((await _c.get('/venues/$venueId/blocks'))['blocks'] as List).cast<Json>().map(Block.new).toList();
  Future<void> addBlock(String venueId, {String? courtId, required DateTime start, required DateTime end, String? reason}) =>
      _c.post('/venues/$venueId/blocks', {
        'court_id': ?courtId,
        'starts_at': start.toUtc().toIso8601String(),
        'ends_at': end.toUtc().toIso8601String(),
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });
  Future<void> deleteBlock(String venueId, String blockId) => _c.delete('/venues/$venueId/blocks/$blockId');

  // Front desk
  Future<Availability> manageAvailability(String venueId, String date) async =>
      Availability(await _c.get('/venues/$venueId/manage/availability', query: {'date': date}));

  Future<List<VenueBooking>> venueBookings(String venueId, String date) async =>
      ((await _c.get('/venues/$venueId/bookings', query: {'date': date}))['bookings'] as List)
          .cast<Json>()
          .map(VenueBooking.new)
          .toList();

  Future<VenueBooking> venueBooking(String venueId, String bookingId) async =>
      VenueBooking((await _c.get('/venues/$venueId/bookings/$bookingId'))['booking']);

  Future<VenueBooking> venueBookingByReference(String venueId, String reference) async =>
      VenueBooking((await _c.get('/venues/$venueId/bookings/by-reference/${Uri.encodeComponent(reference)}'))['booking']);

  Future<void> walkIn(String venueId, {
    required String courtId,
    required String date,
    required String start,
    required int minutes,
    required String name,
    required String phone,
  }) =>
      _c.post('/venues/$venueId/bookings', {
        'court_id': courtId,
        'date': date,
        'start': start,
        'duration_minutes': minutes,
        'customer_name': name,
        'customer_phone': phone,
      });

  Future<void> checkIn(String venueId, String bookingId, {int? collectedPaise}) =>
      _c.post('/venues/$venueId/bookings/$bookingId/check-in', {'collected_paise': ?collectedPaise});
  Future<void> collect(String venueId, String bookingId, int amountPaise) =>
      _c.post('/venues/$venueId/bookings/$bookingId/collect', {'amount_paise': amountPaise});
  Future<void> markNoShow(String venueId, String bookingId) => _c.post('/venues/$venueId/bookings/$bookingId/no-show');
  Future<void> undoNoShow(String venueId, String bookingId) =>
      _c.post('/venues/$venueId/bookings/$bookingId/undo-no-show');
  Future<void> venueCancelBooking(String venueId, String bookingId, String reason) =>
      _c.post('/venues/$venueId/bookings/$bookingId/cancel', {'reason': reason});

  // Dashboard
  Future<Json> venueDashboard(String venueId) async =>
      (await _c.get('/venues/$venueId/dashboard'))['dashboard'] as Json;

  // Staff
  Future<(List<StaffMember>, List<StaffInvite>)> staff(String venueId) async {
    final res = await _c.get('/venues/$venueId/staff');
    return (
      (res['members'] as List).cast<Json>().map(StaffMember.new).toList(),
      (res['pending_invites'] as List).cast<Json>().map(StaffInvite.new).toList(),
    );
  }

  Future<void> inviteStaff(String venueId, String email, String role) =>
      _c.post('/venues/$venueId/staff', {'email': email, 'role': role});
  Future<void> removeStaff(String venueId, String userId) => _c.delete('/venues/$venueId/staff/$userId');
  Future<void> cancelInvite(String venueId, String email) =>
      _c.delete('/venues/$venueId/staff/invites/${Uri.encodeComponent(email)}');

  // Review replies
  Future<ReviewPage> manageReviews(String venueId) async =>
      ReviewPage(await _c.get('/venues/$venueId/manage/reviews', query: {'limit': 50}));
  Future<void> replyToReview(String venueId, String reviewId, String reply) =>
      _c.put('/venues/$venueId/reviews/$reviewId/reply', {'reply': reply});

  // ---------------------------------------------------------------------------
  // Admin

  Future<List<OwnerApplication>> ownerApplications(String status) async =>
      ((await _c.get('/admin/owner-applications', query: {'status': status}))['applications'] as List)
          .cast<Json>()
          .map(OwnerApplication.new)
          .toList();
  Future<void> approveOwner(String userId) => _c.post('/admin/owner-applications/$userId/approve');
  Future<void> rejectOwner(String userId, String reason) =>
      _c.post('/admin/owner-applications/$userId/reject', {'reason': reason});

  Future<List<VenueSummary>> adminVenues(String status) async =>
      ((await _c.get('/admin/venues', query: {'status': status, 'limit': 50}))['venues'] as List)
          .cast<Json>()
          .map((v) => VenueSummary(v))
          .toList();
  Future<void> approveVenue(String venueId) => _c.post('/admin/venues/$venueId/approve');
  Future<void> rejectVenue(String venueId, String reason) => _c.post('/admin/venues/$venueId/reject', {'reason': reason});
  Future<void> suspendVenue(String venueId, String reason) =>
      _c.post('/admin/venues/$venueId/suspend', {'reason': reason});
  Future<void> reinstateVenue(String venueId) => _c.post('/admin/venues/$venueId/reinstate');
}
