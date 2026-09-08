import 'package:sandbox/src/lowering/resolve.dart';
import 'package:sandbox/src/sandbox_spec.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('SpecResolver', () {
    test('folds workspaceRoot into writable and dedupes', () {
      final spec = SpecResolver(memFs()).resolve(
        const SandboxSpec(workspaceRoot: '/w', writableRoots: ['/w', '/x']),
      );
      expect(spec.writableRoots, ['/w', '/x']);
    });

    test('keeps an unresolvable allow root as given', () {
      final spec = SpecResolver(memFs()).resolve(
        const SandboxSpec(workspaceRoot: '/w', readableRoots: ['/maybe']),
      );
      expect(spec.readableRoots, ['/maybe']);
    });

    test('grants a symlinked allow root as both target and link', () {
      // The kernel needs the link node itself granted to traverse it, so
      // keeping only the target would drop access reached through the link
      // (macOS `/var`→`/private/var`).
      final spec =
          SpecResolver(
            memFs(dirs: {'/real': []}, symlinks: {'/link': '/real'}),
          ).resolve(
            const SandboxSpec(workspaceRoot: '/w', readableRoots: ['/link']),
          );
      expect(spec.readableRoots, ['/real', '/link']);
    });

    test('resolves a plain deny to a canonical path', () {
      final spec =
          SpecResolver(
            memFs(
              files: {'/home/dotfiles/gitconfig'},
              symlinks: {'/link': '/home/dotfiles/gitconfig'},
            ),
          ).resolve(
            const SandboxSpec(workspaceRoot: '/w', deniedReads: ['/link']),
          );
      final deny = spec.denies.single;
      expect(deny.isGlob, isFalse);
      expect(deny.path, '/home/dotfiles/gitconfig');
    });

    test('keeps a deny on a missing path as given, rather than failing', () {
      final spec = SpecResolver(memFs()).resolve(
        const SandboxSpec(workspaceRoot: '/w', deniedReads: ['/home/.aws']),
      );
      final deny = spec.denies.single;
      expect(deny.isGlob, isFalse);
      expect(deny.path, '/home/.aws');
    });

    test('canonicalizes a glob deny at its base, keeping the tail', () {
      final spec = SpecResolver(memFs(dirs: {'/home': []})).resolve(
        const SandboxSpec(
          workspaceRoot: '/w',
          deniedReads: ['/home/*/secrets'],
        ),
      );
      final deny = spec.denies.single;
      expect(deny.isGlob, isTrue);
      expect(deny.base, '/home');
      expect(deny.tail, '*/secrets');
      expect(deny.path, '/home/*/secrets');
    });

    test('keeps a glob deny whose base is missing as given', () {
      final spec = SpecResolver(memFs()).resolve(
        const SandboxSpec(
          workspaceRoot: '/w',
          deniedReads: ['/home/*/secrets'],
        ),
      );
      final deny = spec.denies.single;
      expect(deny.isGlob, isTrue);
      expect(deny.base, '/home');
      expect(deny.tail, '*/secrets');
    });
  });
}
