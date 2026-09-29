typedef Json = Map<String, dynamic>;

List<T> _list<T>(Object? raw, T Function(Json) f) =>
    (raw as List? ?? const []).cast<Json>().map(f).toList();

class Profile {
  Profile(this.json);
  final Json json;
  String get id => json['id'];
  String? get email => json['email'];
  String? get fullName => json['full_name'];
  String? get avatarUrl => json['avatar_url'];
  String? get phone => json['phone'];
  String? get city => json['city'];
  String get role => json['role'] ?? 'player';
  bool get isOnboarded => json['onboarded_at'] != null;
  bool get isAdmin => role == 'admin';
  bool get canOwnVenues => role == 'venue_owner' || role == 'admin';
  List<String> get preferredSports => (json['preferred_sports'] as List? ?? const []).cast<String>();
}

class CatalogItem {
  CatalogItem(Json j) : id = j['id'], name = j['name'];
  final String id;
  final String name;
}

class VenueSearchResult {
  VenueSearchResult(Json j)
      : id = j['id'],
        slug = j['slug'],
        name = j['name'],
        locality = j['locality'],
        city = j['city'] ?? '',
        sports = (j['sports'] as List? ?? const []).cast<String>(),
        coverUrl = j['cover_url'],
        distanceKm = (j['distance_km'] as num?)?.toDouble(),
        ratingAvg = (j['rating_avg'] as num?)?.toDouble(),
        ratingCount = j['rating_count'] ?? 0;
  final String id, slug, name, city;
  final String? locality, coverUrl;
  final List<String> sports;
  final double? distanceKm, ratingAvg;
  final int ratingCount;
}

class Court {
  Court(Json j)
      : id = j['id'],
        name = j['name'],
        sportId = j['sport_id'],
        isIndoor = j['is_indoor'] ?? false,
        surface = j['surface'],
        capacity = j['capacity'],
        baseSlotMinutes = j['base_slot_minutes'] ?? 60,
        minDurationMinutes = j['min_duration_minutes'] ?? 60,
        maxDurationMinutes = j['max_duration_minutes'] ?? 120,
        isActive = j['is_active'] ?? true,
        pricePerHourPaise = j['price_per_hour_paise'];
  final String id, name, sportId;
  final bool isIndoor, isActive;
  final String? surface;
  final int? capacity, pricePerHourPaise;
  final int baseSlotMinutes, minDurationMinutes, maxDurationMinutes;
}

class Photo {
  Photo(Json j) : id = j['id'], url = j['url'], thumbUrl = j['thumb_url'] ?? j['url'], isCover = j['is_cover'] ?? false;
  final String id, url, thumbUrl;
  final bool isCover;
}

class PublicVenue {
  PublicVenue(Json j)
      : id = j['id'],
        slug = j['slug'],
        name = j['name'],
        description = j['description'],
        phone = j['phone'],
        address = [j['address_line'], j['locality'], j['city']].whereType<String>().where((s) => s.isNotEmpty).join(', '),
        amenities = (j['amenities'] as List? ?? const []).cast<String>(),
        sports = (j['sports'] as List? ?? const []).cast<String>(),
        rules = j['rules'],
        courts = _list(j['courts'], Court.new),
        photos = _list(j['photos'], Photo.new),
        ratingAvg = (j['rating_avg'] as num?)?.toDouble(),
        ratingCount = j['rating_count'] ?? 0;
  final String id, slug, name, address;
  final String? description, phone, rules;
  final List<String> amenities, sports;
  final List<Court> courts;
  final List<Photo> photos;
  final double? ratingAvg;
  final int ratingCount;
}

class Slot {
  Slot(Json j)
      : start = j['start'],
        end = j['end'],
        pricePaise = j['price_paise'] ?? 0,
        onlinePricePaise = j['online_price_paise'] ?? 0,
        payAtVenue = j['pay_at_venue'] ?? false,
        status = j['status'] ?? 'closed';
  final String start, end, status;
  final int pricePaise, onlinePricePaise;
  final bool payAtVenue;
  bool get isAvailable => status == 'available';
}

