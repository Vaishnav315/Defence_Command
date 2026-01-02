import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class MissionUploadService {
  SupabaseClient? _client;

  // Configuration
  static const String _supabaseUrl = 'https://hhtzahiufhfsqzzbhfwb.supabase.co';
  static const String _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhodHphaGl1Zmhmc3F6emJoZndiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjczNTUxMDEsImV4cCI6MjA4MjkzMTEwMX0.tQIj0E95GAbxUF_wctv6jnZ2bLlKKhVAJJ4JIKk1PM8';
  static const String _bucketName = 'drone_videos';

  /// Step A: Initialize Supabase
  Future<void> init() async {
    try {
      if (_client == null) {
        await Supabase.initialize(
          url: _supabaseUrl,
          anonKey: _supabaseAnonKey,
        );
        _client = Supabase.instance.client;
      }
    } catch (e) {
      // If already initialized, we just get the client
      _client = Supabase.instance.client;
    }
  }

  /// Step B: Upload Video (File-based, Mobile)
  Future<String> uploadVideo(dynamic videoSource) async {
    if (videoSource is Uint8List) {
      return uploadVideoData(videoSource);
    } else {
      // We keep File support but wrap it to avoid crashes on web if not used
      return uploadVideoData(await (videoSource as dynamic).readAsBytes());
    }
  }

  /// Step B2: Upload Video Data (Platform-agnostic)
  Future<String> uploadVideoData(Uint8List bytes) async {
    if (_client == null) await init();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'mission_$timestamp.mp4';

    try {
      await _client!.storage.from(_bucketName).uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: false, contentType: 'video/mp4'),
          );

      final publicUrl =
          _client!.storage.from(_bucketName).getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload video: $e');
    }
  }

  /// Step C: Filter GPS Data (Throttling)
  /// Returns a list containing only one GPS point every 2 seconds
  List<Map> filterGpsData(List<Map> rawLogs) {
    if (rawLogs.isEmpty) return [];

    final List<Map> filteredLogs = [];
    int lastSavedTimestamp = 0;

    for (var log in rawLogs) {
      // Assuming each log has a 'timestamp' key (milliseconds since epoch)
      // If 'timestamp' is missing, we skip the log to be safe
      if (!log.containsKey('timestamp')) continue;

      final dynamic rawTime = log['timestamp'];
      int currentTimestamp;

      try {
        if (rawTime is int) {
          currentTimestamp = rawTime;
        } else if (rawTime is String) {
          currentTimestamp = DateTime.parse(rawTime).millisecondsSinceEpoch;
        } else {
          continue; // Unknown format
        }
      } catch (e) {
        continue; // Parse error
      }

      // Logic: Only keep a point if (current_timestamp - last_saved_timestamp >= 2000ms)
      // Check difference. For the first valid point, lastSavedTimestamp is 0,
      // so currentTimestamp - 0 will be huge (assuming valid epoch), so it will save.
      if (currentTimestamp - lastSavedTimestamp >= 2000) {
        filteredLogs.add(log);
        lastSavedTimestamp = currentTimestamp;
      }
    }
    return filteredLogs;
  }

  /// Step D: Sync Mission Data
  Future<void> syncMissionData(dynamic videoFile, List<Map> rawGpsLogs) async {
    try {
      // 1. Upload Video
      final videoUrl = await uploadVideo(videoFile);

      // 2. Filter GPS Data
      final filteredLogs = filterGpsData(rawGpsLogs);

      // 3. Construct JSON Object
      final result = {
        "video_url": videoUrl,
        "gps_logs": filteredLogs,
        "timestamp": DateTime.now().toIso8601String(),
      };

      // 4. Print JSON to console
      // ignore: avoid_print
      print(result);
    } catch (e) {
      // ignore: avoid_print
      print('Error syncing mission data: $e');
    }
  }
}
