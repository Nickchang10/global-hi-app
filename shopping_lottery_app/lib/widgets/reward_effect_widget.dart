import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';

/// 🎆 通用獎勵特效 Widget
class RewardEffectWidget extends StatefulWidget {
  final String animation; // Lottie 檔案名稱
  final String message; // 顯示文字
  const RewardEffectWidget({
    super.key,
    required this.animation,
    required this.message,
  });

  @override
  State<RewardEffectWidget> createState() => _RewardEffectWidgetState();
}

class _RewardEffectWidgetState extends State<RewardEffectWidget> {
  late ConfettiController _confetti;
  final _audio = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _confetti.play();
      await _audio.play(AssetSource('sounds/reward_sound.mp3'));
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 🎉 Confetti 彩帶效果
        ConfettiWidget(
          confettiController: _confetti,
          blastDirectionality: BlastDirectionality.explosive,
          emissionFrequency: 0.05,
          numberOfParticles: 25,
          gravity: 0.3,
        ),

        // 💎 Lottie 動畫
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/lottie/${widget.animation}',
                height: 200, repeat: false),
            const SizedBox(height: 16),
            Text(
              widget.message,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }
}
