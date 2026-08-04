// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:math' as math;

import 'package:flutter/material.dart';

class AvarynHorseshoeIcon extends StatelessWidget {
  const AvarynHorseshoeIcon({
    super.key,
    this.width,
    this.height,
    this.active = false,
  });

  final double? width;
  final double? height;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final color = active ? theme.secondary : theme.secondaryText;

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _AvarynHorseshoePainter(color)),
    );
  }
}

class _AvarynHorseshoePainter extends CustomPainter {
  const _AvarynHorseshoePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final dx = (size.width - side) / 2;
    final dy = (size.height - side) / 2;
    canvas.translate(dx, dy);

    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final outer = Path()
      ..moveTo(side * 0.22, side * 0.18)
      ..cubicTo(
        side * 0.10,
        side * 0.38,
        side * 0.14,
        side * 0.73,
        side * 0.34,
        side * 0.87,
      )
      ..cubicTo(
        side * 0.43,
        side * 0.94,
        side * 0.57,
        side * 0.94,
        side * 0.66,
        side * 0.87,
      )
      ..cubicTo(
        side * 0.86,
        side * 0.73,
        side * 0.90,
        side * 0.38,
        side * 0.78,
        side * 0.18,
      );
    canvas.drawPath(outer, outline);

    final inner = Path()
      ..moveTo(side * 0.34, side * 0.26)
      ..cubicTo(
        side * 0.27,
        side * 0.43,
        side * 0.29,
        side * 0.66,
        side * 0.41,
        side * 0.74,
      )
      ..cubicTo(
        side * 0.46,
        side * 0.78,
        side * 0.54,
        side * 0.78,
        side * 0.59,
        side * 0.74,
      )
      ..cubicTo(
        side * 0.71,
        side * 0.66,
        side * 0.73,
        side * 0.43,
        side * 0.66,
        side * 0.26,
      );
    final innerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.045
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(inner, innerPaint);

    final nailPaint = Paint()..color = color;
    for (final point in <Offset>[
      Offset(side * 0.22, side * 0.42),
      Offset(side * 0.26, side * 0.67),
      Offset(side * 0.78, side * 0.42),
      Offset(side * 0.74, side * 0.67),
    ]) {
      canvas.drawCircle(point, side * 0.035, nailPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AvarynHorseshoePainter oldDelegate) =>
      oldDelegate.color != color;
}
