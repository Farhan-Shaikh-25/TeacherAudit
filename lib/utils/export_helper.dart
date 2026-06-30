import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
  // 1. EXCEL EXPORT (UPDATED WITH PROGRAMME)
  // ==========================================
  static Future<void> exportToExcel(BuildContext context, List<TaskEntry> tasks) async {
    try {
      var excel = Excel.createExcel();
      var sheet = excel['Audit Report'];
      excel.setDefaultSheet('Audit Report');

      // 1. Add Headers (Inserted Programme column)
      sheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Start Time'),
        TextCellValue('End Time'),
        TextCellValue('Module'),
        TextCellValue('Activity'),
        TextCellValue('Programme'), // New Column
        TextCellValue('Class/Subject'),
        TextCellValue('Details'),
        TextCellValue('Hours Logged'),
      ]);

      // 2. Add Data Rows
      for (var task in tasks) {
        final isAcademicTeaching = task.mainModule == MainModule.academic && task.subCategory == 'Teaching';

        final programmeInfo = isAcademicTeaching ? (task.programme ?? '-') : '-';

        // UPDATED: Appends an "(Extra Lecture)" flag if true
        String classInfo = '-';
        if (isAcademicTeaching) {
          classInfo = '${task.className ?? ''} ${task.division ?? ''} - ${task.subject ?? ''}';
          if (task.isExtraLecture) {
            classInfo += ' (Extra Lecture)';
          }
        }

        sheet.appendRow([
          TextCellValue(_dateFormatter.format(task.startTime)),
          TextCellValue(_timeFormatter.format(task.startTime)),
          TextCellValue(_timeFormatter.format(task.endTime)),
          TextCellValue(task.mainModule.displayName),
          TextCellValue(task.subCategory),
          TextCellValue(programmeInfo),
          TextCellValue(classInfo), // Contains the extra lecture note now
          TextCellValue(task.title ?? task.detailedDescription ?? ''),
          DoubleCellValue(task.duration.inMinutes / 60.0),
        ]);
      }

      final fileBytes = excel.save();
      if (fileBytes == null) return;

      // 3. PLATFORM SPECIFIC SAVING LOGIC
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
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
                onPressed: () => launchUrl(Uri.file(directory!.path)),
              ),
            ),
          );
        }
      } else {
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
  // 2. PDF EXPORT (UPDATED WITH PROGRAMME)
  // ==========================================
  static Future<void> exportToPdf(BuildContext context, List<TaskEntry> tasks) async {
    try {
      final pdf = pw.Document();

      final headers = ['Date', 'Time', 'Category', 'Details', 'Hrs'];
      final data = tasks.map((task) {
        final timeString = '${_timeFormatter.format(task.startTime)}\n${_timeFormatter.format(task.endTime)}';
        String details = task.subCategory;

        if (task.mainModule == MainModule.academic && task.subCategory == 'Teaching') {
          details += '\nProg: ${task.programme ?? "-"}';
          details += '\nClass: ${task.className ?? ''} ${task.division ?? ''} - ${task.subject ?? ''}';

          // UPDATED: Inserts a stark notice if the entry is an extra duty
          if (task.isExtraLecture) {
            details += '\n[EXTRA LECTURE]';
          }
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
                onPressed: () => launchUrl(Uri.file(directory!.path)),
              ),
            ),
          );
        }
      } else {
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