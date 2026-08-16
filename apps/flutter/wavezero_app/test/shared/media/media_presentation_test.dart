import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/shared/media/media_presentation.dart';

void main() {
  test('quality labels preserve existing consumer mapping', () {
    expect(wzProductQualityLabel('original'), 'Original');
    expect(wzProductQualityLabel('lossless'), 'Original');
    expect(wzProductQualityLabel('high'), 'High');
    expect(wzProductQualityLabel('standard'), 'Standard');
    expect(wzProductQualityLabel('low'), 'Standard');
    expect(wzProductQualityLabel(null), 'Unknown');
    expect(wzProductQualityLabel('unknown'), 'Unknown');
    expect(wzProductQualityLabel('Custom Tier'), 'Custom Tier');
  });
}
