import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';

class MapAttribution extends StatefulWidget {
  const MapAttribution({
    super.key,
    required this.attributions,
    this.padding = const EdgeInsets.all(10),
  });

  final List<String> attributions;
  final EdgeInsets padding;

  @override
  State<MapAttribution> createState() => _MapAttributionState();
}

class _MapAttributionState extends State<MapAttribution> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.attributions.isEmpty) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: widget.padding,
        child: Material(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_expanded)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
                    child: _AttributionText(attributions: widget.attributions),
                  ),
                ),
              SizedBox.square(
                dimension: 30,
                child: IconButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: const Icon(Icons.info, size: 18),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttributionText extends StatefulWidget {
  const _AttributionText({required this.attributions});

  final List<String> attributions;

  @override
  State<_AttributionText> createState() => _AttributionTextState();
}

class _AttributionTextState extends State<_AttributionText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void didUpdateWidget(covariant _AttributionText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attributions != widget.attributions) {
      _clearRecognizers();
    }
  }

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  void _clearRecognizers() {
    for (final TapGestureRecognizer recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final TextStyle? style = Theme.of(context).textTheme.bodySmall;
    final List<InlineSpan> spans = [];
    for (int index = 0; index < widget.attributions.length; index++) {
      if (index > 0) spans.add(const TextSpan(text: '  '));
      final dom.Document document = html_parser.parse(
        widget.attributions[index],
      );
      for (final dom.Node node in document.body?.nodes ?? const <dom.Node>[]) {
        if (node is dom.Text) {
          spans.add(TextSpan(text: node.text));
        } else if (node is dom.Element && node.localName == 'a') {
          final TapGestureRecognizer recognizer = TapGestureRecognizer()
            ..onTap = () {
              final String? href = node.attributes['href'];
              if (href != null) launchUrl(Uri.parse(href));
            };
          _recognizers.add(recognizer);
          spans.add(TextSpan(text: node.text, recognizer: recognizer));
        }
      }
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
