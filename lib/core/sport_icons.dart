import '../widgets/app_icons.dart';

/// Icon for a sport id from the catalog; falls back to a generic one for new sports.
AppIconData sportIcon(String? sportId) => switch (sportId) {
  'football' => AppIcons.football,
  'cricket' => AppIcons.cricket,
  'badminton' || 'squash' => AppIcons.racket,
  'tennis' || 'pickleball' => AppIcons.racket,
  'table-tennis' => AppIcons.tableTennis,
  'basketball' => AppIcons.basketball,
  'volleyball' => AppIcons.volleyball,
  'swimming' => AppIcons.swimming,
  _ => AppIcons.venue,
};

/// Icon for an amenity id from the catalog.
AppIconData amenityIcon(String id) => switch (id) {
  'parking' => AppIcons.parking,
  'washroom' || 'shower' => AppIcons.shower,
  'changing-room' || 'locker' => AppIcons.locker,
  'drinking-water' => AppIcons.water,
  'floodlights' => AppIcons.floodlight,
  'equipment-rental' => AppIcons.racket,
  'first-aid' => AppIcons.firstAid,
  'seating' => AppIcons.seat,
  'cafeteria' => AppIcons.cafe,
  'wifi' => AppIcons.wifi,
  _ => AppIcons.check,
};
