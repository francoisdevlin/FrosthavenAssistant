import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/bottom_bar.dart';
import 'package:frosthaven_assistant/Layout/element_button.dart';
import 'package:frosthaven_assistant/Layout/main_list.dart';
import 'package:frosthaven_assistant/Layout/menus/add_character_menu.dart';
import 'package:frosthaven_assistant/Layout/menus/add_monster_menu.dart';
import 'package:frosthaven_assistant/Layout/menus/main_menu.dart';
import 'package:frosthaven_assistant/Layout/menus/numpad_menu.dart';
import 'package:frosthaven_assistant/Layout/menus/select_scenario_menu.dart';
import 'package:frosthaven_assistant/Layout/theme.dart';
import 'package:frosthaven_assistant/Layout/top_bar.dart';
import 'package:frosthaven_assistant/Resource/commands/add_character_command.dart';
import 'package:frosthaven_assistant/Resource/commands/add_monster_command.dart';
import 'package:frosthaven_assistant/Resource/commands/add_standee_command.dart';
import 'package:frosthaven_assistant/Resource/enums.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../command/test_helpers.dart';

// Manual screenshot generator. Outputs goldens to docs/screenshots/manual/
// for reference from docs/manual.html. Test names encode the manual section
// each image illustrates (e.g. s3-2 = §3.2).
//
// Regenerate:  flutter test --update-goldens test/widget/manual_goldens_test.dart
// Verify:      flutter test test/widget/manual_goldens_test.dart
//
// Branch context: this copy targets upstream/main (no `gameState:` named-arg
// API on the Add* commands). The companion `manual-draft` branch off
// upstream/claude_refactor uses the same test logic with `gameState: gs`
// added to each Add* call. The PNG goldens themselves are byte-identical
// when generated from either branch — verified 2026-05-03 with side-by-side
// worktrees, all 11 goldens `cmp` clean. The maintainer can run this exact
// test suite against the claude_refactor branch (after applying the small
// API patch above) as a regression check that the refactor preserves
// rendered widget output.

// ignore_for_file: no-magic-number

const String _goldenDir = '../../../docs/screenshots/manual';

Finder _elementButton(Elements e) =>
    find.byWidgetPredicate((w) => w is ElementButton && w.element == e);

Future<void> _precacheAllImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = (element.widget as Image).image;
      await precacheImage(image, element);
    }
    for (final element in find.byType(DecoratedBox).evaluate()) {
      final decoration = (element.widget as DecoratedBox).decoration;
      if (decoration is BoxDecoration && decoration.image != null) {
        await precacheImage(decoration.image!.image, element);
      }
    }
  });
  await tester.pumpAndSettle();
}

Future<void> _pumpInScaffold(WidgetTester tester, Widget body,
    {PreferredSizeWidget? appBar, Widget? bottomBar, Widget? drawer}) async {
  final originalOnError = FlutterError.onError;
  FlutterError.onError = ignoreOverflowErrors;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        appBar: appBar,
        drawer: drawer,
        bottomNavigationBar: bottomBar,
        body: body,
      ),
    ),
  );
  await _precacheAllImages(tester);
  FlutterError.onError = originalOnError;
}

