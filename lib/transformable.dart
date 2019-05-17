import 'dart:math' show min, max;

import 'package:flutter/material.dart';

const _kMinFlingVelocity = 400.0;

/// A widget that scrolls and scales, both horizontally and vertically.
///
/// This widget behaves like a [StatefulWidget] but there are actually no
/// [setState()] calls. Instead of calling [setState()] to trigger a repaint,
/// this widget uses an [Animation] object which is passed to a [Flow] widget 
/// that listens to the object and repaints when it receives any updates.
/// 
/// This is the fastest way to trigger a repaint with [Flow] (see 
/// https://docs.flutter.io/flutter/widgets/Flow-class.html), which is already
/// "optimized for repositioning children using transformation matrices".
class Transformable extends StatefulWidget {
  final _maxXScale = 10.0;
  final _minXScale = 0.1;
  final _maxYScale = 10.0;
  final _minYScale = 0.1;
  final _startXScale = 1.0;
  final _startYScale = 1.0;

  /// The widget to make transformable.
  final Widget child;

  /// The "normal" or default size of the child.
  final Size size;

  /// The constant size of the viewer.
  final Size viewerSize;

  /// The smallest allowable size of the child.
  final Size minSize;

  /// The largest allowable size of the child.
  final Size maxSize;

  final double minXScale;
  final double minYScale;
  final double maxXScale;
  final double maxYScale;

  /// The initial position of the child, offset from the top left of the view.
  final Offset startOffset;

  /// The initial size of the child.
  ///
  /// Cannot be used with startXScale or startYScale.
  final Size startSize;

  /// The initial horizontal scale to apply to the child.
  final double startXScale;

  /// The initial vertical scale to apply to the child.
  final double startYScale;

  /// The inner [Rect] that the child must cover at all times.
  final Rect innerBoundRect;

  /// The outer [Rect] that the child must remain within at all times.
  final Rect outerBoundRect;

  /// Creates a widget that scrolls and scales, horizontally and vertically.
  Transformable({
    this.viewerSize,
    this.child,
    this.size,
    this.maxSize,
    this.minSize,
    this.maxXScale,
    this.minXScale,
    this.maxYScale,
    this.minYScale,
    this.startOffset = Offset.zero,
    this.startSize,
    this.startXScale,
    this.startYScale,
    this.innerBoundRect,
    this.outerBoundRect,
  });

  @override
  State<StatefulWidget> createState() {
    double minXScale = this.minXScale ?? _minXScale;
    double maxXScale = this.maxXScale ?? _maxXScale;
    double minYScale = this.minYScale ?? _minYScale;
    double maxYScale = this.maxYScale ?? _maxYScale;

    final minSize = this.minSize ?? innerBoundRect?.size;
    final maxSize = this.maxSize ?? outerBoundRect?.size;
    if (minSize != null) {
      minXScale = minSize.width / size.width;
      minYScale = minSize.height / size.height;
    }
    if (maxSize != null) {
      maxXScale = maxSize.width / size.width;
      maxYScale = maxSize.height / size.height;
    }

    double startXScale = this.startXScale ?? _startXScale;
    double startYScale = this.startYScale ?? _startYScale;
    if (this.startSize != null) {
      startXScale = startSize.width / size.width;
      startYScale = startSize.height / size.height;
    }

    return _TransformableState(
      innerBoundRect: innerBoundRect,
      outerBoundRect: outerBoundRect,
      minXScale: minXScale,
      maxXScale: maxXScale,
      minYScale: minYScale,
      maxYScale: maxYScale,
      startOffset: startOffset,
      startXScale: startXScale,
      startYScale: startYScale,
    );
  }
}

