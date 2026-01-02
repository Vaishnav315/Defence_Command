import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../services/livekit_service.dart';
import '../services/api_service.dart';

class MapEntity {
  final String id;
  final String type; // 'soldier', 'uav', 'scout'
  final LatLng position;
  final String? reporterId;
  
  MapEntity({
    required this.id, 
    required this.type, 
    required this.position,
    this.reporterId,
  });
}

class EntityProvider extends ChangeNotifier {
  final Map<String, MapEntity> _entities = {};
  LiveKitService? _liveKitService;
  StreamSubscription? _dataSubscription;
  StreamSubscription? _disconnectSubscription;

  List<MapEntity> get entities => _entities.values.toList();

  // NEW: State for Alerts and Details
  List<AlertData> _alerts = [];
  List<Map<String, dynamic>> _unitDetails = [
      {'label': 'Soldiers', 'count': 0},
      {'label': 'Tanks', 'count': 0},
      {'label': 'UAVs', 'count': 0},
      {'label': 'Artillery', 'count': 0},
  ];
  List<ChatData> _chatMessages = []; 
  final Set<String> _hiddenMessageIds = {}; 
  final Set<String> _hiddenContentHashes = {}; // Fallback
  Timer? _pollingTimer;

  bool _hasLoadedInitialHistory = false; // Ephemeral logic
  final DateTime _startTime = DateTime.now();
  
  List<AlertData> get alerts => _alerts;
  List<Map<String, dynamic>> get unitDetails => _unitDetails;
  List<ChatData> get chatMessages => _chatMessages; // NEW
  
  
  bool _hasUnreadMessages = false;
  bool get hasUnreadMessages => _hasUnreadMessages;
  
  bool _isChatOpen = false; 
  bool get isChatOpen => _isChatOpen;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  void setChatOpen(bool value) {
    _isChatOpen = value;
    if (value) {
      _hasUnreadMessages = false;
      _unreadCount = 0;
    }
    notifyListeners();
  }
  
  void markChatAsRead() {
    _hasUnreadMessages = false;
    _unreadCount = 0;
    notifyListeners();
  }
  
  EntityProvider() {
    _generateEntities();
    _startPolling();
  }
  
  void updateLiveKitService(LiveKitService service) {
    if (_liveKitService == service) return;
    
    _liveKitService = service;
    
    _dataSubscription?.cancel();
    _disconnectSubscription?.cancel();

    _dataSubscription = _liveKitService?.dataStream.listen(_handleLiveKitData);
    _disconnectSubscription = _liveKitService?.onParticipantDisconnected.listen(_handleParticipantDisconnect);
  }
  
