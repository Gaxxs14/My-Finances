import 'dart:math' as math;
import 'package:flutter/material.dart';

class GaxxsLoader extends StatefulWidget {
  final double size;
  final String? loadingText;
  final bool showBrandName;

  const GaxxsLoader({
    super.key,
    this.size = 64.0,
    this.loadingText,
    this.showBrandName = true,
  });

  @override
  State<GaxxsLoader> createState() => _GaxxsLoaderState();
}

class _GaxxsLoaderState extends State<GaxxsLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Transform.rotate(
                angle: _rotationAnimation.value * 0.1,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.35 * _pulseAnimation.value),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _GaxxsBlocksPainter(progress: _controller.value),
                    size: Size(widget.size, widget.size),
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.showBrandName) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF06B6D4), Color(0xFF3B82F6)],
                ).createShader(bounds),
                child: const Text(
                  'GAXXS',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4.0,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (widget.loadingText != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.loadingText!,
            style: const TextStyle(fontSize: 12, color: Colors.white70, letterSpacing: 0.5),
          ),
        ],
      ],
    );
  }
}

class _GaxxsBlocksPainter extends CustomPainter {
  final double progress;

  _GaxxsBlocksPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint1 = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final paint2 = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final gap = w * 0.05;
    final skewAngle = -0.15; // Slanted angle like GAXXS logo

    // Top-left Block
    canvas.save();
    canvas.transform(Matrix4.skewX(skewAngle).storage);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.1, h * 0.05, w * 0.45, h * 0.4), const Radius.circular(6)),
      paint1,
    );
    canvas.restore();

    // Top-right Block
    canvas.save();
    canvas.transform(Matrix4.skewX(skewAngle).storage);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.6, h * 0.15, w * 0.3, h * 0.3), const Radius.circular(6)),
      paint2,
    );
    canvas.restore();

    // Bottom-left Block
    canvas.save();
    canvas.transform(Matrix4.skewX(skewAngle).storage);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.05, h * 0.5, w * 0.3, h * 0.3), const Radius.circular(6)),
      paint2,
    );
    canvas.restore();

    // Bottom-right Block
    canvas.save();
    canvas.transform(Matrix4.skewX(skewAngle).storage);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.4, h * 0.5, w * 0.5, h * 0.4), const Radius.circular(6)),
      paint1,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GaxxsBlocksPainter oldDelegate) => oldDelegate.progress != progress;
}

class GaxxsIconMark extends StatelessWidget {
  final double size;

  const GaxxsIconMark({super.key, this.size = 36.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GaxxsBlocksPainter(progress: 0),
        size: Size(size, size),
      ),
    );
  }
}
