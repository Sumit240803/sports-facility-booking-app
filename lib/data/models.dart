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
        pricePerHourPaise = j['price_per_hour_paise'];
  final String id, name, sportId;
  final bool isIndoor;
  final String? surface;
  final int? pricePerHourPaise;
}

class Photo {
  Photo(Json j) : url = j['url'], thumbUrl = j['thumb_url'] ?? j['url'];
  final String url, thumbUrl;
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
  final String id, reference, startsAt, endsAt, status, paymentMethod, paymentStatus;
  final int durationMinutes, totalPaise;
  final String? courtName, sportId, venueName, venueCity, venuePhone;
  final Json? cancellation;

  bool get isCancellable => status == 'confirmed' || status == 'pending_payment';
}
