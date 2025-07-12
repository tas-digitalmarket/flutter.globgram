import 'package:flutter/material.dart';

class VoicePlayerWidget extends StatefulWidget {
  final String filePath;
  final Duration duration;

  const VoicePlayerWidget({
    super.key,
    required this.filePath,
    required this.duration,
  });

  @override
  State<VoicePlayerWidget> createState() => _VoicePlayerWidgetState();
}

class _VoicePlayerWidgetState extends State<VoicePlayerWidget> {
  bool _isPlaying = false;

  Future<void> _togglePlayback() async {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      // Show playing feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔊 Playing voice message...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Play voice message (placeholder - needs flutter_sound integration)
      await Future.delayed(widget.duration);

      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: _togglePlayback,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Waveform visualization
          Expanded(
            child: SizedBox(
              height: 24,
              child: Row(
                children: List.generate(15, (index) {
                  final isActive = _isPlaying && index < 8;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 2,
                    height: (index % 3 + 1) * 8.0,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  );
                }),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Duration
          Text(
            _formatDuration(widget.duration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
