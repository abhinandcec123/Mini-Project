import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CertificateService {
  static Future<Uint8List> buildPdf(
    Map<String, dynamic> certificate,
  ) async {
    final document = pw.Document();
    final donorName =
        (certificate['donor_name'] ?? 'LifePulse donor').toString();
    final hospitalName =
        (certificate['hospital_name'] ?? 'LifePulse Network').toString();
    final donationDate =
        DateTime.tryParse(certificate['donation_date']?.toString() ?? '');
    final formattedDate = donationDate == null
        ? 'Date not available'
        : '${donationDate.day.toString().padLeft(2, '0')}/'
            '${donationDate.month.toString().padLeft(2, '0')}/'
            '${donationDate.year}';
    final certificateId = certificate['id']?.toString() ?? 'N/A';
    final units = (certificate['units_donated'] as num?)?.toInt() ?? 1;

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(42),
        build: (context) => pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
              color: PdfColor.fromHex('#BE123C'),
              width: 3,
            ),
          ),
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'LIFEPULSE AI',
                style: pw.TextStyle(
                  color: PdfColor.fromHex('#BE123C'),
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              pw.SizedBox(height: 48),
              pw.Text(
                'CERTIFICATE OF DONATION',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 25,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 32),
              pw.Text(
                'This certificate recognizes',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 14),
              pw.Text(
                donorName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  color: PdfColor.fromHex('#BE123C'),
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Text(
                'for completing a blood donation at',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                hospitalName,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                '$units ${units == 1 ? 'unit' : 'units'} donated on $formattedDate',
                style: const pw.TextStyle(fontSize: 13),
              ),
              pw.Spacer(),
              pw.Divider(color: PdfColor.fromHex('#CBD5E1')),
              pw.SizedBox(height: 10),
              pw.Text(
                'Certificate ID: $certificateId',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Issued by LifePulse AI after hospital approval.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );

    return document.save();
  }

  static Future<void> download(Map<String, dynamic> certificate) async {
    final certificateId = certificate['id']?.toString() ?? 'N/A';
    await FileSaver.instance.saveFile(
      name: 'LifePulse_Donation_Certificate_$certificateId',
      bytes: await buildPdf(certificate),
      fileExtension: 'pdf',
      mimeType: MimeType.custom,
      customMimeType: 'application/pdf',
    );
  }
}
