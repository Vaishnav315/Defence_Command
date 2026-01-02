import 'package:flutter/material.dart';
import 'dart:io';
import 'home_page.dart';
import 'more_page.dart';
import 'theme/app_theme.dart';
import 'settings_page.dart';

import 'package:provider/provider.dart';
import 'pages/login_page.dart';
import 'providers/auth_provider.dart';
import 'services/livekit_service.dart';
import 'pages/profile_page.dart';
import 'providers/entity_provider.dart';
import 'simulation_screen.dart';

void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(const MyApp());
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..idleTimeout = const Duration(seconds: 30)
      ..maxConnectionsPerHost = 20
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LiveKitService()),
        ChangeNotifierProxyProvider<LiveKitService, EntityProvider>(
          create: (_) => EntityProvider(),
          update: (_, liveKitService, entityProvider) => 
            entityProvider!..updateLiveKitService(liveKitService),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (ctx, auth, _) => MaterialApp(
          title: 'Defense Command',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          debugShowCheckedModeBanner: false,
          home: const AuthWrapper(),
        ),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      Provider.of<AuthProvider>(context, listen: false).tryAutoLogin();
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    if (auth.isAuthenticated) {
      return const RootPage();
    } else {
      // Logic to show loading if we were waiting for auto-login could be added here
      // But for now, tryAutoLogin is fast enough or default false is fine
      // If we want to avoid initial flicker of Login page if token exists:
      // We could add 'isWaiting' state to AuthProvider.
      return const LoginPage();
    }
  }
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int currentPage = 0;
  
  final List<Widget> _pages = [
    const HomePage(),
    const SimulationScreen(),
    const MorePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF1C1C1E), // Dark Grey for Defense look
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, color: Colors.white, size: 40),
              ),
              accountName: const Text(
                "Commander Reynolds",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              accountEmail: const Text(
                "Authorized Personnel - Lvl 5",
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text("Dashboard"),
              onTap: () {
                Navigator.pop(context);
                setState(() => currentPage = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_outlined),
              title: const Text("Mission Logs"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text("System Settings"),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Provider.of<AuthProvider>(context, listen: false).logout();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      endDrawer: Drawer(
        width: 300,
        backgroundColor: const Color(0xFF1E1E1E), // Dark theme background
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
              decoration: const BoxDecoration(
                color: Color(0xFF2C2C2E), // Slightly lighter header
                border: Border(bottom: BorderSide(color: Colors.black26)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Notifications",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                       Provider.of<EntityProvider>(context, listen: false).clearAlerts();
                    },
                    child: const Text("Clear All", style: TextStyle(color: Colors.blueAccent)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<EntityProvider>(
                builder: (context, provider, _) {
                  if (provider.alerts.isEmpty) {
                    return const Center(child: Text("No Notifications", style: TextStyle(color: Colors.grey)));
                  }
                  return ListView(
                    padding: EdgeInsets.zero,
                    children: provider.alerts.map((alert) => _buildNotificationItem(
                      icon: Icons.warning_amber_rounded,
                      title: alert.title,
                      subtitle: alert.message,
                      time: alert.time,
                      isUnread: true,
                    )).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      appBar: currentPage == 1 ? null : AppBar(
        centerTitle: true,
        leadingWidth: 56,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            color: theme.appBarTheme.foregroundColor, // Explicitly match theme
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            "DEFENSE COMMAND",
            style: TextStyle(
              color: theme.appBarTheme.foregroundColor,
              fontWeight: FontWeight.w900, // Thicker font
              fontSize: 26, // Larger size (was 24)
              letterSpacing: 1.5,
            ),
          ),
        ),
        actions: [
          Builder(
            builder: (context) {
              // Watch both Alerts and Chat Unread status
              final provider = Provider.of<EntityProvider>(context);
              final hasAlerts = provider.alerts.isNotEmpty;
              final hasChats = provider.hasUnreadMessages;
              final totalCount = provider.alerts.length + (hasChats ? 1 : 0);
              
              return Container(
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none),
                      onPressed: () => Scaffold.of(context).openEndDrawer(),
                    ),
                    if (totalCount > 0)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      ),
                    ),
                  ],
                ),
              );
            }
          ),
          IconButton(
            icon: const Icon(Icons.person, size: 30),
            color: Colors.grey,
            onPressed: () {
               Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: theme.dividerColor,
            height: 1,
          ),
        ),
      ),
      body: _pages[currentPage],
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: "Dashboard",
          ),
          NavigationDestination(
            icon: Icon(Icons.videogame_asset),
            label: "Sim",
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            label: "More",
          ),
        ],
        onDestinationSelected: (int index) {
          setState(() {
            currentPage = index;
          });
        },
        selectedIndex: currentPage,
      ),
    );
  }
  Widget _buildNotificationItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required bool isUnread,
  }) {
    return Container(
      color: isUnread ? const Color(0xFF2C2C2E).withOpacity(0.5) : Colors.transparent,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF3A3A3C),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
            fontSize: 15,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Text(
          time,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
    );
  }
}