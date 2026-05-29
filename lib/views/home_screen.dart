import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'notes_screen.dart';
import 'tasks_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'contacts_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Les écrans principaux (ajout Contacts en dernier)
  final List<Widget> _pages = [
    const TasksScreen(),
    const NotesScreen(),
    const ChatScreen(),
    const ProfileScreen(),
    const ContactsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: () =>
                Provider.of<ThemeProvider>(context, listen: false).toggleDark(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () =>
                Provider.of<AuthProvider>(context, listen: false).signOut(),
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            label: 'Tâches',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_document),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome),
            label: 'IA Chat',
          ),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
          NavigationDestination(
            icon: Icon(Icons.contact_phone),
            label: 'Contacts',
          ),
        ],
      ),
    );
  }
}
