import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/backend_api.dart';
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
  const ScanScreen({super.key, this.pickImage = pickWithImagePicker});

  final ImagePickerFn pickImage;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _reading = false;
  String? _error;

  Future<void> _scan({required bool camera}) async {
    final api = context.read<AppState>().api;
    final l = AppLocalizations.of(context);
    final bytes = await widget.pickImage(camera: camera);
    if (bytes == null || !mounted) return;
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      final scan = await api.extractPrescription(bytes);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ConfirmScreen.fromScan(scan, image: bytes),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _error = localizeError(l, e.code) ?? l.errorGeneric);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.scanTitle)),
      body: Padding(
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
    );
  }
}
