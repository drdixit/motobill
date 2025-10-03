import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

// Provider for the database instance
final databaseProvider = Provider<Future<Database>>((ref) async {
  // Use the fixed database path
  const databasePath = 'C:\\motobill\\database\\motobill.db';

  return await openDatabase(databasePath, version: 1);
});
