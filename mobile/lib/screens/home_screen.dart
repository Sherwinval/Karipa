import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _onNavigationTapped(int index) {
    if (index == 0) return; // Already on home

    if (index == 1) {
      Navigator.pushNamed(context, '/routes');
    } else if (index == 2) {
      Navigator.pushNamed(context, '/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PathCraft', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/profile'),
            icon: const Icon(Icons.person, color: Colors.teal),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back, Runner!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Where would you like to go today?', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            const Text(
              'Recommended Routes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildRouteCard(context, 'Morning Run', '5.2 km • 30 mins', Icons.directions_run),
            _buildRouteCard(context, 'City Cycle', '12.5 km • 45 mins', Icons.directions_bike),
            _buildRouteCard(context, 'Park Walk', '2.1 km • 20 mins', Icons.directions_walk),
            const SizedBox(height: 32),
            const Text(
              'Quick Start',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickAction(context, 'Walk', Icons.directions_walk),
                _buildQuickAction(context, 'Run', Icons.directions_run),
                _buildQuickAction(context, 'Cycle', Icons.directions_bike),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onNavigationTapped,
        selectedItemColor: Colors.teal,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Routes'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildRouteCard(BuildContext context, String title, String subtitle, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.teal.withOpacity(0.1),
          radius: 24,
          child: Icon(icon, color: Colors.teal, size: 28),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          Navigator.pushNamed(context, '/route_details', arguments: {
            'activityType': title,
            'distance': subtitle.split(' ')[0], // simple parsing for dummy data
          });
        },
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, String label, IconData icon) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/activity_setup', arguments: {
          'activityType': label,
        });
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Icon(icon, size: 36, color: Colors.teal),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
