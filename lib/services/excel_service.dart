import 'package:drift/drift.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:game/data.dart' as default_data;
import 'package:game/database/app_database.dart';

class ExcelService {
  /// Allows the user to pick an Excel file (.xlsx / .xls) and import questions into Drift DB.
  /// Structure expected: question, a, b, c, d, anwser_number
  static Future<int> pickAndImportQuestions({bool replaceExisting = true}) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (file == null) {
      return 0; // User cancelled
    }

    final bytes = await file.readAsBytes();

    final questionsToInsert = parseExcelBytes(bytes);

    if (questionsToInsert.isEmpty) {
      throw Exception('لم يتم العثور على أي أسئلة صالحة في الملف.');
    }

    if (replaceExisting) {
      await appDatabase.replaceAllQuestions(questionsToInsert);
    } else {
      await appDatabase.insertAllQuestions(questionsToInsert);
    }

    return questionsToInsert.length;
  }

  /// Parses bytes of an Excel file into a list of QuestionsCompanion
  static List<QuestionsCompanion> parseExcelBytes(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final List<QuestionsCompanion> list = [];

    // Find the first sheet with data
    for (var tableName in excel.tables.keys) {
      final sheet = excel.tables[tableName];
      if (sheet == null || sheet.maxRows == 0) continue;

      int questionCol = -1;
      int aCol = -1;
      int bCol = -1;
      int cCol = -1;
      int dCol = -1;
      int answerCol = -1;
      int startRow = 0;

      // Check if row 0 is header
      if (sheet.maxRows > 0) {
        final firstRow = sheet.rows.first;
        for (int c = 0; c < firstRow.length; c++) {
          final cellValue = firstRow[c]?.value?.toString().trim().toLowerCase() ?? '';
          if (cellValue.contains('question') || cellValue.contains('سؤال')) {
            questionCol = c;
          } else if (cellValue == 'a' || cellValue == 'أ' || cellValue == 'option a' || cellValue == 'option_a') {
            aCol = c;
          } else if (cellValue == 'b' || cellValue == 'ب' || cellValue == 'option b' || cellValue == 'option_b') {
            bCol = c;
          } else if (cellValue == 'c' || cellValue == 'ج' || cellValue == 'option c' || cellValue == 'option_c') {
            cCol = c;
          } else if (cellValue == 'd' || cellValue == 'د' || cellValue == 'option d' || cellValue == 'option_d') {
            dCol = c;
          } else if (cellValue.contains('anwser') ||
              cellValue.contains('answer') ||
              cellValue.contains('إجابة') ||
              cellValue.contains('اجابة')) {
            answerCol = c;
          }
        }

        // If header was detected, data starts from row 1
        if (questionCol != -1) {
          startRow = 1;
        }
      }

      // Fallbacks if columns weren't identified by header names
      if (questionCol == -1) questionCol = 0;
      if (aCol == -1) aCol = 1;
      if (bCol == -1) bCol = 2;
      if (cCol == -1) cCol = 3;
      if (dCol == -1) dCol = 4;
      if (answerCol == -1) answerCol = 5;

      for (int r = startRow; r < sheet.maxRows; r++) {
        final row = sheet.rows[r];
        if (row.isEmpty) continue;

        String getCellText(int col) {
          if (col < 0 || col >= row.length) return '';
          final cell = row[col];
          if (cell == null || cell.value == null) return '';
          return cell.value.toString().trim();
        }

        final qText = getCellText(questionCol);
        if (qText.isEmpty) continue;

        final optA = getCellText(aCol);
        final optB = getCellText(bCol);
        final optC = getCellText(cCol);
        final optD = getCellText(dCol);
        final ansRaw = getCellText(answerCol).toLowerCase();

        // Determine answer number (1..4)
        int answerNum = 1;
        if (ansRaw == '1' || ansRaw == 'a' || ansRaw == 'أ') {
          answerNum = 1;
        } else if (ansRaw == '2' || ansRaw == 'b' || ansRaw == 'ب') {
          answerNum = 2;
        } else if (ansRaw == '3' || ansRaw == 'c' || ansRaw == 'ج') {
          answerNum = 3;
        } else if (ansRaw == '4' || ansRaw == 'd' || ansRaw == 'د') {
          answerNum = 4;
        } else {
          // If numeric double like 1.0
          final parsed = double.tryParse(ansRaw)?.toInt();
          if (parsed != null && parsed >= 1 && parsed <= 4) {
            answerNum = parsed;
          }
        }

        list.add(
          QuestionsCompanion(
            question: Value(qText),
            optionA: Value(optA),
            optionB: Value(optB),
            optionC: Value(optC),
            optionD: Value(optD),
            answerNumber: Value(answerNum),
          ),
        );
      }

      // If we found questions in this sheet, don't need to parse other sheets
      if (list.isNotEmpty) break;
    }

    return list;
  }

  /// Seeds default questions from lib/data.dart if the database is currently empty
  static Future<void> seedDefaultQuestionsIfEmpty() async {
    final existing = await appDatabase.getAllQuestions();
    if (existing.isEmpty) {
      final List<QuestionsCompanion> seeds = [];
      for (final item in default_data.questions) {
        final q = item['question']?.toString() ?? '';
        final options = (item['options'] as List?)?.map((e) => e.toString()).toList() ?? [];
        final ans = item['answer']?.toString() ?? '';

        final optA = options.isNotEmpty ? options[0] : '';
        final optB = options.length > 1 ? options[1] : '';
        final optC = options.length > 2 ? options[2] : '';
        final optD = options.length > 3 ? options[3] : '';

        int ansNum = 1;
        if (ans == optB) ansNum = 2;
        if (ans == optC) ansNum = 3;
        if (ans == optD) ansNum = 4;

        seeds.add(
          QuestionsCompanion(
            question: Value(q),
            optionA: Value(optA),
            optionB: Value(optB),
            optionC: Value(optC),
            optionD: Value(optD),
            answerNumber: Value(ansNum),
          ),
        );
      }
      if (seeds.isNotEmpty) {
        await appDatabase.insertAllQuestions(seeds);
      }
    }
  }

  /// Exports all questions in the database to an Excel file using the same structure:
  /// question, a, b, c, d, anwser_number
  static Future<bool> exportQuestionsToExcel() async {
    final questions = await appDatabase.getAllQuestions();
    if (questions.isEmpty) {
      throw Exception('لا توجد أسئلة في قاعدة البيانات لتصديرها.');
    }

    final excel = Excel.createExcel();
    final sheetName = excel.getDefaultSheet() ?? 'Sheet1';
    final sheet = excel[sheetName];

    // Header row
    sheet.appendRow([
      TextCellValue('question'),
      TextCellValue('a'),
      TextCellValue('b'),
      TextCellValue('c'),
      TextCellValue('d'),
      TextCellValue('anwser_number'),
    ]);

    // Questions rows
    for (final q in questions) {
      sheet.appendRow([
        TextCellValue(q.question),
        TextCellValue(q.optionA),
        TextCellValue(q.optionB),
        TextCellValue(q.optionC),
        TextCellValue(q.optionD),
        IntCellValue(q.answerNumber),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('فشل في إنشاء ملف الـ Excel.');
    }

    final uri = await FilePicker.saveFile(
      dialogTitle: 'اختر مكان حفظ ملف الأسئلة',
      fileName: 'questions.xlsx',
      bytes: Uint8List.fromList(bytes),
    );

    return uri != null;
  }
}
