import 'dart:math';

import 'package:flutter/material.dart';

const _colors = <Color>[
  Color(0xFFBBDEFB),
  Color(0xFFFFCDD2),
  Color(0xFFE1BEE7),
  Colors.lightBlueAccent,
  Colors.cyanAccent,
  Colors.tealAccent,
];

// const List<Color> _colors = <Color>[
//   Color(0xFF000000),
//   Color(0xFF111111),
//   Color(0xFF222222),
//   Color(0xFF333333),
//   Color(0xFF444444),
//   Color(0xFF555555),
//   Color(0xFF666666),
//   Color(0xFF777777),
// ];

class Grid extends CustomPaint {
  Grid() : super(painter: GridPainter());
}

class GridPainter extends CustomPainter {
  final _random = Random();

  final rows = 20;
  final columns = 20;

  bool drawNumbers;

  GridPainter({this.drawNumbers = false});

  @override
  void paint(Canvas canvas, Size size) {
    final rowSpacing = size.height / rows;
    final columnSpacing = size.width / columns;

    for (var i = 0; i < rows; i++) {
      for (var j = 0; j < columns; j++) {
        final startX = j * columnSpacing;
        final startY = i * rowSpacing;
        final endX = startX + columnSpacing;
        final endY = startY + rowSpacing;
        //final colorIndex = j * i + i * i - j * i + 2 * j;

        final rect = Rect.fromLTRB(
          startX,
          startY,
          endX,
          endY,
        );
        canvas.drawRect(
          rect,
          Paint()..color = _colors[_random.nextInt(_colors.length)],
          //Paint()..color = _colors[colorIndex % _colors.length],
        );

        if (!drawNumbers) continue;

        final tp = TextPainter(
          text: TextSpan(
            text: '${i * columns + j}',
            style: TextStyle(
              color: Colors.black,
              fontSize: 8,
            ),
          ),
          textDirection: TextDirection.ltr,
        );

        tp.layout();
        tp.paint(canvas, Offset(startX + 2, startY + 4));
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
