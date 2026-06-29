import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart'; // NEW IMPORT

// Excel Packages
import 'package:excel/excel.dart';

// PDF Packages
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'task_entry.dart';

class ExportHelper {
  static final DateFormat _dateFormatter = DateFormat('dd-MMM-yyyy');
  static final DateFormat _timeFormatter = DateFormat('hh:mm a');

  // ==========================================
  // 1. EXCEL EXPORT
  // ==========================================
  static Future<void> exportToExcel(BuildContext context, List<TaskEntry> tasks) async {
    try {
      var excel = Excel.createExcel();
      var sheet = excel['Audit Report'];
      excel.setDefaultSheet('Audit Report');

      // ... [Keep all your existing Excel Header and Row appending logic here] ...
      // 1. Add Headers
      sheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Start Time'),
        TextCellValue('End Time'),
        TextCellValue('Module'),
        TextCellValue('Activity'),
        TextCellValue('Class/Subject'),
        TextCellValue('Details'),
        TextCellValue('Hours Logged'),
      ]);

      // 2. Add Data Rows
      for (var task in tasks) {
        final classInfo = task.mainModule == MainModule.academic && task.subCategory == 'Teaching'
            ? '${task.className ?? ''} ${task.division ?? ''} - ${task.subject ?? ''}'
            : '-';

        sheet.appendRow([
          TextCellValue(_dateFormatter.format(task.startTime)),
          TextCellValue(_timeFormatter.format(task.startTime)),
          TextCellValue(_timeFormatter.format(task.endTime)),
          TextCellValue(task.mainModule.displayName),
          TextCellValue(task.subCategory),
          TextCellValue(classInfo),
          TextCellValue(task.title ?? task.detailedDescription ?? ''),
          DoubleCellValue(task.duration.inMinutes / 60.0),
        ]);
      }

      final fileBytes = excel.save();
      if (fileBytes == null) return;

      // 3. PLATFORM SPECIFIC SAVING LOGIC
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // --- DESKTOP LOGIC ---
        final directory = await getDownloadsDirectory();
        final filePath = '${directory?.path}/Teacher_Audit_Report.xlsx';

        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Excel report saved to Downloads folder!'),
              action: SnackBarAction(
                label: 'Open Folder',
                onPressed: () => launchUrl(Uri.file(directory!.path)), // Opens Windows Explorer / Finder
              ),
            ),
          );
        }
      } else {
        // --- MOBILE LOGIC ---
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/Teacher_Audit_Report.xlsx';

        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        await Share.shareXFiles([XFile(filePath)], text: 'Here is my exported audit report.');
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating Excel: $e')));
    }
  }
  // ==========================================
  // 2. PDF EXPORT
  // ==========================================
  static Future<void> exportToPdf(BuildContext context, List<TaskEntry> tasks) async {
    try {
      final pdf = pw.Document();

      // ... [Keep all your existing PDF Table and Formatting logic here] ...
      final headers = ['Date', 'Time', 'Category', 'Details', 'Hrs'];
      final data = tasks.map((task) {
        final timeString = '${_timeFormatter.format(task.startTime)}\n${_timeFormatter.format(task.endTime)}';
        String details = task.subCategory;
        if (task.mainModule == MainModule.academic && task.subCategory == 'Teaching') {
          details += '\n${task.className ?? ''} - ${task.subject ?? ''}';
        } else if (task.title != null) {
          details += '\n${task.title}';
        }
        return [
          _dateFormatter.format(task.startTime),
          timeString,
          task.mainModule.name.toUpperCase(),
          details,
          (task.duration.inMinutes / 60.0).toStringAsFixed(1),
        ];
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(level: 0, child: pw.Text('Teacher Activity Audit Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 10),
              pw.Text('Generated on: ${_dateFormatter.format(DateTime.now())}'),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: data,
                border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {4: pw.Alignment.centerRight},
              ),
            ];
          },
        ),
      );

      final fileBytes = await pdf.save();

      // PLATFORM SPECIFIC SAVING LOGIC
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // --- DESKTOP LOGIC ---
        final directory = await getDownloadsDirectory();
        final filePath = '${directory?.path}/Teacher_Audit_Report.pdf';

        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('PDF report saved to Downloads folder!'),
              action: SnackBarAction(
                label: 'Open Folder',
                onPressed: () => launchUrl(Uri.file(directory!.path)), // Opens Windows Explorer / Finder
              ),
            ),
          );
        }
      } else {
        // --- MOBILE LOGIC ---
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/Teacher_Audit_Report.pdf';

        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        await Share.shareXFiles([XFile(filePath)], text: 'Here is my exported PDF audit report.');
      }

    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
    }
  }
}