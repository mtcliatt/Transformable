import 'dart:math' show min, max;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// TODOs
// todo: move example folder to proper location (up to be beside lib not in it).

typedef TransformListener = void Function(Transformation);

/// A widget that scrolls and scales, both horizontally and vertically.
///
/// This widget behaves like a [StatefulWidget] but there are actually no
/// [setState()] calls. Instead of calling [setState()] to trigger a repaint,
/// this widget uses a [Flow] widget which is passed to a [Flow] widget
/// that listens to the object and repaints when it receives any updates.
///
/// This is the fastest way to trigger a repaint with [Flow] (see
/// https://docs.flutter.io/flutter/widgets/Flow-class.html), which is already
/// "optimized for repositioning children using transformation matrices".
class Transformable extends StatefulWidget {
  /// Creates a widget that scrolls and scales, horizontally and vertically.
  Transformable({
    this.child,
    this.viewerSize,
    TransformConfig config,
    TransformController controller,
  }) : this.controller = controller ??
            TransformController(
              config: config ?? TransformConfig(),
            );

  /// The widget to make transformable.
  final Widget child;

  /// The constant size of the viewer.
  final Size viewerSize;

  /// An optional controller/observer for this transformable wiget..
  final TransformController controller;

  @override
  State<StatefulWidget> createState() => _TransformableState();
}

class _TransformableState extends State<Transformable>
    with SingleTickerProviderStateMixin {
  _TransformableState();

  TransformController controller;

  @override
  void initState() {
    controller = widget.controller;
    controller.animationController = AnimationController(vsync: this);
    controller.viewportSize = widget.viewerSize;

    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Flow(
        delegate: TransformableFlowDelegate(
          widget.viewerSize,
          widget.controller.config.initialSize,
          widget.controller,
        ),
        children: [widget.child],
      ),
      onDoubleTap: controller.handleDoubleTap,
      onTapUp: controller.handleTapUp,
      onScaleStart: controller.handleScaleStart,
      onScaleUpdate: controller.handleScaleUpdate,
      onScaleEnd: controller.handleScaleEnd,
    );
  }
}

/// Constraints to consider when using a transformation.
class TransformConfig {
  factory TransformConfig({
    Transformation initialTransform,
    Size initialSize,
    Size maxSize,
    Size minSize,
    Rect innerBoundRect = const Rect.fromLTRB(
      double.infinity,
      double.infinity,
      -double.infinity,
      -double.infinity,
    ),
    Rect outerBoundRect = Rect.largest,
    double maxScaleX,
    double minScaleX,
    double maxScaleY,
    double minScaleY,
  }) {
    initialTransform ??= Transformation();

    maxSize ??= outerBoundRect.size;
    minSize ??= innerBoundRect.size;

    maxScaleX ??= maxSize.width / initialSize.width;
    minScaleX ??= minSize.width / initialSize.width;
    maxScaleY ??= maxSize.height / initialSize.height;
    minScaleY ??= minSize.height / initialSize.height;

    return TransformConfig._(
      initialSize: initialSize,
      initialTransform: initialTransform,
      innerBoundRect: innerBoundRect,
      outerBoundRect: outerBoundRect,
      maxScaleX: maxScaleX,
      minScaleX: minScaleX,
      maxScaleY: maxScaleY,
      minScaleY: minScaleY,
      maxSize: maxSize,
      minSize: minSize,
    );
  }

  TransformConfig._({
    this.initialSize,
    this.initialTransform,
    this.innerBoundRect,
    this.outerBoundRect,
    this.maxScaleX,
    this.minScaleX,
    this.maxScaleY,
    this.minScaleY,
    this.maxSize,
    this.minSize,
  });

  final Size initialSize;
  final Transformation initialTransform;

  final Size maxSize;
  final Size minSize;

  final double maxScaleX;
  final double minScaleX;
  final double maxScaleY;
  final double minScaleY;

  /// The area that the child must completely cover at all times.
  final Rect innerBoundRect;

  /// The area that the child must remain within at all times.
  final Rect outerBoundRect;

  @override
  String toString() {
    return '\tTransformConfig:'
        '\n\tinitialSize: $initialSize'
        '\n\tinitialTransform: $initialTransform'
        '\n\tmaxSize: $maxSize'
        '\n\tminSize: $minSize'
        '\n\tmaxScaleX: $maxScaleX'
        '\n\tminScaleX: $minScaleX'
        '\n\tmaxScaleY: $maxScaleY'
        '\n\tminScaleY: $minScaleY'
        '\n\tminSize: $minSize'
        '\n\tminSize: $minSize'
        '\n\tinnerBoundRect: $innerBoundRect'
        '\n\touterBoundRect: $outerBoundRect';
  }
}

