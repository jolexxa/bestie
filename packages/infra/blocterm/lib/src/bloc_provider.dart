import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:blocterm/src/errors.dart';
import 'package:blocterm/src/single_child_component.dart';
import 'package:nocterm/nocterm.dart';

/// Provides a bloc to descendant components.
class BlocProvider<B extends BlocBase<Object?>> extends StatefulComponent
    implements SingleChildComponent {
  /// Creates a [BlocProvider] that owns and disposes the bloc.
  ///
  /// [child] is optional so this provider can sit inside a
  /// `MultiRepositoryProvider`'s `providers` list — `Nested` substitutes a
  /// real child via [buildWithChild] before the provider is rendered.
  const BlocProvider.create({
    required this.create,
    this.child,
    super.key,
  }) : value = null;

  /// Creates a [BlocProvider] that exposes [value] to its descendants.
  const BlocProvider.value({
    required this.value,
    this.child,
    super.key,
  }) : create = null;

  /// The bloc instance exposed to descendants.
  final B? value;

  /// Builder used to create a bloc owned by the provider.
  final B Function(BuildContext context)? create;

  /// The child component. May be `null` when this provider is hosted inside a
  /// `MultiRepositoryProvider` — `Nested` substitutes a real child via
  /// [buildWithChild] before the provider is rendered.
  final Component? child;

  /// Retrieves a bloc of type [B] from the nearest [BlocProvider].
  static B of<B extends BlocBase<Object?>>(
    BuildContext context, {
    bool listen = true,
  }) {
    _BlocProviderInherited<B>? provider;
    if (listen) {
      provider = context
          .dependOnInheritedComponentOfExactType<_BlocProviderInherited<B>>();
    } else {
      final element = context
          .getElementForInheritedComponentOfExactType<
            _BlocProviderInherited<B>
          >();
      provider = element?.component as _BlocProviderInherited<B>?;
    }

    if (provider == null) {
      throw BlocProviderNotFoundException(B);
    }
    return provider.bloc;
  }

  @override
  State<BlocProvider<B>> createState() => _BlocProviderState<B>();

  @override
  Component buildWithChild(BuildContext context, Component child) {
    final create = this.create;
    if (create != null) {
      return BlocProvider<B>.create(
        create: create,
        key: key,
        child: child,
      );
    }
    return BlocProvider<B>.value(
      value: value,
      key: key,
      child: child,
    );
  }
}

final class _BlocProviderState<B extends BlocBase<Object?>>
    extends State<BlocProvider<B>> {
  B? _bloc;
  var _ownsBloc = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureBloc();
  }

  @override
  void didUpdateComponent(covariant BlocProvider<B> oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (component.create != null) {
      // `create` runs at most once per element lifetime.
      if (_ownsBloc) return;

      // Switching from .value to .create: create and take ownership.
      _bloc = component.create!(context);
      _ownsBloc = true;
      return;
    }

    if (_ownsBloc) {
      // Switching from .create to .value: release the owned bloc.
      final oldBloc = _bloc;
      _bloc = component.value;
      _ownsBloc = false;
      if (oldBloc != null) {
        unawaited(oldBloc.close());
      }
      return;
    }

    if (oldComponent.value != component.value) {
      _bloc = component.value;
    }
  }

  @override
  void dispose() {
    if (_ownsBloc) {
      final bloc = _bloc;
      if (bloc != null) {
        unawaited(bloc.close());
      }
    }
    super.dispose();
  }

  void _ensureBloc() {
    if (component.create != null) {
      _bloc ??= component.create!(context);
      _ownsBloc = true;
      return;
    }
    _bloc = component.value;
    _ownsBloc = false;
  }

  @override
  Component build(BuildContext context) {
    _ensureBloc();
    final bloc = _bloc;
    final child = component.child ?? const SizedBox.shrink();
    if (bloc == null) {
      return child;
    }
    return _BlocProviderInherited<B>(
      bloc: bloc,
      child: child,
    );
  }
}

final class _BlocProviderInherited<B extends BlocBase<Object?>>
    extends InheritedComponent {
  const _BlocProviderInherited({
    required this.bloc,
    required super.child,
    super.key,
  });

  final B bloc;

  @override
  bool updateShouldNotify(covariant _BlocProviderInherited<B> oldComponent) {
    return bloc != oldComponent.bloc;
  }
}