class CourtAvailability {
  CourtAvailability(Json j)
      : id = j['id'],
        name = j['name'],
        sportId = j['sport_id'],
        baseSlotMinutes = j['base_slot_minutes'] ?? 60,
        minDurationMinutes = j['min_duration_minutes'] ?? 60,
        maxDurationMinutes = j['max_duration_minutes'] ?? 60,
        slots = _list(j['slots'], Slot.new);
  final String id, name, sportId;
  final int baseSlotMinutes, minDurationMinutes, maxDurationMinutes;
  final List<Slot> slots;
}

class Availability {
  Availability(Json j)
      : date = j['date'],
        onlineDiscountPercent = j['online_discount_percent'] ?? 0,
        courts = _list(j['courts'], CourtAvailability.new);
  final String date;
  final int onlineDiscountPercent;
  final List<CourtAvailability> courts;
}

class Quote {
  Quote(Json j)
      : subtotalPaise = j['subtotal_paise'] ?? 0,
        discountPaise = j['discount_paise'] ?? 0,
        discountPercent = j['discount_percent'] ?? 0,
        totalPaise = j['total_paise'] ?? 0,
        durationMinutes = j['duration_minutes'] ?? 0;
  final int subtotalPaise, discountPaise, discountPercent, totalPaise, durationMinutes;
}

class Booking {
  Booking(Json j)
      : id = j['id'],
        reference = j['reference'] ?? '',
        venueId = j['venue_id'] ?? (j['venue'] as Json?)?['id'] ?? '',
        startsAt = j['starts_at'],
        endsAt = j['ends_at'],
        durationMinutes = j['duration_minutes'] ?? 0,
        status = j['status'] ?? '',
        paymentMethod = j['payment_method'] ?? '',
        paymentStatus = j['payment_status'] ?? '',
        totalPaise = j['total_paise'] ?? 0,
        courtName = (j['court'] as Json?)?['name'],
        sportId = (j['court'] as Json?)?['sport_id'],
        venueName = (j['venue'] as Json?)?['name'],
        venueCity = (j['venue'] as Json?)?['city'],
        venuePhone = (j['venue'] as Json?)?['phone'],
        cancellation = j['cancellation'] as Json?;
  final String id, reference, venueId, startsAt, endsAt, status, paymentMethod, paymentStatus;
  final int durationMinutes, totalPaise;
  final String? courtName, sportId, venueName, venueCity, venuePhone;
  final Json? cancellation;

  bool get isCancellable => status == 'confirmed' || status == 'pending_payment';
}

// ---------------------------------------------------------------------------
// Engagement

class Review {
  Review(Json j)
      : id = j['id'],
        venueId = j['venue_id'],
        rating = j['rating'] ?? 0,
        comment = j['comment'],
        ownerReply = j['owner_reply'],
        authorName = (j['author'] as Json?)?['name'] ?? 'Player',
        authorAvatar = (j['author'] as Json?)?['avatar_url'],
        isHidden = j['status'] == 'hidden',
        createdAt = j['created_at'];
  final String id, venueId, authorName, createdAt;
  final int rating;
  final String? comment, ownerReply, authorAvatar;
  final bool isHidden;
}

class ReviewPage {
  ReviewPage(Json j)
      : reviews = _list(j['reviews'], Review.new),
        total = j['total'] ?? 0,
        breakdown = {for (final e in ((j['breakdown'] as Json?) ?? const {}).entries) int.parse(e.key): (e.value as num).toInt()};
  final List<Review> reviews;
  final int total;
  final Map<int, int> breakdown;
}

class Favourite {
  Favourite(Json j)
      : id = j['id'],
        slug = j['slug'],
        name = j['name'],
        place = [j['locality'], j['city']].whereType<String>().where((s) => s.isNotEmpty).join(', '),
        coverUrl = j['cover_url'],
        ratingAvg = (j['rating_avg'] as num?)?.toDouble(),
        ratingCount = j['rating_count'] ?? 0,
        available = j['available'] ?? true;
  final String id, slug, name, place;
  final String? coverUrl;
  final double? ratingAvg;
  final int ratingCount;
  final bool available;
}

class AppNotification {
  AppNotification(Json j)
      : id = j['id'],
        type = j['type'] ?? '',
        title = j['title'] ?? '',
        body = j['body'] ?? '',
        data = (j['data'] as Json?) ?? const {},
        readAt = j['read_at'],
        createdAt = j['created_at'];
  final String id, type, title, body, createdAt;
  final Json data;
  final String? readAt;
  bool get isRead => readAt != null;
}

