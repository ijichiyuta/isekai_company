import 'package:flutter/material.dart';

import '../game/audio/audio_controller.dart';
import '../game/audio/chiptune.dart';

/// Retro pixel-GUI kit — hard-edged, beveled panels/buttons in the parchment &
/// wood palette. Deliberately NO smooth border-radius and NO Material ripple
/// (those read as a modern app); depth comes from a dark outline plus a light
/// top-left / dark bottom-right bevel, the classic JRPG/Kairosoft menu frame.
const kInk = Color(0xFF43301C); // near-black brown outline
const kBevelLight = Color(0xFFFFF6DC); // top-left highlight
const kBevelShadeC = Color(0xFFB08A56); // bottom-right shadow
const kPanel = Color(0xFFF3E3BE); // parchment panel face
const kPanelLo = Color(0xFFE7CF9E);
const kWood = Color(0xFFC49A63);
const kWoodLo = Color(0xFFAE8248);
const kWell = Color(0xFF7C5A32); // inset track/well fill
const kAccent = Color(0xFFE6B23F); // gold (active)
const kAccentLo = Color(0xFFCB921C);
const kInkText = Color(0xFF5A3A1E);

/// A hard-edged beveled box. [raised] = outset (panel/button face); when false
/// it's inset (a pressed key or a sunken well). Square corners by design.
class PixelBox extends StatelessWidget {
  const PixelBox({
    super.key,
    required this.child,
    this.fill,
    this.gradient,
    this.raised = true,
    this.bevel = 2.0,
    this.outline = 2.0,
    this.padding = const EdgeInsets.all(6),
  });
  final Widget child;
  final Color? fill;
  final Gradient? gradient;
  final bool raised;
  final double bevel;
  final double outline;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final tl = raised ? kBevelLight : kBevelShadeC;
    final br = raised ? kBevelShadeC : kBevelLight;
    // Establish a sane default text style from the theme. Panels are often used
    // in overlays that sit OUTSIDE a Scaffold (the invention/event/転生 dialogs),
    // where un-styled Text would otherwise inherit the framework's oversized,
    // font-less fallback (→ tofu + overflow). Harmless where a Scaffold already
    // provides one.
    final base =
        Theme.of(context).textTheme.bodyMedium ??
        const TextStyle(fontSize: 14, color: kInkText);
    return ColoredBox(
      color: kInk,
      child: Padding(
        padding: EdgeInsets.all(outline),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: gradient == null ? (fill ?? kPanel) : null,
            gradient: gradient,
            border: Border(
              top: BorderSide(color: tl, width: bevel),
              left: BorderSide(color: tl, width: bevel),
              right: BorderSide(color: br, width: bevel),
              bottom: BorderSide(color: br, width: bevel),
            ),
          ),
          child: Padding(
            padding: padding,
            child: DefaultTextStyle(style: base, child: child),
          ),
        ),
      ),
    );
  }
}

/// A tactile pixel button: the bevel inverts and the face drops 1px on press
/// (no ripple — that's the modern-app tell). Disabled dims to 45%.
class PixelButton extends StatefulWidget {
  const PixelButton({
    super.key,
    required this.child,
    required this.onTap,
    this.fill,
    this.gradient,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.semanticLabel,
  });
  final Widget child;
  final VoidCallback? onTap;
  final Color? fill;
  final Gradient? gradient;
  final EdgeInsets padding;
  final String? semanticLabel;

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    void set(bool v) {
      if (enabled && _down != v) setState(() => _down = v);
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => set(true),
        onTapUp: (_) => set(false),
        onTapCancel: () => set(false),
        onTap: enabled
            ? () {
                playSfxHook(Sfx.tap); // arcade click on every press
                widget.onTap!();
              }
            : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Transform.translate(
            offset: Offset(0, _down ? 1 : 0),
            child: PixelBox(
              raised: !_down,
              fill: widget.fill,
              gradient: widget.gradient,
              padding: widget.padding,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A one-line "former-life memo" strip under an app bar — surfaces the
/// 転生者チート framing on the management screens (§1.3: 前世用語は初出時に
/// ワンライン説明). The book glyph + cool tint read as a flash of memory.
Widget maeseMemo(String text) => Container(
  width: double.infinity,
  decoration: const BoxDecoration(
    color: Color(0xFFEDE6CF),
    border: Border(bottom: BorderSide(color: kInk, width: 1.5)),
  ),
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 1),
        child: Icon(Icons.auto_stories, size: 16, color: Color(0xFF7A5A86)),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: kInkText,
          ),
        ),
      ),
    ],
  ),
);

/// A flat, ink-bordered app bar (no Material elevation/tint) to match the
/// panels — pass a PixelTitle as [title].
PreferredSizeWidget pixelAppBar({required Widget title, List<Widget>? actions}) {
  return AppBar(
    title: title,
    centerTitle: true,
    backgroundColor: kPanel,
    foregroundColor: kInkText,
    elevation: 0,
    scrolledUnderElevation: 0,
    shape: const Border(bottom: BorderSide(color: kInk, width: 2)),
    actions: actions,
  );
}

/// A list row as a beveled panel (replaces Material ListTile). [onTap] makes it
/// a pressable panel; otherwise it's a static card.
class PixelListTile extends StatelessWidget {
  const PixelListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        if (leading != null)
          Padding(padding: const EdgeInsets.only(right: 10), child: leading),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DefaultTextStyle.merge(
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: kInkText,
                ),
                child: title,
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A6A44)),
                    child: subtitle!,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null)
          Padding(padding: const EdgeInsets.only(left: 8), child: trailing),
      ],
    );
    final box = PixelBox(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: row,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: onTap == null
          ? box
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: box,
            ),
    );
  }
}

/// A chunky segmented progress bar in a sunken well (replaces the smooth
/// Material LinearProgressIndicator). [value] is 0..1.
class PixelMeter extends StatelessWidget {
  const PixelMeter({
    super.key,
    required this.value,
    this.height = 12,
    this.fill = kAccent,
    this.fillLo = kAccentLo,
  });
  final double value;
  final double height;
  final Color fill;
  final Color fillLo;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return PixelBox(
      raised: false,
      fill: kWell,
      bevel: 1.5,
      outline: 1.5,
      padding: const EdgeInsets.all(1.5),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, c) => Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: c.maxWidth * v,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [fill, fillLo],
                ),
                border: const Border(
                  top: BorderSide(color: Color(0x88FFFFFF), width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
