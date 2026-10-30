import 'package:flutter/material.dart';

class RouteNumberPad extends StatelessWidget {
  const RouteNumberPad({
    super.key,
    required this.possibleChars,
    required this.hasQuery,
    required this.onCharacter,
    required this.onBackspace,
    required this.onClear,
    required this.clearTooltip,
    required this.backspaceTooltip,
  });

  final Set<String> possibleChars;
  final bool hasQuery;
  final ValueChanged<String> onCharacter;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final String clearTooltip;
  final String backspaceTooltip;

  @override
  Widget build(BuildContext context) {
    final Set<String> chars = possibleChars
        .map((String value) => value.toUpperCase())
        .toSet();
    final List<String> letters = chars
        .where((String value) => RegExp(r'^[A-Z]$').hasMatch(value))
        .toList()
      ..sort();
    final bool hasLetters = letters.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: SizedBox(
          height: 248,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  flex: hasLetters ? 62 : 100,
                  child: _NumberPad(
                    chars: chars,
                    hasQuery: hasQuery,
                    onCharacter: onCharacter,
                    onBackspace: onBackspace,
                    onClear: onClear,
                    clearTooltip: clearTooltip,
                    backspaceTooltip: backspaceTooltip,
                  ),
                ),
                if (hasLetters) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 35,
                    child: _LetterPad(
                      letters: letters,
                      onCharacter: onCharacter,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  const _NumberPad({
    required this.chars,
    required this.hasQuery,
    required this.onCharacter,
    required this.onBackspace,
    required this.onClear,
    required this.clearTooltip,
    required this.backspaceTooltip,
  });

  static const List<List<String>> _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['C', '0', 'B'],
  ];

  final Set<String> chars;
  final bool hasQuery;
  final ValueChanged<String> onCharacter;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final String clearTooltip;
  final String backspaceTooltip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final List<String> row in _rows)
          Expanded(
            child: Row(
              children: [
                for (final String key in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: _buildKey(context, key),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildKey(BuildContext context, String key) {
    if (key == 'C') {
      return _PadButton(
        tooltip: clearTooltip,
        onPressed: hasQuery ? onClear : null,
        child: const Icon(Icons.clear),
      );
    }
    if (key == 'B') {
      return _PadButton(
        tooltip: backspaceTooltip,
        onPressed: hasQuery ? onBackspace : null,
        child: const Icon(Icons.backspace_outlined),
      );
    }
    final bool enabled = chars.contains(key);
    return _PadButton(
      onPressed: enabled ? () => onCharacter(key) : null,
      child: Text(key),
    );
  }
}

class _LetterPad extends StatelessWidget {
  const _LetterPad({required this.letters, required this.onCharacter});

  final List<String> letters;
  final ValueChanged<String> onCharacter;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 48,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: letters.length,
      itemBuilder: (BuildContext context, int index) {
        final String letter = letters[index];
        return _PadButton(
          onPressed: () => onCharacter(letter),
          child: Text(letter),
        );
      },
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({required this.onPressed, required this.child, this.tooltip});

  final VoidCallback? onPressed;
  final Widget child;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Widget button = SizedBox.expand(
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: Theme.of(context).textTheme.titleLarge,
        ),
        child: child,
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