/// Data class to hold an [Offset] and xy scale values.
class Transformation {
  Transformation({
    this.offset = Offset.zero,
    this.yScale = 1.0,
    this.xScale = 1.0,
  });

  Offset offset;
  double xScale;
  double yScale;

  double get x => offset.dx;
  double get y => offset.dy;

  Matrix4 get transform => Matrix4.identity()
    ..translate(offset.dx, offset.dy)
    ..scale(xScale, yScale);

  @override
  String toString() =>
      'TransformInfo: $offset, x scale: $xScale, y scale: $yScale';

  /// Returns a deep copy of [this].
  Transformation clone() => Transformation(
        offset: offset == null ? null : Offset(offset.dx, offset.dy),
        xScale: xScale,
        yScale: yScale,
      );
}

/// Maintains offset and scale, and updates listeners when those values change.
class TransformController extends ValueNotifier<Transformation> {
  static final _minFlingVelocity = 400.0;

  // This factory constructor acts like a normal constructor to its users,
  // its only purpose is to create a singly copy of the initial transformation
  // that can be given to both the super constructor and the final field.
  factory TransformController({
    TransformConfig config,
    GestureDragEndCallback dragEndCallback,
    GestureDragStartCallback dragStartCallback,
    GestureDragUpdateCallback dragUpdateCallback,
    GestureScaleEndCallback scaleEndCallback,
    GestureScaleStartCallback scaleStartCallback,
    GestureScaleUpdateCallback scaleUpdateCallback,
    GestureDoubleTapCallback doubleTapCallback,
    GestureTapUpCallback tapUpCallback,
  }) {
    final Transformation transformation = config.initialTransform?.clone();
    return TransformController._(
      config: config,
      transform: transformation,
      dragEndCallback: dragEndCallback,
      dragStartCallback: dragStartCallback,
      dragUpdateCallback: dragUpdateCallback,
      scaleEndCallback: scaleEndCallback,
      scaleStartCallback: scaleStartCallback,
      scaleUpdateCallback: scaleUpdateCallback,
      doubleTapCallback: doubleTapCallback,
      tapUpCallback: tapUpCallback,
    );
  }

  TransformController._({
    this.config,
    this.transform,
    this.viewportSize,
    GestureScaleEndCallback scaleEndCallback,
    GestureScaleStartCallback scaleStartCallback,
    GestureScaleUpdateCallback scaleUpdateCallback,
    GestureDragEndCallback dragEndCallback,
    GestureDragStartCallback dragStartCallback,
    GestureDragUpdateCallback dragUpdateCallback,
    GestureDoubleTapCallback doubleTapCallback,
    GestureTapUpCallback tapUpCallback,
  })  : _dragEndCallback = dragEndCallback,
        _dragStartCallback = dragStartCallback,
        _dragUpdateCallback = dragUpdateCallback,
        _scaleEndCallback = scaleEndCallback,
        _scaleStartCallback = scaleStartCallback,
        _scaleUpdateCallback = scaleUpdateCallback,
        _doubleTapCallback = doubleTapCallback,
        _tapUpCallback = tapUpCallback,
        super(transform);

  final Transformation transform;
  final TransformConfig config;

  final GestureDragEndCallback _dragEndCallback;
  final GestureDragStartCallback _dragStartCallback;
  final GestureDragUpdateCallback _dragUpdateCallback;
  final GestureScaleEndCallback _scaleEndCallback;
  final GestureScaleStartCallback _scaleStartCallback;
  final GestureScaleUpdateCallback _scaleUpdateCallback;
  final GestureDoubleTapCallback _doubleTapCallback;
  final GestureTapUpCallback _tapUpCallback;

  Size viewportSize;

  /// The controller which drives the fling animation.
  ///
  /// This field isn't final because it needs a [TickerProvider] for the vsync
  /// argument, and the ticker comes from some stateful widget.
  AnimationController _animationController;
  Animation<Offset> _flingAnimation;

  set animationController(AnimationController animationController) {
    _animationController?.dispose();
    _animationController = animationController;
    _animationController..addListener(_updateOffsetAfterFling);
  }

