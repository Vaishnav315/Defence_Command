import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AuthService.currentUser;
    final name = user?['name'] ?? 'Commander';
    final email = user?['email'] ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Avatar & Info (Clean, no gradient)
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.dividerColor, width: 2),
                    ),
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: theme.iconTheme.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name.toUpperCase(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.primaryColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      'ACTIVE DUTY',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Stats Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _buildStatCard(theme, 'MISSIONS', '42')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard(theme, 'HOURS', '1,284')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard(theme, 'RATING', '98%')),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Personal Info Section
            _buildSectionHeader(theme, 'PERSONAL INFORMATION'),
            _buildListTile(theme, Icons.email_outlined, 'Email', email, false),
            _buildListTile(theme, Icons.badge_outlined, 'Rank', 'Commander', false),
            _buildListTile(theme, Icons.verified_user_outlined, 'Clearance', 'Level 5', false),
            _buildListTile(theme, Icons.phone_outlined, 'Phone', '+1 (555) 019-2834', false),
            _buildListTile(theme, Icons.lock_outline, 'Password', '••••••••', true),
            
            const SizedBox(height: 24),
            _buildSectionHeader(theme, 'ACCOUNT'),
            _buildListTile(theme, Icons.notifications_none, 'Notifications', 'On', true),
            _buildListTile(theme, Icons.language, 'Language', 'English', true),
             
             const SizedBox(height: 40),
             
             // Logout Button
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 24),
               child: SizedBox(
                 width: double.infinity,
                 height: 50,
                 child: OutlinedButton(
                    onPressed: () async {
                      await AuthService().signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const LoginPage()),
                          (route) => false,
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('LOG OUT', style: TextStyle(fontWeight: FontWeight.bold)),
                 ),
               ),
             ),
             
             const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              // color: theme.primaryColor, // Removed color to reduce "blue gradient" feel if needed, but keeping primarily distinct
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: theme.hintColor,
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(ThemeData theme, IconData icon, String title, String subtitle, bool showArrow) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: theme.iconTheme.color),
          ),
          title: Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                subtitle,
                 style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
              if (showArrow) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 20, color: theme.hintColor),
              ]
            ],
          ),
          onTap: () {},
        ),
      ),
    );
  }
}