class _TransformableState extends State<Transformable>
    with TickerProviderStateMixin {
  _TransformableState({
    this.innerBoundRect,
    this.outerBoundRect,
    this.minXScale,
    this.minYScale,
    this.maxXScale,
    this.maxYScale,
    Offset startOffset,
    double startXScale,
    double startYScale,
  }) : _transform = TransformNotifier(
          offset: startOffset,
          xScale: startXScale,
          yScale: startYScale,
        );
  final double minXScale;
  final double maxXScale;
  final double minYScale;
  final double maxYScale;

  final Rect innerBoundRect;
  final Rect outerBoundRect;
  final TransformNotifier _transform;

  AnimationController _controller;
  Animation<Offset> _flingAnimation;

  Offset _prevFocalPoint;
  Offset _touchStartNormOffset;
  double _touchStartXScale;
  double _touchStartYScale;

  /// The child's current size (with scale).
  Size get _size => Size(
        _transform.xScale * widget.size.width,
        _transform.yScale * widget.size.height,
      );

  Offset get _maxOffset {
    double xMax = outerBoundRect.bottomRight.dx - _size.width;
    double yMax = outerBoundRect.bottomRight.dy - _size.height;

    if (innerBoundRect != null) {
      xMax = min(xMax, innerBoundRect.topLeft.dx);
      yMax = min(yMax, innerBoundRect.topLeft.dy);
    }
    return Offset(xMax, yMax);
  }

  Offset get _minOffset {
    double xMin = innerBoundRect.bottomRight.dx - _size.width;
    double yMin = innerBoundRect.bottomRight.dy - _size.height;

    if (outerBoundRect != null) {
      xMin = max(xMin, outerBoundRect.topLeft.dx);
      yMin = max(yMin, outerBoundRect.topLeft.dy);
    }

    return Offset(xMin, yMin);
  }

  @override
  void initState() {
    _controller = AnimationController(vsync: this)
      ..addListener(_handleFlingAnimation);

    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _clampOffset(Offset offset) => Offset(
        offset.dx.clamp(_minOffset.dx, _maxOffset.dx),
        offset.dy.clamp(_minOffset.dy, _maxOffset.dy),
      );

  void _handleFlingAnimation() {
    _transform.offset = _flingAnimation.value;
  }

  void _handleOnScaleStart(ScaleStartDetails details) {
    _controller.stop();

    final focalOffset = details.focalPoint - _transform.offset;

    _touchStartNormOffset = Offset(
      focalOffset.dx / _transform.xScale,
      focalOffset.dy / _transform.yScale,
    );

    _prevFocalPoint = details.focalPoint;
    _touchStartXScale = _transform.xScale;
    _touchStartYScale = _transform.yScale;
  }

  /// Handles all gesture updates (since pan is a subset of scale
  /// this handler catches both panning and scaling).
  void _handleOnScaleUpdate(ScaleUpdateDetails details) {
    // A scale of 1.0 indicates no scale change, so the gesture is a transform.
    if (details.scale == 1.0) {
      final offsetWithDiff =
          _transform.offset - (_prevFocalPoint - details.focalPoint);
      _transform.offset = _clampOffset(offsetWithDiff);
    } else {
      _transform.xScale = (_touchStartXScale * details.horizontalScale)
          .clamp(minXScale, maxXScale);
      _transform.yScale = (_touchStartYScale * details.verticalScale)
          .clamp(minYScale, maxYScale);

      final scaledNormOffset = Offset(
        _touchStartNormOffset.dx * _transform.xScale,
        _touchStartNormOffset.dy * _transform.yScale,
      );
      final focalPointMinusScaledNorm = details.focalPoint - scaledNormOffset;
      _transform.offset = _clampOffset(focalPointMinusScaledNorm);
    }

    _transform.updateListeners();
    _prevFocalPoint = details.focalPoint;
  }

  void _handleOnScaleEnd(ScaleEndDetails details) {
    final double magnitude = details.velocity.pixelsPerSecond.distance;
    if (magnitude < _kMinFlingVelocity) return;

    final Offset direction = details.velocity.pixelsPerSecond / magnitude;
    final double distance = (Offset.zero & widget.viewerSize).shortestSide;

    _flingAnimation = _controller.drive(Tween<Offset>(
      begin: _transform.offset,
      end: _clampOffset(_transform.offset + direction * distance),
    ));
    _controller
      ..value = 0.0
      ..fling(velocity: magnitude / 1000.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: _handleOnScaleStart,
      onScaleUpdate: _handleOnScaleUpdate,
      onScaleEnd: _handleOnScaleEnd,
      child: Flow(
        delegate: TransformableFlowDelegate(
          widget.viewerSize,
          widget.size,
          _transform,
        ),
        children: [widget.child],
      ),
    );
  }
}

/// Value class to hold an [Offset] and horizontal and vertical scales which
/// make up some transformation.
class TransformInfo {
  Offset offset;

  double xScale;
  double yScale;

  Matrix4 get transform => Matrix4.identity()
    ..translate(offset.dx, offset.dy)
    ..scale(xScale, yScale);

  TransformInfo({Offset offset, double xScale, double yScale})
      : this.offset = offset ?? const Offset(0.0, 0.0),
        this.xScale = xScale ?? 1.0,
        this.yScale = yScale ?? 1.0;
}

/// Maintains some transform data, updating listeners when its value changes.
class TransformNotifier extends ValueNotifier<Matrix4> {
  final TransformInfo _transformInfo;

  TransformNotifier({Offset offset, double xScale, double yScale})
      : _transformInfo = TransformInfo(
          offset: offset,
          xScale: xScale,
          yScale: yScale,
        ),
        super(null) {
    value = _transformInfo.transform;
  }

  Offset get offset => _transformInfo.offset;
  double get xScale => _transformInfo.xScale;
  double get yScale => _transformInfo.yScale;

  set xScale(double scale) => _transformInfo.xScale = scale;
  set yScale(double scale) => _transformInfo.yScale = scale;
  set offset(Offset offset) => _transformInfo.offset = offset;

  void updateListeners() => value = _transformInfo.transform;
}

/// A delegate that repaints its child when notified of a change in the child's
/// transform.
class TransformableFlowDelegate extends FlowDelegate {
  final Size viewerSize;
  final Size childSize;
  final TransformNotifier transformNotifier;

  TransformableFlowDelegate(
      this.viewerSize, this.childSize, TransformNotifier transformNotifier)
      : this.transformNotifier = transformNotifier,
        super(repaint: transformNotifier);

  @override
  Size getSize(BoxConstraints constraints) => viewerSize;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      BoxConstraints.tight(childSize);

  @override
  void paintChildren(FlowPaintingContext context) {
    context.paintChild(0, transform: transformNotifier.value);
  }

  /// No need to do logic here since we passed [transformNotifier] to [super],
  /// so repainting is controlled by its updates.
  @override
  bool shouldRepaint(TransformableFlowDelegate oldDelegate) => false;
}
