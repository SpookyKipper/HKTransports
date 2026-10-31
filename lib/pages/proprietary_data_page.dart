import 'package:flutter/material.dart';
import 'package:hktransports/app/page_bar.dart';
import 'package:hktransports/bus/notice/bbi_service.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

class ProprietaryDataPage extends StatelessWidget {
  const ProprietaryDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      appBar: buildPageBar(
        context,
        title: settings.text('專有資料', 'Proprietary data'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          M3ECard(
            variant: M3ECardVariant.filled,
            color: scheme.errorContainer,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.text('自行承擔風險', 'Use at your own risk'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        settings.text(
                          '這些來源未獲完整授權。啟用任何來源均可能違反使用條款或授權。你需自行承擔所有風險。這些來源的所有請求均由你的裝置直接發出，不經代理伺服器。',
                          'These sources are not fully licensed. Enabling any source may violate terms of use or licenses. You bear all risk. All requests for these sources are made directly from your device; no proxy server is used.',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            settings.text('資料來源', 'Sources'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            settings.text(
              '可選多項。預設不啟用任何來源。',
              'Select any combination. Nothing is enabled by default.',
            ),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final ProprietaryDataSource source
              in ProprietaryDataSource.values) ...[
            _SourceCard(
              source: source,
              settings: settings,
              enabled: settings.isProprietaryEnabled(source),
              onChanged: (bool value) =>
                  _setProprietarySource(settings, source, value),
            ),
            if (source != ProprietaryDataSource.values.last)
              const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Future<void> _setProprietarySource(
    AppSettings settings,
    ProprietaryDataSource source,
    bool value,
  ) async {
    settings.setProprietarySource(source, value);
    if (!value && source == ProprietaryDataSource.kmb) {
      await const BbiService().clearCache();
    }
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.settings,
    required this.enabled,
    required this.onChanged,
  });

  final ProprietaryDataSource source;
  final AppSettings settings;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return M3ECard(
      variant: M3ECardVariant.filled,
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      onPressed: () => onChanged(!enabled),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.label(settings),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  source.description(settings),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          M3ECheckbox(
            value: enabled,
            onChanged: (bool? value) {
              if (value != null) onChanged(value);
            },
            focusable: false,
            semanticLabel: source.label(settings),
          ),
        ],
      ),
    );
  }
}
