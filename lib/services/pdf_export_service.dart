import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfExportService {
  static Future<void> exportRoadmapPdf({
    required String targetRole,
    required Map<String, dynamic> analysisData,
  }) async {
    final doc = pw.Document();

    final int matchScore = analysisData['match_score'] ?? 0;
    final List strengths = analysisData['identified_skills'] ?? [];
    final List gaps = analysisData['missing_skills'] ?? [];
    final List roadmap = analysisData['roadmap'] ?? [];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('AI CareerPilot — Learning Roadmap', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo800)),
                  pw.Text('Target: $targetRole', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.indigo50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Overall Target Alignment Score', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  pw.Text('$matchScore%', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: PdfColors.indigo700)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Current Strengths:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 6),
            pw.Wrap(
              spacing: 6,
              children: strengths.map((s) => pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(color: PdfColors.green100, borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Text(s.toString(), style: const pw.TextStyle(fontSize: 10, color: PdfColors.green900)),
              )).toList(),
            ),
            pw.SizedBox(height: 14),
            pw.Text('Identified Skill Gaps:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 6),
            pw.Wrap(
              spacing: 6,
              children: gaps.map((g) => pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(color: PdfColors.red100, borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Text(g.toString(), style: const pw.TextStyle(fontSize: 10, color: PdfColors.red900)),
              )).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Weekly Upskilling Execution Plan:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15)),
            pw.SizedBox(height: 10),
            ...roadmap.map((step) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(color: PdfColors.indigo100, borderRadius: pw.BorderRadius.circular(4)),
                    child: pw.Text("W${step['week'] ?? 1}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(step['topic'] ?? '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        pw.SizedBox(height: 2),
                        pw.Text(step['action_item'] ?? '', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                      ],
                    ),
                  )
                ],
              ),
            )),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }
}