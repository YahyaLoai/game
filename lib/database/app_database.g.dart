// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $QuestionsTable extends Questions
    with TableInfo<$QuestionsTable, Question> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuestionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _questionMeta = const VerificationMeta(
    'question',
  );
  @override
  late final GeneratedColumn<String> question = GeneratedColumn<String>(
    'question',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _optionAMeta = const VerificationMeta(
    'optionA',
  );
  @override
  late final GeneratedColumn<String> optionA = GeneratedColumn<String>(
    'option_a',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _optionBMeta = const VerificationMeta(
    'optionB',
  );
  @override
  late final GeneratedColumn<String> optionB = GeneratedColumn<String>(
    'option_b',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _optionCMeta = const VerificationMeta(
    'optionC',
  );
  @override
  late final GeneratedColumn<String> optionC = GeneratedColumn<String>(
    'option_c',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _optionDMeta = const VerificationMeta(
    'optionD',
  );
  @override
  late final GeneratedColumn<String> optionD = GeneratedColumn<String>(
    'option_d',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerNumberMeta = const VerificationMeta(
    'answerNumber',
  );
  @override
  late final GeneratedColumn<int> answerNumber = GeneratedColumn<int>(
    'answer_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    question,
    optionA,
    optionB,
    optionC,
    optionD,
    answerNumber,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'questions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Question> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('question')) {
      context.handle(
        _questionMeta,
        question.isAcceptableOrUnknown(data['question']!, _questionMeta),
      );
    } else if (isInserting) {
      context.missing(_questionMeta);
    }
    if (data.containsKey('option_a')) {
      context.handle(
        _optionAMeta,
        optionA.isAcceptableOrUnknown(data['option_a']!, _optionAMeta),
      );
    } else if (isInserting) {
      context.missing(_optionAMeta);
    }
    if (data.containsKey('option_b')) {
      context.handle(
        _optionBMeta,
        optionB.isAcceptableOrUnknown(data['option_b']!, _optionBMeta),
      );
    } else if (isInserting) {
      context.missing(_optionBMeta);
    }
    if (data.containsKey('option_c')) {
      context.handle(
        _optionCMeta,
        optionC.isAcceptableOrUnknown(data['option_c']!, _optionCMeta),
      );
    } else if (isInserting) {
      context.missing(_optionCMeta);
    }
    if (data.containsKey('option_d')) {
      context.handle(
        _optionDMeta,
        optionD.isAcceptableOrUnknown(data['option_d']!, _optionDMeta),
      );
    } else if (isInserting) {
      context.missing(_optionDMeta);
    }
    if (data.containsKey('answer_number')) {
      context.handle(
        _answerNumberMeta,
        answerNumber.isAcceptableOrUnknown(
          data['answer_number']!,
          _answerNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_answerNumberMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Question map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Question(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      question: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question'],
      )!,
      optionA: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}option_a'],
      )!,
      optionB: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}option_b'],
      )!,
      optionC: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}option_c'],
      )!,
      optionD: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}option_d'],
      )!,
      answerNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}answer_number'],
      )!,
    );
  }

  @override
  $QuestionsTable createAlias(String alias) {
    return $QuestionsTable(attachedDatabase, alias);
  }
}

