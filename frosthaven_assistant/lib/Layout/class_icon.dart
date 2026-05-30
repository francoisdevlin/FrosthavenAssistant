import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// A unified renderer for `assets/images/class-icons/$name.png` images.
///
/// Centralizes the icon-rendering pattern that previously lived inline in
/// many widgets (loot cards, modifier deck, status menu, character widgets,
/// menus). Supports an optional soft drop-shadow for legibility against
/// arbitrary card / background art.
///
/// When `dropShadow: true`, renders a 2-layer Stack: a `Transform.translate`
/// wrapping an `ImageFiltered(ImageFilter.blur(...))` wrapping a black-tinted
/// Image, behind the primary tinted Image. The shadow offset and blur sigma
/// are proportional to `size` (≈6.67% — the tuning that survived visual
/// iteration on the loot-card owner icon).
class ClassIcon extends StatelessWidget {
  static const double defaultShadowOffsetRatio = 1.0 / 15.0;
  static const double defaultShadowBlurRatio = 1.0 / 15.0;
  static const Color _kDefaultShadowColor = Colors.black54;

  /// Asset basename, resolved as `assets/images/class-icons/$name.png`.
  /// The class-icons directory is also used for some class-affiliated
  /// condition icons — this widget doesn't care what the name represents.
  final String name;

  /// Logical-pixel size for both width and height. Null means parent-driven
  /// (e.g. inside a `Positioned` with explicit height/width).
  final double? size;

  /// Tint applied via `Image.color`. Null means raw asset colors.
  final Color? color;

  /// When true, renders a soft drop-shadow behind the tinted icon.
  final bool dropShadow;

  /// Override the default shadow tint (`Colors.black54`). Only used when
  /// `dropShadow: true`.
  final Color? shadowColor;

  /// Override the default shadow offset (proportional to `size`). When
  /// non-null, used directly in logical pixels regardless of `size`.
  /// Takes precedence over `shadowOffsetRatio` if both are supplied.
  final double? shadowOffset;

  /// Override the default shadow blur sigma. Same escape-hatch semantics
  /// as `shadowOffset`. Takes precedence over `shadowBlurRatio`.
  final double? shadowBlur;

  /// Per-instance override of the size-proportional shadow offset ratio.
  /// Defaults to `defaultShadowOffsetRatio` (≈6.67%). Ignored when
  /// `shadowOffset` is non-null.
  final double shadowOffsetRatio;

  /// Per-instance override of the size-proportional shadow blur ratio.
  /// Defaults to `defaultShadowBlurRatio` (≈6.67%). Ignored when
  /// `shadowBlur` is non-null.
  final double shadowBlurRatio;

  /// How the image is fit into its bounds. Defaults to `BoxFit.scaleDown`
  /// (matches most existing callsites).
  final BoxFit fit;

  /// Filter quality for the rendered Image. Defaults to `FilterQuality.medium`
  /// (matches existing per-card rendering).
  final FilterQuality filterQuality;

  const ClassIcon({
    super.key,
    required this.name,
    this.size,
    this.color,
    this.dropShadow = false,
    this.shadowColor,
    this.shadowOffset,
    this.shadowBlur,
    this.shadowOffsetRatio = defaultShadowOffsetRatio,
    this.shadowBlurRatio = defaultShadowBlurRatio,
    this.fit = BoxFit.scaleDown,
    this.filterQuality = FilterQuality.medium,
  });

  String get _assetPath => 'assets/images/class-icons/$name.png';

  Image _buildPrimary() => Image(
        image: AssetImage(_assetPath),
        color: color,
        fit: fit,
        filterQuality: filterQuality,
        width: size,
        height: size,
      );

  @override
  Widget build(BuildContext context) {
    final primary = _buildPrimary();

    if (!dropShadow) return primary;

    final effectiveOffset = shadowOffset ??
        (size != null ? size! * shadowOffsetRatio : 0.0);
    final effectiveBlur = shadowBlur ??
        (size != null ? size! * shadowBlurRatio : 0.0);
    final effectiveShadowColor = shadowColor ?? _kDefaultShadowColor;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Transform.translate(
          offset: Offset(effectiveOffset, effectiveOffset),
          child: ImageFiltered(
            imageFilter:
                ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
            child: Image(
              image: AssetImage(_assetPath),
              color: effectiveShadowColor,
              fit: fit,
              filterQuality: filterQuality,
              width: size,
              height: size,
            ),
          ),
        ),
        primary,
      ],
    );
  }
}
