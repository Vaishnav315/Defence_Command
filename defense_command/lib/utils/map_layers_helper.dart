import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'unsafe_tile_provider.dart';

enum WeatherOverlayType {
  none,
  temp,
  wind,
  rain,
  humidity
}

List<Widget> buildTacticalMapLayers({
  required BuildContext context,
  required bool showWeather,
  required bool showTemperature,
  required bool showWind,
  required bool showPrecipitation,
  required bool showPressure, // NEW: Pressure
}) {
  const String apiKey = '73d1d347e5e9cf2437c3c371525f236b';

  return [
    // ATMOSPHERE LAYERS
    
    // 1. TEMPERATURE (OWM)
    if (showTemperature)
       TileLayer(
        urlTemplate: 'https://tile.openweathermap.org/map/temp_new/{z}/{x}/{y}.png?appid=$apiKey',
        tileProvider: UnsafeTileProvider(),
        keepBuffer: 5,
        userAgentPackageName: 'com.groundstation.app',
      ),

    // 2. PRESSURE (OWM) - NEW
    if (showPressure)
       TileLayer(
        urlTemplate: 'https://tile.openweathermap.org/map/pressure_new/{z}/{x}/{y}.png?appid=$apiKey',
        tileProvider: UnsafeTileProvider(),
        keepBuffer: 5,
        userAgentPackageName: 'com.groundstation.app',
      ),

    // 3. WEATHER / CLOUDS (OWM)
    if (showWeather)
      TileLayer(
        urlTemplate: 'https://tile.openweathermap.org/map/clouds_new/{z}/{x}/{y}.png?appid=$apiKey',
        tileProvider: UnsafeTileProvider(),
        keepBuffer: 5,
        userAgentPackageName: 'com.groundstation.app',
      ),
      
    // 4. WIND (OWM)
    if (showWind)
       TileLayer(
        urlTemplate: 'https://tile.openweathermap.org/map/wind_new/{z}/{x}/{y}.png?appid=$apiKey',
        tileProvider: UnsafeTileProvider(),
        keepBuffer: 5,
        userAgentPackageName: 'com.groundstation.app',
      ),
      
    // 5. PRECIPITATION (OWM)
    if (showPrecipitation)
       TileLayer(
        urlTemplate: 'https://tile.openweathermap.org/map/precipitation_new/{z}/{x}/{y}.png?appid=$apiKey',
        tileProvider: UnsafeTileProvider(),
        keepBuffer: 5,
        userAgentPackageName: 'com.groundstation.app',
      ),
  ];
}

