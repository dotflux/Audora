import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedEqualizer extends StatefulWidget {
  const AnimatedEqualizer({super.key});

  @override
  State<AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<AnimatedEqualizer> {
  late Timer _timer;
  final List<double> _heights = List.generate(20, (_) => 10);
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      setState(() {
        for (int i = 0; i < _heights.length; i++) {
          _heights[i] = 5 + _random.nextDouble() * 30;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_heights.length, (i) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 4,
            height: _heights[i],
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}
