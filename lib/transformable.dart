import 'dart:math' show min, max;

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
    maxSize ??= outerBoundRect.size;
    minSize ??= innerBoundRect.size;

    maxScaleX = maxSize.width / initialSize.width;
    minScaleX = minSize.width / initialSize.width;
    maxScaleY = maxSize.height / initialSize.height;
    minScaleY = minSize.height / initialSize.height;

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
  factory TransformController({TransformConfig config}) {
    final Transformation transformation = config.initialTransform?.clone();
    return TransformController._(config: config, transform: transformation);
  }

  TransformController._({
    this.config,
    this.transform,
  }) : super(transform);

  final Transformation transform;
  final TransformConfig config;

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
    final focalOffset = details.focalPoint - transform.offset;

    _touchStartNormOffset = Offset(
      focalOffset.dx / transform.xScale,
      focalOffset.dy / transform.yScale,
    );

    _prevFocalPoint = details.focalPoint;
    _touchStartScaleX = transform.xScale;
    _touchStartScaleY = transform.yScale;
  }

  /// Handle an update to a pan or scale geture.
  ///
  /// Handles all gesture updates (since pan is a subset of scale
  /// this handler catches both panning and scaling).
  void handleScaleUpdate(ScaleUpdateDetails details) {
    // A scale of 1.0 indicates no scale change, so the gesture is a pan.
    if (details.scale == 1.0) {
      final offsetWithDiff =
          transform.offset - (_prevFocalPoint - details.focalPoint);
      transform.offset = clampOffset(offsetWithDiff);
    } else {
      transform.xScale = (_touchStartScaleX * details.horizontalScale)
          .clamp(config.minScaleX, config.maxScaleX);
      transform.yScale = (_touchStartScaleY * details.verticalScale)
          .clamp(config.minScaleY, config.maxScaleY);

      final scaledOffset = Offset(
        _touchStartNormOffset.dx * transform.xScale,
        _touchStartNormOffset.dy * transform.yScale,
      );
      final focalPointMinusOffset = details.focalPoint - scaledOffset;
      transform.offset = clampOffset(focalPointMinusOffset);
    }

    notifyListeners();
    _prevFocalPoint = details.focalPoint;
  }

  /// Check if a fling occured, and if so call [_handleFling].
  void handleScaleEnd(ScaleEndDetails details) {
    // Check to see if the gesture ended with a fling.
    final double magnitude = details.velocity.pixelsPerSecond.distance;
    if (magnitude < _minFlingVelocity) return;

    _handleFling(magnitude, details.velocity.pixelsPerSecond);
  }

  void _updateOffsetAfterFling() {
    transform.offset = _flingAnimation.value;
    notifyListeners();
  }

  void _handleFling(double magnitude, Offset pixelsPerSecond) {
    final Offset direction = pixelsPerSecond / magnitude;

    // todo: double check the value of this field.
    final double distance = config.outerBoundRect.shortestSide;
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
