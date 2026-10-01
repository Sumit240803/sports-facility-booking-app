import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

/// Hugeicons glyph data (stroke-rounded set).
typedef AppIconData = List<List<dynamic>>;

/// Renders an [AppIcons] glyph. Size and colour default to the surrounding [IconTheme],
/// so it drops in wherever a Material `Icon` would (buttons, list tiles, chips, nav bars).
class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size, this.color, this.strokeWidth});

  final AppIconData icon;
  final double? size;
  final Color? color;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    return HugeIcon(
      icon: icon,
      size: size ?? theme.size ?? 24,
      color: color ?? theme.color,
      strokeWidth: strokeWidth ?? 1.7,
    );
  }
}

/// Every icon the app uses, by meaning. Change the look of the whole app here.
abstract final class AppIcons {
  // Navigation
  static const explore = HugeIcons.strokeRoundedCompass01;
  static const bookings = HugeIcons.strokeRoundedTicket01;
  static const manage = HugeIcons.strokeRoundedStore01;
  static const admin = HugeIcons.strokeRoundedUserShield01;
  static const profile = HugeIcons.strokeRoundedUserCircle;
  static const chevronRight = HugeIcons.strokeRoundedArrowRight01;
  static const chevronLeft = HugeIcons.strokeRoundedArrowLeft01;
  static const expand = HugeIcons.strokeRoundedArrowDown01;
  static const outbound = HugeIcons.strokeRoundedArrowUpRight01;

  // Actions
  static const add = HugeIcons.strokeRoundedAdd01;
  static const addCircle = HugeIcons.strokeRoundedAddCircle;
  static const remove = HugeIcons.strokeRoundedMinusSign;
  static const removeCircle = HugeIcons.strokeRoundedMinusSignCircle;
  static const edit = HugeIcons.strokeRoundedPencilEdit02;
  static const delete = HugeIcons.strokeRoundedDelete02;
  static const close = HugeIcons.strokeRoundedCancel01;
  static const cancel = HugeIcons.strokeRoundedCancelCircle;
  static const check = HugeIcons.strokeRoundedCheckmarkCircle02;
  static const verified = HugeIcons.strokeRoundedCheckmarkBadge01;
  static const search = HugeIcons.strokeRoundedSearch01;
  static const searchOff = HugeIcons.strokeRoundedSearchRemove;
  static const filter = HugeIcons.strokeRoundedFilterHorizontal;
  static const sort = HugeIcons.strokeRoundedSorting05;
  static const refresh = HugeIcons.strokeRoundedRefresh;
  static const undo = HugeIcons.strokeRoundedUndo02;
  static const reply = HugeIcons.strokeRoundedReply;
  static const reorder = HugeIcons.strokeRoundedArrowUpDown;
  static const drag = HugeIcons.strokeRoundedDragDropVertical;
  static const link = HugeIcons.strokeRoundedLink01;
  static const keyboard = HugeIcons.strokeRoundedKeyboard;
  static const play = HugeIcons.strokeRoundedPlay;
  static const stop = HugeIcons.strokeRoundedCancelCircle;
  static const repeat = HugeIcons.strokeRoundedRepeat;
  static const login = HugeIcons.strokeRoundedLogin03;
  static const google = HugeIcons.strokeRoundedGoogle;
  static const logout = HugeIcons.strokeRoundedLogout03;
  static const lock = HugeIcons.strokeRoundedLock;
  static const unlock = HugeIcons.strokeRoundedLockKeyholeOpen;
  static const hide = HugeIcons.strokeRoundedViewOff;
  static const flashlight = HugeIcons.strokeRoundedFlashlight;
  static const dot = HugeIcons.strokeRoundedCircle;

  // People
  static const user = HugeIcons.strokeRoundedUser;
  static const users = HugeIcons.strokeRoundedUserGroup;
  static const userAdd = HugeIcons.strokeRoundedUserAdd01;
  static const userRemove = HugeIcons.strokeRoundedUserRemove01;
  static const userBlock = HugeIcons.strokeRoundedUserBlock01;
  static const userSearch = HugeIcons.strokeRoundedUserSearch01;
  static const idCard = HugeIcons.strokeRoundedIdentityCard;
  static const business = HugeIcons.strokeRoundedBuilding03;
  static const handshake = HugeIcons.strokeRoundedAgreement01;

