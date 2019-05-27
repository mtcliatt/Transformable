import 'package:flutter/material.dart';

import 'src/boundpainter.dart';
import 'src/grid.dart';
import '../../transformable.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Transformable Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MyHomePage(title: 'Transformable Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static final innerRect = Rect.fromPoints(Offset(100, 100), Offset(200, 200));
  static final outerRect = Rect.fromPoints(Offset(10, 10), Offset(400, 350));
  static final childStartSize = Size(250, 250);
  static final startOffset = Offset(50, 50);
  static final viewerSize = Size(400, 350);

  static final controller = TransformController(
    config: TransformConfig(
      initialTransform: Transformation(offset: startOffset),
      initialSize: childStartSize,
      innerBoundRect: innerRect,
      outerBoundRect: outerRect,
    ),
  );

  static String shorten(dynamic value) {
    final long = '$value';
    return long.substring(0, (long.length > 5 ? 5 : long.length));
  }

  final transformable = Transformable(
    child: Grid(),
    viewerSize: viewerSize,
    controller: controller,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ValueListenableBuilder<Transformation>(
        valueListenable: transformable.controller,
        builder: (context, Transformation transform, child) {
          return Column(
            children: <Widget>[
              Container(
                height: viewerSize.height,
                width: viewerSize.width,
                child: Stack(
                  children: [
                    transformable,
                    BoundPaint(
                      innerRect: innerRect,
                      outerRect: outerRect,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          _buildSliderRow(
                            'x: ${shorten(transform.x)}',
                            transform.x,
                            controller.minOffset.dx,
                            controller.maxOffset.dx,
                          ),
                          _buildSliderRow(
                            'y: ${shorten(transform.y)}',
                            transform.y,
                            controller.minOffset.dy,
                            controller.maxOffset.dy,
                          ),
                          _buildSliderRow(
                            'x scale: ${shorten(transform.scale.x)}',
                            transform.scale.x,
                            controller.config.minScale.x,
                            controller.config.maxScale.x,
                          ),
                          _buildSliderRow(
                            'y scale: ${shorten(transform.scale.y)}',
                            transform.scale.y,
                            controller.config.minScale.y,
                            controller.config.maxScale.y,
                          ),
                          _buildSliderRow(
                            'width: ${shorten(controller.size.width)}',
                            controller.size.width,
                            controller.config.minSize.width,
                            controller.config.maxSize.width,
                          ),
                          _buildSliderRow(
                            'height: ${shorten(controller.size.height)}',
                            controller.size.height,
                            controller.config.minSize.height,
                            controller.config.maxSize.height,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliderRow(String text, double value, double min, double max) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            children: <Widget>[
              Text(text),
            ],
          ),
        ),
        Flexible(
          flex: 2,
          child: Column(
            children: <Widget>[
              Slider(
                value: value,
                min: min,
                max: max,
                onChanged: null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
