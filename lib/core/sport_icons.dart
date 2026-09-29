import 'package:flutter/material.dart';

/// Icon for a sport id from the catalog; falls back to a generic one for new sports.
IconData sportIcon(String? sportId) => switch (sportId) {
  'football' => Icons.sports_soccer,
  'cricket' => Icons.sports_cricket,
  'badminton' || 'squash' => Icons.sports_tennis,
  'tennis' || 'pickleball' => Icons.sports_tennis,
  'table-tennis' => Icons.sports_handball,
  'basketball' => Icons.sports_basketball,
  'volleyball' => Icons.sports_volleyball,
  'swimming' => Icons.pool,
  _ => Icons.sports,
};
