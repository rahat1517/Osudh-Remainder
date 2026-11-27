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
    maxWidth: 2400,
    imageQuality: 90,
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
    final bytes = await widget.pickImage(camera: camera);
    if (bytes == null || !mounted) return;
    await _read(bytes);
  }

  Future<void> _read(Uint8List bytes) async {
    final api = context.read<AppState>().api;
    final l = AppLocalizations.of(context);
    setState(() {
      _reading = true;
      _error = null;
      _retryImage = null;
    });
    try {
      PrescriptionScan scan;
      try {
        scan = await api.extractPrescription(bytes);
      } on ApiException catch (e) {
        if (!_transientCodes.contains(e.code)) rethrow;
        // Try once more on its own before bothering the user
        await Future<void>.delayed(widget.retryDelay);
        if (!mounted) return;
        scan = await api.extractPrescription(bytes);
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