  // Places & time
  static const location = HugeIcons.strokeRoundedLocation01;
  static const nearMe = HugeIcons.strokeRoundedNavigation03;
  static const city = HugeIcons.strokeRoundedCity01;
  static const globe = HugeIcons.strokeRoundedGlobe02;
  static const venue = HugeIcons.strokeRoundedFootballPitch;
  static const storefront = HugeIcons.strokeRoundedStore02;
  static const addVenue = HugeIcons.strokeRoundedStoreAdd01;
  static const calendar = HugeIcons.strokeRoundedCalendar03;
  static const calendarRange = HugeIcons.strokeRoundedCalendar04;
  static const today = HugeIcons.strokeRoundedCalendar02;
  static const calendarCheck = HugeIcons.strokeRoundedCalendarCheckIn01;
  static const calendarOff = HugeIcons.strokeRoundedCalendarRemove01;
  static const clock = HugeIcons.strokeRoundedClock01;
  static const history = HugeIcons.strokeRoundedClock04;
  static const hourglass = HugeIcons.strokeRoundedHourglass;
  static const alarm = HugeIcons.strokeRoundedAlarmClock;
  static const alarmOff = HugeIcons.strokeRoundedAlarmClockOff;
  static const block = HugeIcons.strokeRoundedUnavailable;

  // Money
  static const wallet = HugeIcons.strokeRoundedWallet02;
  static const rupee = HugeIcons.strokeRoundedRupee;
  static const card = HugeIcons.strokeRoundedCreditCard;
  static const cash = HugeIcons.strokeRoundedMoney03;
  static const bank = HugeIcons.strokeRoundedBank;
  static const receipt = HugeIcons.strokeRoundedInvoice01;
  static const savings = HugeIcons.strokeRoundedPiggyBank;
  static const refund = HugeIcons.strokeRoundedMoneyReceive01;
  static const refundOff = HugeIcons.strokeRoundedMoneyRemove01;
  static const counter = HugeIcons.strokeRoundedCashier02;
  static const priceTag = HugeIcons.strokeRoundedTag01;
  static const payout = HugeIcons.strokeRoundedArrowUpRight01;

  // Content
  static const notification = HugeIcons.strokeRoundedNotification03;
  static const notificationOff = HugeIcons.strokeRoundedNotificationOff01;
  static const favourite = HugeIcons.strokeRoundedFavourite;
  static const star = HugeIcons.strokeRoundedStar;
  static const review = HugeIcons.strokeRoundedComment01;
  static const writeReview = HugeIcons.strokeRoundedStarSquare;
  static const phone = HugeIcons.strokeRoundedCall;
  static const mail = HugeIcons.strokeRoundedMail01;
  static const note = HugeIcons.strokeRoundedNote;
  static const photos = HugeIcons.strokeRoundedImage02;
  static const addPhoto = HugeIcons.strokeRoundedImageAdd01;
  static const qr = HugeIcons.strokeRoundedQrCode;
  static const scan = HugeIcons.strokeRoundedQrCodeScan;
  static const inbox = HugeIcons.strokeRoundedInbox;
  static const offline = HugeIcons.strokeRoundedWifiDisconnected01;
  static const error = HugeIcons.strokeRoundedAlertCircle;
  static const insights = HugeIcons.strokeRoundedAnalytics01;
  static const checklist = HugeIcons.strokeRoundedTaskDone01;
  static const category = HugeIcons.strokeRoundedDashboardSquare02;
  static const settings = HugeIcons.strokeRoundedSettings02;

  // Appearance
  static const sun = HugeIcons.strokeRoundedSun03;
  static const moon = HugeIcons.strokeRoundedMoon02;
  static const phoneTheme = HugeIcons.strokeRoundedSmartPhone01;

  // Amenities
  static const parking = HugeIcons.strokeRoundedParkingAreaSquare;
  static const shower = HugeIcons.strokeRoundedShowerHead;
  static const locker = HugeIcons.strokeRoundedLocker;
  static const water = HugeIcons.strokeRoundedDroplet;
  static const floodlight = HugeIcons.strokeRoundedBulb;
  static const firstAid = HugeIcons.strokeRoundedFirstAidKit;
  static const seat = HugeIcons.strokeRoundedSofa01;
  static const cafe = HugeIcons.strokeRoundedCoffee02;
  static const wifi = HugeIcons.strokeRoundedWifi01;

  // Sports
  static const football = HugeIcons.strokeRoundedFootball;
  static const cricket = HugeIcons.strokeRoundedCricketBat;
  static const badminton = HugeIcons.strokeRoundedBadminton;
  static const tennis = HugeIcons.strokeRoundedTennisBall;
  static const racket = HugeIcons.strokeRoundedTennisRacket;
  static const tableTennis = HugeIcons.strokeRoundedTableTennisBat;
  static const basketball = HugeIcons.strokeRoundedBasketball01;
  static const volleyball = HugeIcons.strokeRoundedVolleyball;
  static const swimming = HugeIcons.strokeRoundedSwimming;
}
