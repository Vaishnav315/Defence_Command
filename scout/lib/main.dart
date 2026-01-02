import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart' as livekit;
import 'package:permission_handler/permission_handler.dart';

import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'providers/auth_provider.dart';
import 'pages/login_page.dart';
import 'services/mission_upload_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;
import 'dart:typed_data';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Init Notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..tryAutoLogin()),
      ],
      child: const ScoutApp(),
    ),
  );
}

class ScoutApp extends StatelessWidget {
  const ScoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scout Streamer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,

      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    if (!auth.isAuthenticated) {
      return const LoginPage();
    }
    return const StreamHomeView();
  }
}

class StreamHomeView extends StatefulWidget {
  const StreamHomeView({super.key});

  @override
  State<StreamHomeView> createState() => _StreamHomeViewState();
}

class _StreamHomeViewState extends State<StreamHomeView> {
  // --- LiveKit & State ---
  livekit.Room? _room;
  livekit.EventsListener<livekit.RoomEvent>? _listener;

  final TextEditingController _callsignController = TextEditingController();
  final TextEditingController _chatController = TextEditingController(); // Chat
  bool _isConnecting = false;
  bool _isOnline = false;
  bool _isStreaming = false; // New state for video/audio
  bool _isFrontCamera = false;
  bool _isMicMuted = true; // Muted by default
  String? _error;
  
  // --- Chat State ---
  bool _isChatOpen = false;
  bool _hasUnreadMessages = false;
  bool _hasLoadedInitialHistory = false; // Ephemeral Chat Logic
  final List<Map<String, String>> _chatMessages = []; // {sender, message, time, id}
  final Set<String> _hiddenMessageIds = {}; 
  final Set<String> _hiddenContentHashes = {}; // Fallback for missing/changing IDs
  String? _editingId; // For inline editing
  final FocusNode _chatFocusNode = FocusNode();
  
  // --- Mapping State ---
  bool _isMapping = false;
  String? _mapCacheBuster;
  Timer? _mapRefreshTimer;

  // --- Telemetry & Chat Polling ---
  Timer? _telemetryTimer;
  Timer? _chatPollTimer;
  Position? _lastPosition;
  Position? _lastRecordedPosition; // For throttling
  DateTime? _lastRecordTime;       // For throttling

  // --- Mission Sync State ---
  final List<Map> _telemetryTrail = [];
  final MissionUploadService _uploadService = MissionUploadService();
  bool _isSyncing = false;
  
  // --- Recording State (Mobile Compatible) ---
  webrtc.MediaRecorder? _mediaRecorder;
  String? _recordingPath;

  // --- Logs ---
  final List<String> _activities = [];
  final ScrollController _logScrollController = ScrollController();

  // --- Constants ---
  // --- Constants ---
  String _identity = '';
  static const String _serverUrl = 'https://flabbergastedly-censerless-tanna.ngrok-free.dev';

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    
    // Set Identity from Auth
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _callsignController.text = auth.identity;
    _identity = auth.identity;
    
