import 'package:drift_flutter/drift_flutter.dart';

import 'app_database.dart';

/// Shared local database used by ASAP.
final AppDatabase appDatabase = AppDatabase(
  driftDatabase(
    name: 'asap_database',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  ),
);