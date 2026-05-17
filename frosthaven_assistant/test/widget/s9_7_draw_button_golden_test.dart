import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/draw_button.dart';
import 'package:frosthaven_assistant/Layout/theme.dart';
import 'package:frosthaven_assistant/Resource/commands/add_character_command.dart';
import 'package:frosthaven_assistant/Resource/commands/draw_command.dart';
import 'package:frosthaven_assistant/Resource/commands/set_init_command.dart';
import 'package:frosthaven_assistant/Resource/enums.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../command/test_helpers.dart';

// Register the Pirata font (used by `theme.dart` for button text) so the
// golden renders glyphs instead of missing-glyph boxes.
Future<void> _loadAppFonts() async {
  final loader = FontLoader('Pirata');
  loader.addFont(
    File('assets/fonts/PirataOne-Gloomhaven.ttf').readAsBytes().then(
          (bytes) => ByteData.view(bytes.buffer),
        ),
  );
  await loader.load();
}

// Manual §9.7 figure: DrawButton mid-lockout (synchronizing pause).
//
// This file is intentionally standalone — it does not share infrastructure
// with manual_goldens_test.dart, which has compile errors against the
// claude_refactor API on this branch (see comment header in that file).
//
// Regenerate:  flutter test --update-goldens test/widget/s9_7_draw_button_golden_test.dart
// Verify:      flutter test test/widget/s9_7_draw_button_golden_test.dart

// ignore_for_file: no-magic-number

const String _goldenDir = '../../../docs/screenshots/manual';

void main() {
  setUpAll(() async {
    await setUpGame();
    await _loadAppFonts();
  });

  setUp(() {
    final gs = getIt<GameState>();
    gs.clearList();
    while (gs.roundState.value != RoundState.chooseInitiative &&
        gs.gameSaveStates.isNotEmpty) {
      gs.undo();
    }
  });

  testWidgets('s9-7 draw button sync lockout', (WidgetTester tester) async {
    // Render the DrawButton at 4× the desktop bar scale so the button text
    // is comfortably legible at the size the manual embeds. Tight surface
    // crops to just the round-counter + button strip, which is what §9.7
    // illustrates — the morphing-button artifact.
    getIt<Settings>().userScalingBars.value = 4.0;

    await tester.binding.setSurfaceSize(const Size(420, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final gs = getIt<GameState>();
    AddCharacterCommand('Blinkblade', 'Frosthaven', null, 1).execute();
    SetInitCommand('Blinkblade', 25, gameState: gs).execute();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF1B1B1B),
          body: Center(child: DrawButton(gameState: gs)),
        ),
      ),
    );

    // Fire a roundState change to enter the sync lockout. The button
    // disables (onPressed: null) and AnimatedOpacity targets 0.5 over a
    // 120ms fade. Pump past the fade so the dimmed state is fully settled
    // but well within the 300ms lockout window.
    gs.action(DrawCommand(gameState: gs));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    await expectLater(
      find.byType(DrawButton),
      matchesGoldenFile('$_goldenDir/s9-7-draw-button-sync.png'),
    );

    // Drain the rest of the lockout timer and DrawCommand's 600ms
    // post-action scroll Future before the test ends.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 600));
    gs.undo();
  });
}
