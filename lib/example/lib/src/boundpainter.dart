import 'package:flutter/material.dart';

class BoundPaint extends CustomPaint {
  final Rect innerRect;
  final Rect outerRect;

  BoundPaint({
    this.innerRect,
    this.outerRect,
  }) : super(
            painter: BoundPainter(
          innerRect: innerRect,
          outerRect: outerRect,
        ));
}

class BoundPainter extends CustomPainter {
  final Rect innerRect;
  final Rect outerRect;

  BoundPainter({
    this.innerRect,
    this.outerRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (innerRect != null) {
      canvas.drawRect(
        innerRect,
        Paint()..color = Colors.redAccent,
      );
    }
    
    if (outerRect != null) {
      canvas.drawRect(
        outerRect,
        Paint()
          ..color = Colors.green
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
