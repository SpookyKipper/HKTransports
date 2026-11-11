import 'package:url_launcher/url_launcher.dart';

const String appUpdateUrl =
    'https://repo.spookysrv.com/apps/com.spookysrv.hktransports';

Future<bool> openAppUpdatePage() {
  return launchUrl(
    Uri.parse(appUpdateUrl),
    mode: LaunchMode.externalApplication,
  );
}
