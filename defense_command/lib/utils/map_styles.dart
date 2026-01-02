import 'package:flutter/material.dart';

// Represents a Map Style configuration
class MapStyle {
  final String title;
  final String url;
  final List<String> subdomains;
  final IconData icon;
  final String description;

  const MapStyle({
    required this.title,
    required this.url,
    this.subdomains = const [],
    required this.icon,
    required this.description,
  });

  // Helper for NASA GIBS Date
  static String get _yesterdayStr {
    // NASA GIBS data often has 1-day lag for full global coverage
    final date = DateTime.now().subtract(const Duration(days: 1));
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}

// Shared list of available map styles
final List<MapStyle> kMapStyles = [
  MapStyle(
    title: 'Standard',
    url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    subdomains: ['a', 'b', 'c'], // OSM default subdomains
    icon: Icons.map_outlined,
    description: 'Default OSM View',
  ),
  MapStyle(
    title: 'Satellite',
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    icon: Icons.satellite_alt,
    description: 'Esri World Imagery',
  ),
  MapStyle(
    title: 'Light Mode', // NEW: CartoDB Positron
    url: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
    subdomains: ['a', 'b', 'c', 'd'],
    icon: Icons.light_mode,
    description: 'CartoDB Positron (Clean)',
  ),
  MapStyle(
    title: 'Dark Mode',
    url: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
    subdomains: ['a', 'b', 'c', 'd'],
    icon: Icons.dark_mode,
    description: 'CartoDB Dark Matter',
  ),
  MapStyle(
    title: 'Terrain',
    url: 'https://mt0.google.com/vt/lyrs=p&x={x}&y={y}&z={z}', // Google Terrain
    icon: Icons.terrain,
    description: 'Google Terrain View',
  ),
  MapStyle(
    title: 'Topography',
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
    icon: Icons.landscape,
    description: 'Detailed Contours',
  ),
];

// Special "Clean" Base for Weather layers
// Using Dark Matter for "Separate Heat Map" look (High contrast)
const kDarkMatterBase = MapStyle(
  title: 'Dark Matter', 
  url: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
  subdomains: ['a', 'b', 'c', 'd'],
  icon: Icons.dark_mode,
  description: 'Clean Dark Data Map',
);

// NASA GIBS Layers (Real-time data)
// LST = Land Surface Temperature (Day)
String kGibsHeatMapUrl = 'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/MODIS_Terra_Land_Surface_Temp_Day/default/${MapStyle._yesterdayStr}/GoogleMapsCompatible_Level9/{z}/{y}/{x}.jpg';

// Soil Moisture / Precip Proxy?
// Let's use "Temperature" again for the temp map but maybe Night?
String kGibsTempMapUrl = 'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/MODIS_Terra_Land_Surface_Temp_Night/default/${MapStyle._yesterdayStr}/GoogleMapsCompatible_Level9/{z}/{y}/{x}.jpg';

// For "Humidity", generic humidity clouds or water vapor?
// "AIRS_L3_Surface_Relative_Humidity_Day" - availability varies.
// Let's use "Blue Marble" or "Precipitation" if available as tiles?
// "IMERG_Precipitation_Rate" is great.
String kGibsHumidityMapUrl = 'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/IMERG_Precipitation_Rate/default/${MapStyle._yesterdayStr}/GoogleMapsCompatible_Level6/{z}/{y}/{x}.png';
