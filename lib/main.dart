import 'package:flutter/material.dart';
import 'package:game/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Arial',
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
 }
// import 'package:ffi/ffi.dart';
// import 'package:flutter/material.dart';
// import 'package:game/test.dart';
// import 'dart:ffi';

// typedef HelloWorldFunc = Pointer<Utf8> Function();
// typedef HelloWorld = Pointer<Utf8> Function();

// class HelloWorldBindings {
//   HelloWorldBindings() : _lib = DynamicLibrary.open('libhello_world.dylib');
//   final DynamicLibrary _lib;
//   String helloWorld() {
//     final HelloWorld helloWorld = _lib
//         .lookup<NativeFunction<HelloWorldFunc>>('hello_world')
//         .asFunction();
//     return helloWorld().toDartString();
//   }
// }

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   runApp(const TestApp());
// }

// class LabeledDivider extends LeafRenderObjectWidget {
//   const LabeledDivider({
//     super.key,
//     required this.label,
//     this.thickness = 1.0,
//     this.color = Colors.black,
//   });
//   final String label;
//   final double thickness;
//   final Color color;
//   @override
//   RenderLabeledDivider createRenderObject(BuildContext context) {
//     return RenderLabeledDivider(
//       label: label,
//       thickness: thickness,
//       color: color,
//     );
//     // This will be completed in a later step
//   }

//   @override
//   void updateRenderObject(
//     BuildContext context,
//     RenderLabeledDivider renderObject,
//   ) {
//     renderObject
//       ..label = label
//       ..thickness = thickness
//       ..color = color;
//   }
// }

// class RenderLabeledDivider extends RenderBox {
//   String _label;
//   double _thickness;
//   Color _color;
//   late TextPainter _textPainter;

//   set label(String value) {
//     if (_label != value) {
//       _label = value;
//       markNeedsLayout();
//       markNeedsSemanticsUpdate();
//     }
//   }

//   String get label => _label;

//   set thickness(double value) {
//     if (_thickness != value) {
//       _thickness = value;
//       markNeedsLayout();
//     }
//   }

//   double get thickness => _thickness;

//   set color(Color value) {
//     if (_color != value) {
//       _color = value;
//       markNeedsPaint();
//     }
//   }

//   Color get color => _color;

//   RenderLabeledDivider({
//     required String label,
//     required double thickness,
//     required Color color,
//   }) : _label = label,
//        _thickness = thickness,
//        _color = color {
//     _textPainter = TextPainter(textDirection: TextDirection.ltr);
//   }
//   @override
//   void performLayout() {
//     _textPainter.text = TextSpan(
//       text: _label,
//       style: TextStyle(color: _color),
//     );
//     _textPainter.layout();
//     final double textHeight = _textPainter.size.height;
//     size = constraints.constrain(
//       Size(double.infinity, _thickness + textHeight),
//     );
//   }

//   @override
//   void paint(PaintingContext context, Offset offset) {
//     final Paint paint = Paint()..color = _color;
//     final double yCenter = offset.dy + size.height / 2;
//     context.canvas.drawLine(
//       offset,
//       Offset(offset.dx + size.width, yCenter),
//       paint,
//     );
//     // Draw the text
//     final double textStart =
//         offset.dx + (size.width - _textPainter.size.width) / 2;
//     _textPainter.paint(
//       context.canvas,
//       Offset(textStart, yCenter - _textPainter.size.height / 2),
//     );
//   }

//   @override
//   void describeSemanticsConfiguration(SemanticsConfiguration config) {
//     super.describeSemanticsConfiguration(config);
//     config
//       ..isSemanticBoundary = true
//       ..label = 'Divider with text: $_label'
//       ..textDirection = TextDirection.ltr; // 👈 fix
//   }

//   // Setters and getters will be added next
// }

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   @override
//   Widget build(BuildContext context) {
//     return const Placeholder();
//   }
// }
