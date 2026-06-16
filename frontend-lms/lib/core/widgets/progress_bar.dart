import 'package:flutter/material.dart';
import '../theme/colors.dart';

enum ProgressTone { amber, green, orange, red }

class ArrestoProgressBar extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final double height;
  final ProgressTone tone;
  final Color? trackColor;

  const ArrestoProgressBar({
    super.key,
    required this.value,
    this.height = 8.0,
    this.tone = ProgressTone.amber,
    this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = switch (tone) {
      ProgressTone.amber => ArrestoColors.amber,
      ProgressTone.green => ArrestoColors.green,
      ProgressTone.orange => ArrestoColors.orange,
      ProgressTone.red => ArrestoColors.red,
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        backgroundColor: trackColor ?? ArrestoColors.line,
        valueColor: AlwaysStoppedAnimation(fillColor),
        minHeight: height,
      ),
    );
  }
}

class AnimatedArrestoProgressBar extends StatefulWidget {
  final double value;
  final double height;
  final ProgressTone tone;
  final Color? trackColor;
  final Duration duration;

  const AnimatedArrestoProgressBar({
    super.key,
    required this.value,
    this.height = 8.0,
    this.tone = ProgressTone.amber,
    this.trackColor,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<AnimatedArrestoProgressBar> createState() =>
      _AnimatedArrestoProgressBarState();
}

class _AnimatedArrestoProgressBarState
    extends State<AnimatedArrestoProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _oldValue = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedArrestoProgressBar old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _oldValue = old.value;
      _animation = Tween<double>(begin: _oldValue, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => ArrestoProgressBar(
        value: _animation.value,
        height: widget.height,
        tone: widget.tone,
        trackColor: widget.trackColor,
      ),
    );
  }
}
