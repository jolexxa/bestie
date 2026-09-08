import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_view/src/view/components/compaction_marker_view.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

Component _themed(Component child) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(data: appThemeDefault, child: child),
);

final _t0 = DateTime.utc(2026);

void main() {
  group('CompactionMarkerView', () {
    test('shows the committed result without a progress bar', () async {
      await testNocterm('compaction committed', (tester) async {
        await tester.pumpComponent(
          _themed(
            CompactionMarkerView(
              CompactionMarkerTimelineItem(
                id: 'c1',
                timestamp: _t0,
                summary: 'rolling memory',
                tokensBefore: 42,
              ),
            ),
          ),
        );
        expect(
          tester.terminalState,
          containsText('Compacted ~42 tokens'),
        );
        expect(tester.terminalState, isNot(containsText('█')));
      });
    });

    test('streams progress while folding', () async {
      await testNocterm('compaction running', (tester) async {
        await tester.pumpComponent(
          _themed(
            CompactionMarkerView(
              CompactionMarkerTimelineItem(
                id: 'c1',
                timestamp: _t0,
                summary: 'rolling',
                tokensBefore: 42,
                running: true,
                prefillFraction: 0.5,
              ),
            ),
          ),
        );
        expect(
          tester.terminalState,
          containsText('Compacting ~42 tokens…'),
        );
        expect(tester.terminalState, containsText('█'));
      });
    });
  });
}
