import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/ui/adaptive_layout.dart';

void main() {
  group('adaptiveGridColumns', () {
    test('phones keep their column count', () {
      expect(adaptiveGridColumns(360), 2); // typical phone
      expect(adaptiveGridColumns(430), 2); // large phone
      expect(adaptiveGridColumns(599), 2); // just under the first step
    });

    test('mid-size screens gain one column', () {
      expect(adaptiveGridColumns(600), 3); // small tablet / foldable
      expect(adaptiveGridColumns(899), 3);
    });

    test('wide screens gain two columns', () {
      expect(adaptiveGridColumns(900), 4); // 10" tablet
      expect(adaptiveGridColumns(1280), 4);
    });

    test('respects a custom phone baseline', () {
      expect(adaptiveGridColumns(360, phoneColumns: 3), 3);
      expect(adaptiveGridColumns(900, phoneColumns: 3), 5);
    });
  });
}
