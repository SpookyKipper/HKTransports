package com.spookysrv.hktransports

import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "com.spookysrv.hktransports/ota"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasInstallPermission" -> {
                        result.success(hasInstallPermission())
                    }
                    "openInstallPermissionSettings" -> {
                        try {
                            openInstallPermissionSettings()
                            result.success(null)
                        } catch (error: Exception) {
                            result.error(
                                "permission_settings_failed",
                                error.message,
                                null,
                            )
                        }
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("missing_path", "APK path is missing", null)
                            return@setMethodCallHandler
                        }
                        installApk(File(path), result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasInstallPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
    }

    private fun openInstallPermissionSettings() {
        startActivity(
            Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    private fun installApk(file: File, result: MethodChannel.Result) {
        if (!file.exists() || file.length() == 0L) {
            result.error("missing_file", "APK file does not exist", null)
            return
        }
        if (!hasInstallPermission()) {
            try {
                openInstallPermissionSettings()
                result.error(
                    "permission_required",
                    "Allow this app to install unknown apps",
                    null,
                )
            } catch (error: Exception) {
                result.error("permission_required", error.message, null)
            }
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            try {
                installWithSession(file)
                result.success(true)
                return
            } catch (_: Exception) {
                // Fall back to the legacy install intent below.
            }
        }
        try {
            installWithLegacyIntent(file)
            result.success(true)
        } catch (error: Exception) {
            result.error("install_failed", error.message, null)
        }
    }

    private fun installWithSession(file: File) {
        val installer = packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(
            PackageInstaller.SessionParams.MODE_FULL_INSTALL,
        )
        params.setAppPackageName(packageName)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // This app is updating itself. On Android 12+ the system can skip
            // the installer confirmation when this normal permission is held.
            params.setRequireUserAction(
                PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED,
            )
        }
        val sessionId = installer.createSession(params)
        try {
            installer.openSession(sessionId).use { session ->
                session.openWrite("base.apk", 0, file.length()).use { output ->
                    file.inputStream().use { input -> input.copyTo(output) }
                    session.fsync(output)
                }
                val intent = Intent(this, InstallResultReceiver::class.java)
                    .setAction("$packageName.ACTION_INSTALL_COMMIT")
                val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        PendingIntent.FLAG_MUTABLE
                    } else {
                        0
                    }
                val pendingIntent = PendingIntent.getBroadcast(
                    this,
                    sessionId,
                    intent,
                    flags,
                )
                session.commit(pendingIntent.intentSender)
            }
        } catch (error: Exception) {
            try {
                installer.abandonSession(sessionId)
            } catch (_: Exception) {
                // Best effort cleanup.
            }
            throw error
        }
    }

    private fun installWithLegacyIntent(file: File) {
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file,
        )
        startActivity(
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_ACTIVITY_NEW_TASK,
                ),
        )
    }
}
