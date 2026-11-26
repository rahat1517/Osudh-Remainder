import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../insights/insights.dart';
import '../state/app_state.dart';
import '../l10n/generated/app_localizations.dart';

/// Adherence over the last 7 days, shareable as a PDF for the doctor.
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  /// English PDF: doctors in Bangladesh read prescriptions and reports in English.
  static Future<List<int>> buildPdf(AppState state, Adherence a) async {
    final doc = pw.Document();
    final now = state.wallNow;
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Medicine adherence report',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              '7 days to ${now.toIso8601String().substring(0, 10)} (Oshudh Reminder)',
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Overall: ${a.taken} of ${a.scheduled} doses taken (${(a.rate * 100).round()}%), '
              '${a.skipped} skipped, ${a.missed} missed',
            ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: ['Medicine', 'Dose', 'Taken', 'Scheduled', '%'],
              data: [
                for (final m in state.active)
                  if (a.byMedicine[m.id] case final s?)
                    [
                      m.label,
                      m.dosePattern ?? '',
                      '${s.taken}',
                      '${s.scheduled}',
                      s.scheduled == 0
                          ? '-'
                          : '${(100 * s.taken / s.scheduled).round()}',
                    ],
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Recorded by the patient in the app; "missed" means no action was recorded.',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final a = state.weeklyAdherence();
    return Scaffold(
      appBar: AppBar(title: Text(l.reportTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l.reportOverall(a.taken, a.scheduled, (a.rate * 100).round()),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(l.reportMissed(a.missed, a.skipped)),
          const SizedBox(height: 12),
          for (final m in state.active)
            if (a.byMedicine[m.id] case final s?)
              ListTile(
                title: Text(m.label),
                trailing: Text('${s.taken}/${s.scheduled}'),
                subtitle: LinearProgressIndicator(
                  value: s.scheduled == 0 ? 0 : s.taken / s.scheduled,
                ),
              ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              final bytes = await buildPdf(state, a);
              await Printing.sharePdf(
                bytes: Uint8List.fromList(bytes),
                filename: 'adherence-report.pdf',
              );
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: Text(l.reportShare),
          ),
        ],
      ),
    );
  }
}