class Question extends DataClass implements Insertable<Question> {
  final int id;
  final String question;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final int answerNumber;
  const Question({
    required this.id,
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.answerNumber,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['question'] = Variable<String>(question);
    map['option_a'] = Variable<String>(optionA);
    map['option_b'] = Variable<String>(optionB);
    map['option_c'] = Variable<String>(optionC);
    map['option_d'] = Variable<String>(optionD);
    map['answer_number'] = Variable<int>(answerNumber);
    return map;
  }

  QuestionsCompanion toCompanion(bool nullToAbsent) {
    return QuestionsCompanion(
      id: Value(id),
      question: Value(question),
      optionA: Value(optionA),
      optionB: Value(optionB),
      optionC: Value(optionC),
      optionD: Value(optionD),
      answerNumber: Value(answerNumber),
    );
  }

  factory Question.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Question(
      id: serializer.fromJson<int>(json['id']),
      question: serializer.fromJson<String>(json['question']),
      optionA: serializer.fromJson<String>(json['optionA']),
      optionB: serializer.fromJson<String>(json['optionB']),
      optionC: serializer.fromJson<String>(json['optionC']),
      optionD: serializer.fromJson<String>(json['optionD']),
      answerNumber: serializer.fromJson<int>(json['answerNumber']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'question': serializer.toJson<String>(question),
      'optionA': serializer.toJson<String>(optionA),
      'optionB': serializer.toJson<String>(optionB),
      'optionC': serializer.toJson<String>(optionC),
      'optionD': serializer.toJson<String>(optionD),
      'answerNumber': serializer.toJson<int>(answerNumber),
    };
  }

  Question copyWith({
    int? id,
    String? question,
    String? optionA,
    String? optionB,
    String? optionC,
    String? optionD,
    int? answerNumber,
  }) => Question(
    id: id ?? this.id,
    question: question ?? this.question,
    optionA: optionA ?? this.optionA,
    optionB: optionB ?? this.optionB,
    optionC: optionC ?? this.optionC,
    optionD: optionD ?? this.optionD,
    answerNumber: answerNumber ?? this.answerNumber,
  );
  Question copyWithCompanion(QuestionsCompanion data) {
    return Question(
      id: data.id.present ? data.id.value : this.id,
      question: data.question.present ? data.question.value : this.question,
      optionA: data.optionA.present ? data.optionA.value : this.optionA,
      optionB: data.optionB.present ? data.optionB.value : this.optionB,
      optionC: data.optionC.present ? data.optionC.value : this.optionC,
      optionD: data.optionD.present ? data.optionD.value : this.optionD,
      answerNumber: data.answerNumber.present
          ? data.answerNumber.value
          : this.answerNumber,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Question(')
          ..write('id: $id, ')
          ..write('question: $question, ')
          ..write('optionA: $optionA, ')
          ..write('optionB: $optionB, ')
          ..write('optionC: $optionC, ')
          ..write('optionD: $optionD, ')
          ..write('answerNumber: $answerNumber')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    question,
    optionA,
    optionB,
    optionC,
    optionD,
    answerNumber,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Question &&
          other.id == this.id &&
          other.question == this.question &&
          other.optionA == this.optionA &&
          other.optionB == this.optionB &&
          other.optionC == this.optionC &&
          other.optionD == this.optionD &&
          other.answerNumber == this.answerNumber);
}

class QuestionsCompanion extends UpdateCompanion<Question> {
  final Value<int> id;
  final Value<String> question;
  final Value<String> optionA;
  final Value<String> optionB;
  final Value<String> optionC;
  final Value<String> optionD;
  final Value<int> answerNumber;
  const QuestionsCompanion({
    this.id = const Value.absent(),
    this.question = const Value.absent(),
    this.optionA = const Value.absent(),
    this.optionB = const Value.absent(),
    this.optionC = const Value.absent(),
    this.optionD = const Value.absent(),
    this.answerNumber = const Value.absent(),
  });
  QuestionsCompanion.insert({
    this.id = const Value.absent(),
    required String question,
    required String optionA,
    required String optionB,
    required String optionC,
    required String optionD,
    required int answerNumber,
  }) : question = Value(question),
       optionA = Value(optionA),
       optionB = Value(optionB),
       optionC = Value(optionC),
       optionD = Value(optionD),
       answerNumber = Value(answerNumber);
  static Insertable<Question> custom({
    Expression<int>? id,
    Expression<String>? question,
    Expression<String>? optionA,
    Expression<String>? optionB,
    Expression<String>? optionC,
    Expression<String>? optionD,
    Expression<int>? answerNumber,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (question != null) 'question': question,
      if (optionA != null) 'option_a': optionA,
      if (optionB != null) 'option_b': optionB,
      if (optionC != null) 'option_c': optionC,
      if (optionD != null) 'option_d': optionD,
      if (answerNumber != null) 'answer_number': answerNumber,
    });
  }

  QuestionsCompanion copyWith({
    Value<int>? id,
    Value<String>? question,
    Value<String>? optionA,
    Value<String>? optionB,
    Value<String>? optionC,
    Value<String>? optionD,
    Value<int>? answerNumber,
  }) {
    return QuestionsCompanion(
      id: id ?? this.id,
      question: question ?? this.question,
      optionA: optionA ?? this.optionA,
      optionB: optionB ?? this.optionB,
      optionC: optionC ?? this.optionC,
      optionD: optionD ?? this.optionD,
      answerNumber: answerNumber ?? this.answerNumber,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (question.present) {
      map['question'] = Variable<String>(question.value);
    }
    if (optionA.present) {
      map['option_a'] = Variable<String>(optionA.value);
    }
    if (optionB.present) {
      map['option_b'] = Variable<String>(optionB.value);
    }
    if (optionC.present) {
      map['option_c'] = Variable<String>(optionC.value);
    }
    if (optionD.present) {
      map['option_d'] = Variable<String>(optionD.value);
    }
    if (answerNumber.present) {
      map['answer_number'] = Variable<int>(answerNumber.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuestionsCompanion(')
          ..write('id: $id, ')
          ..write('question: $question, ')
          ..write('optionA: $optionA, ')
          ..write('optionB: $optionB, ')
          ..write('optionC: $optionC, ')
          ..write('optionD: $optionD, ')
          ..write('answerNumber: $answerNumber')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $QuestionsTable questions = $QuestionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [questions];
}

typedef $$QuestionsTableCreateCompanionBuilder =
    QuestionsCompanion Function({
      Value<int> id,
      required String question,
      required String optionA,
      required String optionB,
      required String optionC,
      required String optionD,
      required int answerNumber,
    });
typedef $$QuestionsTableUpdateCompanionBuilder =
    QuestionsCompanion Function({
      Value<int> id,
      Value<String> question,
      Value<String> optionA,
      Value<String> optionB,
      Value<String> optionC,
      Value<String> optionD,
      Value<int> answerNumber,
    });

class $$QuestionsTableFilterComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get optionA => $composableBuilder(
    column: $table.optionA,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get optionB => $composableBuilder(
    column: $table.optionB,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get optionC => $composableBuilder(
    column: $table.optionC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get optionD => $composableBuilder(
    column: $table.optionD,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get answerNumber => $composableBuilder(
    column: $table.answerNumber,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuestionsTableOrderingComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionA => $composableBuilder(
    column: $table.optionA,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionB => $composableBuilder(
    column: $table.optionB,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionC => $composableBuilder(
    column: $table.optionC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionD => $composableBuilder(
    column: $table.optionD,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get answerNumber => $composableBuilder(
    column: $table.answerNumber,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuestionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get question =>
      $composableBuilder(column: $table.question, builder: (column) => column);

  GeneratedColumn<String> get optionA =>
      $composableBuilder(column: $table.optionA, builder: (column) => column);

  GeneratedColumn<String> get optionB =>
      $composableBuilder(column: $table.optionB, builder: (column) => column);

  GeneratedColumn<String> get optionC =>
      $composableBuilder(column: $table.optionC, builder: (column) => column);

  GeneratedColumn<String> get optionD =>
      $composableBuilder(column: $table.optionD, builder: (column) => column);

  GeneratedColumn<int> get answerNumber => $composableBuilder(
    column: $table.answerNumber,
    builder: (column) => column,
  );
}

class $$QuestionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuestionsTable,
          Question,
          $$QuestionsTableFilterComposer,
          $$QuestionsTableOrderingComposer,
          $$QuestionsTableAnnotationComposer,
          $$QuestionsTableCreateCompanionBuilder,
          $$QuestionsTableUpdateCompanionBuilder,
          (Question, BaseReferences<_$AppDatabase, $QuestionsTable, Question>),
          Question,
          PrefetchHooks Function()
        > {
  $$QuestionsTableTableManager(_$AppDatabase db, $QuestionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuestionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuestionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuestionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> question = const Value.absent(),
                Value<String> optionA = const Value.absent(),
                Value<String> optionB = const Value.absent(),
                Value<String> optionC = const Value.absent(),
                Value<String> optionD = const Value.absent(),
                Value<int> answerNumber = const Value.absent(),
              }) => QuestionsCompanion(
                id: id,
                question: question,
                optionA: optionA,
                optionB: optionB,
                optionC: optionC,
                optionD: optionD,
                answerNumber: answerNumber,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String question,
                required String optionA,
                required String optionB,
                required String optionC,
                required String optionD,
                required int answerNumber,
              }) => QuestionsCompanion.insert(
                id: id,
                question: question,
                optionA: optionA,
                optionB: optionB,
                optionC: optionC,
                optionD: optionD,
                answerNumber: answerNumber,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$QuestionsTable, Question>(table),
                  BaseReferences<_$AppDatabase, $QuestionsTable, Question>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QuestionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuestionsTable,
      Question,
      $$QuestionsTableFilterComposer,
      $$QuestionsTableOrderingComposer,
      $$QuestionsTableAnnotationComposer,
      $$QuestionsTableCreateCompanionBuilder,
      $$QuestionsTableUpdateCompanionBuilder,
      (Question, BaseReferences<_$AppDatabase, $QuestionsTable, Question>),
      Question,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$QuestionsTableTableManager get questions =>
      $$QuestionsTableTableManager(_db, _db.questions);
}
