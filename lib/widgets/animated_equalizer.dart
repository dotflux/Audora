import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AnimatedEqualizer extends StatefulWidget {
  final AudioPlayer player;

  const AnimatedEqualizer({super.key, required this.player});

  @override
  State<AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<AnimatedEqualizer> {
  late Timer _timer;
  final List<double> _heights = List.generate(20, (_) => 10);
  final _random = Random();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  @override
  void initState() {
    super.initState();

    _playerStateSubscription = widget.player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    _positionSubscription = widget.player.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _isPlaying = widget.player.playing;

    _timer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (mounted) {
        setState(() {
          _updateHeights();
        });
      }
    });
  }

  void _updateHeights() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final time = now / 1000.0;
    final positionMs = _position.inMilliseconds / 1000.0;

    final baseIntensity = _isPlaying ? 1.0 : 0.3;

    for (int i = 0; i < _heights.length; i++) {
      final bandIndex = i / _heights.length;

      final bassFreq = 0.3 + (bandIndex < 0.3 ? bandIndex * 0.5 : 0);
      final midFreq =
          0.8 +
          (bandIndex >= 0.3 && bandIndex < 0.7 ? (bandIndex - 0.3) * 1.2 : 0);
      final trebleFreq = 1.5 + (bandIndex >= 0.7 ? (bandIndex - 0.7) * 2.0 : 0);

      final phase =
          time * (bassFreq + midFreq + trebleFreq) + positionMs * 0.15;

      final bassWave = sin(phase * bassFreq);
      final midWave = sin(phase * midFreq * 1.8);
      final trebleWave = sin(phase * trebleFreq * 3.2);

      double combined;
      if (bandIndex < 0.3) {
        combined = bassWave * 0.7 + midWave * 0.2 + trebleWave * 0.1;
      } else if (bandIndex < 0.7) {
        combined = bassWave * 0.3 + midWave * 0.5 + trebleWave * 0.2;
      } else {
        combined = bassWave * 0.1 + midWave * 0.3 + trebleWave * 0.6;
      }

      final normalized = (combined + 1.0) / 2.0;

      final randomBoost = _random.nextDouble() * 0.25;
      final finalValue = (normalized * 0.75 + randomBoost * 0.25);

      double heightMultiplier;
      if (bandIndex < 0.25) {
        heightMultiplier = 0.6;
      } else if (bandIndex < 0.5) {
        heightMultiplier = 0.85;
      } else if (bandIndex < 0.75) {
        heightMultiplier = 1.1;
      } else {
        heightMultiplier = 0.95;
      }

      final heightValue = finalValue * baseIntensity * heightMultiplier;
      _heights[i] = 5 + heightValue * 30;
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
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
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
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
