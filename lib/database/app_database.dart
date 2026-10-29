import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Questions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get question => text()();
  TextColumn get optionA => text()();
  TextColumn get optionB => text()();
  TextColumn get optionC => text()();
  TextColumn get optionD => text()();
  IntColumn get answerNumber => integer()(); // 1 = A, 2 = B, 3 = C, 4 = D
}

@DriftDatabase(tables: [Questions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'game_database');
  }

  // Get all questions
  Future<List<Question>> getAllQuestions() => select(questions).get();

  // Watch all questions for real-time updates
  Stream<List<Question>> watchAllQuestions() => select(questions).watch();

  // Insert a single question
  Future<int> insertQuestion(QuestionsCompanion question) =>
      into(questions).insert(question);

  // Batch insert multiple questions
  Future<void> insertAllQuestions(List<QuestionsCompanion> questionList) async {
    await batch((batch) {
      batch.insertAll(questions, questionList);
    });
  }

  // Replace all questions with a new list (useful for fresh import)
  Future<void> replaceAllQuestions(List<QuestionsCompanion> questionList) async {
    await transaction(() async {
      await delete(questions).go();
      await batch((batch) {
        batch.insertAll(questions, questionList);
      });
    });
  }

  // Update a single question
  Future<bool> updateQuestionData({
    required int id,
    required String question,
    required String optionA,
    required String optionB,
    required String optionC,
    required String optionD,
    required int answerNumber,
  }) {
    return (update(questions)..where((tbl) => tbl.id.equals(id))).write(
      QuestionsCompanion(
        question: Value(question),
        optionA: Value(optionA),
        optionB: Value(optionB),
        optionC: Value(optionC),
        optionD: Value(optionD),
        answerNumber: Value(answerNumber),
      ),
    ).then((rows) => rows > 0);
  }

  // Delete all questions
  Future<int> deleteAllQuestions() => delete(questions).go();

  // Delete a single question
  Future<int> deleteQuestionById(int id) =>
      (delete(questions)..where((tbl) => tbl.id.equals(id))).go();
}

// Global database instance
final AppDatabase appDatabase = AppDatabase();
