import 'dart:math' show min, max;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

const _kMinFlingVelocity = 400.0;

typedef TransformListener = void Function(TransformInfo);

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

  /// Creates a widget that scrolls and scales, horizontally and vertically.
  Transformable({
    @required this.viewerSize,
    @required this.child,
    @required this.size,
    this.startOffset = Offset.zero,
    this.startSize,
    this.startXScale,
    this.startYScale,
    this.maxSize,
    this.minSize,
    this.maxXScale,
    this.minXScale,
    this.maxYScale,
    this.minYScale,
    this.innerBoundRect,
    this.outerBoundRect,
  }) : transformNotifier = TransformNotifier();

  /// The constant size of the viewer.
  final Size viewerSize;

  /// The widget to make transformable.
  final Widget child;

  /// The "normal" or default size of the child.
  final Size size;

  /// The initial size of the child.
  ///
  /// Cannot be used with startXScale or startYScale.
  final Size startSize;

  /// The initial position of the child, offset from the top left of the view.
  final Offset startOffset;

  /// The initial horizontal scale to apply to the child.
  final double startXScale;

  /// The initial vertical scale to apply to the child.
  final double startYScale;

  /// The largest allowable size of the child.
  final Size maxSize;

  /// The smallest allowable size of the child.
  final Size minSize;

  final double maxXScale;
  final double minXScale;
  final double maxYScale;
  final double minYScale;

  /// The inner [Rect] that the child must cover at all times.
  final Rect innerBoundRect;

  /// The outer [Rect] that the child must remain within at all times.
  final Rect outerBoundRect;

  /// A [ValueNotifier] for listening to the child's transform.
  final TransformNotifier transformNotifier;

  @override
  State<StatefulWidget> createState() {
    double minXScale = this.minXScale ?? _minXScale;
    double maxXScale = this.maxXScale ?? _maxXScale;
    double minYScale = this.minYScale ?? _minYScale;
    double maxYScale = this.maxYScale ?? _maxYScale;

    final minSize = this.minSize ?? innerBoundRect?.size;
    if (minSize != null) {
      minXScale = minSize.width / size.width;
      minYScale = minSize.height / size.height;
    }

    final maxSize = this.maxSize ?? outerBoundRect?.size;
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

    transformNotifier.transform.offset = startOffset;
    transformNotifier.transform.xScale = startXScale;
    transformNotifier.transform.yScale = startYScale;

    final constraints = TransformConstraints(
      minXScale: minXScale,
      maxXScale: maxXScale,
      minYScale: minYScale,
      maxYScale: maxYScale,
      innerBoundRect: innerBoundRect,
      outerBoundRect: outerBoundRect,
    );

    return _TransformableState(
      constraints: constraints,
    );
  }
}

