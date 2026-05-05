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
import 'package:frosthaven_assistant/Layout/menus/add_section_menu.dart';
import 'package:frosthaven_assistant/Layout/menus/numpad_menu.dart';
import 'package:frosthaven_assistant/Layout/menus/select_scenario_menu.dart';
import 'package:frosthaven_assistant/Layout/menus/set_level_menu.dart';
import 'package:frosthaven_assistant/Layout/theme.dart';
import 'package:frosthaven_assistant/Layout/top_bar.dart';
import 'package:frosthaven_assistant/Resource/commands/add_character_command.dart';
import 'package:frosthaven_assistant/Resource/commands/add_monster_command.dart';
import 'package:frosthaven_assistant/Resource/commands/add_standee_command.dart';
import 'package:frosthaven_assistant/Resource/commands/set_campaign_command.dart';
import 'package:frosthaven_assistant/Resource/commands/set_scenario_command.dart';
import 'package:frosthaven_assistant/Resource/enums.dart';
import 'package:frosthaven_assistant/Resource/game_data.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    {PreferredSizeWidget? appBar,
    Widget? bottomBar,
    Widget? drawer,
    Size? surfaceSize}) async {
  if (surfaceSize != null) {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  final originalOnError = FlutterError.onError;
  FlutterError.onError = ignoreOverflowErrors;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      debugShowCheckedModeBanner: false,
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
// Also explicitly registers MaterialIcons (the hamburger ≡ etc.) — without
// this the Icon widgets render as empty boxes in the test environment.
Future<void> _loadAppFonts() async {
  const fontsDir = 'assets/fonts';
  final appFamilies = <String, List<String>>{
    'Majalla': ['$fontsDir/majallab.ttf'],
    'Pirata': ['$fontsDir/PirataOne-Gloomhaven.ttf'],
    'GermaniaOne': ['$fontsDir/GermaniaOne-Regular.ttf'],
    'Markazi': ['$fontsDir/MarkaziText-VariableFont_wght.ttf'],
  };
  for (final entry in appFamilies.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(File(path).readAsBytes().then(
            (bytes) => ByteData.view(bytes.buffer),
          ));
    }
    await loader.load();
  }

  // Material Icons — Flutter ships this with the SDK. FLUTTER_ROOT is set
  // by the test runner; fall back to common install paths.
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      '${Platform.environment['HOME']}/development/flutter';
  final materialIconsPath =
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  if (File(materialIconsPath).existsSync()) {
    final loader = FontLoader('MaterialIcons');
    loader.addFont(File(materialIconsPath).readAsBytes().then(
          (bytes) => ByteData.view(bytes.buffer),
        ));
    await loader.load();
  }
}

/// Like setUpGame but loads production data (assets/) instead of testData.
/// Needed so the manual's anchor edition Gloomhaven is reachable —
/// Brute, Bandit Guard, Bandit Archer aren't present in testData.
/// GameData.editions is `late final` so we can't call loadData twice;
/// this replaces the setUpGame call entirely.
Future<void> _setUpGameWithFullData() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  setupGetIt();
  final gs = getIt<GameState>();
  gs.init();
  await getIt<GameData>().loadData('assets/data/');
  await gs.load();
}

/// Sets up the Black Barrow roster used by §2 Quick Start and §3 anatomy
/// goldens. Brute is the manual's anchor character; Spellweaver is added
/// when `withSpellweaver` so §2.7 can demonstrate element management
/// (Spellweaver casts a fire ability, fire becomes infused).
void _setupBlackBarrow({bool withSpellweaver = false}) {
  AddCharacterCommand('Brute', 'Gloomhaven', null, 1).execute();
  if (withSpellweaver) {
    AddCharacterCommand('Spellweaver', 'Gloomhaven', null, 1).execute();
  }
  AddMonsterCommand('Bandit Guard', 1, false).execute();
  AddStandeeCommand(1, null, 'Bandit Guard', MonsterType.normal, false)
      .execute();
  AddStandeeCommand(2, null, 'Bandit Guard', MonsterType.elite, false)
      .execute();
  AddMonsterCommand('Bandit Archer', 1, false).execute();
  AddStandeeCommand(3, null, 'Bandit Archer', MonsterType.normal, false)
      .execute();
}

/// Pumps the full app shell (TopBar + BottomBar + MainMenu drawer + MainList)
/// in a layout that mirrors the live app. Used for §2 full-screen goldens
/// where the manual needs to show the actual app, not isolated widgets.
///
/// Surface size is widened to 800×900 so the §2 Black Barrow roster
/// (Spellweaver + Brute + Bandit Guard + Bandit Archer rows) fits without
/// clipping the trailing figure at the bottom of the viewport.
Future<void> _pumpFullApp(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final originalOnError = FlutterError.onError;
  FlutterError.onError = ignoreOverflowErrors;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: const Scaffold(
        appBar: PreferredSize(
            preferredSize: Size.fromHeight(56), child: TopBar()),
        bottomNavigationBar: BottomBar(),
        drawer: MainMenu(),
        body: MainList(),
      ),
    ),
  );
  // Drain NetworkUI's 200ms Future.delayed before capturing.
  await tester.pump(const Duration(milliseconds: 250));
  await _precacheAllImages(tester);
  FlutterError.onError = originalOnError;
}

