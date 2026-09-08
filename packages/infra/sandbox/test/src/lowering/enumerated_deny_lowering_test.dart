import 'package:file/file.dart';
import 'package:sandbox/src/lowering/enumerated_deny_lowering.dart';
import 'package:sandbox/src/lowering/glob.dart';
import 'package:sandbox/src/lowering/lowered_policy.dart';
import 'package:sandbox/src/lowering/lowering_outcome.dart';
import 'package:sandbox/src/lowering/resolved_spec.dart';
import 'package:sandbox/src/sandbox_spec.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('EnumeratedDenyLowering', () {
    const lowering = EnumeratedDenyLowering();

    LoweringSucceeded lower(ResolvedSpec spec, FileSystem fs) =>
        lowering.lower(spec, GlobExpander(fs)) as LoweringSucceeded;

    GrantProgram program(ResolvedSpec spec, FileSystem fs) =>
        lower(spec, fs).policy as GrantProgram;

    test('grants a deny-free readable root wholesale', () {
      final policy = program(
        const ResolvedSpec(
          readableRoots: ['/usr'],
          writableRoots: [],
          denies: [],
          network: NetworkTier.all,
        ),
        memFs(),
      );
      expect(policy.grants, [const Grant('/usr', GrantAccess.read)]);
    });

    test('writable roots grant read+write', () {
      final policy = program(
        const ResolvedSpec(
          readableRoots: [],
          writableRoots: ['/w'],
          denies: [],
          network: NetworkTier.all,
        ),
        memFs(),
      );
      expect(policy.grants, [const Grant('/w', GrantAccess.readWrite)]);
    });

    test('a single deny lists the parent but hides the child', () {
      final fs = memFs(
        dirs: {
          '/home/joanna': [
            '/home/joanna/.ssh',
            '/home/joanna/.bashrc',
            '/home/joanna/docs',
          ],
        },
      );
      final policy = program(
        const ResolvedSpec(
          readableRoots: ['/home/joanna'],
          writableRoots: ['/w'],
          denies: [
            ResolvedDeny(base: '/home/joanna/.ssh', tail: '', isGlob: false),
          ],
          network: NetworkTier.all,
        ),
        fs,
      );

      // The parent is list-only — the leak regression: never `read` on a parent
      // that holds a deny, or the whole subtree (including .ssh) is readable.
      expect(
        policy.grants,
        contains(const Grant('/home/joanna', GrantAccess.listDir)),
      );
      expect(
        policy.grants.where((g) => g.path == '/home/joanna'),
        everyElement((Grant g) => g.access == GrantAccess.listDir),
      );
      // Allowed siblings are readable; the denied child is granted nothing.
      expect(
        policy.grants,
        contains(const Grant('/home/joanna/.bashrc', GrantAccess.read)),
      );
      expect(
        policy.grants,
        contains(const Grant('/home/joanna/docs', GrantAccess.read)),
      );
      expect(
        policy.grants.map((g) => g.path),
        isNot(contains('/home/joanna/.ssh')),
      );
    });

    test('a nested deny decomposes both levels and skips the sub-parent', () {
      final fs = memFs(
        dirs: {
          '/home/joanna': ['/home/joanna/.config', '/home/joanna/docs'],
          '/home/joanna/.config': [
            '/home/joanna/.config/gh',
            '/home/joanna/.config/nvim',
          ],
        },
      );
      final policy = program(
        const ResolvedSpec(
          readableRoots: ['/home/joanna'],
          writableRoots: [],
          denies: [
            ResolvedDeny(
              base: '/home/joanna/.config/gh',
              tail: '',
              isGlob: false,
            ),
          ],
          network: NetworkTier.all,
        ),
        fs,
      );

      expect(
        policy.grants,
        containsAll(const [
          Grant('/home/joanna', GrantAccess.listDir),
          Grant('/home/joanna/.config', GrantAccess.listDir),
          Grant('/home/joanna/docs', GrantAccess.read),
          Grant('/home/joanna/.config/nvim', GrantAccess.read),
        ]),
      );
      // The sub-parent is never granted read (only list), and gh gets nothing.
      expect(
        policy.grants,
        isNot(contains(const Grant('/home/joanna/.config', GrantAccess.read))),
      );
      expect(
        policy.grants.map((g) => g.path),
        isNot(contains('/home/joanna/.config/gh')),
      );
    });

    test('a symlinked deny target decomposes without leaking via the link', () {
      // ~/.gitconfig → ~/dotfiles/gitconfig; resolve canonicalizes the deny to
      // the target, so the deny is the target path.
      final fs = memFs(
        dirs: {
          '/home/joanna': ['/home/joanna/dotfiles', '/home/joanna/docs'],
          '/home/joanna/dotfiles': [
            '/home/joanna/dotfiles/gitconfig',
            '/home/joanna/dotfiles/other',
          ],
        },
        symlinks: {
          '/home/joanna/.gitconfig': '/home/joanna/dotfiles/gitconfig',
        },
      );
      final policy = program(
        const ResolvedSpec(
          readableRoots: ['/home/joanna'],
          writableRoots: [],
          denies: [
            ResolvedDeny(
              base: '/home/joanna/dotfiles/gitconfig',
              tail: '',
              isGlob: false,
            ),
          ],
          network: NetworkTier.all,
        ),
        fs,
      );

      final grantedPaths = policy.grants.map((g) => g.path).toSet();
      // Neither the real target nor the symlink pointing at it is granted read.
      expect(grantedPaths, isNot(contains('/home/joanna/dotfiles/gitconfig')));
      expect(grantedPaths, isNot(contains('/home/joanna/.gitconfig')));
      // Its allowed siblings still are.
      expect(
        policy.grants,
        containsAll(const [
          Grant('/home/joanna/dotfiles', GrantAccess.listDir),
          Grant('/home/joanna/dotfiles/other', GrantAccess.read),
          Grant('/home/joanna/docs', GrantAccess.read),
        ]),
      );
    });

    test('a glob deny snapshots into grants and the report', () {
      final fs = memFs(
        dirs: {
          '/home': ['/home/a.env', '/home/b.txt'],
        },
      );
      final result = lower(
        const ResolvedSpec(
          readableRoots: ['/home'],
          writableRoots: [],
          denies: [ResolvedDeny(base: '/home', tail: '*.env', isGlob: true)],
          network: NetworkTier.all,
        ),
        fs,
      );
      final policy = result.policy as GrantProgram;

      expect(
        policy.grants,
        containsAll(const [
          Grant('/home', GrantAccess.listDir),
          Grant('/home/b.txt', GrantAccess.read),
        ]),
      );
      expect(policy.grants.map((g) => g.path), isNot(contains('/home/a.env')));
      expect(result.report.deniedReads, ['/home/a.env']);
    });

    test('a deny under no readable root is a no-op on grants', () {
      final result = lower(
        const ResolvedSpec(
          readableRoots: ['/usr'],
          writableRoots: [],
          denies: [
            ResolvedDeny(base: '/home/.ssh', tail: '', isGlob: false),
          ],
          network: NetworkTier.all,
        ),
        memFs(),
      );
      final policy = result.policy as GrantProgram;
      // /usr grants wholesale — nothing beneath it is denied.
      expect(policy.grants, [const Grant('/usr', GrantAccess.read)]);
      // But the deny is still reported honestly.
      expect(result.report.deniedReads, ['/home/.ssh']);
    });
  });
}
