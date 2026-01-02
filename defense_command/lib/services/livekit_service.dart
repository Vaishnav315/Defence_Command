import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

class LiveKitService extends ChangeNotifier {
  Room? _room;
  final StreamController<Map<String, dynamic>> _dataStreamController = StreamController.broadcast();
  final StreamController<String> _participantDisconnectedController = StreamController.broadcast();
  
  Room? get room => _room;
  Stream<Map<String, dynamic>> get dataStream => _dataStreamController.stream;
  Stream<String> get onParticipantDisconnected => _participantDisconnectedController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  List<Participant> get participants {
    if (_room == null) return [];
    return [..._room!.remoteParticipants.values, if (_room!.localParticipant != null) _room!.localParticipant!];
  }

  Future<void> connect(String url, String token) async {
    if (_isConnected) return;

    try {
      _room = Room();
      _setupListeners();

      await _room!.connect(url, token, roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ));
      
      _isConnected = true;
      notifyListeners();
      debugPrint('LiveKit Connected to $url');

    } catch (e) {
      debugPrint('LiveKit Connection Error: $e');
      rethrow;
    }
  }

  void _setupListeners() {
    if (_room == null) return;

    var listener = _room!.createListener();

    listener.on<DataReceivedEvent>((event) {
      if (event.data.isEmpty) return;
      try {
        final String decoded = utf8.decode(event.data);
        final Map<String, dynamic> jsonData = json.decode(decoded);
        _dataStreamController.add(jsonData);
      } catch (e) {
        debugPrint('Error parsing data channel message: $e');
      }
    });

    listener.on<ParticipantConnectedEvent>((event) {
      notifyListeners();
    });

    listener.on<ParticipantDisconnectedEvent>((event) {
      _participantDisconnectedController.add(event.participant.identity);
          notifyListeners();
    });
    
    listener.on<TrackSubscribedEvent>((event) {
      notifyListeners();
    });
    
    listener.on<TrackUnsubscribedEvent>((event) {
      notifyListeners();
    });

    listener.on<RoomDisconnectedEvent>((event) {
      _isConnected = false;
      notifyListeners();
    });
  }

  Future<void> disconnect() async {
    await _room?.disconnect();
    _room = null;
    _isConnected = false;
    notifyListeners();
  }

  Future<void> publishData(Map<String, dynamic> data) async {
    if (_room == null || !_isConnected) return;
    
    try {
      final String payload = json.encode(data);
      final List<int> bytes = utf8.encode(payload);
      
      await _room!.localParticipant?.publishData(
        bytes, 
        reliable: true,
      );
    } catch (e) {
      debugPrint('Error publishing data: $e');
    }
  }

  @override
  void dispose() {
    _dataStreamController.close();
    _participantDisconnectedController.close();
    _room?.dispose();
    super.dispose();
  }
}