// Register the custom fonts declared in pubspec.yaml so goldens render
// title text and other glyphs faithfully instead of missing-glyph boxes.
Future<void> _loadAppFonts() async {
  const fontsDir = 'assets/fonts';
  final families = <String, List<String>>{
    'Majalla': ['$fontsDir/majallab.ttf'],
    'Pirata': ['$fontsDir/PirataOne-Gloomhaven.ttf'],
    'GermaniaOne': ['$fontsDir/GermaniaOne-Regular.ttf'],
    'Markazi': ['$fontsDir/MarkaziText-VariableFont_wght.ttf'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(File(path).readAsBytes().then(
            (bytes) => ByteData.view(bytes.buffer),
          ));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(() async {
    await setUpGame();
    await _loadAppFonts();
  });

  setUp(() {
    getIt<GameState>().clearList();
  });

  group('Manual screenshots', () {
    // ── §3.2 Top bar — elements ──────────────────────────────────────────

    testWidgets('s3-2 top bar all inert', (tester) async {
      await _pumpInScaffold(
        tester,
        const SizedBox(),
        appBar: const PreferredSize(
            preferredSize: Size.fromHeight(56), child: TopBar()),
      );
      await expectLater(
        find.byType(TopBar),
        matchesGoldenFile('$_goldenDir/s3-2-top-bar-inert.png'),
      );
    });

    testWidgets('s3-2 top bar fire full', (tester) async {
      final gs = getIt<GameState>();
      await _pumpInScaffold(
        tester,
        const SizedBox(),
        appBar: const PreferredSize(
            preferredSize: Size.fromHeight(56), child: TopBar()),
      );
      await tester.tap(_elementButton(Elements.fire));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(TopBar),
        matchesGoldenFile('$_goldenDir/s3-2-top-bar-fire-full.png'),
      );
      gs.undo();
    });

    testWidgets('s3-2 top bar fire waning', (tester) async {
      final gs = getIt<GameState>();
      await _pumpInScaffold(
        tester,
        const SizedBox(),
        appBar: const PreferredSize(
            preferredSize: Size.fromHeight(56), child: TopBar()),
      );
      await tester.longPress(_elementButton(Elements.fire));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(TopBar),
        matchesGoldenFile('$_goldenDir/s3-2-top-bar-fire-half.png'),
      );
      gs.undo();
    });

    // ── §3.3 Main list — initiative and figures ──────────────────────────

    testWidgets('s3-3 main list empty', (tester) async {
      await _pumpInScaffold(tester, const MainList());
      await expectLater(
        find.byType(MainList),
        matchesGoldenFile('$_goldenDir/s3-3-main-list-empty.png'),
      );
    });

    testWidgets('s3-3 main list populated', (tester) async {
      // Two characters + one monster type with normal + elite standees.
      // Entities chosen to match what's available in test data
      // (assets/testData/editions/): Blinkblade, Banner Spear (Frosthaven),
      // Zealot (Jaws of the Lion).
      // Commands use positional args only (no gameState named param) so the
      // test compiles on both upstream/main and upstream/claude_refactor.
      AddCharacterCommand('Blinkblade', 'Frosthaven', null, 3).execute();
      AddCharacterCommand('Banner Spear', 'Frosthaven', null, 3).execute();
      AddMonsterCommand('Zealot', 2, false).execute();
      AddStandeeCommand(1, null, 'Zealot', MonsterType.normal, false).execute();
      AddStandeeCommand(2, null, 'Zealot', MonsterType.normal, false).execute();
      AddStandeeCommand(3, null, 'Zealot', MonsterType.elite, false).execute();
      await _pumpInScaffold(tester, const MainList());
      await expectLater(
        find.byType(MainList),
        matchesGoldenFile('$_goldenDir/s3-3-main-list-populated.png'),
      );
    });

    // ── §3.4 Bottom bar — round, scenario, draw, AMD ─────────────────────

    testWidgets('s3-4 bottom bar default', (tester) async {
      await _pumpInScaffold(
        tester,
        const SizedBox(),
        bottomBar: const BottomBar(),
      );
      // NetworkUI schedules a 200ms Future.delayed on every build; let it drain
      // before the test ends so the framework's pending-timer guard is happy.
      await tester.pump(const Duration(milliseconds: 250));
      await expectLater(
        find.byType(BottomBar),
        matchesGoldenFile('$_goldenDir/s3-4-bottom-bar-default.png'),
      );
    });

    // ── §3.5 Sidebar drawer ──────────────────────────────────────────────

    testWidgets('s3-5 main menu drawer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: SizedBox(width: 304, child: MainMenu()),
          ),
        ),
      );
      await _precacheAllImages(tester);
      await expectLater(
        find.byType(MainMenu),
        matchesGoldenFile('$_goldenDir/s3-5-main-menu.png'),
      );
    });

    // ── §4.1 Add Character menu ──────────────────────────────────────────

    testWidgets('s4-1 add character menu', (tester) async {
      await _pumpInScaffold(tester, const AddCharacterMenu());
      await expectLater(
        find.byType(AddCharacterMenu),
        matchesGoldenFile('$_goldenDir/s4-1-add-character-menu.png'),
      );
    });

    // ── §4.2 Set Scenario menu ───────────────────────────────────────────

    testWidgets('s4-2 select scenario menu', (tester) async {
      await _pumpInScaffold(tester, const SelectScenarioMenu());
      await expectLater(
        find.byType(SelectScenarioMenu),
        matchesGoldenFile('$_goldenDir/s4-2-select-scenario-menu.png'),
      );
    });

    // ── §4.3 Add Monsters menu ───────────────────────────────────────────

    testWidgets('s4-3 add monster menu', (tester) async {
      await _pumpInScaffold(tester, const AddMonsterMenu());
      await expectLater(
        find.byType(AddMonsterMenu),
        matchesGoldenFile('$_goldenDir/s4-3-add-monster-menu.png'),
      );
    });

    // ── §5.3 Initiative numpad ───────────────────────────────────────────

    testWidgets('s5-3 numpad menu', (tester) async {
      final controller = TextEditingController();
      await _pumpInScaffold(
        tester,
        Center(child: NumpadMenu(controller: controller, maxLength: 2)),
      );
      await expectLater(
        find.byType(NumpadMenu),
        matchesGoldenFile('$_goldenDir/s5-3-numpad-menu.png'),
      );
    });
  });
}
