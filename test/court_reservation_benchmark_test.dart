import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Benchmark finding first available slot index logic', () {
    final startTimes = List<TimeOfDay>.generate(
      15,
      (i) => TimeOfDay(hour: 8 + i, minute: 0),
    );
    final bookedIndices = {0, 1, 2, 3, 4, 5, 6, 7, 8};

    bool isSlotBooked(int i) => bookedIndices.contains(i);
    bool isTimeBooked(TimeOfDay time) => bookedIndices.contains(startTimes.indexOf(time));

    int findManual() {
      for (int i = 0; i < startTimes.length; i++) {
        if (!isSlotBooked(i)) {
          return i;
        }
      }
      return -1;
    }

    int findIndexWhereWithTrackedIndex() {
      int i = 0;
      return startTimes.indexWhere((_) => !isSlotBooked(i++));
    }

    int findIndexWhereWithTime() {
      return startTimes.indexWhere((time) => !isTimeBooked(time));
    }

    int findIterableGenerate() {
      return Iterable<int>.generate(startTimes.length)
          .firstWhere((i) => !isSlotBooked(i), orElse: () => -1);
    }

    // Warmup
    for (int i = 0; i < 1000; i++) {
      findManual();
      findIndexWhereWithTrackedIndex();
      findIndexWhereWithTime();
      findIterableGenerate();
    }

    const iterations = 1000000;

    final sw1 = Stopwatch()..start();
    for (int i = 0; i < iterations; i++) {
      findManual();
    }
    sw1.stop();

    final sw2 = Stopwatch()..start();
    for (int i = 0; i < iterations; i++) {
      findIndexWhereWithTrackedIndex();
    }
    sw2.stop();

    final sw3 = Stopwatch()..start();
    for (int i = 0; i < iterations; i++) {
      findIterableGenerate();
    }
    sw3.stop();

    print('Manual loop: ${sw1.elapsedMicroseconds} us');
    print('indexWhere (tracked index): ${sw2.elapsedMicroseconds} us');
    print('Iterable.generate: ${sw3.elapsedMicroseconds} us');

    expect(findManual(), equals(9));
    expect(findIndexWhereWithTrackedIndex(), equals(9));
    expect(findIterableGenerate(), equals(9));
  });
}
