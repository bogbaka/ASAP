import 'package:drift/drift.dart';

part 'app_database.g.dart';

class Conversations extends Table {
  TextColumn get id => text()();

  TextColumn get contactName => text()();

  TextColumn get lastMessage =>
      text().withDefault(const Constant(''))();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Messages extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get conversationId => text().references(
        Conversations,
        #id,
        onDelete: KeyAction.cascade,
      )();

  TextColumn get content => text()();

  BoolColumn get isOutgoing => boolean()();

  BoolColumn get isRead =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get sentAt =>
      dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Conversations, Messages])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}