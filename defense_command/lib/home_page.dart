import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'services/livekit_service.dart';
import 'package:livekit_client/livekit_client.dart';
import 'providers/entity_provider.dart';
import 'pages/entity_list_page.dart';
import 'services/api_service.dart';
import 'utils/map_styles.dart';
import 'utils/unsafe_tile_provider.dart';
import 'utils/map_layers_helper.dart';





class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedTab = 0;
  final MapController _mapController = MapController();
  final TextEditingController _chatController = TextEditingController(); // Chat Controller
  Timer? _locationTimer;
  
  // Map State
  // Default center (Hyderabad)
  LatLng _currentCenter = const LatLng(17.3850, 78.4867);
  double _currentZoom = 13.0;
  double _currentAccuracy = 0.0; // Accuracy in meters
  
  // Tactical Entities
  // Managed by EntityProvider now

  // Map Styles
  late MapStyle _currentMapStyle;
  // Local list removed, using kMapStyles from utils
  
  // Tactical Pins State
  // Dynamic Data State (From Provider)
  // Local list removed

  // Advanced Map Layers State
  bool _isHeatMapEnabled = false; // Now "Temperature"
  bool _isPressureMapEnabled = false; // New "Pressure"
  bool _isTempMapEnabled = false; // Now "Clouds"
  bool _isHumidityMapEnabled = false; // Now "Wind"
  bool _isPrecipitationMapEnabled = false;

  // Weather Probe
  Map<String, dynamic>? _currentWeather;
  Timer? _weatherDebounce;

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

  void _onMapMove(MapCamera pos, bool hasGesture) {
    if (_weatherDebounce?.isActive ?? false) _weatherDebounce!.cancel();
    _weatherDebounce = Timer(const Duration(milliseconds: 800), _fetchWeatherForCenter);
  }

  Widget _buildOverlayToggle(ThemeData theme, String title, IconData icon, Color color, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: color,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      dense: true,
    );
  }
 
  @override
  void initState() {
    super.initState();
    _currentMapStyle = kMapStyles[0];
    
    // Initial Random Entities managed by EntityProvider
    _wipeServerData(); // Wipe slate clean on startup

    // Connect to LiveKit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectToLiveKit();
    });

    // Try to get location on startup
    Future.delayed(const Duration(milliseconds: 500), () {
      // Optional: Don't auto-override Hyderabad for now unless user asks
      _getCurrentLocation(silent: true);
    });
  }

  Future<void> _connectToLiveKit() async {
    final liveKitService = Provider.of<LiveKitService>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    if (!liveKitService.isConnected) {
      try {
        const url = ApiService.livekitUrl;
        // Fetch Token with DYNAMIC IDENTITY
        // This fixes the bug where multiple devices kicked each other off
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
               if (jsonBody.containsKey('token')) {
                 actualToken = jsonBody['token'];
               }
               if (jsonBody.containsKey('url')) {
                 connectUrl = jsonBody['url'];
               }
             }
           } catch (_) {}

           await liveKitService.connect(connectUrl, actualToken); // Connect
           
           // Hook up EntityProvider to listen for data (Chat & Locations)
           if (mounted) {
             Provider.of<EntityProvider>(context, listen: false).updateLiveKitService(liveKitService);
           }
           
           // If Soldier, Start Sending Location Updates
           if (!auth.isCommander) {
             _startSendingLocationUpdates();
           }
           
        } else {
          debugPrint('Failed to fetch token: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Error connecting to LiveKit: $e');
      }
    }
  }

  void _startSendingLocationUpdates() {
    _locationTimer?.cancel();
    debugPrint("Starting GPS Location Broadcast...");
    _locationTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
       try {
         final Position position = await Geolocator.getCurrentPosition(
           desiredAccuracy: LocationAccuracy.medium, // Balance battery/precision
         );
         
         final auth = Provider.of<AuthProvider>(context, listen: false);
         final liveKit = Provider.of<LiveKitService>(context, listen: false);
         
         if (liveKit.isConnected) {
            liveKit.publishData({
               'id': auth.identity, // Unique ID
               'lat': position.latitude,
               'long': position.longitude,
               'type': 'soldier', // Could be dynamic
            });
         }
       } catch (e) {
         debugPrint("Error sending location: $e");
       }
    });
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





  final List<String> _tabLabels = ['Details', 'Alerts', 'Chats'];
  


  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _wipeServerData() async {
    try {
      final url = Uri.parse("${ApiService.baseUrl}/tactical/clear");
      await http.delete(url);
      debugPrint("🧹 Server memory wiped for new session.");
    } catch (e) {
      debugPrint("Wipe failed: $e");
    }
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
                subtitle: Text("Reported by: ${entity.reporterId ?? entity.id}"),
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

  List<Marker> _generateMarkers(List<MapEntity> entities) {
    final Map<String, List<MapEntity>> groupedEntities = {};
    for (var entity in entities) {
      String key = "${entity.position.latitude.toStringAsFixed(3)}_${entity.position.longitude.toStringAsFixed(3)}";
      if (!groupedEntities.containsKey(key)) groupedEntities[key] = [];
      groupedEntities[key]!.add(entity);
    }

    final List<Marker> newMarkers = [];

    groupedEntities.forEach((key, cluster) {
       final firstEntity = cluster.first;
       final position = firstEntity.position;

       if (cluster.length == 1) {
         final entity = cluster.first;
         IconData iconData;
         Color color;
         
         String type = entity.type.toLowerCase();
         if (type.contains('tank')) { iconData = Icons.local_shipping; color = Colors.red; }
         else if (type.contains('artillery')) { iconData = Icons.my_location; color = Colors.purple; }
         else if (type.contains('uav')) { iconData = Icons.flight; color = Colors.blue; }
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

  void _zoomIn() {
    setState(() {
      _currentZoom++;
      _mapController.move(_mapController.camera.center, _currentZoom);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom--;
      _mapController.move(_mapController.camera.center, _currentZoom);
    });
  }

  // Search Location using OpenStreetMap Nominatim API
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1');
      final response = await http.get(url, headers: {'User-Agent': 'DefenseCommandApp/1.0'});

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final newCenter = LatLng(lat, lon);
          
          _mapController.move(newCenter, 15.0);
          setState(() {
             _currentZoom = 15.0;
             _currentCenter = newCenter; // Move blue dot to search result
          });
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

  // Get Current GPS Location
  Future<void> _getCurrentLocation({bool silent = false}) async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check Service Status
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!silent && mounted) {
        // If actively pressed, ask to open settings
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location services are disabled.'),
            action: SnackBarAction(
              label: 'ENABLE',
              onPressed: () {
                Geolocator.openLocationSettings();
              },
            ),
          ),
        );
      }
      return;
    }

    // 2. Check/Request Permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied')));
        }
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location permissions are permanently denied.'),
            action: SnackBarAction(
              label: 'SETTINGS',
              onPressed: () {
                Geolocator.openAppSettings();
              },
            ),
          ),
        );
      }
      return;
    } 

    // 3. Get Position
    try {
       if (!silent && mounted) {
         ScaffoldMessenger.of(context).hideCurrentSnackBar();
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text('Acquiring GPS Signal...'), 
             duration: Duration(milliseconds: 1000),
           ),
         );
       }

       final Position position = await Geolocator.getCurrentPosition(
         desiredAccuracy: LocationAccuracy.best, // Changed to 'best' for highest precision
         timeLimit: const Duration(seconds: 15), 
       );
       final newCenter = LatLng(position.latitude, position.longitude);
    
       _mapController.move(newCenter, 15.0);
       setState(() {
         _currentZoom = 15.0;
         _currentCenter = newCenter;
         _currentAccuracy = position.accuracy;
       });
       
       if (!silent && mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
       }

    } catch (e) {
       // On Error, keep the Hyderabad default but ensure Accuracy Circle is visible for demo
       if (mounted) {
          setState(() {
             // Set a default accuracy radius so the circle is visible even if GPS fails
             if (_currentAccuracy == 0) _currentAccuracy = 1000.0; 
          });
       }

       if (!silent && mounted) {
         debugPrint("Error getting location: $e");
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('GPS Error: $e'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
         );
       }
    }
  }
  
  // Custom Marker Icon Loader with Fallback
  Widget _getMarkerIcon(String type) {
    IconData iconData = Icons.person;
    Color color = Colors.orangeAccent;
    
    if (type == 'uav') {
       iconData = Icons.flight;
       color = Colors.purpleAccent;
    } else if (type == 'scout') {
       iconData = Icons.person; 
       color = Colors.tealAccent;
    } else if (type == 'tank') {
       iconData = Icons.agriculture; // Tractor/Heavy Vehicle Proxy
       color = Colors.redAccent;
    } else if (type == 'truck') {
       iconData = Icons.local_shipping; // Transport
       color = Colors.brown;
    } else if (type == 'artillery') {
       iconData = Icons.flight; // "Use uavs with flight icons" as requested
       color = Colors.deepOrange;
    } else if (type == 'soldier') {
       iconData = Icons.person;
       color = Colors.orange;
    }

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      child: Icon(
        iconData,
        color: color,
        size: 32, // Slightly larger for visibility
        shadows: const [
          BoxShadow(color: Colors.black, blurRadius: 4),
        ],
      ),
    );
  }



  void _showMapStyleSelector(BuildContext context) {
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
              const SizedBox(height: 16),
              
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
                     _fetchWeatherForCenter();
                   } else { _currentWeather = null; }
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
                     _fetchWeatherForCenter();
                   } else { _currentWeather = null; }
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
                     _fetchWeatherForCenter();
                   } else { _currentWeather = null; }
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
                     _fetchWeatherForCenter();
                   } else { _currentWeather = null; }
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
                     _fetchWeatherForCenter();
                   } else { _currentWeather = null; }
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





  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final auth = Provider.of<AuthProvider>(context);
    final entityProvider = Provider.of<EntityProvider>(context);
    final isCommander = auth.isCommander;
    
    final visibleTabs = isCommander ? _tabLabels : _tabLabels.sublist(0, 2);

    // Generate Markers dynamically from Provider
    // (Variables already declared above)
    final authProvider = Provider.of<AuthProvider>(context);
    final liveKitService = Provider.of<LiveKitService>(context);

    // 1. Generate Tactical Markers from EntityProvider
    final List<Marker> tacticalMarkers = _generateMarkers(entityProvider.entities);

    // 2. Generate LiveKit Markers
    final Map<String, Marker> liveKitMarkers = {};
    for (var p in liveKitService.participants) {
      if (p.identity != authProvider.identity) {
         liveKitMarkers[p.identity] = Marker(
           point: const LatLng(0,0), // Placeholder, updated via data
           width: 40,
           height: 40,
           child: const Icon(Icons.person_pin_circle, color: Colors.greenAccent),
         );
      }
    }
    
    // Alias tacticalMarkers to markers for legacy code compatibility
    final markers = tacticalMarkers;
    
    final bool showBaseMap = !(_isHeatMapEnabled || _isTempMapEnabled || _isHumidityMapEnabled || _isPrecipitationMapEnabled);

    return SingleChildScrollView(
      child: Column(
        children: [
          // Map Section (48.5% of screen height)
          Container( // Changed SizedBox to Container for color
            height: MediaQuery.of(context).size.height * 0.485,
            color: Colors.black, // Dark background for opaque maps
            child: Stack(
              children: [
                // Map Background with FlutterMap
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentCenter,
                    initialZoom: _currentZoom,
                    minZoom: 3.0,
                    maxZoom: 18.0,
                    onPositionChanged: _onMapMove, // Hook up weather update
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
                        userAgentPackageName: 'com.example.defense_command',
                        tileProvider: UnsafeTileProvider(),
                      ),

                    // 2. OVERLAYS (Heat/Weather/Wind)
                    ...buildTacticalMapLayers(
                      context: context,
                      showWeather: _isTempMapEnabled, // Clouds
                      showTemperature: _isHeatMapEnabled, // Temperature
                      showPressure: _isPressureMapEnabled, // Pressure
                      showWind: _isHumidityMapEnabled,
                      showPrecipitation: _isPrecipitationMapEnabled,
                    ),
                    
                    // 3. Current Location Layer (Accuracy Halo)
                    CircleLayer(
                      circles: [
                        if (_currentAccuracy > 0)
                          CircleMarker(
                            point: _currentCenter,
                            radius: _currentAccuracy,
                            useRadiusInMeter: true,
                            color: Colors.blue.withOpacity(0.15),
                            borderColor: Colors.blue.withOpacity(0.4),
                            borderStrokeWidth: 1,
                          ),
                      ],
                    ),

                    // 4. Current Location Marker (Blue Dot)
                    MarkerLayer(
                      markers: [
                         Marker(
                           point: _currentCenter,
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

                    // 5. User & LiveKit Markers
                    MarkerLayer(
                      markers: [
                        ...markers,
                        ...liveKitMarkers.values,
                      ],
                    ),
                  ],
                ),
                
                // Top Right Controls (Map Select Only)
                if (isCommander)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.dividerColor),
                      boxShadow: [
                         BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.layers, 
                        color: theme.iconTheme.color,
                      ),
                      tooltip: "Change Map Layer",
                      onPressed: () => _showMapStyleSelector(context),
                    ),
                  ),
                ),




                // Search Bar (Extended)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 80, // Extended to near the right edge (80px for Map Select button space)
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor.withOpacity(0.9), 
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.dividerColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: TextField(
                      onSubmitted: (value) => _searchLocation(value), // Trigger search
                      textInputAction: TextInputAction.search, // Show Search button on keyboard
                      decoration: InputDecoration(
                        hintText: "Search assets...",
                        hintStyle: theme.textTheme.bodyMedium,
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search, color: theme.iconTheme.color),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        filled: true,
                        fillColor: Colors.transparent, // Let container color show through
                        hoverColor: Colors.transparent,
                      ),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ),

                // Map Controls (Bottom Right)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Zoom Controls
                      Material(
                        color: theme.cardColor.withOpacity(0.9),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                        child: InkWell(
                          onTap: _zoomIn,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(Icons.add, color: theme.iconTheme.color),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Material(
                        color: theme.cardColor.withOpacity(0.9),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                        child: InkWell(
                          onTap: _zoomOut,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                          child: Container(
                             padding: const EdgeInsets.all(8),
                             child: Icon(Icons.remove, color: theme.iconTheme.color),
                          ),
                        ),
                      ),
                       const SizedBox(height: 16),

                    ],
                  ),
                ),
                  
                  // --- LEGEND (Dynamic) ---
                  if (_isHeatMapEnabled || _isPressureMapEnabled || _isHumidityMapEnabled || _isPrecipitationMapEnabled)
                    Positioned(
                      bottom: 16, 
                      left: 80, // Beside the Location Button (16 + ButtonWidth + Spacing)
                      child: _buildLegend(),
                    ),
                    
                  // Floating Action Button (Weather Probe)
                  Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.dividerColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          _getCurrentLocation();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.my_location,
                            color: theme.iconTheme.color,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
        // Details Section
        Container(
            color: theme.scaffoldBackgroundColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Tab Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ...visibleTabs.asMap().entries.map((entry) {
                      int index = entry.key;
                      String label = entry.value;
                      bool isSelected = _selectedTab == index;
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedTab = index;
                                final p = Provider.of<EntityProvider>(context, listen: false);
                                if (index == 2) { // Chats index
                                   p.setChatOpen(true);
                                } else {
                                   p.setChatOpen(false);
                                }
                              });
                            },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? (isDark ? const Color(0xFF2A2A2A) : Colors.grey[300])
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected 
                                    ? theme.dividerColor
                                    : Colors.transparent,
                              ),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    color: isSelected 
                                        ? theme.textTheme.bodyLarge?.color 
                                        : theme.textTheme.bodyMedium?.color,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                  if (label == 'Chats' && entityProvider.hasUnreadMessages)
                                    Positioned(
                                      right: -12,
                                      top: -8,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                        child: Text(
                                          entityProvider.unreadCount.toString(),
                                          style: const TextStyle(
                                            color: Colors.white, 
                                            fontSize: 10, 
                                            fontWeight: FontWeight.bold
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                    );
                  }),
                ],
              ),
                
                const SizedBox(height: 20),
                
                // Content based on selected tab
                _buildContent(theme, entityProvider),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, EntityProvider provider) {
    switch (_selectedTab) {
      case 0:
        return _buildDetailsTable(theme, provider);
      case 1:
        return _buildAlertsList(theme, provider);
      case 2:
        return _buildChatList(theme, provider);
      default:
        return Container();
    }
  }

  Widget _buildDetailsTable(ThemeData theme, EntityProvider provider) {
    // Uses data From Provider
    final detailsData = provider.unitDetails;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.dividerColor,
          width: 1,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor,
                    width: 1,
                  ),
                ),
                color: theme.brightness == Brightness.dark 
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey[200],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Unit Type',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Count',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Table Rows
            if (detailsData.isEmpty || detailsData.every((e) => e['count'] == 0))
                   // Default Empty State (Show 0s)
                   ...[
                     {'label': 'Soldiers', 'count': 0},
                     {'label': 'Tanks', 'count': 0},
                     {'label': 'UAVs', 'count': 0},
                     {'label': 'Artillery', 'count': 0},
                   ].map((item) {
                       return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor))),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text(item['label'].toString(), style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14))),
                            Expanded(flex: 1, child: Text("0", style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold))),
                            Icon(Icons.arrow_forward_ios, size: 12, color: theme.iconTheme.color?.withOpacity(0.5))
                          ],
                        ),
                      );
                   })
            else
            ...detailsData.map((item) {
              bool isLast = detailsData.last == item;
              
              Widget rowContent = Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        item['label'],
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        item['count'].toString(),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 12, color: theme.iconTheme.color?.withOpacity(0.5))
                  ],
                );

              return InkWell(
                onTap: () {
                   String type = item['label'].toString().toLowerCase();
                   if (type.endsWith('s')) type = type.substring(0, type.length - 1);
                   
                   // Exception for 'artillery' (already singular-ish or same)
                   if (item['label'] == 'Artillery') type = 'artillery';
                   
                   Navigator.push(context, MaterialPageRoute(builder: (context) => EntityListPage(
                     title: "${item['label']} List",
                     entityType: type,
                   )));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: isLast
                          ? BorderSide.none
                          : BorderSide(
                              color: theme.dividerColor,
                              width: 1,
                            ),
                    ),
                  ),
                  child: rowContent,
                ),
              );
            }),
            
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor,
                    width: 1,
                  ),
                ),
                color: theme.brightness == Brightness.dark 
                  ? Colors.black.withOpacity(0.3)
                  : Colors.grey[100],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Last updated: 15:42:23',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark 
                          ? Colors.grey[800] 
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'OPERATIONAL',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsList(ThemeData theme, EntityProvider provider) {
    // Maps list of dynamic maps to widgets
    final alerts = provider.alerts;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
             padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text(
                   'Recent Alerts',
                   style: theme.textTheme.bodyLarge?.copyWith(
                     fontWeight: FontWeight.w600,
                   ),
                 ),
                 Container(
                   padding: const EdgeInsets.symmetric(
                     horizontal: 12,
                     vertical: 4,
                   ),
                   decoration: BoxDecoration(
                     color: theme.brightness == Brightness.dark 
                         ? Colors.grey[800] 
                         : Colors.grey[300],
                     borderRadius: BorderRadius.circular(4),
                   ),
                   child: Text(
                     '${alerts.length} Active',
                     style: theme.textTheme.bodyMedium?.copyWith(
                       color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                       fontSize: 12,
                       fontWeight: FontWeight.w600,
                     ),
                   ),
                 ),
               ],
             ),
           ),
           
           if (alerts.isEmpty)
              Padding(padding: EdgeInsets.all(20), child: Center(child: Text("All Clear")))
           else
             ...alerts.map((alert) {
               return Container(
                 padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                 decoration: BoxDecoration(
                   border: Border(
                     top: BorderSide(
                       color: theme.dividerColor,
                       width: 1,
                     ),
                   ),
                 ),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text(
                           alert.title,
                           style: theme.textTheme.bodyLarge?.copyWith(
                             fontSize: 15,
                             fontWeight: FontWeight.w500,
                           ),
                         ),
                         Text(
                           alert.time,
                           style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                         ),
                       ],
                     ),
                     const SizedBox(height: 6),
                     Text(
                       alert.message,
                       style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                     ),
                   ],
                 ),
               );
             }),
             
             Container(
               padding: const EdgeInsets.all(16),
               child: Center(
                 child: Text(
                   'All alerts are being monitored',
                   style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                 ),
               ),
             ),
        ],
      ),
    );
  }

  Widget _buildChatList(ThemeData theme, EntityProvider provider) {
    final chatList = provider.chatMessages;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final myIdentity = auth.identity ?? "Unknown";
    final isCommander = auth.isCommander;

    return Container(
      // height: 600, // REMOVED FIXED HEIGHT to allow natural scrolling
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
              color: theme.brightness == Brightness.dark ? Colors.black.withOpacity(0.3) : Colors.grey[200],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Mission Chat", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                             provider.clearChatHistory();
                             Navigator.pop(ctx);
                           }, 
                           child: const Text("Clear", style: TextStyle(color: Colors.red))
                         ),
                       ],
                     ));
                  },
                )
              ],
            ),
          ),
          
          // Chat Area
            chatList.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: Text("No communications logs")),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: chatList.length,
                    shrinkWrap: true, // Allow sizing to content
                    physics: const NeverScrollableScrollPhysics(), // Let outer page scroll
                    itemBuilder: (context, index) {
                       final chat = chatList[index];
                       // Determine if "Me"
                       bool isMe = (chat.sender == myIdentity) || (isCommander && chat.sender == 'Commander');
                       
                       return Align(
                         alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                         child: GestureDetector(
                           behavior: HitTestBehavior.opaque,
                           onLongPressStart: (details) {
                               if (chat.id.isNotEmpty) {
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
                                       const PopupMenuItem(
                                         value: 'edit',
                                         child: Row(children: [Icon(Icons.edit, size: 20, color: Colors.blue), SizedBox(width: 8), Text("Edit")]),
                                       ),
                                       const PopupMenuItem(
                                         value: 'delete',
                                         child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))]),
                                       ),
                                     ],
                                     elevation: 8.0,
                                   ).then((value) {
                                     if (value == 'edit') {
                                        TextEditingController editCtrl = TextEditingController(text: chat.message);
                                        showDialog(context: context, builder: (editCtx) => AlertDialog(
                                           title: const Text("Edit Message"),
                                           content: TextField(controller: editCtrl, autofocus: true),
                                           actions: [
                                             TextButton(onPressed: () => Navigator.pop(editCtx), child: const Text("Cancel")),
                                             TextButton(onPressed: () {
                                               provider.editChatMessage(chat.id, editCtrl.text.trim());
                                               Navigator.pop(editCtx);
                                             }, child: const Text("Save")),
                                           ],
                                        ));
                                     } else if (value == 'delete') {
                                        provider.deleteChatMessage(chat.id);
                                     }
                                   });
                               }
                           },
                           child: Container(
                             margin: const EdgeInsets.symmetric(vertical: 4),
                             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                             constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                             decoration: BoxDecoration(
                               color: isMe 
                                   ? (theme.brightness == Brightness.dark ? Colors.blue[900] : Colors.blue[100])
                                   : (theme.brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200]),
                               borderRadius: BorderRadius.circular(12).copyWith(
                                 bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                                 topLeft: isMe ? const Radius.circular(12) : Radius.zero,
                               ),
                             ),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               if (!isMe)
                               Text(
                                 chat.sender, 
                                 style: TextStyle(
                                   fontSize: 10, 
                                   fontWeight: FontWeight.bold,
                                   color: theme.dividerColor
                                 )
                               ),
                               Text(
                                 chat.message,
                                 style: theme.textTheme.bodyMedium,
                               ),
                               const SizedBox(height: 2),
                               Align(
                                 alignment: Alignment.bottomRight,
                                 child: Text(
                                   chat.time,
                                   style: TextStyle(
                                     fontSize: 9, 
                                     color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)
                                   ),
                                 ),
                               ),
                             ],
                           ),
                           ), // End Container
                         ), // End GestureDetector
                       ); // End Align
                    },
                  ),
          // REMOVED Expanded - now just part of column
            
            // New message input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark ? Colors.grey[900] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _chatController, // Bind Controller
                        decoration: const InputDecoration(
                          hintText: "Type message...",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        style: theme.textTheme.bodyLarge,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (val) { // Allow Enter key to send
                           if (val.trim().isNotEmpty) {
                             String sender = isCommander ? "Commander" : myIdentity;
                             provider.sendChatMessage(sender, val.trim());
                             _chatController.clear();
                           }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                     backgroundColor: Colors.blueAccent,
                     child: IconButton(
                        onPressed: () {
                          if (_chatController.text.trim().isNotEmpty) {
                               String sender = isCommander ? "Commander" : myIdentity;
                               provider.sendChatMessage(sender, _chatController.text.trim());
                               _chatController.clear();
                          }
                        },
                        icon: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                  ),
                ],
              ),
            ),
        ],
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