import 'dart:async';

import 'package:bestie_ui/src/banner/banner_style.dart';
import 'package:blocterm/blocterm.dart';
import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';
import 'package:nocterm/nocterm.dart';

/// A banner notification to display briefly in the UI.
@model
class BannerNotification {
  /// Creates a [BannerNotification].
  const BannerNotification({
    required this.message,
    required this.icon,
    this.style = BannerStyle.normal,
    this.duration = const Duration(milliseconds: 1500),
  });

  /// The message text.
  final String message;

  /// Icon character (e.g. '↓', '✓', '!').
  final String icon;

  /// Visual style — picks the semantic palette to render with.
  final BannerStyle style;

  /// How long the banner stays visible.
  final Duration duration;
}

/// Broadcasts banner notifications to the UI.
@dataSource
class BannerNotifier {
  /// Returns the [BannerNotifier] from the nearest ancestor.
  static BannerNotifier of(BuildContext context) =>
      Provider.of<BannerNotifier>(context);

  final _controller = StreamController<BannerNotification>.broadcast();

  /// Stream of banner notifications.
  Stream<BannerNotification> get notifications => _controller.stream;

  /// Shows a banner notification.
  void show(BannerNotification notification) {
    _controller.add(notification);
  }

  /// Cleans up resources.
  @mustCallSuper
  Future<void> dispose() async {
    await _controller.close();
  }
}