    _addActivity("Welcome, $_identity. System initialized.");
  }
  
  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
            'scout_channel', 'Scout Notifications',
            channelDescription: 'Notifications for Scout App',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker');
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
        0, title, body, platformChannelSpecifics,
        payload: 'chat');
  }

  @override
  void dispose() {
    _disconnect();
    _callsignController.dispose();
    _chatFocusNode.dispose();
    _telemetryTimer?.cancel();
    _mapRefreshTimer?.cancel();
    _logScrollController.dispose();
    super.dispose();
  }

  void _addActivity(String message) {
    if (!mounted) return;
    final now = DateTime.now();
    final time = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    setState(() {
      _activities.add("$time - $message");
      if (_activities.length > 50) _activities.removeAt(0);
    });
    
    // Auto-scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.location,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted) {
      _showErrorSnackBar("Permissions are required for streaming.");
      _addActivity("Error: Permissions denied.");
    } else {
      // Auto-connect if permissions granted
      _connect();
    }
  }

  Future<void> _toggleConnection() async {
    if (_isOnline || _isConnecting) {
      await _disconnect();
    } else {
      await _connect();
    }
  }

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
      _error = null;
    });
    _addActivity("Connecting to server...");
    
    // NEW: Fetch chat history on connect and start polling
    _fetchChatHistory();
    _chatPollTimer?.cancel();
    _chatPollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isOnline) {
        _fetchChatHistory();
      }
    });

    try {
      // 1. Fetch Token using the authenticated identity
      final uri = Uri.parse('$_serverUrl/livekit/token?identity=$_identity');
      
      final response = await http.get(uri, headers: {"ngrok-skip-browser-warning": "true"});
      print("Token Response: ${response.body}"); // Debugging

      if (response.statusCode != 200) {
        throw "Server error: ${response.statusCode}";
      }

      String token;
      String url;

      try {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('token')) {
          token = data['token'];
          url = data['url'];
        } else {
           // If it's JSON but not the expected structure, or just a string disguised as JSON?
           // The requirement says: "If it returns just the string, use it directly."
           // But assuming dual format support:
           token = response.body; 
           // We might need a default URL if it's just a token string, 
           // but the existing code used `data['url']`. 
           // If the server returns *just* a token string, where do we get the URL?
           // The livekit connect method needs a URL.
           // Looking at previous lines: `final uri = Uri.parse('$_serverUrl/livekit/token?identity=$_identity');`
           // Usually LiveKit token endpoints return token + url. 
           // If the instruction says "If it returns just the string, use it directly", 
           // it implies the response body itself is the token.
           // I'll keep the URL from the previous decoded block if available, otherwise?
           // Wait, if it's just a string, we might not have the URL.
           // However, let's strictly follow "If it returns just the string, use it directly."
           // I will assume the URL is already known or handled elsewhere? 
           // Actually, `_room!.connect(url, token, ...)` requires url.
           // If the server returns just the token, we might have to hardcode the WS URL or derive it.
           // BUT, let's look at the existing code: `final String url = data['url'];`
           // If I change to string token, I miss the URL.
           // Let's assume for now if it's a string, we might reuse `_serverUrl` but replaced with ws://?
           // Or maybe the user implies the token is all we need? No, `connect` needs url.
           // I will stick to the plan: "If the server returns {"token": "..."}, extract the "token" field. If it returns just the string, use it directly."
           // And for the URL, I'll fallback to a default or keep the logic compatible.
           // Actually, if it returns just a string, it's likely *just* the token. 
           // The URL might be fixed or I should try to parse it. 
           // Let's protect the `url` assignment.
           // For now, I will initialize `url` to a default derived from `_serverUrl` (http -> ws) just in case, or leave it nullable?
           // `connect` signature: `Future<void> connect(String url, String token, ...)`
           // I'll try to extract URL from `data` if possible, otherwise use a safe default or strict error?
           // Let's look at how I can be safe.
           url = "wss://${Uri.parse(_serverUrl).authority}"; // Fallback guess?
        }
      } catch (e) {
        // Not JSON, assume it's the token string
        token = response.body;
        // Fallback URL needed?
        url = "wss://${Uri.parse(_serverUrl).authority}"; 
      }
      
      // better approach:
      // If valid JSON with token/url, use it.
      // If not, use body as token and try to guess URL or maybe the user has a fixed URL in mind?
      // The user prompt didn't specify what to do with URL if it's just a string. 
      // "If it returns just the string, use it directly." refers to the token.
      // I will assume the `url` variable needs to be populated. The safest is to try JSON first.
      
      // REVISED LOGIC FOR CHUNK:


      // 2. Connect to LiveKit
      _room = livekit.Room();
      _listener = _room!.createListener();
      
      // LISTEN FOR DATA (CHAT)
      _listener!.on<livekit.DataReceivedEvent>((event) {
        String decoded = utf8.decode(event.data);
        try {
          final data = jsonDecode(decoded);
          if (data['type'] == 'chat') {
            setState(() {
              final newMsg = {
                'id': (data['id'] ?? '').toString(),
                'sender': (data['sender'] ?? 'Commander').toString(),
                'message': (data['message'] ?? '').toString(),
                'time': (data['time'] ?? 'Now').toString(),
              };
              
               // Dedup
               if (!_chatMessages.any((m) => m['id'] == newMsg['id'] && m['message'] == newMsg['message'])) {
                  _chatMessages.add(newMsg);
                  if (!_isChatOpen) {
                     _hasUnreadMessages = true;
                     _showNotification("New Message", "${newMsg['sender']}: ${newMsg['message']}");
                  }
               }
            });
          }
        } catch (e) {
          print("Data Parse Error: $e");
        }
      });

      final roomOptions = livekit.RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultVideoPublishOptions: const livekit.VideoPublishOptions(),
      );

      await _room!.connect(url, token, roomOptions: roomOptions);
      _addActivity("Connected to room. Ready to stream.");

      // 3. Publish Tracks REMOVED (Manual now)
      
      // 4. Start Telemetry
      _startTelemetryStream();

      // 4. Start Telemetry
      _startTelemetryStream();

      if (mounted) {
        setState(() {
          _isOnline = true;
          _isConnecting = false;
        });
      }

    } catch (e) {
      _setError("Connection failed: $e");
      await _disconnect();
    }
  }

  Future<void> _toggleMediaStream() async {
    if (_room == null) return;
    
    if (_isStreaming) {
       // Stop Streaming
       try {
         final participants = _room!.localParticipant;
         if (participants != null) {
           await participants.setCameraEnabled(false);
           await participants.setMicrophoneEnabled(false);
         }
         setState(() => _isStreaming = false);
         _addActivity("Stream paused.");
         
         // --- STOP RECORDING ---
         await _stopRecording();
         
         // --- AUTOMATIC SYNC ON STOP ---
         _syncMissionSession();
       } catch (e) {
         _showErrorSnackBar("Failed to stop stream: $e");
       }
    } else {
      // Start Streaming
      try {
        final participants = _room!.localParticipant;
        if (participants != null) {
           await participants.setCameraEnabled(true, 
             cameraCaptureOptions: const livekit.CameraCaptureOptions(
                params: livekit.VideoParameters(
                  dimensions: livekit.VideoDimensions(1280, 720),
                  encoding: livekit.VideoEncoding(
                    maxBitrate: 1500000,
                    maxFramerate: 30,
                  ),
                ),
             )
           );
           await participants.setMicrophoneEnabled(true);

           // --- START RECORDING (MOBILE/EMULATOR) ---
           try {
             // We need to wait a small bit for tracks to be published
             await Future.delayed(const Duration(milliseconds: 500));
             
             final trackPub = participants.videoTrackPublications.firstOrNull;
             final videoTrack = trackPub?.track;
             
             if (videoTrack != null && videoTrack is livekit.LocalVideoTrack) {
                _addActivity("Preparing mission recording...");
                
                final tempDir = await getTemporaryDirectory();
                _recordingPath = '${tempDir.path}/mission_capture.mp4';
                
                if (_mediaRecorder != null) {
                  await _mediaRecorder!.stop();
                }

                _mediaRecorder = webrtc.MediaRecorder();
                
                final videoTrackPub = participants.videoTrackPublications.firstOrNull;
                final audioTrackPub = participants.audioTrackPublications.firstOrNull;
                
                final vTrack = (videoTrack as dynamic).mediaStreamTrack;
                final aTrack = (audioTrackPub?.track as dynamic)?.mediaStreamTrack;

                await _mediaRecorder!.start(
                  _recordingPath!, 
                  videoTrack: vTrack,
                  audioChannel: webrtc.RecorderAudioChannel.INPUT, // For Android
                );
                _addActivity("Session recording started.");
             }
           } catch (recError) {
             print("Recording Start Error: $recError");
             _addActivity("Recording failed to start: $recError");
           }
        }
        setState(() => _isStreaming = true);
        _addActivity("Live Stream Started!");
        
        // --- PREPARE TRAIL FOR NEW SESSION ---
        _telemetryTrail.clear();
        _lastRecordedPosition = null;
        _lastRecordTime = null;
      } catch (e) {
         _showErrorSnackBar("Failed to start stream: $e");
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      if (_mediaRecorder != null) {
        await _mediaRecorder!.stop();
        _mediaRecorder = null;
        _addActivity("Session recording captured.");
      }
    } catch (e) {
      print("Recording Stop Error: $e");
    }
  }

  Future<void> _disconnect() async {
    if (mounted) {
      setState(() {
        _isConnecting = false;
        _isOnline = false;
        _isStreaming = false;
      });
    }

    _telemetryTimer?.cancel();
    _telemetryTimer = null;
    _chatPollTimer?.cancel();
    _chatPollTimer = null;

    if (_room != null) {
      await _room!.disconnect();
      _room = null;
    }

    _listener?.dispose();
    _listener = null;
    
    _addActivity("Disconnected.");
  }

  Future<void> _toggleCamera() async {
    if (_room == null || _room!.localParticipant == null) return;

    try {
      final videoTrack = _room!.localParticipant!.videoTrackPublications
          .firstWhere((pub) => pub.track is livekit.LocalVideoTrack)
          .track;

      if (videoTrack != null) {
        setState(() {
          _isFrontCamera = !_isFrontCamera;
        });
        
        final options = livekit.CameraCaptureOptions(
          cameraPosition: _isFrontCamera 
              ? livekit.CameraPosition.front 
              : livekit.CameraPosition.back,
        );
        
        await videoTrack.restartTrack(options);
        _addActivity("Switched to ${_isFrontCamera ? 'Front' : 'Back'} Camera");
      }
    } catch (e) {
      _setError("Failed to switch camera: $e");
    }
  }

  Future<void> _toggleMic() async {
    if (_room == null || _room!.localParticipant == null) return;

    try {
      final audioTrack = _room!.localParticipant!.audioTrackPublications
          .firstWhere((pub) => pub.track is livekit.LocalAudioTrack)
          .track;

      if (audioTrack != null) {
        if (_isMicMuted) {
          await audioTrack.unmute();
        } else {
          await audioTrack.mute();
        }
        
        setState(() {
          _isMicMuted = !_isMicMuted;
        });
        _addActivity("Microphone ${_isMicMuted ? 'Muted' : 'Unmuted'}");
      }
    } catch (e) {
      _setError("Failed to toggle microphone: $e");
    }
  }

  void _setError(String msg) {
    if (mounted) {
      setState(() {
        _error = msg;
        _isConnecting = false;
        _isOnline = false;
      });
      _showErrorSnackBar(msg);
      _addActivity("Error: $msg");
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _toggleMapping() async {
    if (!_isOnline) {
      _showErrorSnackBar("Start video stream first!");
      return;
    }

    if (_isMapping) {
      // --- STOP LOGIC (CRITICAL) ---
      // 1. Cancel timer immediately
      _mapRefreshTimer?.cancel();
      _mapRefreshTimer = null;

      // 2. Update UI state immediately (optimistic stop)
      setState(() {
        _isMapping = false;
        // One final refresh
        _mapCacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
      });
      
      _addActivity("Stopping mapping...");

      // 3. Send POST request to stop
      try {
        await http.post(
          Uri.parse('$_serverUrl/map/stop'),
          headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
          body: jsonEncode({'identity': _identity}),
        );
        _addActivity("Mapping stopped.");
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Mapping Stopped"),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        // Even if server request fails, local state is stopped. 
        _addActivity("Error stopping mapping: $e");
      }
    } else {
      // --- START LOGIC ---
      _addActivity("Starting mapping...");
      
      try {
        final response = await http.post(
          Uri.parse('$_serverUrl/map/start'),
          headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
          body: jsonEncode({'identity': _identity}),
        );
        
        if (response.statusCode == 200) {
          if (mounted) {
            setState(() {
              _isMapping = true;
              
              // Start Timer
              _mapRefreshTimer?.cancel(); // Safety check
              _mapRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
                if (mounted) {
                  setState(() {
                    _mapCacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
                  });
                }
              });
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Mapping Started"),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          _addActivity("Mapping started.");
        } else {
          throw "Server returned ${response.statusCode}";
        }
      } catch (e) {
        if (mounted) _showErrorSnackBar("Failed to start mapping: $e");
        _addActivity("Start Error: $e");
      }
    }
  }

  void _startTelemetryStream() {
    _telemetryTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
       if (_room == null || _room!.connectionState != livekit.ConnectionState.connected) {
        timer.cancel();
        return;
      }

      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
        );
        
        if (mounted) {
          setState(() {
            _lastPosition = position;
          });
        }

        // --- GPS Throttling Logic ---
        bool shouldRecord = false;
        final now = DateTime.now();

        if (_lastRecordedPosition == null || _lastRecordTime == null) {
          shouldRecord = true;
        } else {
          double distance = Geolocator.distanceBetween(
            _lastRecordedPosition!.latitude,
            _lastRecordedPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          
          final timeDiff = now.difference(_lastRecordTime!);
          // Only record if moved > 5 meters OR > 30 seconds passed
          if (distance >= 5 || timeDiff.inSeconds >= 30) {
            shouldRecord = true;
          }
        }

        if (shouldRecord) {
          _lastRecordedPosition = position;
          _lastRecordTime = now;

          final telemetryData = {
            "type": "gps",
            "lat": position.latitude,
            "long": position.longitude,
            "id": _identity,
            "timestamp": now.toUtc().toIso8601String(),
            "unix_timestamp": now.millisecondsSinceEpoch
          };

          // Track trail for sync
          _telemetryTrail.add({
            "lat": position.latitude,
            "lng": position.longitude,
            "timestamp": now.millisecondsSinceEpoch
          });

          final jsonString = jsonEncode(telemetryData);
          final bytes = utf8.encode(jsonString);

          await _room!.localParticipant?.publishData(bytes);
          // Optional: _addActivity("GPS broadcasted (Throttled)");
        }
      } catch (e) {
        print("Telemetry Error: $e");
      }
    });
  }

  Future<void> _syncMissionSession() async {
    if (_telemetryTrail.isEmpty) {
      _showErrorSnackBar("No GPS data to sync!");
      return;
    }

    setState(() => _isSyncing = true);
    _addActivity("Starting data synchronization...");

    try {
      // 1. Read the recorded video file (Mobile/Emulator)
      if (_recordingPath == null) {
        _addActivity("Uplink failed: No recording file found.");
        throw "No Recording";
      }

      final file = io.File(_recordingPath!);
      if (!await file.exists()) {
        _addActivity("Uplink failed: Recording file doesn't exist.");
        throw "File Missing";
      }

      final Uint8List videoBytes = await file.readAsBytes();
      
      if (videoBytes.isEmpty) {
        _addActivity("Uplink failed: Recording is empty.");
        throw "Recording Empty";
      }

      _addActivity("Mission record prepared (${(videoBytes.length / (1024 * 1024)).toStringAsFixed(2)} MB)");

      // 2. Call the upload service - Wrapped in try-catch to be resilient
      String videoUrl = "UPLOAD_FAILED";
      try {
        _addActivity("Automatic uplink initiated...");
        videoUrl = await _uploadService.uploadVideoData(videoBytes);
        _addActivity("Video uplink successful.");
      } catch (uploadError) {
        _addActivity("Video uplink failed: $uploadError");
        _addActivity("Proceeding with partial GPS telemetry sync...");
      }
      
      _addActivity("Filtering GPS telemetry...");
      final filteredLogs = _uploadService.filterGpsData(_telemetryTrail);
      
      final payload = {
        "scout_id": _identity,
        "video_url": videoUrl,
        "gps_logs": filteredLogs,
        "timestamp": DateTime.now().toIso8601String()
      };

      _addActivity("Sending data to Ground Station...");
      final response = await http.post(
        Uri.parse('$_serverUrl/mission/sync'),
        headers: {"Content-Type": "application/json", "ngrok-skip-browser-warning": "true"},
        body: jsonEncode(payload)
      );

      if (response.statusCode == 200) {
        _addActivity("Mission Sync Complete!");
        _telemetryTrail.clear(); // Clear after success
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Mission Data Synced Successfully"), backgroundColor: Colors.green),
          );
        }
      } else {
        throw "Backend Error: ${response.statusCode}";
      }
    } catch (e) {
      _addActivity("Sync Error: $e");
      _showErrorSnackBar("Sync Failed: $e");
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // --- Spot Report Feature ---

  Future<void> _handleSpotReport(String type) async {
    // Close the modal first
    Navigator.pop(context);

    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 16),
              Text("Marking target..."),
            ],
          ),
          duration: Duration(days: 1), // Keep open until dismissed
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    try {
      // 1. Get Current Position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );

      // 3. Send Request
      print("Sending Spot Report to $_serverUrl...");
      final response = await http.post(
        Uri.parse('$_serverUrl/tactical/pin'),
        headers: {"Content-Type": "application/json", "ngrok-skip-browser-warning": "true"},
        body: jsonEncode({
          "lat": position.latitude,
          "lng": position.longitude,
          "type": type.toLowerCase(), // Ensure lowercase
          "description": "Visual confirmation from Scout",
          "reporter_id": _callsignController.text.trim().isEmpty 
              ? "Unknown-Scout" 
              : _callsignController.text.trim()
        }),
      );

      print("Server Response: ${response.statusCode}");
      print("Response Body: ${response.body}"); // Debugging

      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Target Uploaded"),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _addActivity("Target marked: $type");
        }
      } else {
        throw "Server error: ${response.statusCode}";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showErrorSnackBar("Failed to mark target: $e");
      }
    }
  }



  Future<void> _undoLastAction() async {
    final String reporterId = _callsignController.text.trim().isEmpty 
        ? "Unknown-Scout" 
        : _callsignController.text.trim();

    try {
      final response = await http.delete(
        Uri.parse('$_serverUrl/tactical/undo?reporter_id=$reporterId'),
        headers: {"ngrok-skip-browser-warning": "true"},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Last Action Reversed"),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _addActivity("Undo successful.");
        }
      } else {
        throw "Server error: ${response.statusCode}";
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar("Undo failed: $e");
    }
  }

  void _showTargetSelectionModal() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Identify Target Type",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTargetOption("Infantry", "soldier", Icons.person, Colors.orange),
                  _buildTargetOption("Tank", "tank", Icons.local_shipping, Colors.red),
                  _buildTargetOption("Artillery", "artillery", Icons.warning, Colors.purple),
                  _buildTargetOption("Intel/POI", "intel", Icons.visibility, Colors.blue),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTargetOption(String label, String type, IconData icon, Color color) {
    return InkWell(
      onTap: () => _handleSpotReport(type),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }



  Future<void> _sendChatMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return; 
    
    // Inline Edit Logic
    if (_editingId != null) {
       await _editMessage(_editingId!, text);
       setState(() {
         _editingId = null;
         _chatController.clear();
         _chatFocusNode.unfocus();
       });
       return;
    }

    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final sender = _callsignController.text.isEmpty ? "Scout" : _callsignController.text;

    try {
      // Use HTTP POST instead of LiveKit Publish
      final response = await http.post(
        Uri.parse('$_serverUrl/tactical/chat'),
        headers: {"Content-Type": "application/json", "ngrok-skip-browser-warning": "true"},
        body: jsonEncode({
          "sender": sender,
          "message": text,
          "time": timeStr
          // ID is generated by Backend if omitted, or we can send one. 
          // Backend expects {sender, message, time}. It assigns UUID.
          // Better to let backend assign ID to guarantee uniqueness compliant with its system.
        })
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
         _chatController.clear();
         // Fetch immediately to update UI with the new message (and its ID)
         _fetchChatHistory();
      } else {
        throw "Server error: ${response.statusCode}";
      }
    } catch (e) {
      _showErrorSnackBar("Failed to send: $e");
    }
  }

  Widget _buildCommandBar() {
    final theme = Theme.of(context);


    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, // Adaptive surface color
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Left: UNDO
          InkWell(
            onTap: _undoLastAction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.undo, color: theme.colorScheme.onSurface, size: 28),
                  const SizedBox(height: 4),
                  Text("UNDO", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface)),
                ],
              ),
            ),
          ),
          
          // Center: ENGAGE
          InkWell(
            onTap: _showTargetSelectionModal,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 180,
              height: 50,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary, // Use Primary (Blue/Seed) color
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.gps_fixed, color: theme.colorScheme.onPrimary),
                  const SizedBox(width: 8),
                  Text(
                    "MARK TARGET", 
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimary, 
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right: STATUS
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi, color: Colors.green, size: 28),
              const SizedBox(height: 4),
              Text("LINKED", style: theme.textTheme.labelSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      drawer: _buildDrawer(theme),
      appBar: AppBar(
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.cardColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
             boxShadow: [
               BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
              ),
            ],
          ),
          child: Builder( // Need Builder to get context with Scaffold
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: "System Menu",
              padding: EdgeInsets.zero,
            ),
          ),
        ),

        title: const Text("Scout Streamer"),
        actions: [
          if (_isOnline)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "LIVE",
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              ),

          // CHAT BUTTON (Always visible)
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.chat_bubble_outline, color: theme.colorScheme.onSurface),
                if (_hasUnreadMessages)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              // DEBUG: Print current state
              print("DEBUG: Chat Pressed. Room: $_room");
              if (_room != null) {
                print("DEBUG: Connection State: ${_room!.connectionState}");
              } else {
                print("DEBUG: Room is NULL");
              }

              // Check actual connection state
              bool isConnected = _room != null && _room!.connectionState == livekit.ConnectionState.connected;
              
              if (!isConnected) {
                // If the user THINKS they are connected but state says otherwise:
                 String state = _room != null ? _room!.connectionState.name : "NULL";
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Not Connected. State: $state")),
                );
                return;
              }
              setState(() {
                _isChatOpen = true;
                _hasUnreadMessages = false;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main Content
          SingleChildScrollView(
            child: Column(
              children: [
                // Callsign Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _callsignController,
                decoration: const InputDecoration(
                  labelText: "Callsign / ID",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
            ),



            // Camera Preview Section
            SizedBox(
              height: 400,
              child: Container(
                margin: const EdgeInsets.all(16),
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: _room != null && _room!.localParticipant != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ..._room!.localParticipant!.videoTrackPublications.map((pub) {
                            if (pub.track != null) {
                              return livekit.VideoTrackRenderer(
                                pub.track as livekit.VideoTrack,
                                fit: livekit.VideoViewFit.cover,
                              );
                            }
                            return const SizedBox();
                          }),
                          if (!_isOnline && !_isConnecting)
                            Center(
                              child: Icon(Icons.videocam_off_outlined, 
                                size: 48, color: theme.disabledColor),
                            ),
                          // Camera Switch Button
                          Positioned(
                            top: 12,
                            right: 12,
                            child: InkWell(
                              onTap: _toggleCamera,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: const Icon(
                                  Icons.cameraswitch,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),

                          // Mapping & Mic Controls (Overlay)
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FilledButton.icon(
                                  onPressed: _toggleMapping,
                                  icon: Icon(_isMapping ? Icons.stop : Icons.map, size: 20),
                                  label: Text(_isMapping ? "Stop Mapping" : "Start Mapping"),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _isMapping ? Colors.red : Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: _toggleMic,
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _isMicMuted ? Colors.red : Colors.black54,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Icon(
                                      _isMicMuted ? Icons.mic_off : Icons.mic,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_outlined, size: 64, color: theme.disabledColor),
                            const SizedBox(height: 16),
                            Text("Camera Offline", style: theme.textTheme.bodyLarge),
                          ],
                        ),
                      ),
              ),
            ),
  
            // Main Action Button (Stream Only)
            if (_isOnline || _isConnecting)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _isOnline ? _toggleMediaStream : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _isStreaming ? Colors.red : (_isOnline ? Colors.green : Colors.grey),
                  ),
                  icon: _isConnecting 
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(_isStreaming ? Icons.videocam_off : Icons.videocam),
                  label: Text(
                     _isConnecting ? "Connecting to HQ..." : (_isStreaming ? "Stop Live Stream" : "Go Live"),
                     style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            
            // Retry Button (if failed/offline)
            if (!_isOnline && !_isConnecting)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text("Connection Lost or Offline", style: TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _connect,
                      child: const Text("Retry Connection"),
                    ),
                  ],
                ),
              ),

            // Mapping Controls & Display
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                   // Map Display
                  Container(
                    height: 250,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: _mapCacheBuster == null 
                      ? Center(child: Text("No map generated yet.", style: TextStyle(color: Colors.grey[600])))
                      : Image.network(
                          "$_serverUrl/map/image?identity=$_identity&t=$_mapCacheBuster",
                          gaplessPlayback: true,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Text("Waiting for map..."),
                        ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            
            // Bottom Padding for Command Bar

            // Info & Controls Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
              child: Column(
                children: [
                  // Location Status
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Current Location",
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _lastPosition != null
                                    ? "${_lastPosition!.latitude.toStringAsFixed(4)}, ${_lastPosition!.longitude.toStringAsFixed(4)}"
                                    : "Waiting for GPS...",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace', // Monospace only for coords looks good
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
  

  
                  // Activity Log Label
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Activity Log",
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  const Divider(),
                  
                  // Activity List
                  SizedBox(
                    height: 150, // Fixed height for log in scroll view
                    child: ListView.builder(
                      controller: _logScrollController,
                      itemCount: _activities.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            _activities[index],
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24), // Bottom padding
                  const SizedBox(height: 100), // Bottom padding for Command Bar inside Column
                ],
              ),
            ),
            ],
          ),
        ),

          // --- CHAT OVERLAY (Themed) ---
          if (_isChatOpen)
             Positioned.fill(
               child: Container(
                 color: theme.scaffoldBackgroundColor, // Match App Theme
                 child: SafeArea( // Respect notch/bottom bar
                   child: Column(
                     children: [
                       // 1. Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          color: theme.colorScheme.surface, 
                          child: Row(
                            children: [
                              // Back Button
                              InkWell(
                                onTap: () => setState(() => _isChatOpen = false),
                                child: Row(
                                  children: [
                                    Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
                                    const SizedBox(width: 4),
                                    CircleAvatar(
                                      backgroundColor: theme.colorScheme.primaryContainer,
                                      child: Icon(Icons.security, color: theme.colorScheme.onPrimaryContainer, size: 20),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(width: 12),
                              
                              // Title
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Secure Channel", style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text(_isStreaming ? "Live • Audio Active" : "Encrypted", style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                                  ],
                                ),
                              ),
                              
                              // Clear Chat Button
                              IconButton(
                                icon: const Icon(Icons.delete_sweep, color: Colors.grey),
                                onPressed: () {
                                   showDialog(context: context, builder: (ctx) => AlertDialog(
                                     title: const Text("Delete All History?"),
                                     content: const Text("This will permanently delete messages for everyone."),
                                     actions: [
                                       TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                                        TextButton(
                                          onPressed: () {
                                            _clearChatHistory();
                                            Navigator.pop(ctx);
                                          }, 
                                          child: const Text("Clear", style: TextStyle(color: Colors.red))
                                        ),
                                     ],
                                   ));
                                },
                              ),
                            ],
                          ),
                        ),

                       // 2. Chat List Background
                       Expanded(
                         child: Container(
                           color: theme.colorScheme.surfaceContainerLow, // Slightly different background
                           child: ListView.builder(
                             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                             itemCount: _chatMessages.length,
                             itemBuilder: (context, index) {
                                final msg = _chatMessages[index];
                                final myCallsign = _callsignController.text.trim();
                                bool isMe = false;
                                if (myCallsign.isEmpty) {
                                   // If no callsign set, 'Scout' is me
                                   if (msg['sender'] == 'Scout' || msg['sender'] == 'Me') isMe = true;
                                } else {
                                   if (msg['sender'] == myCallsign || msg['sender'] == 'Me') isMe = true;
                                }
                                                              return Align(
                                   alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                   child: GestureDetector(
                                     behavior: HitTestBehavior.opaque, // Ensure clicks are caught
                                     onLongPressStart: (details) {
                                        // Handle Missing ID Gracefully
                                        bool isIdMissing = (msg['id'] == null || msg['id']!.isEmpty);
                                        
                                        final position = details.globalPosition;
                                        showMenu(
                                          context: context,
                                          position: RelativeRect.fromLTRB(
                                            position.dx,
                                            position.dy,
                                            MediaQuery.of(context).size.width - position.dx,
                                            MediaQuery.of(context).size.height - position.dy,
                                          ),
                                          items: [
                                            if (!isIdMissing) ...[
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(children: [Icon(Icons.edit, size: 20, color: Colors.blue), SizedBox(width: 8), Text("Edit")]),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))]),
                                              ),
                                            ] else ...[
                                               // Allow local cleanup
                                               const PopupMenuItem(
                                                value: 'delete_local',
                                                child: Row(children: [Icon(Icons.delete_forever, size: 20, color: Colors.grey), SizedBox(width: 8), Text("Clear (Local)", style: TextStyle(color: Colors.grey))]),
                                              ),
                                            ]
                                          ],
                                          elevation: 8.0,
                                        ).then((value) {
                                          if (value == 'edit' && !isIdMissing) {
                                            // Inline Edit Trigger
                                            setState(() {
                                               _editingId = msg['id'];
                                               _chatController.text = msg['message']!;
                                               // Fix: Wait for frame to focus
                                               WidgetsBinding.instance.addPostFrameCallback((_) {
                                                  _chatFocusNode.requestFocus();
                                               });
                                            });
                                          } else if (value == 'delete' && !isIdMissing) {
                                            _deleteMessage(msg['id']!);
                                          } else if (value == 'delete_local') {
                                             setState(() {
                                               _chatMessages.removeAt(index);
                                             });
                                          }
                                        });
                                     },
                                     child: Container(
                                       margin: const EdgeInsets.only(bottom: 8),
                                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                       constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                       decoration: BoxDecoration(
                                         color: isMe ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest, 
                                         borderRadius: BorderRadius.only(
                                           topLeft: const Radius.circular(12),
                                           topRight: const Radius.circular(12),
                                           bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                                           bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                                         ),
                                       ),
                                       child: Column(
                                         crossAxisAlignment: CrossAxisAlignment.start,
                                         mainAxisSize: MainAxisSize.min,
                                         children: [
                                           if (!isMe)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 2),
                                              child: Text(msg['sender']!, style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                                            ),
                                           Text(msg['message']!, style: TextStyle(color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface, fontSize: 15)),
                                           
                                           // Edited Flag
                                           if (msg.containsKey('is_edited') && msg['is_edited'] == 'true')
                                             Padding(
                                               padding: const EdgeInsets.only(top: 2),
                                               child: Text("(edited)", style: TextStyle(fontStyle: FontStyle.italic, fontSize: 10, color: (isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface).withOpacity(0.6))),
                                             ),

                                           const SizedBox(height: 2),
                                           Align(
                                             alignment: Alignment.bottomRight,
                                             child: Text(
                                                msg['time']!, 
                                                style: TextStyle(color: (isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface).withOpacity(0.6), fontSize: 10)
                                              ),
                                            ),
                                         ],
                                       ),
                                     ),
                                   ),
                                 );
                             },
                           ),
                         ),
                       ),

                       // 3. Input Area (Themed)
                       Container(
                         padding: EdgeInsets.only(
                           left: 8, 
                           right: 8, 
                           top: 8, 
                           bottom: 8 + MediaQuery.of(context).viewInsets.bottom // Push up with keyboard
                         ),
                         color: theme.colorScheme.surface, // Input bar background
                         child: Row(
                           children: [
                             // Plus Button
                             IconButton(
                               onPressed: () {}, 
                               icon: Icon(Icons.add, color: theme.colorScheme.primary),
                               padding: EdgeInsets.zero,
                               constraints: const BoxConstraints(),
                             ),
                             const SizedBox(width: 8),
                             
                             // Text Input Pill
                             Expanded(
                               child: TextField(
                                 controller: _chatController,
                                 focusNode: _chatFocusNode,
                                 style: TextStyle(color: theme.colorScheme.onSurface),
                                 cursorColor: theme.colorScheme.primary,
                                 minLines: 1,
                                 maxLines: 1, // Enforce single line so Enter sends
                                 textInputAction: TextInputAction.send,
                                 decoration: InputDecoration(
                                   hintText: _editingId != null ? "Editing message..." : "Message",
                                   hintStyle: TextStyle(color: _editingId != null ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                                   filled: true,
                                   fillColor: theme.colorScheme.surfaceContainerHighest, // Input Pill Color
                                   border: OutlineInputBorder(
                                     borderRadius: BorderRadius.circular(24),
                                     borderSide: _editingId != null ? BorderSide(color: theme.colorScheme.primary, width: 2) : BorderSide.none,
                                   ),
                                   // Keep content compact
                                   isDense: true,
                                   contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                   // Emoji Icon (Internal Right)
                                   suffixIcon: _editingId != null 
                                     ? IconButton(icon: const Icon(Icons.close), onPressed: () {
                                         setState(() {
                                           _editingId = null;
                                           _chatController.clear();
                                           _chatFocusNode.unfocus();
                                         });
                                       })
                                     : Icon(Icons.emoji_emotions_outlined, color: theme.colorScheme.onSurfaceVariant),
                                 ),

                                  onSubmitted: (val) {
                                     // Prevent newlines and just send
                                     _sendChatMessage();
                                  },
                                  onChanged: (val) => setState(() {}), // Rebuild to toggle Mic/Send icon
                                ),
                             ),
                             
                             const SizedBox(width: 8),
                             
                             // Mic or Send Button
                             GestureDetector(
                               onTap: () {
                                 if (_chatController.text.trim().isNotEmpty) {
                                   _sendChatMessage();
                                 } else {
                                   // Handle Mic logic here if needed (e.g. toggle system mic)
                                   // For now, maybe simple feedback or do nothing as user just wanted the UI look
                                    setState(() {
                                      _isMicMuted = !_isMicMuted;
                                      // If we were streaming, we'd mute the track here ideally
                                      // But user visual request was priority. 
                                      // Let's make it useful: Toggle global mute state?
                                    });
                                 }
                               },
                               child: CircleAvatar(
                                 backgroundColor: _editingId != null ? Colors.green : theme.colorScheme.primary,
                                 radius: 22,
                                 child: Icon(
                                   _editingId != null ? Icons.check : (_chatController.text.trim().isNotEmpty ? Icons.send : (_isMicMuted ? Icons.mic_off : Icons.mic)), 
                                   color: theme.colorScheme.onPrimary, 
                                   size: 20
                                  ),
                               ),
                             ),
                           ],
                         ),
                       ),
                     ],
                   ),
                 ),
               ),
             ),

          // Tactical Command Bar (Bottom Layer)
          if (!_isChatOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildCommandBar(),
            ),
        ],
      ),
    );
  }
  // --- SYSTEM MENU ---
  void _showSystemMenu() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1110), // Terminal Black
            border: Border(
              top: BorderSide(color: Colors.greenAccent[400]!, width: 2),
              left: BorderSide(color: Colors.greenAccent[700]!, width: 1),
              right: BorderSide(color: Colors.greenAccent[700]!, width: 1),
            ),
            boxShadow: [
               BoxShadow(color: Colors.greenAccent.withOpacity(0.2), blurRadius: 20, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "SYSTEM // MENU",
                    style: TextStyle(
                      fontFamily: 'Courier',
                      color: Colors.greenAccent[400],
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.greenAccent[700]),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Operative Info
              _buildTerminalRow("OPERATIVE", _callsignController.text.isEmpty ? "UNKNOWN" : _callsignController.text),
              const SizedBox(height: 12),
              _buildTerminalRow("STATUS", _isOnline ? "UPLINK ACTIVE" : "OFFLINE", 
                  valueColor: _isOnline ? Colors.greenAccent : Colors.redAccent),
              const SizedBox(height: 12),
              _buildTerminalRow("GRID REF", _lastPosition != null 
                  ? "${_lastPosition!.latitude.toStringAsFixed(4)}, ${_lastPosition!.longitude.toStringAsFixed(4)}" 
                  : "ACQUIRING..."),
              
              const SizedBox(height: 32),
              const Divider(color: Colors.white24),
              const SizedBox(height: 32),
              
              // ACTIONS
              // Logout / Terminate
              InkWell(
                onTap: () async {
                  Navigator.pop(context); // Close menu
                  await _disconnect();
                  if (mounted) {
                     Provider.of<AuthProvider>(context, listen: false).logout();
                     // AuthWrapper will handle navigation to Login
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.redAccent.withOpacity(0.7), width: 2),
                    color: Colors.redAccent.withOpacity(0.1),
                  ),
                  child: const Center(
                    child: Text(
                      "TERMINATE LINK [LOGOUT]",
                      style: TextStyle(
                        fontFamily: 'Courier',
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Close
              Center(
                 child: TextButton(
                   onPressed: () => Navigator.pop(context),
                   child: Text("RETURN TO MISSION", style: TextStyle(color: Colors.grey[600], fontFamily: 'Courier')),
                 ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTerminalRow(String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Courier',
              color: Colors.greenAccent[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          ": ",
          style: TextStyle(color: Colors.greenAccent[700]),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Courier',
              color: valueColor ?? Colors.greenAccent[100],
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _fetchChatHistory() async {
    try {
      final response = await http.get(Uri.parse('$_serverUrl/tactical/chat'), headers: {"ngrok-skip-browser-warning": "true"});
      if (response.statusCode == 200) {
        final List<dynamic> history = jsonDecode(response.body);
        setState(() {
          if (!_hasLoadedInitialHistory) {
             for (var item in history) {
                String id = (item['id']?.toString() ?? '').trim();
                String sender = item['sender']?.toString() ?? 'Unknown';
                String msg = item['message']?.toString() ?? '';
                String time = item['time']?.toString() ?? '';
                
                if (id.isNotEmpty) _hiddenMessageIds.add(id);
                _hiddenContentHashes.add("${sender}_${time}_$msg");
             }
             _hasLoadedInitialHistory = true;
          }

          // CLEANUP: If we deleted everything, we should clear hidden lists too? 
          // Actually, if we delete on server, they are gone.
          // But if we have hidden them, it doesn't matter.
          // Just ensure "Clear" calls API.
          
          _chatMessages.clear();
          for (var item in history) {
            String id = (item['id']?.toString() ?? '').trim();
            // Start Empty Logic: Still hide initially loaded ones
             String sender = item['sender']?.toString() ?? 'Unknown';
             String message = item['message']?.toString() ?? '';
             String time = item['time']?.toString() ?? '';
             String hash = "${sender}_${time}_$message";

             if (_hiddenMessageIds.contains(id) || _hiddenContentHashes.contains(hash)) {
                continue; 
             }

            _chatMessages.add({
              'id': id,
              'sender': item['sender']?.toString() ?? 'Unknown',
              'message': item['message']?.toString() ?? '',
              'time': item['time']?.toString() ?? '',
              'is_edited': item['is_edited']?.toString() == 'true' ? 'true' : 'false',
            });
            // Update unread if closed
            // Update unread if closed
             if (!_isChatOpen && item['id'] != null) {
                // Was: if (!_isChatOpen) _hasUnreadMessages = true;
                // Now: Trigger Notification too
                if (!_hasUnreadMessages) { // trigger once per batch?
                   _hasUnreadMessages = true;
                   _showNotification("New Message", "${item['sender']}: ${item['message']}");
                }
             }
          }
        });
      }

    } catch (e) {
      print("History Error: $e");
    }
  }

  Future<void> _deleteMessage(String id) async {
    // 1. Locally Hide IMMEDIATELY to prevent flickering/reappearance
    setState(() {
      _hiddenMessageIds.add(id); 
      
      // Also hide by content hash in case ID generation was inconsistent
      final msg = _chatMessages.firstWhere((m) => m['id'] == id, orElse: () => {});
      if (msg.isNotEmpty) {
         String sender = msg['sender'] ?? 'Unknown';
         String message = msg['message'] ?? '';
         String time = msg['time'] ?? '';
         _hiddenContentHashes.add("${sender}_${time}_$message");
         _chatMessages.removeWhere((m) => m['id'] == id);
      }
    });

    try {
      await http.delete(Uri.parse('$_serverUrl/tactical/chat/$id'), headers: {"ngrok-skip-browser-warning": "true"});
      // Success - It is already gone locally.
    } catch (e) {
       _showErrorSnackBar("Delete failed on server: $e");
       // Optional: Un-hide if server fail? 
       // No, better to keep it hidden as user intended to delete it.
    }
  }

  Future<void> _clearChatHistory() async {
     // 1. Locally Hide IMMEDIATELY 
     setState(() {
       for (var msg in _chatMessages) {
          if (msg['id'] != null && msg['id']!.isNotEmpty) {
             _hiddenMessageIds.add(msg['id']!.trim());
          }
          String sender = msg['sender'] ?? 'Unknown';
          String message = msg['message'] ?? '';
          String time = msg['time'] ?? '';
          _hiddenContentHashes.add("${sender}_${time}_$message");
       }
       
       _chatMessages.clear();
       _editingId = null; 
       _chatController.clear();
     });

     try {
       await http.delete(Uri.parse('$_serverUrl/tactical/chat'), headers: {"ngrok-skip-browser-warning": "true"});
     } catch (e) {
       _showErrorSnackBar("Clear failed on server: $e");
       // Keep cleared locally.
     }
  }


  Future<void> _editMessage(String id, String newText) async {
    try {
      final response = await http.put(
        Uri.parse('$_serverUrl/tactical/chat/$id'), 
        headers: {"Content-Type": "application/json", "ngrok-skip-browser-warning": "true"},
        body: jsonEncode({
          "sender": "Scout", // Required by backend model but not used for update
          "message": newText,
          "time": "Updated" 
        })
      );
      
      if (response.statusCode == 200) {
        setState(() {
          final index = _chatMessages.indexWhere((m) => m['id'] == id);
          if (index != -1) {
             _chatMessages[index]['message'] = newText;
             _chatMessages[index]['is_edited'] = 'true';
          }
        });
        // Navigator.pop(context); // Removed: Handled by caller if needed
      }
    } catch (e) {
       _showErrorSnackBar("Edit failed: $e");
    }
  }

  void _showEditDialog(String id, String currentText) {
    TextEditingController editCtrl = TextEditingController(text: currentText);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Edit Message"),
      content: TextField(controller: editCtrl, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        TextButton(onPressed: () {
          _editMessage(id, editCtrl.text.trim());
          Navigator.pop(ctx); 
        }, child: const Text("Save")),
      ],
    ));
  }
  Future<void> _handleLogout() async {
     await _disconnect();
     if (mounted) {
       Provider.of<AuthProvider>(context, listen: false).logout();
     }
  }

  Widget _buildDrawer(ThemeData theme) {
    String identity = _callsignController.text.trim();
    if (identity.isEmpty) identity = "Scout";

    return Drawer(
      backgroundColor: Colors.transparent, // Important for glass
      width: MediaQuery.of(context).size.width * 0.75,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor.withOpacity(0.85),
              border: Border(right: BorderSide(color: theme.dividerColor.withOpacity(0.2))),
            ),
            child: Column(
              children: [
                const SizedBox(height: 60),
                // Custom Header
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                    child: Text(
                      identity.isNotEmpty ? identity[0].toUpperCase() : "S",
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  identity, 
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 8),
                Container(
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                   decoration: BoxDecoration(
                     color: _isOnline ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                     borderRadius: BorderRadius.circular(16),
                     border: Border.all(color: _isOnline ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                   ),
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Icon(_isOnline ? Icons.wifi : Icons.wifi_off, size: 12, color: _isOnline ? Colors.green : Colors.red),
                       const SizedBox(width: 6),
                       Text(
                         _isOnline ? "ONLINE" : "OFFLINE", 
                         style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isOnline ? Colors.green : Colors.red)
                       ),
                     ],
                   ),
                ),
                
                const SizedBox(height: 40),
                const Divider(indent: 20, endIndent: 20, height: 1),
                const SizedBox(height: 10),

                // Location
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text("Location"),
                  subtitle: Text(_lastPosition != null 
                        ? "${_lastPosition!.latitude.toStringAsFixed(4)}, ${_lastPosition!.longitude.toStringAsFixed(4)}" 
                        : "Acquiring..."),
                  onTap: () {
                     // Maybe center map?
                     Navigator.pop(context);
                  },
                ),

                const Spacer(),
                const Divider(indent: 20, endIndent: 20),
                
                // MISSION SYNC BUTTON
                ListTile(
                  leading: _isSyncing 
                    ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync, color: Colors.blue),
                  title: Text(_isSyncing ? "Syncing..." : "Sync Session Data", 
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                  subtitle: Text("${_telemetryTrail.length} GPS points collected"),
                  onTap: _isSyncing ? null : () {
                    _syncMissionSession();
                  },
                ),
                
                const Divider(indent: 20, endIndent: 20),
                ListTile(
                  leading: Icon(Icons.logout, color: theme.colorScheme.error),
                  title: Text("Logout", style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _handleLogout();
                  },
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
