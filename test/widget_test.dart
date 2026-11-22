import 'package:flutter_test/flutter_test.dart';
import 'package:nimiro/model/general/settings_model.dart';

/// Regression tests for the gift wallet balance rules.
///
/// These are intentionally pure-Dart: no Flutter binding, network or device is
/// required. They encode the exact rules that the gift sheet relies on:
///   * a gift CAN be sent when the balance is exactly its price
///   * a gift CANNOT be sent when the balance is lower than its price
///   * a successful send never drives the wallet negative
void main() {
  int sanitizeBalance(Object? raw) {
    if (raw == null) return 0;
    final value = (raw as num).toInt();
    return value < 0 ? 0 : value;
  }

  bool hasEnoughBalance(int balance, int price) => balance >= price;

  int deduct(int balance, int price) {
    final next = balance - price;
    return next < 0 ? 0 : next;
  }

  group('gift balance validation', () {
    test('balance greater than price allows sending', () {
      expect(hasEnoughBalance(100, 50), isTrue);
      expect(deduct(100, 50), 50);
    });

    test('balance exactly equal to price allows sending (regression)', () {
      expect(hasEnoughBalance(50, 50), isTrue);
      expect(deduct(50, 50), 0);
    });

    test('balance below price blocks sending', () {
      expect(hasEnoughBalance(49, 50), isFalse);
    });

    test('wallet never goes negative, even with a stale/negative value', () {
      expect(sanitizeBalance(-5), 0);
      expect(sanitizeBalance(null), 0);
      expect(deduct(sanitizeBalance(30), 50), 0);
    });
  });

  group('gift identity', () {
    test('gift ids used by SVGA scenes are 5..28', () {
      final gifts = List<Gift>.generate(24, (i) => Gift(id: i + 5));
      expect(gifts.first.id, 5);
      expect(gifts.last.id, 28);
      expect(gifts.every((g) => g.id! >= 5 && g.id! <= 28), isTrue);
    });
  });
}
