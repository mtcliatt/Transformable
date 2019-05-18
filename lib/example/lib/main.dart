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
  final innerRect = Rect.fromPoints(Offset(150, 150), Offset(250, 250));
  final outerRect = Rect.fromPoints(Offset(20, 20), Offset(380, 450));
  final viewerSize = Size(400, 650);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          Transformable(
            child: Grid(),
            viewerSize: viewerSize,
            size: Size(100, 100),
            startSize: Size(200, 200),
            startOffset: Offset(100, 100),
            minXScale: .1,
            minYScale: .1,
            outerBoundRect: outerRect,
            innerBoundRect: innerRect,
          ),
          BoundPaint(
            innerRect: innerRect,
            outerRect: outerRect,
          ),
        ],
      ),
    );
  }
}
