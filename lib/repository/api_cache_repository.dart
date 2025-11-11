import 'package:sqflite_common/sqflite.dart';

class ApiCacheRepository {
  final Database _db;

  ApiCacheRepository(this._db);

  /// Check if a cached response exists for the given file hash
  Future<String?> getCachedResponse(String fileHash) async {
    try {
      final result = await _db.rawQuery(
        'SELECT api_response FROM api_response_cache WHERE file_hash = ?',
        [fileHash],
      );

      if (result.isNotEmpty) {
        return result.first['api_response'] as String;
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching cached response: $e');
    }
  }

  /// Store a new API response with its file hash
  Future<void> cacheResponse(String fileHash, String apiResponse) async {
    try {
      await _db.rawInsert(
        '''
        INSERT INTO api_response_cache (file_hash, api_response, created_at, updated_at)
        VALUES (?, ?, datetime('now', 'localtime'), datetime('now', 'localtime'))
        ON CONFLICT(file_hash)
        DO UPDATE SET
          api_response = excluded.api_response,
          updated_at = datetime('now', 'localtime')
        ''',
        [fileHash, apiResponse],
      );
    } catch (e) {
      throw Exception('Error caching response: $e');
    }
  }

  /// Clear all cached responses (optional utility method)
  Future<void> clearCache() async {
    try {
      await _db.rawDelete('DELETE FROM api_response_cache');
    } catch (e) {
      throw Exception('Error clearing cache: $e');
    }
  }

  /// Get cache statistics (optional utility method)
  Future<int> getCacheCount() async {
    try {
      final result = await _db.rawQuery(
        'SELECT COUNT(*) as count FROM api_response_cache',
      );
      return result.first['count'] as int;
    } catch (e) {
      throw Exception('Error getting cache count: $e');
    }
  }
}
