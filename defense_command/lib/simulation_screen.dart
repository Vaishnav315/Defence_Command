import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'services/api_service.dart';
import 'utils/map_styles.dart';
import 'utils/unsafe_tile_provider.dart';
import 'utils/map_layers_helper.dart';

import 'package:provider/provider.dart';
import 'providers/entity_provider.dart';
import 'providers/auth_provider.dart';
import 'services/livekit_service.dart';
import 'package:livekit_client/livekit_client.dart';

import 'dart:io';
import 'dart:async';
import 'package:geolocator/geolocator.dart'; // For User Location

enum PlacementMode { soldier, enemy, target }

enum EnemyType {
  soldier,
  tank,
  artillery,
}

class Enemy {
  final LatLng position;
  final EnemyType type;

  Enemy({required this.position, required this.type});
}

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  final MapController _mapController = MapController();
  
  // State
  PlacementMode _currentMode = PlacementMode.soldier;
  EnemyType _selectedEnemyType = EnemyType.soldier; 

  LatLng? _soldierPosition;
  LatLng? _targetPosition;
  final List<Enemy> _enemyPositions = [];
  List<LatLng> _pathPolyline = [];
  bool _isLoadingPath = false;
  
  // Map Style
  MapStyle _currentMapStyle = kMapStyles[0];

  // AI State
  bool _isGeneratingBriefing = false;

  // Advanced Map Layers State
  bool _isHeatMapEnabled = false; // Temperature
  bool _isPressureMapEnabled = false; // Pressure
  bool _isTempMapEnabled = false; // Clouds
  bool _isHumidityMapEnabled = false; // Wind
  bool _isPrecipitationMapEnabled = false;
  

  
  // Location State
  LatLng? _currentCenter; // User's real location
  double _currentAccuracy = 0;

  // Weather Probe
  Map<String, dynamic>? _currentWeather;
  Timer? _weatherDebounce;

  @override
  void initState() {
    super.initState();
    _wipeServerData(); // Wipe server memory for clean boot
    _initLocation(); // Center map on user

    // Connect to LiveKit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectToLiveKit();
    });
  }

  Future<void> _connectToLiveKit() async {
    final liveKitService = Provider.of<LiveKitService>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    if (!liveKitService.isConnected) {
      try {
        const url = ApiService.livekitUrl;
        final identity = auth.identity;
        debugPrint("Connecting to LiveKit with Identity: $identity");
        
        final tokenUri = Uri.parse('$url/token?identity=$identity');
        final response = await ApiService.client.get(tokenUri);
        
        if (response.statusCode == 200) {
           final token = response.body; 
           String actualToken = token;
           String connectUrl = url;
           try {
             final jsonBody = json.decode(token);
             if (jsonBody is Map) {
               if (jsonBody.containsKey('token')) actualToken = jsonBody['token'];
               if (jsonBody.containsKey('url')) connectUrl = jsonBody['url'];
             }
           } catch (_) {}

           await liveKitService.connect(connectUrl, actualToken);
           
           if (mounted) {
             Provider.of<EntityProvider>(context, listen: false).updateLiveKitService(liveKitService);
           }
        }
      } catch (e) {
        debugPrint('Error connecting to LiveKit: $e');
      }
    } else {
       // Already connected, just ensure EntityProvider is hooked
       if (mounted) {
         Provider.of<EntityProvider>(context, listen: false).updateLiveKitService(liveKitService);
       }
    }
  }

  void _showVideoFeed(BuildContext context, String entityId) {
    final liveKitService = Provider.of<LiveKitService>(context, listen: false);
    
    // Find Participant with identity == entityId
    Participant? targetParticipant;
    try {
      targetParticipant = liveKitService.participants.firstWhere(
        (p) => p.identity == entityId,
      );
    } catch (e) {
      // Not found
    }

    VideoTrack? videoTrack;
    if (targetParticipant != null) {
       for (var p in targetParticipant.trackPublications.values) {
         if (p.kind == TrackType.VIDEO && p.subscribed && p.track is VideoTrack) {
           videoTrack = p.track as VideoTrack;
           break;
         }
       }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
           children: [
             // Header
             Container(
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(
                 border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
               ),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        Text('Live Feed: $entityId', style: Theme.of(context).textTheme.titleLarge),
                        Text('Status: ${videoTrack != null ? "Online" : "No Video Signal"}', style: Theme.of(context).textTheme.bodySmall),
                     ],
                   ),
                   IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                 ],
               ),
             ),
             // Video Area
             Expanded(
               child: Container(
                 color: Colors.black,
                 child: videoTrack != null 
                    ? VideoTrackRenderer(
                        videoTrack,
                        fit: VideoViewFit.cover,
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.signal_wifi_off, color: Colors.white54, size: 50),
                            const SizedBox(height: 10),
                            Text("Waiting for video stream...", style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
               ),
             ),
           ],
        ),
      ),
    );
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      if (mounted) {
        setState(() {
           _currentCenter = LatLng(position.latitude, position.longitude);
           _currentAccuracy = position.accuracy;
           // Move map to user location
           _mapController.move(_currentCenter!, 15.0);
        });
      }
    } catch (e) {
      debugPrint("Loc Error: $e");
    }
  }

  Future<void> _fetchWeatherForCenter() async {
    if (!_isHeatMapEnabled && !_isTempMapEnabled && !_isHumidityMapEnabled && !_isPrecipitationMapEnabled) {
      if (mounted) setState(() => _currentWeather = null);
      return;
    }

    final center = _mapController.camera.center;
    final url = Uri.parse("https://api.openweathermap.org/data/2.5/weather?lat=${center.latitude}&lon=${center.longitude}&appid=73d1d347e5e9cf2437c3c371525f236b&units=metric");
    
    try {
      final response = await ApiService.client.get(url);
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _currentWeather = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Weather Probe Error: $e");
    }
  }



  // Clear inspector when moving map aggressively? 
  // User said "When I drag my finger... update tooltip". 
  // So OnPositionChanged is useful too, but for "Center".
  // If user Taps, we inspect specific point.
  void _onMapMove(MapCamera pos, bool hasGesture) {
    // Optional: If we want to inspect the Center while dragging
    // _inspectLocation(pos.center); 
    // But this might be too much API trashing. User asked for "drag my finger". 
    // Let's stick to Tap for precision or limit drag updates.
  }

  Future<void> _wipeServerData() async {
    try {
      // Explicitly using the Global Base URL for Production
      final url = Uri.parse("${ApiService.baseUrl}/tactical/clear");
      await ApiService.client.delete(url);
      debugPrint("🧹 Server memory wiped for new session.");
      
      // Silent wipe - no user notification needed
    } catch (e) {
      debugPrint("Wipe failed: $e");
    }
  }

  @override
  void dispose() {
     super.dispose();
  }

  List<Marker> _generateMarkers(List<MapEntity> entities) {
    // 2. Cluster Validation (Strict 3-decimal precision ~100m)
    final Map<String, List<MapEntity>> groupedEntities = {};
    for (var entity in entities) {
      String key = "${entity.position.latitude.toStringAsFixed(3)}_${entity.position.longitude.toStringAsFixed(3)}";
      if (!groupedEntities.containsKey(key)) groupedEntities[key] = [];
      groupedEntities[key]!.add(entity);
    }

    final List<Marker> newMarkers = [];

    // 3. Generate Markers
    groupedEntities.forEach((key, cluster) {
       final firstEntity = cluster.first;
       final position = firstEntity.position;

       if (cluster.length == 1) {
         // OPTION A: SINGLE ITEM
         final entity = cluster.first;
         IconData iconData;
         Color color;
         
         String type = entity.type.toLowerCase();
         if (type.contains('tank')) { iconData = Icons.local_shipping; color = Colors.red; }
         else if (type.contains('artillery')) { iconData = Icons.my_location; color = Colors.purple; }
         else if (type.contains('intel')) { iconData = Icons.visibility; color = Colors.blue; }
         else { iconData = Icons.person; color = Colors.orange; }

         newMarkers.add(
            Marker(
              point: position,
              width: 60,
              height: 60,
              child: GestureDetector(
                onTap: () => _showVideoFeed(context, entity.id),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        entity.id,
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      iconData,
                      color: color,
                      size: 30,
                    ),
                  ],
                ),
              ),
            ),
         );
       } else {
         // OPTION B: CLUSTER
         newMarkers.add(
           Marker(
             point: position,
             width: 32,
             height: 32,
             child: GestureDetector(
               onTap: () => _showClusterDialog(cluster),
               child: Stack(
                 alignment: Alignment.center,
                 children: [
                   const Icon(
                     Icons.location_on, 
                     color: Colors.redAccent, 
                     size: 32,
                     shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                   ),
                   Positioned(
                     top: 5,
                     child: Text(
                       "${cluster.length}",
                       style: const TextStyle(
                         color: Colors.white, 
                         fontSize: 10, 
                         fontWeight: FontWeight.bold
                       ),
                     ),
                   ),
                 ],
               ),
             ),
           ),
         );
       }
    });
    return newMarkers;
  }

  void _showClusterDialog(List<MapEntity> cluster) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Cluster Content (${cluster.length})"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: cluster.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final entity = cluster[index];
              IconData icon;
              Color color;
              
              String type = entity.type.toLowerCase();
              if (type.contains('tank')) { icon = Icons.local_shipping; color = Colors.red; }
              else if (type.contains('artillery')) { icon = Icons.my_location; color = Colors.purple; }
              else if (type.contains('intel')) { icon = Icons.visibility; color = Colors.blue; }
              else { icon = Icons.person; color = Colors.orange; }

              return ListTile(
                leading: Icon(icon, color: color),
                title: Text(entity.type.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Reported by: ${entity.id}"),
                dense: true,
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE")),
        ],
      ),
    );
  }

  // Server Endpoint logic
  String get _serverUrl {
    return ApiService.calculatePathUrl;
  }
  
  String get _aiBriefingUrl {
    return ApiService.getAiBriefingUrl;
  }

  // --- AI COMMANDER LOGIC ---

  Future<void> _requestAiBriefing() async {
    setState(() {
      _isGeneratingBriefing = true;
    });

    try {
      final bounds = _mapController.camera.visibleBounds;
      
      // Reusing the same payload structure as pathfinding
      final payload = {
        "bounds": {
          "min_lat": bounds.southWest.latitude,
          "max_lat": bounds.northEast.latitude,
          "min_lng": bounds.southWest.longitude,
          "max_lng": bounds.northEast.longitude,
        },
        "soldier": _soldierPosition != null ? {
          "lat": _soldierPosition!.latitude,
          "lng": _soldierPosition!.longitude
        } : null,
        "target": _targetPosition != null ? {
          "lat": _targetPosition!.latitude,
          "lng": _targetPosition!.longitude
        } : null,
        "enemies": _enemyPositions.map((e) => {
          "lat": e.position.latitude,
          "lng": e.position.longitude,
          "type": e.type.name, // Sends 'soldier', 'tank', 'artillery'
        }).toList(),
      };

      final response = await ApiService.client.post(
        Uri.parse(_aiBriefingUrl),
        headers: {"Content-Type": "application/json", "ngrok-skip-browser-warning": "true"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['briefing'] != null) {
          _showBriefingDialog(data['briefing']);
        }
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Commander Offline: Radio connection failed.')),
           );
        }
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Commander Offline: $e')),
         );
      }
    } finally {
      setState(() {
        _isGeneratingBriefing = false;
      });
    }
  }

  void _showBriefingDialog(String briefing) {
    final theme = Theme.of(context);
    final kTerminalColor = Colors.cyanAccent;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.canvasColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.4,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                     children: [
                       Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                       const SizedBox(width: 12),
                       Text(
                         "AI ANALYSIS", 
                         style: TextStyle(
                           color: theme.colorScheme.primary, 
                           fontFamily: Platform.isIOS ? "Courier" : "monospace",
                           fontWeight: FontWeight.bold,
                           fontSize: 20,
                           letterSpacing: 2.0,
                         )
                       ),
                     ],
                   ),
                   Divider(color: theme.dividerColor, thickness: 1, height: 30),
                   Expanded(
                     child: SingleChildScrollView(
                       controller: scrollController,
                       child: _TypewriterText(
                         text: briefing,
                         style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                            fontFamily: Platform.isIOS ? "Courier" : "monospace",
                            fontSize: 16,
                            height: 1.5,
                         ),
                       ),
                     ),
                   ),
                   const SizedBox(height: 16),
                   SizedBox(
                     width: double.infinity,
                     child: OutlinedButton(
                       style: OutlinedButton.styleFrom(
                         foregroundColor: theme.colorScheme.primary,
                         side: BorderSide(color: theme.colorScheme.primary),
                       ),
                       onPressed: () => Navigator.pop(context), 
                       child: const Text("CLOSE BRIEFING")
                     ),
                   )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    debugPrint("📍 New Destination: ${point.latitude}, ${point.longitude}");
    
    setState(() {
      _pathPolyline = []; // Instant Visual Feedback: Clear old path
      
      switch (_currentMode) {
        case PlacementMode.soldier:
          _soldierPosition = point;
          break;
        case PlacementMode.enemy:
          _enemyPositions.add(Enemy(position: point, type: _selectedEnemyType));
          break;
        case PlacementMode.target:
          _targetPosition = point;
          break;
      }
    });
    
    // Tap-to-Move Logic
    if (_soldierPosition != null) {
       // If we just moved the soldier or target, navigate to target
       if (_currentMode == PlacementMode.target || _currentMode == PlacementMode.soldier) {
          _requestNavigation(point);
       }
       // If we placed an enemy, RE-CALCULATE path to the EXISTING target (if applicable)
       else if (_currentMode == PlacementMode.enemy && _targetPosition != null) {
          _requestNavigation(_targetPosition!);
       }
    }
  }

  // New Navigation Request to Fix 422 Error
  Future<void> _requestNavigation(LatLng target) async {
    if (_soldierPosition == null) {
      debugPrint("❌ ABORT: GPS Waiting...");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Place a Soldier first!')));
      }
      return;
    }

    debugPrint("🚀 Requesting Auto-Path from $_soldierPosition to $target...");

    setState(() => _isLoadingPath = true);

    try {
      final payload = {
        "start_lat": _soldierPosition!.latitude,
        "start_lng": _soldierPosition!.longitude,
        "end_lat": target.latitude,
        "end_lng": target.longitude,
        "mode": "auto",
        "enemies": _enemyPositions.map((e) => {
          "lat": e.position.latitude,
          "lng": e.position.longitude,
          "type": e.type.name
        }).toList(),
      };

      final response = await ApiService.client.post(
        Uri.parse(_serverUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['waypoints'] != null) {
          final List<dynamic> waypoints = data['waypoints'];
          setState(() {
            _pathPolyline = waypoints
                .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
                .toList();
          });
          debugPrint("✅ Path Received! Waypoints: ${waypoints.length}");
        }
      } else {
        debugPrint("❌ SERVER ERROR: ${response.statusCode}");
        debugPrint("❌ BODY: ${response.body}");
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Nav Failed: ${response.statusCode}')),
           );
        }
      }
    } catch (e) {
      debugPrint('Nav Exception: $e');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoadingPath = false);
    }
  }

  // Old _calculateTacticalPath removed/replaced by _requestNavigation

  void _showMapStyleSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, 
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Map Layer',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Grid of Options
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2.5, 
                ),
                itemCount: kMapStyles.length,
                itemBuilder: (context, index) {
                  final style = kMapStyles[index];
                  final isSelected = _currentMapStyle.title == style.title;
                  
                  return InkWell(
                    onTap: () {
                      setState(() {
                         _currentMapStyle = style;
                      });
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? theme.primaryColor.withOpacity(0.1) 
                            : theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? theme.primaryColor : theme.dividerColor,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            style.icon,
                            color: isSelected ? theme.primaryColor : theme.iconTheme.color,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  style.title,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? theme.primaryColor : null,
                                  ),
                                ),
                                Text(
                                  style.description,
                                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 24),
              Text(
                'Data Overlays',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              _buildOverlayToggle(theme, "Temperature", Icons.thermostat, Colors.orange, _isHeatMapEnabled, (val) {
                setState(() {
                   _isHeatMapEnabled = val; // Temperature
                   if (val) {
                     _isTempMapEnabled = false;
                     _isHumidityMapEnabled = false;
                     _isPrecipitationMapEnabled = false;
                     _isPressureMapEnabled = false;
                   }
                });
                Navigator.pop(context);
              }),
              _buildOverlayToggle(theme, "Pressure", Icons.speed, Colors.purple, _isPressureMapEnabled, (val) {
                setState(() {
                   _isPressureMapEnabled = val;
                   if (val) {
                     _isHeatMapEnabled = false;
                     _isTempMapEnabled = false;
                     _isHumidityMapEnabled = false;
                     _isPrecipitationMapEnabled = false;
                   }
                });
                Navigator.pop(context);
              }),
              _buildOverlayToggle(theme, "Clouds (Wx)", Icons.cloud, Colors.blue, _isTempMapEnabled, (val) {
                setState(() {
                   _isTempMapEnabled = val;
                   if (val) {
                     _isHeatMapEnabled = false;
                     _isHumidityMapEnabled = false;
                     _isPrecipitationMapEnabled = false;
                     _isPressureMapEnabled = false;
                   }
                });
                Navigator.pop(context);
              }),
              _buildOverlayToggle(theme, "Wind Speed", Icons.air, Colors.cyan, _isHumidityMapEnabled, (val) {
                setState(() {
                   _isHumidityMapEnabled = val;
                   if (val) {
                     _isHeatMapEnabled = false;
                     _isTempMapEnabled = false;
                     _isPrecipitationMapEnabled = false;
                     _isPressureMapEnabled = false;
                   }
                });
                Navigator.pop(context);
              }),
              _buildOverlayToggle(theme, "Precipitation", Icons.water_drop, Colors.indigo, _isPrecipitationMapEnabled, (val) {
                setState(() {
                   _isPrecipitationMapEnabled = val;
                   if (val) {
                     _isHeatMapEnabled = false;
                     _isTempMapEnabled = false;
                     _isHumidityMapEnabled = false; 
                     _isPressureMapEnabled = false;
                   }
                });
                Navigator.pop(context);
              })
            ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverlayToggle(ThemeData theme, String title, IconData icon, Color color, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: value ? color : theme.dividerColor, width: value ? 2 : 1),
      ),
      child: SwitchListTile(
        title: Row(
          children: [
            Icon(icon, color: value ? color : theme.iconTheme.color),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: value ? color : null)),
          ],
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: color,
      ),
    );
  }

  void _undoLastEnemy() {
    if (_enemyPositions.isNotEmpty) {
      setState(() {
        _enemyPositions.removeLast();
      });
      // _calculateTacticalPath(); // Removed
    }
  }


  void _clearAll() {
    setState(() {
      _soldierPosition = null;
      _targetPosition = null;
      _enemyPositions.clear();
      _pathPolyline.clear();
    });
  }



  // Search Location using OpenStreetMap Nominatim API
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1');
      final response = await ApiService.client.get(url, headers: {'User-Agent': 'DefenseCommandApp/1.0'});

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final newCenter = LatLng(lat, lon);
          
          _mapController.move(newCenter, 15.0);
          // Optional: Add a temporary marker or highlight
        } else {
           if (!mounted) return;
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Location not found')),
           );
        }
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Access Provider
    final entityProvider = Provider.of<EntityProvider>(context);
    // Generate Markers
    final tacticalMarkers = _generateMarkers(entityProvider.entities);

    // DEBUG LOGIC
    // DEBUG LOGIC


    return Scaffold(
      backgroundColor: Colors.black, // Dark background for opaque maps
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 50, // Standard Height (was 40)
        centerTitle: true,
        leadingWidth: 56,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            color: theme.appBarTheme.foregroundColor, // Match Theme
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'SIMULATION', 
            style: TextStyle(
              fontWeight: FontWeight.bold, // Bold (Fix "Too Thin")
              fontSize: 22, // Larger (was 18)
              letterSpacing: 1.0,
              color: theme.appBarTheme.foregroundColor, // Match Theme
            )
          ),
        ),
        bottom: _isLoadingPath 
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4), 
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent, 
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                )
              )
            : null,
        backgroundColor: theme.appBarTheme.backgroundColor, // Match Theme
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: theme.appBarTheme.foregroundColor, // Match Theme
            onPressed: _clearAll,
            tooltip: 'Reset Simulation',
          ),
          if (_isLoadingPath)
             const Padding(
               padding: EdgeInsets.all(12.0),
               child: SizedBox(width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
             )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(34.0522, -118.2437),
              initialZoom: 14.0,
              onTap: _onMapTap, // RESTORED TAPPING
              onPositionChanged: _onMapMove, 
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // 1. BASE MAP (User Selected)
              TileLayer(
                key: ValueKey(_currentMapStyle.url),
                urlTemplate: _currentMapStyle.url,
                subdomains: _currentMapStyle.subdomains,
                userAgentPackageName: 'com.groundstation.app',
                tileProvider: UnsafeTileProvider(),
              ),

              // 2. WEATHER OVERLAY 
              ...buildTacticalMapLayers(
                context: context,
                showWeather: _isTempMapEnabled, // Clouds
                showTemperature: _isHeatMapEnabled, // Temperature
                showPressure: _isPressureMapEnabled, // Pressure
                showWind: _isHumidityMapEnabled,
                showPrecipitation: _isPrecipitationMapEnabled,
              ),

              // 3. Markers & Paths
              PolylineLayer(
                polylines: [
                  if (_pathPolyline.isNotEmpty)
                    Polyline(points: _pathPolyline, strokeWidth: 4.0, color: Colors.blueAccent),
                ],
              ),
              
              // 4. Current Location Layer (Accuracy Halo)
              CircleLayer(
                circles: [
                  if (_currentAccuracy > 0 && _currentCenter != null)
                    CircleMarker(
                      point: _currentCenter!,
                      radius: _currentAccuracy,
                      useRadiusInMeter: true,
                      color: Colors.blue.withOpacity(0.15),
                      borderColor: Colors.blue.withOpacity(0.4),
                      borderStrokeWidth: 1,
                    ),
                ],
              ),

              // 5. Current Location Marker (Blue Dot)
              MarkerLayer(
                markers: [
                    if (_currentCenter != null)
                      Marker(
                        point: _currentCenter!,
                        width: 18,
                        height: 18,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
              
              MarkerLayer(
                markers: [
                   // Soldier (User) - Blue Glow
                   if (_soldierPosition != null) 
                      Marker(
                        point: _soldierPosition!, 
                        width: 35, 
                        height: 35, 
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.5),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.blueAccent.withOpacity(0.8), blurRadius: 10, spreadRadius: 1)
                            ],
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 20),
                        )
                      ),

                   // Target - Amber Glow
                   if (_targetPosition != null) 
                      Marker(
                        point: _targetPosition!, 
                        width: 35, 
                        height: 35, 
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.5),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.amber.withOpacity(0.8), blurRadius: 10, spreadRadius: 1)
                            ],
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.flag, color: Colors.white, size: 20),
                        )
                      ),
                   
                   // Enemies - Red Glow
                   ..._enemyPositions.map((e) => Marker(point: e.position, width: 30, height: 30, 
                      child: Container(
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.5),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.redAccent.withOpacity(0.8), blurRadius: 8, spreadRadius: 1)
                            ],
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Icon(
                            e.type == EnemyType.tank ? Icons.local_shipping : (e.type == EnemyType.artillery ? Icons.gps_fixed : Icons.warning), 
                            color: Colors.white, 
                            size: 16
                          ),
                   ))),
                   ...tacticalMarkers, 
                ],
              ),
            ],
          ),

          
          
          
          // --- MAIN HEADER (Title + Back) ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                bottom: 16,
                left: 16,
                right: 16
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              ),
              child: Row(
                children: [
                   // Back Button (Integrated in Header)
                   InkWell(
                     onTap: () => Navigator.pop(context),
                     child: Container(
                       padding: const EdgeInsets.all(8),
                       decoration: BoxDecoration(
                         color: Colors.white.withOpacity(0.1),
                         shape: BoxShape.circle,
                       ),
                       child: const Icon(Icons.arrow_back, color: Colors.white),
                     ),
                   ),
                   const SizedBox(width: 16),
                   // Title
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Text(
                         "SIMULATED ENVIRONMENT",
                         style: Theme.of(context).textTheme.titleSmall?.copyWith(
                           color: Colors.cyanAccent,
                           fontWeight: FontWeight.bold,
                           letterSpacing: 2,
                         ),
                       ),
                       const SizedBox(height: 2),
                       Text(
                         "TACTICAL MAP",
                         style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                           color: Colors.white,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                     ],
                   ),
                ],
              ),
            ),
          ),
          
          // --- SEARCH & LAYERS (Below Header) ---
          Positioned(
            top: MediaQuery.of(context).padding.top + 90, // Below the header
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Search Bar
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                    ),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: "Search Location...",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20),
                        suffixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: _searchLocation,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Layers Button
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.layers),
                    onPressed: _showMapStyleSelector,
                    tooltip: 'Map Layers',
                  ),
                ),
              ],
            ),
          ),






          // --- LEGEND (Dynamic) ---
          if (_isHeatMapEnabled || _isPressureMapEnabled || _isHumidityMapEnabled || _isPrecipitationMapEnabled)
            Positioned(
              bottom: 160, // Moved up to make room for GPS button
              left: 16,
              child: _buildLegend(),
            ),

          // MY LOCATION FAB (Bottom Left)
          Positioned(
            bottom: 100, 
            left: 16,
            child: Container(
               decoration: BoxDecoration(
                 color: Theme.of(context).cardColor,
                 borderRadius: BorderRadius.circular(12),
                 border: Border.all(color: Theme.of(context).dividerColor),
                 boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
               ),
               child: IconButton(
                 onPressed: () {
                   if (_currentCenter != null) {
                      _mapController.move(_currentCenter!, 15.0);
                   } else {
                      _initLocation();
                   }
                  },
                 icon: Icon(Icons.my_location, color: Theme.of(context).iconTheme.color),
                 tooltip: "My Location",
               ),
            ),
          ),

          // --- ZOOM CONTROLS (+/-) (Bottom Right) ---
          Positioned(
            bottom: 110, // Above User Location/Enemy Selector
            right: 16,
            child: Column(
              children: [
                _buildZoomButton(Icons.add, () {
                  final newZoom = _mapController.camera.zoom + 1;
                  _mapController.move(_mapController.camera.center, newZoom);
                }),
                const SizedBox(height: 8),
                _buildZoomButton(Icons.remove, () {
                  final newZoom = _mapController.camera.zoom - 1;
                  _mapController.move(_mapController.camera.center, newZoom);
                }),
              ],
            ),
          ),

          // --- AI COMMANDER BUTTON ---
          Positioned(
            top: MediaQuery.of(context).padding.top + 150, 
            left: 16,
            child: _buildAiAssistCard(),
          ),



          // --- ENEMY SELECTOR ---
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: Center(child: _buildEnemySelector()),
          ),
        ],
      ),
    );
  }






  // --- WIDGET BUILDERS ---
  
  Widget _buildZoomButton(IconData icon, VoidCallback onPressed) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
      ),
      child: IconButton(
        icon: Icon(icon, color: theme.colorScheme.primary),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildAiAssistCard() {
    final theme = Theme.of(context);
    final kTerminalColor = Colors.cyanAccent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), // Increased padding
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _isGeneratingBriefing ? kTerminalColor : Colors.transparent),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
      ),
      child: InkWell(
        onTap: _isGeneratingBriefing ? null : _requestAiBriefing,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isGeneratingBriefing)
              const SizedBox(
                width: 12, 
                height: 12, 
                child: CircularProgressIndicator(strokeWidth: 2)
              )
            else
              Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 18),
            
            const SizedBox(width: 8),
            
            Text(
              _isGeneratingBriefing ? "Analyzing..." : "AI ASSIST",
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnemySelector() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSelectorButton(
            mode: PlacementMode.soldier, 
            icon: Icons.person, 
            label: "Soldier", 
            color: Colors.blue
          ),
          
          // Enemy Group
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                _buildEnemyTypeButton(EnemyType.soldier, Icons.person, "Infantry"),
                _buildEnemyTypeButton(EnemyType.tank, Icons.local_shipping, "Heavy"),
                _buildEnemyTypeButton(EnemyType.artillery, Icons.gps_fixed, "Artillery"),
              ],
            ),
          ),

          _buildSelectorButton(
            mode: PlacementMode.target, 
            icon: Icons.flag, 
            label: "Target", 
            color: Colors.amber
          ),
          
          Container(width: 1, height: 24, color: theme.dividerColor),
          
          IconButton(
            onPressed: _undoLastEnemy,
            icon: Icon(Icons.undo, color: theme.iconTheme.color, size: 20),
            tooltip: 'Undo',
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorButton({
    required PlacementMode mode,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isSelected = _currentMode == mode;
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: () => setState(() => _currentMode = mode),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: color, width: 1) : Border.all(color: Colors.transparent),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: isSelected ? color : theme.disabledColor),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
              fontSize: 10, 
              fontWeight: FontWeight.bold, 
              color: isSelected ? color : theme.disabledColor,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildEnemyTypeButton(EnemyType type, IconData icon, String label) {
    final isModeSelected = _currentMode == PlacementMode.enemy;
    final isTypeSelected = _selectedEnemyType == type;
    final isActive = isModeSelected && isTypeSelected;
    final color = Colors.redAccent;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        setState(() {
          _currentMode = PlacementMode.enemy;
          _selectedEnemyType = type;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isActive ? Colors.white : (isModeSelected ? color : theme.disabledColor)),
            const SizedBox(height: 2),
             Text(
               // Shorten label for layout
               type == EnemyType.soldier ? "INF" : (type == EnemyType.tank ? "TNK" : "ART"), 
               style: TextStyle(
                fontSize: 9, 
                fontWeight: FontWeight.bold, 
                color: isActive ? Colors.white : (isModeSelected ? color : theme.disabledColor),
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    String title = "";
    List<Color> colors = [];
    String minLabel = "";
    String maxLabel = "";
    String midLabel = "";

    if (_isHeatMapEnabled) {
      title = "Temperature (°C)";
      colors = [Colors.purple, Colors.blue, Colors.green, Colors.yellow, Colors.red];
      minLabel = "-40";
      midLabel = "0";
      maxLabel = "+40";
    } else if (_isPressureMapEnabled) {
      title = "Pressure (hPa)";
      colors = [Colors.blue, Colors.green, Colors.yellow, Colors.red];
      minLabel = "950";
      midLabel = "1013";
      maxLabel = "1070";
    } else if (_isHumidityMapEnabled) { // Wind
      title = "Wind Speed (m/s)";
      colors = [Colors.green, Colors.yellow, Colors.red, Colors.purple];
      minLabel = "0";
      midLabel = "50";
      maxLabel = "100";
    } else if (_isPrecipitationMapEnabled) {
      title = "Precipitation (mm)";
      colors = [Colors.transparent, Colors.lightBlue, Colors.blue, Colors.indigo, Colors.purple];
      minLabel = "0";
      midLabel = "50";
      maxLabel = "200";
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          // Gradient Bar
          Container(
            width: 100, // Reduced width
            height: 8,  // Reduced height
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white30, width: 0.5),
            ),
          ),
          const SizedBox(height: 2),
          // Labels Row
          SizedBox(
            width: 110, // Match reduced width + margin
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(minLabel, style: const TextStyle(color: Colors.white70, fontSize: 8)),
                Text(midLabel, style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w500)),
                Text(maxLabel, style: const TextStyle(color: Colors.white70, fontSize: 8)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



class _TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration duration;

  const _TypewriterText({
    required this.text,
    required this.style,
    this.duration = const Duration(milliseconds: 50),
  });

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> {
  String _displayedText = "";
  int _currentIndex = 0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    _timer = Timer.periodic(widget.duration, (timer) {
      if (_currentIndex < widget.text.length) {
        setState(() {
          _displayedText += widget.text[_currentIndex];
          _currentIndex++;
        });
      } else {
        _timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(_displayedText, style: widget.style);
  }
}
