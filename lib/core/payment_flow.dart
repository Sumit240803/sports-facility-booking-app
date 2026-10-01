import 'dart:async';

import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../app_scope.dart';

/// Opens Razorpay Checkout for a pending online booking and confirms it with the backend.
/// Returns true when the booking ended up confirmed.
Future<bool> payForBooking(BuildContext context, String bookingId) async {
  final api = context.api;
  final messenger = ScaffoldMessenger.of(context);
  void say(String m) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  final order = await (() async {
    try {
      return await api.startPayment(bookingId);
    } catch (e) {
      say('$e');
      return null;
    }
  })();
  if (order == null) return false;

  final razorpay = Razorpay();
  final result = Completer<PaymentSuccessResponse?>();
  razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) => result.complete(r));
  razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
    if (r.code != Razorpay.PAYMENT_CANCELLED) say(r.message ?? 'Payment failed');
    result.complete(null);
  });
  razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
    say('Complete the payment in ${r.walletName ?? 'the wallet app'}; the booking confirms automatically.');
    result.complete(null);
  });

  try {
    razorpay.open({
      'key': order.keyId,
      'order_id': order.orderId,
      'amount': order.amountPaise,
      'currency': order.currency,
      'name': 'ZocoPlay',
      'description': order.description,
      'timeout': order.timeoutSeconds,
      'prefill': {
        if (order.prefill['name'] != null) 'name': order.prefill['name'],
        if (order.prefill['email'] != null) 'email': order.prefill['email'],
        if (order.prefill['contact'] != null) 'contact': order.prefill['contact'],
      },
      'theme': {'color': '#0B8A5B'},
    });

    final success = await result.future;
    if (success == null) return false;

    final (outcome, refundReason) = await api.verifyPayment(
      bookingId,
      success.orderId ?? order.orderId,
      success.paymentId ?? '',
      success.signature ?? '',
    );
    switch (outcome) {
      case 'confirmed' || 'already_processed':
        say('Payment successful, booking confirmed!');
        return true;
      case 'refund_queued':
        say(
          'We couldn\'t confirm this slot${refundReason != null ? ' ($refundReason)' : ''}. '
          'Your payment will be refunded automatically.',
        );
        return false;
      default:
        say('Payment could not be verified. If money was debited it will be refunded.');
        return false;
    }
  } catch (e) {
    say('$e');
    return false;
  } finally {
    razorpay.clear();
  }
}

/// Live "pay within mm:ss" countdown for a payment hold.
class HoldCountdown extends StatefulWidget {
  const HoldCountdown({super.key, required this.expiresAt, this.onExpired});
  final String expiresAt;
  final VoidCallback? onExpired;

  @override
  State<HoldCountdown> createState() => _HoldCountdownState();
}

class _HoldCountdownState extends State<HoldCountdown> {
  late final DateTime _end = DateTime.parse(widget.expiresAt).toLocal();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (!DateTime.now().isBefore(_end)) {
        _timer?.cancel();
        widget.onExpired?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = _end.difference(DateTime.now());
    if (left.isNegative) return const Text('Payment window ended');
    final mm = left.inMinutes.toString().padLeft(2, '0');
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');
    return Text('Pay within $mm:$ss to keep this slot', style: TextStyle(color: Theme.of(context).colorScheme.error));
  }
}