  // Internal values used to keep the most recent calculated min and max
  // offsets. This is useful because those offsets may need to be referenced
  // several times each time they change, but only need to be calculated once.
  Size _lastInputToMaxOffset;
  Size _lastInputToMinOffset;
  Offset _cachedMaxOffset;
  Offset _cachedMinOffset;

  Offset _prevFocalPoint;
  Offset _touchStartNormOffset;
  double _touchStartScaleX;
  double _touchStartScaleY;

  /// The child's current visible size (includes scale).
  Size get size => Size(
        transform.xScale * config.initialSize.width,
        transform.yScale * config.initialSize.height,
      );

  /// Returns the maximum allowed offset of a child with the given [size],
  /// considering the constraint information of [this].
  Offset get maxOffset {
    if (size == _lastInputToMaxOffset) return _cachedMaxOffset;
    _lastInputToMaxOffset = size;

    double xMax = min(
      config.outerBoundRect.right - size.width,
      config.innerBoundRect.left,
    );
    double yMax = min(
      config.outerBoundRect.bottom - size.height,
      config.innerBoundRect.top,
    );

    final maxOffset = Offset(xMax, yMax);
    _cachedMaxOffset = maxOffset;
    return maxOffset;
  }

  /// Returns the minimum allowed offset of a child with the given [size],
  /// considering the constraint information of [this].
  Offset get minOffset {
    if (size == _lastInputToMinOffset) return _cachedMinOffset;
    _lastInputToMinOffset = size;

    double xMin = max(
      config.innerBoundRect.right - size.width,
      config.outerBoundRect.left,
    );
    double yMin = max(
      config.innerBoundRect.bottom - size.height,
      config.outerBoundRect.top,
    );

    final minOffset = Offset(xMin, yMin);
    _cachedMinOffset = minOffset;
    return minOffset;
  }

  Offset clampOffset(Offset offset) {
    return Offset(
      min(maxOffset.dx, max(offset.dx, minOffset.dx)),
      min(maxOffset.dy, max(offset.dy, minOffset.dy)),
    );
  }

  void handleScaleStart(ScaleStartDetails details) {
    _scaleStartCallback?.call(details);
    _dragStartCallback?.call(DragStartDetails(
      globalPosition: details.focalPoint,
      localPosition: details.localFocalPoint,
    ));
    final focalOffset = details.localFocalPoint - transform.offset;

    _touchStartNormOffset = Offset(
      focalOffset.dx / transform.xScale,
      focalOffset.dy / transform.yScale,
    );

    _prevFocalPoint = details.localFocalPoint;
    _touchStartScaleX = transform.xScale;
    _touchStartScaleY = transform.yScale;
  }

  /// Handle an update to a pan or scale geture.
  ///
  /// Handles all gesture updates (since pan is a subset of scale
  /// this handler catches both panning and scaling).
  void handleScaleUpdate(ScaleUpdateDetails details) {
    _scaleUpdateCallback?.call(details);
    // A scale of 1.0 indicates no scale change, so the gesture is a pan.
    if (details.scale == 1.0) {
      _dragUpdateCallback?.call(DragUpdateDetails(
        globalPosition: details.focalPoint,
        localPosition: details.localFocalPoint,
      ));

      final offsetWithDiff =
          transform.offset - (_prevFocalPoint - details.localFocalPoint);
      transform.offset = clampOffset(offsetWithDiff);
    } else {
      final desiredScaleX = _touchStartScaleX * details.horizontalScale;
      final desiredScaleY = _touchStartScaleY * details.verticalScale;

      _zoomTo(
        normStartOffset: _touchStartNormOffset,
        zoomTo: details.localFocalPoint,
        newZoomX: desiredScaleX,
        newZoomY: desiredScaleY,
      );
    }

    notifyListeners();
    _prevFocalPoint = details.localFocalPoint;
  }

  /// Check if a fling occured, and if so call [_handleFling].
  void handleScaleEnd(ScaleEndDetails details) {
    _scaleEndCallback?.call(details);
    _dragEndCallback?.call(DragEndDetails());
    // Check to see if the gesture ended with a fling.
    final double magnitude = details.velocity.pixelsPerSecond.distance;
    if (magnitude < _minFlingVelocity) return;

    _handleFling(magnitude, details.velocity.pixelsPerSecond);
  }

  void handleTapUp(TapUpDetails details) {
    _tapUpCallback?.call(details);
  }

  void handleDoubleTap() {
    _doubleTapCallback?.call();
  }

  void _updateOffsetAfterFling() {
    transform.offset = _flingAnimation.value;
    notifyListeners();
  }