  void _startPolling() {
    // Poll fast for pins (2s), slower for others? Or just 2s common?
    // Let's do 2s for all for responsiveness.
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchGlobalData());
  }

  Future<void> _fetchGlobalData() async {
    try {
      final newAlerts = await ApiService.fetchAlerts();
      final newDetails = await ApiService.fetchUnitDetails();
      final newChat = await ApiService.fetchChatMessages();
      
      _alerts = newAlerts;
      // Only update details if we got data, otherwise keep "0" placeholders intact
      if (newDetails.isNotEmpty) {
          _unitDetails = newDetails;
      }
      
      if (newChat.isNotEmpty) {
         // Merge Strategy: TRUST SERVER, but Keep Local Optimistic Updates
         // 1. Start with Server Information
         final List<ChatData> merged = List.from(newChat);
         
         // 2. Add any local messages not present in server list (Optimistic persistence)
         for (var localMsg in _chatMessages) {
            if (!merged.contains(localMsg)) {
               merged.add(localMsg);
            }
         }
         


         // SESSION VIEW LOGIC: Hide initial load
         if (!_hasLoadedInitialHistory) {
             final cutoff = _startTime.subtract(const Duration(seconds: 30));
             
             for (var msg in merged) {
                 // CRITICAL FIX: Only hide messages that we DON'T already have locally AND are older than buffer.
                 // If we have it locally (via LiveKit or Optimistic Send), it's "live" for this session.
                 bool isLocallyKnown = _chatMessages.any((local) => 
                    (local.id.isNotEmpty && local.id == msg.id) || 
                    (local.sender == msg.sender && local.time == msg.time && local.message == msg.message)
                 );
                 
                 // PARSE TIME for reliable "Recent Message" check
                 bool isRecent = false;
                 try {
                     // formats are usually HH:mm, so we assume today. 
                     // If standard ISO, we parse fully. The app seems to use HH:mm.
                     // Since we only have HH:mm, this is imperfect for "30s ago" if across midnight or simplified.
                     // FALLBACK: If we rely on backend ID/timestamp if available? 
                     // The `msg.time` is a string "HH:mm".
                     // This simple check might be "good enough" if we just allow ALL initial messages if they match current "HH:mm"?
                     // BETTER: Just allow ALL messages if they are the *very last* one?
                     // requested: "just like i get a red dot... sometimes the first msg... is not appearing"
                     // The user wants 'session only' but 'race condition' fixed.
                     // Let's assume 'isRecent' if it matches current HH:mm?
                     final now = DateTime.now();
                     final msgTimeParts = msg.time.split(':'); // HH:mm
                     if (msgTimeParts.length == 2) {
                        final msgH = int.parse(msgTimeParts[0]);
                        final msgM = int.parse(msgTimeParts[1]);
                        // If same hour and minute (or previous minute), let it through?
                        // Simple robust check: if msg.time == now.time OR msg.time == now-1min.time
                        final timeStrNow = "${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}";
                        final timeStrPrev = "${now.subtract(const Duration(minutes: 1)).hour.toString().padLeft(2,'0')}:${now.subtract(const Duration(minutes: 1)).minute.toString().padLeft(2,'0')}";
                        if (msg.time == timeStrNow || msg.time == timeStrPrev) {
                           isRecent = true;
                        }
                     }
                 } catch(_) {}

                 if (!isLocallyKnown && !isRecent) {
                     if (msg.id.isNotEmpty) _hiddenMessageIds.add(msg.id.trim());
                     _hiddenContentHashes.add("${msg.sender}_${msg.time}_${msg.message}");
                 }
             }
             _hasLoadedInitialHistory = true;
         }

         // 2.5 Filter Hidden Messages
         merged.removeWhere((msg) {
            if (msg.id.isNotEmpty && _hiddenMessageIds.contains(msg.id.trim())) return true;
            String hash = "${msg.sender}_${msg.time}_${msg.message}";
            if (_hiddenContentHashes.contains(hash)) return true;
            return false;
         });
         
         // 3. Update Notification State
         int newCount = 0;
         if (merged.length > _chatMessages.length) {
            int diff = merged.length - _chatMessages.length;
            if (!_isChatOpen) {
               _hasUnreadMessages = true;
               _unreadCount += diff; 
            }
         }
         
         _chatMessages = merged;
      }
      
      await _fetchTacticalPins(); // Fetch pins from backend

    } catch (e) {
      // debugPrint("Provider Poll Error (Using Mocks): $e");
    } finally {
      notifyListeners();
    }
  }

  void clearAlerts() {
    _alerts = [];
    notifyListeners();
  }

  Future<void> _fetchTacticalPins() async {
    final url = Uri.parse("${ApiService.baseUrl}/tactical/pins");
    try {
      final response = await ApiService.client.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> pinsJson = data['pins'] ?? [];
        
        final Set<String> activeIds = {};

        for (var pinJson in pinsJson) {
           double? lat = double.tryParse(pinJson['lat'].toString());
           double? lng = double.tryParse(pinJson['lng'].toString());
           if (lat == null || lng == null) continue;

           String type = (pinJson['type'] as String? ?? 'soldier').toLowerCase();
           String reporterId = pinJson['reporter_id'] ?? 'Unknown';
           // FIX: Use Unique ID from Backend, fallback to reporterId only if missing (shouldn't happen)
           String id = pinJson['id'] ?? reporterId;

           activeIds.add(id);

           // Update or Add
           _entities[id] = MapEntity(
              id: id,
              type: type,
              position: LatLng(lat, lng),
              reporterId: reporterId,
           );
        }
        
        // FIX: Sync with backend by removing stale entities (Fixes Undo)
        // Ensure we don't accidentally wipe valid ones.
        _entities.removeWhere((key, value) => !activeIds.contains(key));
     }
    } catch (e) {
      // ignore
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _dataSubscription?.cancel();
    _disconnectSubscription?.cancel();
    super.dispose();
  }

  void _handleParticipantDisconnect(String identity) {
    if (_entities.containsKey(identity)) {
      _entities.remove(identity);
      notifyListeners();
      debugPrint('Entity removed: $identity');
    }
  }

  void _generateEntities() {
    _entities.clear();
    _alerts = [];
    _unitDetails = [];
    notifyListeners();
  }

  // NEW: Sync with backend data
  void updateFromTacticalPins(List<Map<String, dynamic>> pins) {
    // ... existing logic ...
    
    final Set<String> activeIds = {};

    for (var pin in pins) {
      final String id = pin['id'] ?? pin['reporterId'] ?? "Unknown-${pin.hashCode}"; // Fix ID usage
      final String type = pin['type'] ?? 'soldier';
      final double lat = pin['lat'] ?? 0.0;
      final double lng = pin['lng'] ?? 0.0;
      final pos = LatLng(lat, lng);
      
      activeIds.add(id);

      _entities[id] = MapEntity(
        id: id,
        type: type.toLowerCase(),
        position: pos,
      );
    }
    
    _entities.removeWhere((key, value) => !activeIds.contains(key));
    notifyListeners();
  }

  void _handleLiveKitData(Map<String, dynamic> data) {
    // Expected: {"id": "Scout-1", "lat": ..., "long": ...}
    if (data.containsKey('id') && data.containsKey('lat') && data.containsKey('long')) {
      final String id = data['id'];
      final double lat = data['lat'] is String ? double.parse(data['lat']) : data['lat'].toDouble();
      final double long = data['long'] is String ? double.parse(data['long']) : data['long'].toDouble();
      
      String type = 'soldier';
      if (data.containsKey('type')) {
        type = data['type'].toString().toLowerCase();
      } else {
        if (id.toLowerCase().contains('uav')) {
          type = 'uav';
        } else if (id.toLowerCase().contains('scout')) {
          type = 'scout';
        } else if (id.toLowerCase().contains('tank')) {
          type = 'tank';
        } else if (id.toLowerCase().contains('truck')) {
          type = 'truck';
        } else if (id.toLowerCase().contains('artillery')) {
          type = 'artillery';
        }
      }

      final newEntity = MapEntity(
        id: id,
        type: type,
        position: LatLng(lat, long),
      );

      _entities[id] = newEntity;
      // debugPrint("LIVEKIT ENTITY: $id ($type) @ $lat,$long"); 
      _recalculateDetails(); // Recalculate counts
      notifyListeners();
    } else if (data['type'] == 'chat') {
        // Handle Chat Message
        try {
          final chatMsg = ChatData(
            sender: data['sender'] ?? 'Unknown',
            message: data['message'] ?? '',
            time: data['time'] ?? 'Now',
          );
          
          // Dedupe before adding
          if (!_chatMessages.contains(chatMsg)) {
             _chatMessages.add(chatMsg);
             // Keep only last 50 messages
             if (_chatMessages.length > 50) _chatMessages.removeAt(0);
             
             // NOTIFICATION LOGIC: Only if chat is NOT open
             if (!_isChatOpen) {
               _hasUnreadMessages = true; 
               _unreadCount++;
             }
             
             notifyListeners();
          }
        } catch (e) {
          debugPrint("Error parsing chat message: $e");
        }
    } else {
      debugPrint("LIVEKIT DATA IGNORED: $data");
    }
  }

  // NEW: Send Chat Message via API (Persistent)
  Future<void> sendChatMessage(String sender, String text) async {
    // 1. Send to Backend via API
    await ApiService.sendChatMessage(sender, text);
    
    // 2. Fetch immediately to update UI
    await _fetchGlobalData();
  }

  Future<void> deleteChatMessage(String id) async {
       bool success = await ApiService.deleteChatMessage(id); // Use static
       if (success) {
         _chatMessages.removeWhere((m) => m.id == id);
         notifyListeners();
       }
  }

  Future<void> clearChatHistory() async {
      // LOCAL ONLY: Do not call ApiService.clearChatHistory()
      
      // Add to hidden lists before clearing to prevent "ghost" reappearance from backend poll
      for(var msg in _chatMessages) {
         if (msg.id.isNotEmpty) _hiddenMessageIds.add(msg.id.trim());
         _hiddenContentHashes.add("${msg.sender}_${msg.time}_${msg.message}");
      }
      
      _chatMessages.clear();
      // DO NOT CLEAR HIDDEN LISTS (we actively added to them)
      notifyListeners();
  } 
  
  Future<void> editChatMessage(String id, String newText) async {
    bool success = await ApiService.editChatMessage(id, newText); // Use static
    if (success) {
       final index = _chatMessages.indexWhere((msg) => msg.id == id);
       if (index != -1) {
          final old = _chatMessages[index];
          _chatMessages[index] = ChatData(id: old.id, sender: old.sender, message: newText, time: old.time);
          notifyListeners();
       }
    }
  }
  


  void _recalculateDetails() {
    int soldier = 0;
    int tank = 0;
    int uav = 0;
    int artillery = 0;

    for (var entity in _entities.values) {
      switch (entity.type) {
        case 'tank': tank++; break;
        case 'uav': uav++; break;
        case 'artillery': artillery++; break;
        default: soldier++; break;
      }
    }

    _unitDetails = [
      {'label': 'Soldiers', 'count': soldier},
      {'label': 'Tanks', 'count': tank},
      {'label': 'UAVs', 'count': uav},
      {'label': 'Artillery', 'count': artillery},
    ];
  }
}
