import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../db/database.dart';
import '../models/models.dart';
import 'crypto_service.dart';

/// تصدير Excel وطباعة العقود A4 ومشاركة واتساب.
class ExportService {
  final CryptoService crypto;
  ExportService(this.crypto);

  static final _money = NumberFormat('#,##0.00', 'ar_EG');
  static final _date = NumberFormat('00', 'en');

  String fmtDate(DateTime d) =>
      '${_date.format(d.year)}/${_date.format(d.month)}/${_date.format(d.day)}';

  Future<void> exportExcel() async {
    final d = await AppDatabase.instance.db;
    final book = Excel.createExcel();
    final clientsSheet = book['العملاء'];
    clientsSheet.appendRow([
      TextCellValue('الاسم'), TextCellValue('الرقم القومي'), TextCellValue('الهاتف'),
      TextCellValue('هاتف 2'), TextCellValue('العنوان'), TextCellValue('ملاحظات'),
      TextCellValue('تاريخ التسجيل'),
    ]);
    for (final m in await d.query('clients', where: 'is_sample = 0')) {
      final c = Client.fromMap(m);
      clientsSheet.appendRow([
        TextCellValue(c.name), TextCellValue(crypto.decryptText(c.nationalId)),
        TextCellValue(crypto.decryptText(c.phone)), TextCellValue(crypto.decryptText(c.phone2)),
        TextCellValue(c.address), TextCellValue(c.notes), TextCellValue(fmtDate(c.createdAt)),
      ]);
    }
    final contractsSheet = book['العقود'];
    contractsSheet.appendRow([
      TextCellValue('العميل'), TextCellValue('المنتج'), TextCellValue('الإجمالي'),
      TextCellValue('المقدم'), TextCellValue('القسط'), TextCellValue('المدة'),
      TextCellValue('المدفوع'), TextCellValue('الحالة'), TextCellValue('التاريخ'),
    ]);
    for (final m in await d.query('contracts')) {
      final c = Contract.fromMap(m);
      contractsSheet.appendRow([
        TextCellValue(c.clientName), TextCellValue(c.product),
        DoubleCellValue(c.total), DoubleCellValue(c.downPayment),
        DoubleCellValue(c.monthly), IntCellValue(c.months),
        DoubleCellValue(c.paid), TextCellValue(c.status), TextCellValue(fmtDate(c.createdAt)),
      ]);
    }
    book.delete('Sheet1');
    final bytes = book.encode()!;
    if (kIsWeb) {
      await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: 'dari-export.xlsx');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'dari-export-${DateTime.now().millisecondsSinceEpoch}.xlsx'));
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'تصدير Excel — نظام التقسيط الذكي');
    }
  }

  Future<Uint8List> buildContractPdf(Contract c, Client client, {String companyName = '', String branchAddress = ''}) async {
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Regular.ttf'));
    final doc = pw.Document();
    final money = NumberFormat('#,##0.00', 'en');
    // الشعار المخصص من الإعدادات (base64) يظهر أعلى العقد
    pw.Widget? logo;
    try {
      final d = await AppDatabase.instance.db;
      final r = await d.query('settings', where: 'key = ?', whereArgs: ['logo_data'], limit: 1);
      final b64 = r.isEmpty ? '' : (r.first['value'] as String? ?? '');
      if (b64.isNotEmpty) {
        logo = pw.Center(
            child: pw.Image(pw.MemoryImage(base64Decode(b64)), width: 64, height: 64));
      }
    } catch (_) {}
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (logo != null) ...[logo, pw.SizedBox(height: 4)],
            pw.Center(child: pw.Text(companyName.isEmpty ? 'نظام التقسيط الذكي' : companyName,
                style: pw.TextStyle(font: font, fontSize: 20, fontWeight: pw.FontWeight.bold))),
            if (branchAddress.isNotEmpty)
              pw.Center(child: pw.Text(branchAddress, style: pw.TextStyle(font: font, fontSize: 11))),
            pw.SizedBox(height: 8),
            pw.Center(child: pw.Text('عقد تقسيط', style: pw.TextStyle(font: font, fontSize: 16))),
            pw.SizedBox(height: 12),
            pw.Text('العميل: ${c.clientName}', style: pw.TextStyle(font: font)),
            pw.Text('الرقم القومي: ${client.nationalId}', style: pw.TextStyle(font: font)),
            pw.Text('الهاتف: ${client.phone}', style: pw.TextStyle(font: font)),
            pw.Text('العنوان: ${client.address}', style: pw.TextStyle(font: font)),
            pw.SizedBox(height: 8),
            pw.Text('المنتج: ${c.product}', style: pw.TextStyle(font: font)),
            pw.Text('الإجمالي: ${money.format(c.total)}  —  المقدم: ${money.format(c.downPayment)}  —  القسط: ${money.format(c.monthly)} × ${c.months} شهر',
                style: pw.TextStyle(font: font)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('م', style: pw.TextStyle(font: font))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('الاستحقاق', style: pw.TextStyle(font: font))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('المبلغ', style: pw.TextStyle(font: font))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('السداد', style: pw.TextStyle(font: font))),
                ]),
                ...c.installments.map((i) => pw.TableRow(children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${i.n}', style: pw.TextStyle(font: font))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(fmtDate(i.dueDate), style: pw.TextStyle(font: font))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(money.format(i.amount), style: pw.TextStyle(font: font))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(i.status, style: pw.TextStyle(font: font))),
                    ])),
              ],
            ),
            pw.Spacer(),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('توقيع العميل: ................', style: pw.TextStyle(font: font)),
              pw.Text('توقيع الضامن: ................', style: pw.TextStyle(font: font)),
              pw.Text('ختم المحل: ................', style: pw.TextStyle(font: font)),
            ]),
          ],
        ),
      ),
    );
    return doc.save();
  }

  Future<void> printContract(Contract c, Client client, {String companyName = '', String branchAddress = ''}) async {
    final bytes = await buildContractPdf(c, client, companyName: companyName, branchAddress: branchAddress);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  /// طباعة بطاقة الرقم القومي للعميل (الاسم + الرقم + الهاتفات + العنوان).
  Future<void> printIdCard(Client client) async {
    final font = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      build: (ctx) => pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Center(
          child: pw.Container(
            width: 300,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 2)),
            child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
              pw.Text('بطاقة الرقم القومي',
                  style: pw.TextStyle(font: pw.Font.ttf(font), fontSize: 18)),
              pw.SizedBox(height: 12),
              pw.Text(client.name, style: pw.TextStyle(font: pw.Font.ttf(font), fontSize: 16)),
              pw.SizedBox(height: 8),
              pw.Text(crypto.decryptText(client.nationalId),
                  style: pw.TextStyle(fontSize: 20, letterSpacing: 2)),
              pw.SizedBox(height: 8),
              pw.Text('${crypto.decryptText(client.phone)}  ${crypto.decryptText(client.phone2)}',
                  style: pw.TextStyle(font: pw.Font.ttf(font), fontSize: 12)),
              pw.SizedBox(height: 4),
              pw.Text(client.address, style: pw.TextStyle(font: pw.Font.ttf(font), fontSize: 12)),
            ]),
          ),
        ),
      ),
    ));
    final bytes = await doc.save();
    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: 'id_card.pdf');
    } else {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    }
  }

  Future<void> shareWhatsApp(String phone, String message) async {
    final p = phone.startsWith('0') ? '2${phone.substring(0)}' : phone;
    final uri = Uri.parse('https://wa.me/$p?text=${Uri.encodeComponent(message)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}


