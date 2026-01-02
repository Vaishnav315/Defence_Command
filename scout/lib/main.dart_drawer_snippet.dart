
  Widget _buildDrawer(ThemeData theme) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
               color: theme.colorScheme.primaryContainer,
            ),
            accountName: Text(
               widget.identity, 
               style: TextStyle(
                 fontWeight: FontWeight.bold,
                 color: theme.colorScheme.onPrimaryContainer
               )
            ),
            accountEmail: Text(
              "STATUS: ${_isOnline ? 'ONLINE' : 'OFFLINE'}",
              style: TextStyle(
                color: _isOnline ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              )
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: theme.colorScheme.onPrimaryContainer,
              child: Text(
                widget.identity.isNotEmpty ? widget.identity[0].toUpperCase() : "S",
                style: TextStyle(color: theme.colorScheme.primaryContainer, fontWeight: FontWeight.bold)
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text("Grid Reference"),
            subtitle: Text("37.4220, -122.0840"), // Placeholder or real loc
          ),
          const Divider(),
          const Spacer(),
          ListTile(
            tileColor: Colors.red.withOpacity(0.1),
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("TERMINATE LINK [LOGOUT]", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context); // Close Drawer
              _handleLogout();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
