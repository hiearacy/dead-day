import 'package:flutter/material.dart';

/// Functional text-reveal component; not a Gemini streaming implementation.
/// The designer can replace typography/scroll without touching game state.
class TypewriterText extends StatefulWidget {
  const TypewriterText({super.key, required this.text, this.milliseconds = 22});
  final String text;
  final int milliseconds;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with TickerProviderStateMixin {
  late final AnimationController _reveal;
  late final AnimationController _cursor;
  late List<String> _graphemes;

  @override
  void initState() {
    super.initState();
    _graphemes = widget.text.characters.toList();
    _reveal = AnimationController(vsync: this);
    _cursor = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 550),
    )..repeat(reverse: true);
    _startReveal();
  }

  void _startReveal() {
    _reveal.duration = Duration(
      milliseconds: (_graphemes.length * widget.milliseconds).clamp(1, 12000).toInt(),
    );
    _reveal.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _graphemes = widget.text.characters.toList();
      _startReveal();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    _cursor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6);
    if (reduceMotion) return Text(widget.text, style: style);
    return AnimatedBuilder(
      animation: Listenable.merge([_reveal, _cursor]),
      builder: (context, _) {
        final count = (_graphemes.length * _reveal.value)
            .round().clamp(0, _graphemes.length).toInt();
        final visible = _graphemes.take(count).join();
        final showCaret = _reveal.isAnimating && _cursor.value >= 0.45;
        return Semantics(
          label: widget.text,
          child: ExcludeSemantics(
            child: Text('$visible${showCaret ? '▍' : ''}', style: style),
          ),
        );
      },
    );
  }
}
