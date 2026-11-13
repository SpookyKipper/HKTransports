import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hktransports/app/app_config.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:http/http.dart' as http;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

const MethodChannel _otaChannel = MethodChannel(
  'com.spookysrv.hktransports/ota',
);

const String appRepositoryUrl =
    'https://repo.spookysrv.com/apps/com.spookysrv.hktransports';

Future<bool> openAppRepositoryPage() {
  return launchUrl(
    Uri.parse(appRepositoryUrl),
    mode: LaunchMode.externalApplication,
  );
}

String appUpdateDownloadUrl(String versionName) {
  return 'https://github.com/SpookyKipper/HKTransports/releases/latest/download/'
      'HKTransports-v${Uri.encodeComponent(versionName)}.apk';
}

class AppUpdateService {
  const AppUpdateService._();

  static Future<File> download(
    AppConfig config, {
    void Function(double? progress)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    final String versionName = config.latestVersionName.trim();
    if (versionName.isEmpty) {
      throw const AppUpdateException('Missing version name');
    }
    final http.Client client = http.Client();
    final Uri uri = Uri.parse(appUpdateDownloadUrl(versionName));
    try {
      final http.Request request = http.Request('GET', uri)
        ..headers['User-Agent'] = 'HKTransports'
        ..headers['Accept'] = 'application/octet-stream';
      final http.StreamedResponse response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw AppUpdateException('Download failed (${response.statusCode})');
      }

      final Directory directory = Directory(
        '${(await getTemporaryDirectory()).path}/ota',
      );
      await directory.create(recursive: true);
      final File file = File(
        '${directory.path}/HKTransports-v$versionName.apk',
      );
      final IOSink sink = file.openWrite();
      final int? total = response.contentLength;
      int received = 0;
      try {
        await for (final List<int> chunk in response.stream) {
          if (shouldCancel?.call() ?? false) {
            await sink.close();
            if (await file.exists()) await file.delete();
            throw const AppUpdateCancelled();
          }
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(
            total == null || total <= 0 ? null : received / total,
          );
        }
        await sink.close();
      } catch (_) {
        await sink.close();
        if (await file.exists()) await file.delete();
        rethrow;
      }
      if (await file.length() == 0) {
        throw const AppUpdateException('Downloaded file is empty');
      }
      return file;
    } finally {
      client.close();
    }
  }

  static Future<bool> hasInstallPermission() async {
    if (!Platform.isAndroid) return true;
    return await _otaChannel.invokeMethod<bool>('hasInstallPermission') ??
        false;
  }

  static Future<void> openInstallPermissionSettings() {
    return _otaChannel.invokeMethod<void>('openInstallPermissionSettings');
  }

  static Future<void> install(File file) {
    return _otaChannel.invokeMethod<void>('installApk', <String, String>{
      'path': file.path,
    });
  }
}

class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppUpdateCancelled implements Exception {
  const AppUpdateCancelled();
}

Future<void> startAppUpdate(
  BuildContext context,
  AppConfigController controller,
) async {
  final AppConfig? config = controller.config;
  if (config == null || !controller.hasUpdate) return;
  if (!config.doOtaUpdate) {
    bool opened = false;
    try {
      opened = await openAppRepositoryPage();
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      final AppSettings settings = context.read<AppSettings>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settings.text(
              '無法開啟瀏覽器，請前往 $appRepositoryUrl。',
              'Could not open the browser. Visit $appRepositoryUrl.',
            ),
          ),
        ),
      );
    }
    return;
  }
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return _AppUpdateDialog(config: config);
    },
  );
}

class _AppUpdateDialog extends StatefulWidget {
  const _AppUpdateDialog({required this.config});

  final AppConfig config;

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  double? _progress;
  bool _installing = false;
  String? _error;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _progress = 0;
      _installing = false;
    });
    try {
      if (!await AppUpdateService.hasInstallPermission()) {
        await AppUpdateService.openInstallPermissionSettings();
        if (!mounted) return;
        final AppSettings settings = context.read<AppSettings>();
        setState(() {
          _error = settings.text(
            '請先允許此應用程式安裝 APK，然後按「重試」。',
            'Allow this app to install APKs first, then tap Retry.',
          );
        });
        return;
      }
      final File file = await AppUpdateService.download(
        widget.config,
        shouldCancel: () => _cancelled,
        onProgress: (double? value) {
          if (!mounted || _cancelled) return;
          setState(() => _progress = value);
        },
      );
      if (!mounted || _cancelled) return;
      setState(() => _installing = true);
      await AppUpdateService.install(file);
      if (!mounted || _cancelled) return;
      Navigator.of(context).pop();
    } on AppUpdateCancelled {
      // The dialog is already closing.
    } on PlatformException catch (error) {
      if (!mounted) return;
      final AppSettings settings = context.read<AppSettings>();
      final String message = error.code == 'permission_required'
          ? settings.text(
              '請允許此應用程式安裝 APK，然後再試一次。',
              'Allow this app to install APKs, then try again.',
            )
          : error.message ??
                settings.text('安裝更新失敗。', 'Could not install the update.');
      setState(() {
        _installing = false;
        _error = message;
      });
    } catch (error) {
      if (!mounted) return;
      final AppSettings settings = context.read<AppSettings>();
      setState(() {
        _installing = false;
        _error = settings.text(
          '下載或安裝更新失敗：$error',
          'Could not download or install the update: $error',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      icon: const Icon(Icons.system_update_alt_rounded),
      title: Text(settings.text('更新 HKTransports', 'Update HKTransports')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null)
            Text(_error!)
          else if (_installing)
            Text(settings.text('正在開啟安裝程式…', 'Opening the installer…'))
          else ...[
            SizedBox(
              width: 240,
              child: M3EProgressIndicator.linearWavy(
                value: _progress,
                linearSize: M3EProgressIndicatorSize.m,
                strokeWidth: 4,
                trackStrokeWidth: 4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _progress == null
                  ? settings.text('正在下載更新…', 'Downloading the update…')
                  : '${(_progress! * 100).round()}%',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: _start,
            child: Text(settings.text('重試', 'Retry')),
          ),
        TextButton(
          onPressed: () {
            _cancelled = true;
            Navigator.of(context).pop();
          },
          child: Text(settings.text('取消', 'Cancel')),
        ),
      ],
    );
  }
}
