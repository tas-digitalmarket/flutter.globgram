import 'package:flutter/material.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final Function(String filePath, Duration duration) onVoiceRecorded;

  const VoiceRecorderWidget({
    super.key,
    required this.onVoiceRecorded,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  DateTime? _recordingStartTime;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _startRecording() async {
    setState(() {
      _isRecording = true;
      _recordingStartTime = DateTime.now();
    });

    // Start animation
    _animationController.repeat(reverse: true);

    // Show recording feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎤 Recording... Release to send'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    // Stop animation
    _animationController.stop();
    _animationController.reset();

    final duration = DateTime.now().difference(_recordingStartTime!);

    setState(() {
      _isRecording = false;
    });

    // Create voice file reference (placeholder - needs flutter_sound integration)
    final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    // Call callback with recorded data
    widget.onVoiceRecorded(fileName, duration);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Voice message sent (${duration.inSeconds}s)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        print('Voice recorder tapped down');
        _startRecording();
      },
      onTapUp: (_) {
        print('Voice recorder tapped up');
        _stopRecording();
      },
      onTapCancel: () {
        print('Voice recorder tap cancelled');
        _stopRecording();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isRecording ? _scaleAnimation.value : 1.0,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red : Colors.blue,
                shape: BoxShape.circle,
                boxShadow: _isRecording
                    ? [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ]
                    : [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.2),
                          blurRadius: 5,
                          spreadRadius: 1,
                        )
                      ],
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 28,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