  /// Zooms in to the center of the viewport.
  ///
  /// The zoom change can be specified in percentage (0-100) or absolute terms.
  void zoomIn(
      {double xPercent, double yPercent, double xAbsolute, double yAbsolute}) {
    // todo: This could take a callback to start some simple animation to indicate
    // the zoom couldn't complete (probably because the zoom was outside of the
    // min/max).
    assert(
        (xPercent != null || xAbsolute != null) ||
            (yPercent != null || yAbsolute != null),
        'The amount to zoom in must be provided, but all arguments were null.');
    assert(
        !(xPercent != null && xAbsolute != null),
        'The x-scale can only change by either a percentage or an absolute'
        'amount, but xPercent and xAbsolute were both specified.');
    assert(
        !(yPercent != null && yAbsolute != null),
        'The y-scale can only change by either a percentage or an absolute'
        'amount, but yPercent and yAbsolute were both specified.');
    zoomInToPoint(
      xScale: xPercent == null
          ? transform.xScale + xAbsolute
          : transform.xScale * (xPercent / 100 + 1),
      yScale: yPercent == null
          ? transform.yScale + yAbsolute
          : transform.yScale * (yPercent / 100 + 1),
    );
  }

  /// Zooms in or out to the desired zoom level.
  ///
  /// Zooms from the center of the viewport.
  void setZoom({double xZoom, double yZoom}) {
    zoomIn(
      xAbsolute: xZoom - transform.xScale,
      yAbsolute: yZoom - transform.yScale,
    );
  }

  /// Zooms in or out to the desired zoom level.
  ///
  /// Zooms from the center of the viewport.
  void resetZoomAndOffset() {
    transform.xScale = config.initialTransform.xScale;
    transform.yScale = config.initialTransform.yScale;
    transform.offset = config.initialTransform.offset;

    notifyListeners();
  }

  /// Zooms to the given `zoomPoint`, or the center if one isn't specified.
  void zoomInToPoint({double xScale, double yScale, Offset zoomPoint}) {
    zoomPoint ??= Offset(viewportSize.width / 2, viewportSize.height / 2);
    final offsetZoomPoint = zoomPoint - transform.offset;
    final normStartOffset = Offset(
      offsetZoomPoint.dx / transform.xScale,
      offsetZoomPoint.dy / transform.yScale,
    );

    _zoomTo(
      normStartOffset: normStartOffset,
      zoomTo: zoomPoint,
      newZoomX: xScale,
      newZoomY: yScale,
    );
  }

  void _zoomTo({
    Offset normStartOffset,
    Offset zoomTo,
    double newZoomX,
    double newZoomY,
  }) {
    transform.xScale = (newZoomX).clamp(config.minScaleX, config.maxScaleX);
    transform.yScale = (newZoomY).clamp(config.minScaleY, config.maxScaleY);

    final scaledOffset = zoomTo -
        Offset(
          normStartOffset.dx * transform.xScale,
          normStartOffset.dy * transform.yScale,
        );

    transform.offset = clampOffset(scaledOffset);

    notifyListeners();
  }

  void _handleFling(double magnitude, Offset pixelsPerSecond) {
    final Offset direction = pixelsPerSecond / magnitude;
    final double distance = viewportSize.shortestSide;
    final Offset begin = transform.offset;
    final Offset end = clampOffset(begin + direction * distance);

    _flingAnimation = _animationController.drive(Tween<Offset>(
      begin: begin,
      end: end,
    ));
    _animationController
      ..value = 0.0
      ..fling(velocity: magnitude / 1000.0);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  String toString() => 'TransformController:'
      '\n\tcurrent transform: ${transform.offset}'
      '\n\tx scale: ${transform.xScale}, y scale: ${transform.yScale}';
}

/// A delegate that repaints its child when notified of a change in the child's
/// transform.
class TransformableFlowDelegate extends FlowDelegate {
  final Size viewerSize;
  final Size childSize;
  final TransformController controller;

  TransformableFlowDelegate(
      this.viewerSize, this.childSize, TransformController controller)
      : this.controller = controller,
        super(repaint: controller);

  @override
  Size getSize(BoxConstraints constraints) => viewerSize;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      BoxConstraints.tight(childSize);

  @override
  void paintChildren(FlowPaintingContext context) {
    context.paintChild(0, transform: controller.value.transform);
  }

  /// No need to do logic here since we passed [controller] to [super],
  /// so repainting is controlled by its updates.
  @override
  bool shouldRepaint(TransformableFlowDelegate oldDelegate) => false;
}