class _TransformableState extends State<Transformable>
    with TickerProviderStateMixin {
  _TransformableState({
    this.constraints,
  });

  final TransformConstraints constraints;

  TransformInfo transform;

  AnimationController _controller;
  Animation<Offset> _flingAnimation;

  Offset _prevFocalPoint;
  Offset _touchStartNormOffset;
  double _touchStartXScale;
  double _touchStartYScale;

  /// The child's current size (with scale).
  Size get _size => Size(
        transform.xScale * widget.size.width,
        transform.yScale * widget.size.height,
      );

  Offset get _maxOffset {
    final bottomRightBound = constraints.outerBoundRect != null
        ? constraints.outerBoundRect.bottomRight
        : Offset.infinite;

    double xMax = bottomRightBound.dx - _size.width;
    double yMax = bottomRightBound.dy - _size.height;

    if (constraints.innerBoundRect != null) {
      xMax = min(xMax, constraints.innerBoundRect.topLeft.dx);
      yMax = min(yMax, constraints.innerBoundRect.topLeft.dy);
    }
    return Offset(xMax, yMax);
  }

  Offset get _minOffset {
    final bottomRightBound = constraints.innerBoundRect != null
        ? constraints.innerBoundRect.bottomRight
        : -Offset.infinite;

    double xMin = bottomRightBound.dx - _size.width;
    double yMin = bottomRightBound.dy - _size.height;

    if (constraints.outerBoundRect != null) {
      xMin = max(xMin, constraints.outerBoundRect.topLeft.dx);
      yMin = max(yMin, constraints.outerBoundRect.topLeft.dy);
    }

    return Offset(xMin, yMin);
  }

  @override
  void initState() {
    transform = widget.transformNotifier.transform;

    _controller = AnimationController(vsync: this)
      ..addListener(_handleFlingAnimation);

    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _clampOffset(Offset offset) {
    final x = min(_maxOffset.dx, max(offset.dx, _minOffset.dx));
    final y = min(_maxOffset.dy, max(offset.dy, _minOffset.dy));

    return Offset(x, y);
  }

  void _handleFlingAnimation() {
    transform.offset = _flingAnimation.value;
  }

  void _handleOnScaleStart(ScaleStartDetails details) {
    _controller.stop();

    final focalOffset = details.focalPoint - transform.offset;

    _touchStartNormOffset = Offset(
      focalOffset.dx / transform.xScale,
      focalOffset.dy / transform.yScale,
    );

    _prevFocalPoint = details.focalPoint;
    _touchStartXScale = transform.xScale;
    _touchStartYScale = transform.yScale;
  }

  /// Handles all gesture updates (since pan is a subset of scale
  /// this handler catches both panning and scaling).
  void _handleOnScaleUpdate(ScaleUpdateDetails details) {
    // A scale of 1.0 indicates no scale change, so the gesture is a transform.
    if (details.scale == 1.0) {
      final offsetWithDiff =
          transform.offset - (_prevFocalPoint - details.focalPoint);
      transform.offset = _clampOffset(offsetWithDiff);
    } else {
      transform.xScale = (_touchStartXScale * details.horizontalScale)
          .clamp(constraints.minXScale, constraints.maxXScale);
      transform.yScale = (_touchStartYScale * details.verticalScale)
          .clamp(constraints.minYScale, constraints.maxYScale);

      final scaledOffset = Offset(
        _touchStartNormOffset.dx * transform.xScale,
        _touchStartNormOffset.dy * transform.yScale,
      );
      final focalPointMinusOffset = details.focalPoint - scaledOffset;
      transform.offset = _clampOffset(focalPointMinusOffset);
    }

    widget.transformNotifier.notifyListeners();
    _prevFocalPoint = details.focalPoint;
  }

  void _handleOnScaleEnd(ScaleEndDetails details) {
    final double magnitude = details.velocity.pixelsPerSecond.distance;
    if (magnitude < _kMinFlingVelocity) return;

    final Offset direction = details.velocity.pixelsPerSecond / magnitude;
    final double distance = (Offset.zero & widget.viewerSize).shortestSide;

    _flingAnimation = _controller.drive(Tween<Offset>(
      begin: transform.offset,
      end: _clampOffset(transform.offset + direction * distance),
    ));
    _controller
      ..value = 0.0
      ..fling(velocity: magnitude / 1000.0);
  }

  @override
  Widget build(BuildContext context) {
    // Wait until after the build to broadcast the transform information (
    // otherwise, an Exception would be thrown).
    SchedulerBinding.instance.addPostFrameCallback(
        (_) => widget.transformNotifier.notifyListeners());

    return GestureDetector(
      onScaleStart: _handleOnScaleStart,
      onScaleUpdate: _handleOnScaleUpdate,
      onScaleEnd: _handleOnScaleEnd,
      child: Flow(
        delegate: TransformableFlowDelegate(
          widget.viewerSize,
          widget.size,
          widget.transformNotifier,
        ),
        children: [widget.child],
      ),
    );
  }
}


/// Constraints to consider when using a transformation.
@immutable
class TransformConstraints {
  final double minXScale;
  final double maxXScale;
  final double minYScale;
  final double maxYScale;

  /// The area that the child must completely cover at all times.
  final Rect innerBoundRect;

  /// The area that the child must remain within at all times.
  final Rect outerBoundRect;

  TransformConstraints({
    this.innerBoundRect,
    this.outerBoundRect,
    this.minXScale,
    this.maxXScale,
    this.minYScale,
    this.maxYScale,
  });
}

/// Value class to hold an [Offset] and horizontal and vertical scales which
/// make up some transformation.
class TransformInfo {
  TransformInfo({this.offset, this.xScale, this.yScale});

  Offset offset;
  double xScale;
  double yScale;

  Matrix4 get transform => Matrix4.identity()
    ..translate(offset.dx, offset.dy)
    ..scale(xScale, yScale);

  @override
  String toString() =>
      'TransformInfo: $offset, x scale: $xScale, y scale: $yScale';
}

/// Maintains offset and scale, and updates listeners when those values change.
class TransformNotifier extends ValueNotifier<TransformInfo> {
  TransformNotifier({Offset offset, double xScale, double yScale})
      : transform = TransformInfo(
          offset: offset,
          xScale: xScale,
          yScale: yScale,
        ),
        super(null) {
    value = transform;
  }

  final TransformInfo transform;

  @override
  void notifyListeners() => super.notifyListeners();

  @override
  String toString() =>
      'TransformNotifier, current transform: ${transform.offset}, '
      'x scale: ${transform.xScale}, y scale: ${transform.yScale}';
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
    context.paintChild(0, transform: transformNotifier.value.transform);
  }

  /// No need to do logic here since we passed [transformNotifier] to [super],
  /// so repainting is controlled by its updates.
  @override
  bool shouldRepaint(TransformableFlowDelegate oldDelegate) => false;
}
