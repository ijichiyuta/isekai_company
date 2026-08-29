import 'package:flutter/material.dart';

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
          child: Padding(padding: padding, child: child),
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
        onTap: enabled ? widget.onTap : null,
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
