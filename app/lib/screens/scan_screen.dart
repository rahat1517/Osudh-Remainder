import 'dart:async';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/backend_api.dart';
import '../data/models.dart';
import '../l10n/codes.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';
import 'confirm_screen.dart';

typedef ImagePickerFn = Future<Uint8List?> Function({required bool camera});

Future<Uint8List?> pickWithImagePicker({required bool camera}) async {
  final file = await ImagePicker().pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    // The server reads at most 1568 px on the long side: sending more only slows the upload
    // (about 3x smaller than 2400 px on mobile data)
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 85,
  );
  return file?.readAsBytes();
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    this.pickImage = pickWithImagePicker,
    this.retryDelay = const Duration(seconds: 3),
  });

  final ImagePickerFn pickImage;

  /// Wait before the automatic second try after a connection failure.
  final Duration retryDelay;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

/// Failures where the same photo may well work a moment later: no connection, or the server
/// restarting (a new version, or waking up on the free plan).
const _transientCodes = {'network_error', 'server_error', 'ai_unavailable'};

class _ScanScreenState extends State<ScanScreen> {
  bool _reading = false;
  String? _error;

  /// The photo of a failed attempt, so "Try again" needs no new photo.
  Uint8List? _retryImage;

  @override
  void initState() {
    super.initState();
    // Wake the server while the user frames the photo (it sleeps when idle on the free plan)
    unawaited(context.read<AppState>().api.wakeUp());
  }

  Future<void> _scan({required bool camera}) async {
    await _askAboutCloudReaderOnce();
    if (!mounted) return;
    final bytes = await widget.pickImage(camera: camera);
    if (bytes == null || !mounted) return;
    await _read(bytes);
  }

  /// Before the first scan: may photos the server's own reader is unsure of (often handwriting)
  /// be read by Google's AI? Asked once; changeable in Settings.
  Future<void> _askAboutCloudReaderOnce() async {
    final state = context.read<AppState>();
    if (state.store == null || state.cloudReaderConsent != null) return;
    final l = AppLocalizations.of(context);
    final allowed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l.cloudReaderTitle),
        content: SingleChildScrollView(child: Text(l.cloudReaderBody)),
        actions: [
          TextButton(
            key: const Key('cloudReaderDeny'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cloudReaderDeny),
          ),
          FilledButton(
            key: const Key('cloudReaderAllow'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.cloudReaderAllow),
          ),
        ],
      ),
    );
    if (allowed != null) await state.setCloudReaderConsent(allowed);
  }

  Future<void> _read(Uint8List bytes) async {
    final api = context.read<AppState>().api;
    final cloudOk = context.read<AppState>().cloudReaderConsent ?? false;
    final l = AppLocalizations.of(context);
    setState(() {
      _reading = true;
      _error = null;
      _retryImage = null;
    });
    try {
      PrescriptionScan scan;
      try {
        scan = await api.extractPrescription(bytes, cloudOk: cloudOk);
      } on ApiException catch (e) {
        if (!_transientCodes.contains(e.code)) rethrow;
        // Try once more on its own before bothering the user
        await Future<void>.delayed(widget.retryDelay);
        if (!mounted) return;
        scan = await api.extractPrescription(bytes, cloudOk: cloudOk);
      }
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ConfirmScreen.fromScan(scan, image: bytes),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = localizeError(l, e.code) ?? l.errorGeneric;
        if (_transientCodes.contains(e.code)) _retryImage = bytes;
      });
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.scanTitle)),
      // SafeArea: on phones that draw behind the navigation bar, the buttons were under it
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _reading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(l.reading),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.scanTips,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      if (_retryImage case final image?)
                        FilledButton.tonalIcon(
                          key: const Key('retryScan'),
                          onPressed: () => _read(image),
                          icon: const Icon(Icons.refresh),
                          label: Text(l.retry),
                        ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => ConfirmScreen.manual(),
                          ),
                        ),
                        child: Text(l.addManually),
                      ),
                    ],
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () => _scan(camera: true),
                      icon: const Icon(Icons.photo_camera),
                      label: Text(l.takePhoto),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _scan(camera: false),
                      icon: const Icon(Icons.photo_library),
                      label: Text(l.chooseFromGallery),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
