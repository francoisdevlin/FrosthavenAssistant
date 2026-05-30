import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/class_icon.dart';

import '../command/test_helpers.dart';

// ignore_for_file: no-magic-number

void main() {
  Future<void> pumpIcon(WidgetTester tester, ClassIcon icon) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = ignoreOverflowErrors;
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: icon)),
    );
    FlutterError.onError = originalOnError;
  }

  group('ClassIcon (no drop shadow)', () {
    testWidgets('renders single Image when dropShadow is false',
        (WidgetTester tester) async {
      await pumpIcon(tester, const ClassIcon(name: 'Brute', size: 32));
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(ImageFiltered), findsNothing);
    });

    testWidgets('color param tints the primary Image',
        (WidgetTester tester) async {
      await pumpIcon(
        tester,
        const ClassIcon(name: 'Brute', size: 32, color: Colors.red),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.color, Colors.red);
    });

    testWidgets('null color leaves Image untinted',
        (WidgetTester tester) async {
      await pumpIcon(tester, const ClassIcon(name: 'Brute', size: 32));
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.color, isNull);
    });

    testWidgets('size param sets Image width and height',
        (WidgetTester tester) async {
      await pumpIcon(tester, const ClassIcon(name: 'Brute', size: 42));
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 42);
      expect(image.height, 42);
    });

    testWidgets('fit defaults to BoxFit.scaleDown',
        (WidgetTester tester) async {
      await pumpIcon(tester, const ClassIcon(name: 'Brute', size: 32));
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.scaleDown);
    });

    testWidgets('fit override is respected', (WidgetTester tester) async {
      await pumpIcon(
        tester,
        const ClassIcon(name: 'Brute', size: 32, fit: BoxFit.contain),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.contain);
    });
  });

  group('ClassIcon (drop shadow)', () {
    testWidgets('renders Stack with ImageFiltered when dropShadow is true',
        (WidgetTester tester) async {
      await pumpIcon(
        tester,
        const ClassIcon(
          name: 'Brute',
          size: 32,
          color: Colors.white,
          dropShadow: true,
        ),
      );
      // MaterialApp + Scaffold contribute their own Stacks; the widget's
      // own Stack is the inner one.
      expect(find.byType(Stack), findsAtLeastNWidgets(1));
      expect(find.byType(ImageFiltered), findsOneWidget);
      expect(find.byType(Transform), findsAtLeastNWidgets(1));
      // Two Image widgets: shadow (behind) + primary (on top)
      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('default shadow color is Colors.black54',
        (WidgetTester tester) async {
      await pumpIcon(
        tester,
        const ClassIcon(
          name: 'Brute',
          size: 32,
          color: Colors.white,
          dropShadow: true,
        ),
      );
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      // First Image (behind) is the shadow; second is the primary.
      expect(images.first.color, Colors.black54);
      expect(images.last.color, Colors.white);
    });

    testWidgets('shadowColor overrides Colors.black54',
        (WidgetTester tester) async {
      await pumpIcon(
        tester,
        const ClassIcon(
          name: 'Brute',
          size: 32,
          color: Colors.white,
          dropShadow: true,
          shadowColor: Colors.green,
        ),
      );
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images.first.color, Colors.green);
    });

    testWidgets('shadowOffset overrides the size-proportional offset',
        (WidgetTester tester) async {
      await pumpIcon(
        tester,
        const ClassIcon(
          name: 'Brute',
          size: 32,
          dropShadow: true,
          shadowOffset: 4.5,
        ),
      );
      final transform = tester.widget<Transform>(
        find
            .ancestor(of: find.byType(ImageFiltered), matching: find.byType(Transform))
            .first,
      );
      expect(transform.transform.getTranslation().x, 4.5);
      expect(transform.transform.getTranslation().y, 4.5);
    });

    testWidgets('shadowBlur overrides the size-proportional sigma',
        (WidgetTester tester) async {
      await pumpIcon(
        tester,
        const ClassIcon(
          name: 'Brute',
          size: 32,
          dropShadow: true,
          shadowBlur: 5.5,
        ),
      );
      final filtered = tester.widget<ImageFiltered>(find.byType(ImageFiltered));
      // ImageFilter.blur stringifies as "ImageFilter.blur(5.5, 5.5, clampToEdge)"
      // (or similar) — assert the sigmas via toString since ImageFilter is opaque.
      expect(filtered.imageFilter.toString(), contains('5.5'));
    });

    testWidgets('size-proportional offset matches _kShadowOffsetRatio',
        (WidgetTester tester) async {
      // 1/15 * 15 = 1.0 (the loot card owner-icon tuning).
      await pumpIcon(
        tester,
        const ClassIcon(
          name: 'Brute',
          size: 15,
          dropShadow: true,
        ),
      );
      final transform = tester.widget<Transform>(
        find
            .ancestor(of: find.byType(ImageFiltered), matching: find.byType(Transform))
            .first,
      );
      expect(transform.transform.getTranslation().x, closeTo(1.0, 0.001));
    });

    testWidgets(
        'dropShadow with null size and no overrides degrades to zero offset/blur',
        (WidgetTester tester) async {
      await pumpIcon(
        tester,
        const ClassIcon(name: 'Brute', dropShadow: true),
      );
      // Still renders the Stack — just with a no-op shadow.
      expect(find.byType(ImageFiltered), findsOneWidget);
      final transform = tester.widget<Transform>(
        find
            .ancestor(of: find.byType(ImageFiltered), matching: find.byType(Transform))
            .first,
      );
      expect(transform.transform.getTranslation().x, 0.0);
    });
  });
}
