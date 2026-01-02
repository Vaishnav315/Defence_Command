import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class ApiService {
  // Global Base URL (Ngrok)
  static const String baseUrl = "https://flabbergastedly-censerless-tanna.ngrok-free.dev";
  static const String livekitUrl = "$baseUrl/livekit";

  // Create a custom client that ignores bad certificates
  // Create a custom client that ignores bad certificates
  // Create a custom client with interceptor or just use a helper?
  // Simpler: Just update the requests below.
  static final http.Client client = _createClient();

  static http.Client _createClient() {
    final ioc = HttpClient()
      ..idleTimeout = const Duration(seconds: 30)
      ..maxConnectionsPerHost = 10
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return IOClient(ioc);
  }

  // --- WEATHER ENDPOINTS ---
  static Future<Map<String, dynamic>?> fetchWeatherAt(double lat, double lng) async {
    final url = Uri.parse("https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lng&appid=73d1d347e5e9cf2437c3c371525f236b&units=metric");
    try {
      final response = await client.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Weather Fetch Error: $e");
    }
    return null;
  }


  // --- MAPPING ENDPOINTS ---

  // Start Mapping: Changed from GET query params to POST JSON body
  static Future<bool> startMapping(String identity) async {
    final url = Uri.parse('$baseUrl/map/start');
    try {
      final response = await client.post(
        url,
        headers: {"Content-Type": "application/json", "ngrok-skip-browser-warning": "true"},
        body: jsonEncode({"identity": identity}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Stop Mapping: Changed from GET query params to POST JSON body
  static Future<bool> stopMapping(String identity) async {
    final url = Uri.parse('$baseUrl/map/stop');
    try {
      final response = await client.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"identity": identity}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Get Map Image URL (GET) with cache buster
  static String getMapImageUrl(String identity) {
    // Append timestamp to bypass cache
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$baseUrl/map/image?identity=$identity&t=$timestamp';
  }

  // --- NAVIGATION ENDPOINTS ---
  
  // Tactical Path Calculation
  static String get calculatePathUrl => '$baseUrl/nav/calculate';

  // --- AI COMMANDER ENDPOINTS ---
  static String get getAiBriefingUrl => '$baseUrl/ai/briefing';

  // --- TACTICAL PINS ENDPOINT ---
  static Future<List<TacticalPin>> getTacticalPins() async {
    final url = Uri.parse('$baseUrl/tactical/pins');
    try {
      final response = await client.get(url, headers: {"ngrok-skip-browser-warning": "true"});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> pinsJson = data['pins'] ?? [];
        return pinsJson.map((json) => TacticalPin.fromJson(json)).toList();
      }
    } catch (e) {
      // Fail silently or log error
      print('Error fetching tactical pins: $e');
    }
    return [];
  }


  // --- FETCH HELPERS ---

  static Future<List<AlertData>> fetchAlerts() async {
    final url = Uri.parse('${ApiService.baseUrl}/tactical/alerts');
    try {
      final response = await ApiService.client.get(url, headers: {"ngrok-skip-browser-warning": "true"});
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((e) => AlertData.fromJson(e)).toList();
      }
    } catch (e) {
      print("Alerts Error: $e");
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchUnitDetails() async {
    final url = Uri.parse('${ApiService.baseUrl}/tactical/details');
    try {
      final response = await ApiService.client.get(url, headers: {"ngrok-skip-browser-warning": "true"});
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      print("Details Error: $e");
    }
    return [];
  }

  static Future<List<ChatData>> fetchChatMessages() async {
    final url = Uri.parse('${ApiService.baseUrl}/tactical/chat');
    try {
      final response = await ApiService.client.get(url, headers: {"ngrok-skip-browser-warning": "true"});
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((e) => ChatData.fromJson(e)).toList();
      }
    } catch (e) {
       print("Chat Error: $e");
    }
    return [];
  }

  static Future<bool> sendChatMessage(String sender, String message) async {
    final url = Uri.parse('${ApiService.baseUrl}/tactical/chat');
    try {
      final now = DateTime.now();
      final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      
      final body = jsonEncode({
        "sender": sender,
        "message": message,
        "time": timeStr,
      });

      final response = await ApiService.client.post(
        url, 
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "true"
        },
        body: body
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print("Send Chat Error: $e");
      return false;
    }
  }

  static Future<bool> deleteChatMessage(String id) async {
    final url = Uri.parse('${ApiService.baseUrl}/tactical/chat/$id');
    try {
      final response = await ApiService.client.delete(url, headers: {"ngrok-skip-browser-warning": "true"});
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> editChatMessage(String id, String newText) async {
    final url = Uri.parse('${ApiService.baseUrl}/tactical/chat/$id');
    try {
      final body = jsonEncode({
        "sender": "Commander", // Sender not changed, but required by model
        "message": newText,
        "time": "Updated"
      });
      
      final response = await ApiService.client.put(
        url, 
        headers: {"Content-Type": "application/json", "ngrok-skip-browser-warning": "true"},
        body: body
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- MISSION HISTORY ENDPOINTS ---
  static Future<List<MissionHistory>> fetchMissionHistory() async {
    final url = Uri.parse('$baseUrl/mission/history');
    try {
      final response = await client.get(url, headers: {"ngrok-skip-browser-warning": "true"});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> list = data['history'] ?? [];
        return list.map((e) => MissionHistory.fromJson(e)).toList();
      }
    } catch (e) {
      print("Mission History Error: $e");
    }
    return [];
  }

  static Future<bool> clearMissionHistory() async {
    final url = Uri.parse('$baseUrl/mission/clear');
    try {
      final response = await client.delete(url, headers: {"ngrok-skip-browser-warning": "true"});
      return response.statusCode == 200;
    } catch (e) {
      print("Clear Mission Error: $e");
      return false;
    }
  }
} // End ApiService
class TacticalPin {
  final double lat;
  final double lng;
  final String type;
  final String reporterId;

  TacticalPin({
    required this.lat, 
    required this.lng, 
    required this.type,
    this.reporterId = '',
  });

  factory TacticalPin.fromJson(Map<String, dynamic> json) {
    return TacticalPin(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      type: json['type'] as String,
      reporterId: json['reporter_id'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TacticalPin &&
          runtimeType == other.runtimeType &&
          lat == other.lat &&
          lng == other.lng &&
          type == other.type &&
          reporterId == other.reporterId;

  @override
  int get hashCode => lat.hashCode ^ lng.hashCode ^ type.hashCode ^ reporterId.hashCode;
}

// --- NEW MODELS ---

class AlertData {
  final String title;
  final String message;
  final String time;

  AlertData({required this.title, required this.message, required this.time});

  factory AlertData.fromJson(Map<String, dynamic> json) {
    return AlertData(
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      time: json['time'] ?? '',
    );
  }
}

class ChatData {
  final String id;
  final String sender;
  final String message;
  final String time;

  ChatData({this.id = '', required this.sender, required this.message, required this.time});

  factory ChatData.fromJson(Map<String, dynamic> json) {
    return ChatData(
      id: json['id'] ?? '',
      sender: json['sender'] ?? '',
      message: json['message'] ?? '',
      time: json['time'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatData &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          sender == other.sender &&
          message == other.message &&
          time == other.time;

  @override
  int get hashCode => id.hashCode ^ sender.hashCode ^ message.hashCode ^ time.hashCode;
}

class MissionHistory {
  final int id;
  final String scoutId;
  final String videoUrl;
  final String syncTimestamp;
  final String missionTimestamp;
  final List<MissionGpsLog> gpsLogs;

  MissionHistory({
    required this.id,
    required this.scoutId,
    required this.videoUrl,
    required this.syncTimestamp,
    required this.missionTimestamp,
    required this.gpsLogs,
  });

  factory MissionHistory.fromJson(Map<String, dynamic> json) {
    return MissionHistory(
      id: json['id'] ?? 0,
      scoutId: json['scout_id'] ?? '',
      videoUrl: json['video_url'] ?? '',
      syncTimestamp: json['sync_timestamp'] ?? '',
      missionTimestamp: json['mission_timestamp'] ?? '',
      gpsLogs: (json['gps_logs'] as List? ?? [])
          .map((e) => MissionGpsLog.fromJson(e))
          .toList(),
    );
  }
}

class MissionGpsLog {
  final double lat;
  final double lng;
  final String timestamp;

  MissionGpsLog({required this.lat, required this.lng, required this.timestamp});

  factory MissionGpsLog.fromJson(Map<String, dynamic> json) {
    return MissionGpsLog(
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] ?? '',
    );
  }
}
