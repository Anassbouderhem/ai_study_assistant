import 'package:flutter/material.dart';
import 'notes_screen.dart';
import 'tasks_screen.dart';

class NotesTasksScreen extends StatelessWidget {
  const NotesTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Theme.of(context).colorScheme.onPrimary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              tabs: const [
                Tab(text: 'Notes'),
                Tab(text: 'Taches'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Expanded(
            child: TabBarView(
              children: [
                NotesScreen(),
                TasksScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
