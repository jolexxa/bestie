import 'dart:async';

import 'package:bestie_ui/src/banner/banner_notifier.dart';
import 'package:bestie_ui/src/banner/banner_style.dart';
import 'package:bestie_ui/src/banner/state/banner_cubit.dart';
import 'package:bestie_ui/src/banner/state/banner_logic.dart';
import 'package:bestie_ui/src/theme/app_theme.dart';
import 'package:blocterm/blocterm.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Displays auto-dismissing banner notifications.
///
/// Listens to [BannerNotifier] and renders up to three banners,
/// each driven by its own [BannerCubit] state machine that handles
/// the reveal, hold, and slide-out lifecycle.
@view
class BannerOverlay extends StatefulComponent {
  /// Creates a [BannerOverlay].
  const BannerOverlay({super.key});

  @override
  State<BannerOverlay> createState() => _BannerOverlayState();
}

class _BannerOverlayState extends State<BannerOverlay> {
  static const _maxBanners = 3;

  final _cubits = <BannerCubit>[];
  StreamSubscription<BannerNotification>? _sub;

  @override
  void initState() {
    super.initState();
    final service = BannerNotifier.of(context);
    _sub = service.notifications.listen(_onNotification);
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    for (final cubit in _cubits) {
      unawaited(cubit.close());
    }
    _cubits.clear();
    super.dispose();
  }

  void _onNotification(BannerNotification notification) {
    if (_cubits.length >= _maxBanners) {
      final removed = _cubits.removeAt(0);
      unawaited(removed.close());
    }

    final cubit = BannerCubit(notification: notification);
    cubit.onCompleted = () => _completeBanner(cubit);

    setState(() => _cubits.add(cubit));
  }

  void _completeBanner(BannerCubit cubit) {
    if (!mounted) return;
    setState(() => _cubits.remove(cubit));
    // Defer disposal so we don't close the cubit while still inside one
    // of its own output callbacks.
    unawaited(Future<void>.microtask(() => cubit.close()));
  }

  @override
  Component build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final cubit in _cubits)
          BlocProvider<BannerCubit>.value(
            key: ValueKey<BannerCubit>(cubit),
            value: cubit,
            child: const _BannerItem(),
          ),
      ],
    );
  }
}

class _BannerItem extends StatelessComponent {
  const _BannerItem();

  @override
  Component build(BuildContext context) {
    return BlocBuilder<BannerCubit, BannerState>(
      builder: (context, state) {
        if (state.revealHeight == 0) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 1),
          child: SizedBox(
            width: bannerWidth.toDouble(),
            height: state.revealHeight.toDouble(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: state.slideOffset.toDouble(),
                  top: 0,
                  width: bannerWidth.toDouble(),
                  height: bannerHeight.toDouble(),
                  child: _BannerBody(notification: state.notification),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BannerBody extends StatelessComponent {
  const _BannerBody({required this.notification});

  final BannerNotification notification;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    final palette = _palette(theme, notification.style);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: bannerGutterWidth.toDouble(),
          color: palette.gutter,
          alignment: Alignment.center,
          child: Text(
            notification.icon,
            style: TextStyle(color: palette.onBody),
          ),
        ),
        Expanded(
          child: Container(
            color: palette.body,
            padding: const EdgeInsets.symmetric(horizontal: 1),
            alignment: Alignment.centerLeft,
            child: Text(
              notification.message,
              style: TextStyle(color: palette.onBody),
              softWrap: false,
            ),
          ),
        ),
      ],
    );
  }
}

BannerPalette _palette(AppThemeData theme, BannerStyle style) {
  switch (style) {
    case BannerStyle.normal:
      return BannerPalette(
        body: theme.primary,
        gutter: theme.accent,
        onBody: theme.onPrimary,
      );
    case BannerStyle.info:
      return BannerPalette(
        body: theme.info,
        gutter: theme.infoAccent,
        onBody: theme.onInfo,
      );
    case BannerStyle.success:
      return BannerPalette(
        body: theme.success,
        gutter: theme.successAccent,
        onBody: theme.onSuccess,
      );
    case BannerStyle.error:
      return BannerPalette(
        body: theme.error,
        gutter: theme.errorAccent,
        onBody: theme.onError,
      );
    case BannerStyle.muted:
      return BannerPalette(
        body: theme.muted,
        gutter: theme.mutedAccent,
        onBody: theme.onMuted,
      );
  }
}
