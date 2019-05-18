

# Transformable

[![Pub](https://img.shields.io/pub/v/transformable.svg)](https://pub.dartlang.org/packages/transformable)

A 2D Scrollable and Scalable Flutter Widget.

## Example

<p align="center">
<img width="400" height="800" src="lib/example/screenshots/example.gif">
</p>

This example app is included in the package (`/lib/example/lib/main.dart`).

The following example restricts the child's size to be at least half of the view size, and at most the entire view size. It also keeps the child positioned over the middle half of the view.

```
LayoutBuilder(
  builder: (context, constraints) => Transformable(
        child: Grid(),
        viewerSize: viewerSize,
        size: Size(100, 100),
        startSize: Size(200, 200),
        startOffset: Offset(100, 100),
        innerBoundRect: Rect.fromLTWH(
          constraints.biggest.width / 4,
          constraints.biggest.height / 4,
          constraints.biggest.width / 2,
          constraints.biggest.height / 2,
        ),
        outerBoundRect: Rect.fromPoints(
            Offset.zero, constraints.biggest.bottomRight(Offset.zero)),
      ),
);
```


### Usage

Wrap your desired widget in the Transformable widget, and specify the size of the child and the size of the view. To use the maximum available view, wrap this in a LayoutBuilder and use constraints.biggest as the size.

```
Transformable(
  child: Grid(),
  size: Size(100, 100)
);
```

Restrict the allowed area that the child can be moved to by specifying an inner and/or outer boundary rectangle.
The inner rectangle is useful in situations like a photo viewer, where you want to make sure the child fills the a given area at all times.
The outer rectangle is useful anytime you want to keep the child within a given area.

### Details

The `outerBoundRect` restricts the child's size to the size of the view, and restricts the child's position such that no part of the child can be out of the view. The `innerBoundRect` restricts the child's size to at least the size of the `innerBoundRect`, and restricts the child's position such that the child will completely cover `innerBoundRect` at all times.

          
