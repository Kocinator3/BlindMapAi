import 'dart:math';

// Preserve explicit transition sequences; randomness is tested separately.
class FixedOrderRandom implements Random {
  @override
  int nextInt(int max) => max - 1;
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0.5;
}
