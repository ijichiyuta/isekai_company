import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_app/ui/progress.dart';

// The rank-up bar fills to the LESSER of the assets/fame ratios — both gates
// must be cleared to promote, so the weaker one governs. These guard the edge
// cases the widget itself can't easily assert (zero thresholds, clamping).

void main() {
  test('both thresholds unmet: bar shows the weaker (smaller) ratio', () {
    // funds 50/100 = .5, fame 90/100 = .9 → min .5
    expect(
      rankUpProgress(funds: 50, fame: 90, minAssets: 100, minFame: 100),
      0.5,
    );
    // symmetric: fame is now the weaker gate
    expect(
      rankUpProgress(funds: 90, fame: 50, minAssets: 100, minFame: 100),
      0.5,
    );
  });

  test('meeting both thresholds fills the bar', () {
    expect(
      rankUpProgress(funds: 100, fame: 100, minAssets: 100, minFame: 100),
      1.0,
    );
  });

  test('a zero threshold counts as already satisfied', () {
    // No fame gate → only funds governs.
    expect(
      rankUpProgress(funds: 25, fame: 0, minAssets: 100, minFame: 0),
      0.25,
    );
    // No gates at all → full.
    expect(rankUpProgress(funds: 0, fame: 0, minAssets: 0, minFame: 0), 1.0);
  });

  test('over-target clamps to 1.0 and negative funds clamp to 0.0', () {
    expect(
      rankUpProgress(funds: 999, fame: 999, minAssets: 100, minFame: 100),
      1.0,
    );
    expect(
      rankUpProgress(funds: -50, fame: 100, minAssets: 100, minFame: 100),
      0.0,
    );
  });
}