class Reminder {
  Reminder(Json j)
      : id = j['id'],
        slotStart = j['slot_start'],
        slotDate = j['slot_date'],
        notifyAt = j['notify_at'],
        status = j['status'] ?? 'pending',
        courtName = (j['court'] as Json?)?['name'],
        venueName = (j['venue'] as Json?)?['name'];
  final String id, slotStart, slotDate, notifyAt, status;
  final String? courtName, venueName;
}

// ---------------------------------------------------------------------------
// Venue management

class VenueSummary {
  VenueSummary(Json j, {this.role})
      : id = j['id'],
        name = j['name'],
        slug = j['slug'],
        place = [j['locality'], j['city']].whereType<String>().where((s) => s.isNotEmpty).join(', '),
        status = j['status'] ?? 'draft',
        statusReason = j['status_reason'],
        coverUrl = j['cover_url'];
  final String id, name, slug, place, status;
  final String? statusReason, coverUrl;

  /// null = owner; otherwise the staff role (manager | staff).
  final String? role;
}

class ManagedVenue {
  ManagedVenue(this.json, this.access);
  final Json json;

  /// admin | owner | manager | staff
  final String access;

  String get id => json['id'];
  String get name => json['name'];
  String get slug => json['slug'];
  String get status => json['status'] ?? 'draft';
  String? get statusReason => json['status_reason'];

  bool get isOwner => access == 'owner' || access == 'admin';
  bool get canEdit => isOwner || access == 'manager';
  bool get isListed => status == 'live' || status == 'pending_review';
}

class HoursRange {
  HoursRange(this.day, this.open, this.close);
  HoursRange.fromJson(Json j) : day = j['day'], open = j['open'], close = j['close'];
  final int day;
  final String open, close;
  Json toJson() => {'day': day, 'open': open, 'close': close};
}

class PriceRule {
  PriceRule({this.days, this.date, required this.start, required this.end, required this.pricePerHourPaise});
  PriceRule.fromJson(Json j)
      : days = (j['days'] as List?)?.cast<int>(),
        date = j['date'],
        start = j['start'],
        end = j['end'],
        pricePerHourPaise = j['price_per_hour_paise'];
  final List<int>? days;
  final String? date;
  final String start, end;
  final int pricePerHourPaise;
  Json toJson() => {
        if (days != null) 'days': days,
        if (date != null) 'date': date,
        'start': start,
        'end': end,
        'price_per_hour_paise': pricePerHourPaise,
      };
}

class Block {
  Block(Json j)
      : id = j['id'],
        courtId = j['court_id'],
        startsAt = j['starts_at'],
        endsAt = j['ends_at'],
        reason = j['reason'];
  final String id, startsAt, endsAt;
  final String? courtId, reason;
}

class VenueBooking {
  VenueBooking(Json j)
      : booking = Booking(j),
        customerName = (j['customer'] as Json?)?['full_name'] ?? j['customer_name'],
        customerPhone = (j['customer'] as Json?)?['phone'] ?? j['customer_phone'],
        collectedPaise = j['collected_paise'],
        notes = j['notes'],
        events = (j['events'] as List? ?? const []).cast<Json>();
  final Booking booking;
  final String? customerName, customerPhone, notes;
  final int? collectedPaise;
  final List<Json> events;
}

class StaffMember {
  StaffMember(Json j)
      : userId = (j['user'] as Json)['id'],
        name = (j['user'] as Json)['full_name'] ?? (j['user'] as Json)['email'] ?? 'Staff',
        email = (j['user'] as Json)['email'],
        role = j['role'];
  final String userId, name, role;
  final String? email;
}

class StaffInvite {
  StaffInvite(Json j) : email = j['email'], role = j['role'];
  final String email, role;
}

class OwnerApplication {
  OwnerApplication(Json j)
      : userId = j['user_id'],
        businessName = j['business_name'] ?? '',
        businessPhone = j['business_phone'] ?? '',
        gstin = j['gstin'],
        status = j['verification_status'] ?? 'pending',
        rejectionReason = j['rejection_reason'],
        applicantName = (j['user'] as Json?)?['full_name'],
        applicantEmail = (j['user'] as Json?)?['email'],
        createdAt = j['created_at'];
  final String userId, businessName, businessPhone, status, createdAt;
  final String? gstin, rejectionReason, applicantName, applicantEmail;
}