void main() {
  setUpAll(() async {
    await _setUpGameWithFullData();
    await _loadAppFonts();
  });

  setUp(() {
    getIt<GameState>().clearList();
  });

  group('Manual screenshots', () {
    // ── §2.1 Quick Start — fresh app at launch ───────────────────────────

    testWidgets('s2-1 fresh app', (tester) async {
      await _pumpFullApp(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('$_goldenDir/s2-1-fresh-app.png'),
      );
    });

    // ── §2.3 Quick Start — scenario active, party assembled ──────────────

    testWidgets('s2-3 scenario active', (tester) async {
      _setupBlackBarrow(withSpellweaver: true);
      await _pumpFullApp(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('$_goldenDir/s2-3-scenario-active.png'),
      );
    });

    // ── §2.7 Quick Start — fire infused after Spellweaver casts ──────────

    testWidgets('s2-7 elements after cast', (tester) async {
      final gs = getIt<GameState>();
      _setupBlackBarrow(withSpellweaver: true);
      await _pumpFullApp(tester);
      await tester.tap(_elementButton(Elements.fire));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('$_goldenDir/s2-7-elements-after-cast.png'),
      );
      gs.undo();
    });

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
      _setupBlackBarrow(withSpellweaver: true);
      // Wider surface so the four-row roster (Spellweaver, Brute, Bandit
      // Guard, Bandit Archer) fits without crushing portraits at small scale.
      await _pumpInScaffold(tester, const MainList(),
          surfaceSize: const Size(800, 900));
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
      // Populate body with the Black Barrow roster so the scrim has
      // something behind it to dim, matching what users see in the live app.
      _setupBlackBarrow(withSpellweaver: true);

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          home: const Scaffold(
            drawer: MainMenu(),
            body: MainList(),
          ),
        ),
      );
      // Open the drawer first so the DrawerHeader's icon.png is mounted
      // and reachable by the precache pass; Scaffold draws a scrim over the
      // body automatically — that's the dim-overlay effect from the live app.
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();
      await _precacheAllImages(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('$_goldenDir/s3-5-main-menu.png'),
      );
    });

    // ── §4.1 Add Character menu ──────────────────────────────────────────

    testWidgets('s4-1 add character menu', (tester) async {
      // Render Add Character as the live app shows it: the menu opened as
      // a centered modal over the populated main scaffold, with the rest
      // of the app dimmed behind a scrim. We compose this manually with a
      // Stack rather than calling showDialog — showDialog leaves a pending
      // Future that the test framework treats as a failure when the test
      // ends without the dialog being dismissed.
      _setupBlackBarrow(withSpellweaver: true);
      // Switch to Gloomhaven so the menu surfaces Brute / Spellweaver /
      // Tinkerer first, matching the manual's anchor and the §4.1 narrative.
      getIt<GameState>().action(SetCampaignCommand('Gloomhaven'));
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            appBar: const PreferredSize(
                preferredSize: Size.fromHeight(56), child: TopBar()),
            bottomNavigationBar: const BottomBar(),
            body: Stack(
              children: const [
                MainList(),
                // Scrim — heavier than Material's default 0x80 to match the
                // live-app reference (background is strongly desaturated).
                Positioned.fill(child: ColoredBox(color: Color(0xB0000000))),
                // Centered dialog with elevation/shadow + a fixed reading
                // width that mirrors the live app's modal proportions.
                Center(
                  child: Material(
                    elevation: 24,
                    color: Colors.white,
                    child: SizedBox(width: 400, child: AddCharacterMenu()),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      // Drain NetworkUI's 200ms Future.delayed before capture.
      await tester.pump(const Duration(milliseconds: 250));
      await _precacheAllImages(tester);
      // Connectivity_plus's platform stream fires a MissingPluginException
      // in the test environment (no native impl). Other tests where it
      // surfaces don't fail because the exception arrives after expectLater
      // resolves. Here the longer setup gives it time to land before
      // capture, so consume it explicitly.
      tester.takeException();
      await expectLater(
        find.byType(MaterialApp),
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

    // ── §4.4 Add Section menu ────────────────────────────────────────────
    //
    // Anchor scenario chosen for illustrative section content: Gloomhaven 2E
    // #19 Military Outpost has three named, non-spawn sections — enough to
    // populate the menu meaningfully without overflowing the capture. Most
    // GH 1E scenarios (including Black Barrow, the §2/§3 anchor) carry no
    // sections, so the manual switches anchor here.

    testWidgets('s4-4 add section menu', (tester) async {
      final gs = getIt<GameState>();
      gs.action(SetCampaignCommand('Gloomhaven 2nd Edition'));
      gs.action(SetScenarioCommand('#19 Military Outpost', false));
      await _pumpInScaffold(tester, const AddSectionMenu());
      await expectLater(
        find.byType(AddSectionMenu),
        matchesGoldenFile('$_goldenDir/s4-4-add-section-menu.png'),
      );
    });

    // ── §4.5 Set Level / Custom difficulty menu ──────────────────────────

    testWidgets('s4-5 set level menu', (tester) async {
      await _pumpInScaffold(
        tester,
        const Center(child: SetLevelMenu()),
      );
      await expectLater(
        find.byType(SetLevelMenu),
        matchesGoldenFile('$_goldenDir/s4-5-set-level-menu.png'),
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
