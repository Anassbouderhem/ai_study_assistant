import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../providers/auth_provider.dart';
import '../providers/tasks_provider.dart';
import '../widgets/logo_loader.dart';
import '../widgets/app_card.dart';

enum TaskFilter { all, active, done }

enum TaskSort { priorityDate, recent, alpha }

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();
  int _priority = 1;
  TaskFilter _filter = TaskFilter.all;
  TaskSort _sort = TaskSort.priorityDate;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _priorityLabel(int value) {
    switch (value) {
      case 3:
        return 'Urgent';
      case 2:
        return 'Important';
      case 1:
        return 'Normal';
      case 0:
      default:
        return 'Bas';
    }
  }

  Color _priorityColor(int value) {
    switch (value) {
      case 3:
        return const Color(0xFFE74C3C);
      case 2:
        return const Color(0xFFF39C12);
      case 1:
        return const Color(0xFF2ECC71);
      case 0:
      default:
        return const Color(0xFF3498DB);
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} min';
    }
    if (duration.inHours < 24) {
      final minutes = duration.inMinutes.remainder(60);
      return minutes == 0
          ? '${duration.inHours} h'
          : '${duration.inHours} h ${minutes} min';
    }
    final hours = duration.inHours.remainder(24);
    return hours == 0
        ? '${duration.inDays} j'
        : '${duration.inDays} j ${hours} h';
  }

  String _formatReminder(DateTime dt) {
    final d = dt.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  TaskItem? _nextUrgent(List<TaskItem> tasks) {
    final pending = tasks.where((task) => !task.isDone).toList();
    if (pending.isEmpty) return null;
    pending.sort((a, b) {
      final pDiff = b.priority - a.priority;
      if (pDiff != 0) return pDiff;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return pending.first;
  }

  void _openEditor({TaskItem? task}) {
    _titleController.text = task?.title ?? '';
    _descriptionController.text = task?.description ?? '';
    _priority = task?.priority ?? 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final tasksProvider = Provider.of<TasksProvider>(
          context,
          listen: false,
        );
        final userId = authProvider.user?.uid;
        DateTime? reminderAt = task?.reminderAt;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task == null ? 'Nouvelle tache' : 'Modifier la tache',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Titre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _priority,
                    decoration: const InputDecoration(
                      labelText: 'Priorite',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 3, child: Text('Urgent')),
                      DropdownMenuItem(value: 2, child: Text('Important')),
                      DropdownMenuItem(value: 1, child: Text('Normal')),
                      DropdownMenuItem(value: 0, child: Text('Bas')),
                    ],
                    onChanged: (value) =>
                        setModalState(() => _priority = value ?? 1),
                  ),
                  const SizedBox(height: 12),
                  // Reminder picker
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          reminderAt == null
                              ? 'Aucun rappel'
                              : 'Rappel: ${reminderAt!.toLocal().toString().replaceFirst('.000', '')}',
                        ),
                      ),
                      if (reminderAt != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              setModalState(() => reminderAt = null),
                        ),
                      IconButton(
                        icon: const Icon(Icons.date_range),
                        onPressed: () async {
                          final now = DateTime.now();
                          final initialDate = reminderAt ?? now;
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: initialDate,
                            firstDate: now,
                            lastDate: DateTime(now.year + 5),
                          );
                          if (pickedDate == null) return;
                          final initialTime = reminderAt == null
                              ? TimeOfDay.now()
                              : TimeOfDay.fromDateTime(reminderAt!);
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: initialTime.hour,
                              minute: initialTime.minute,
                            ),
                          );
                          final combined = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime?.hour ?? 9,
                            pickedTime?.minute ?? 0,
                          );
                          setModalState(() => reminderAt = combined);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: userId == null
                              ? null
                              : () async {
                                  final title = _titleController.text.trim();
                                  final description = _descriptionController
                                      .text
                                      .trim();
                                  if (title.isEmpty) return;

                                  if (task == null) {
                                    await tasksProvider.addTask(
                                      userId: userId,
                                      title: title,
                                      description: description,
                                      priority: _priority,
                                      reminderAt: reminderAt,
                                    );
                                  } else {
                                    await tasksProvider.updateTask(
                                      taskId: task.id,
                                      title: title,
                                      description: description,
                                      priority: _priority,
                                      reminderAt: reminderAt,
                                    );
                                  }

                                  if (mounted) Navigator.pop(context);
                                },
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Enregistrer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final tasksProvider = Provider.of<TasksProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    return Scaffold(
      body: userId == null
          ? const Center(
              child: Text('Veuillez vous connecter pour voir vos taches.'),
            )
          : StreamBuilder<List<TaskItem>>(
              stream: tasksProvider.streamTasks(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: LogoLoader());
                }

                final tasks = snapshot.data ?? [];
                if (tasks.isEmpty) {
                  return const Center(
                    child: Text('Aucune tache pour le moment.'),
                  );
                }

                final doneCount = tasks.where((task) => task.isDone).length;
                final progress = tasks.isEmpty ? 0.0 : doneCount / tasks.length;
                final query = _searchController.text.trim().toLowerCase();
                final urgentTask = _nextUrgent(tasks);
                final activeCount = tasks.length - doneCount;
                final percentDone = tasks.isEmpty
                    ? 0
                    : ((doneCount / tasks.length) * 100).round();
                final completedDurations = tasks
                    .where((task) => task.completedAt != null)
                    .map((task) => task.completedAt!.difference(task.createdAt))
                    .where((duration) => duration.inSeconds > 0)
                    .toList();
                final avgCompletion = completedDurations.isEmpty
                    ? null
                    : Duration(
                        seconds:
                            completedDurations
                                .map((duration) => duration.inSeconds)
                                .reduce((a, b) => a + b) ~/
                            completedDurations.length,
                      );
                final priorityCounts = <int, int>{0: 0, 1: 0, 2: 0, 3: 0};
                for (final task in tasks) {
                  priorityCounts[task.priority] =
                      (priorityCounts[task.priority] ?? 0) + 1;
                }

                final filteredTasks = tasks
                    .where((task) {
                      switch (_filter) {
                        case TaskFilter.active:
                          return !task.isDone;
                        case TaskFilter.done:
                          return task.isDone;
                        case TaskFilter.all:
                        default:
                          return true;
                      }
                    })
                    .where((task) {
                      if (query.isEmpty) return true;
                      final haystack = '${task.title} ${task.description}'
                          .toLowerCase();
                      return haystack.contains(query);
                    })
                    .toList();

                filteredTasks.sort((a, b) {
                  switch (_sort) {
                    case TaskSort.alpha:
                      return a.title.toLowerCase().compareTo(
                        b.title.toLowerCase(),
                      );
                    case TaskSort.recent:
                      return b.updatedAt.compareTo(a.updatedAt);
                    case TaskSort.priorityDate:
                    default:
                      final pDiff = b.priority - a.priority;
                      if (pDiff != 0) return pDiff;
                      return b.updatedAt.compareTo(a.updatedAt);
                  }
                });

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mes taches',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Georgia',
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$doneCount terminees sur ${tasks.length}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 10,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surface,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _StatPill(label: 'Actives', value: activeCount),
                                const SizedBox(width: 8),
                                _StatPill(label: 'Terminees', value: doneCount),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _StatPillText(
                                  label: '% Terminees',
                                  value: '$percentDone%',
                                ),
                                const SizedBox(width: 8),
                                _StatPillText(
                                  label: 'Temps moyen',
                                  value: avgCompletion == null
                                      ? '-'
                                      : _formatDuration(avgCompletion),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _PriorityChip(
                                  label: 'Urgent',
                                  count: priorityCounts[3] ?? 0,
                                  color: _priorityColor(3),
                                ),
                                _PriorityChip(
                                  label: 'Important',
                                  count: priorityCounts[2] ?? 0,
                                  color: _priorityColor(2),
                                ),
                                _PriorityChip(
                                  label: 'Normal',
                                  count: priorityCounts[1] ?? 0,
                                  color: _priorityColor(1),
                                ),
                                _PriorityChip(
                                  label: 'Bas',
                                  count: priorityCounts[0] ?? 0,
                                  color: _priorityColor(0),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Rechercher une tache',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                        ),
                      ),
                    ),
                    if (urgentTask != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _priorityColor(
                              urgentTask.priority,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _priorityColor(
                                urgentTask.priority,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.flash_on,
                                color: _priorityColor(urgentTask.priority),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Prochaine tache urgente',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      urgentTask.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => _openEditor(task: urgentTask),
                                child: const Text('Voir'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          DropdownButton<TaskSort>(
                            value: _sort,
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _sort = value);
                            },
                            items: const [
                              DropdownMenuItem(
                                value: TaskSort.priorityDate,
                                child: Text('Priorite + Date'),
                              ),
                              DropdownMenuItem(
                                value: TaskSort.recent,
                                child: Text('Recent'),
                              ),
                              DropdownMenuItem(
                                value: TaskSort.alpha,
                                child: Text('A-Z'),
                              ),
                            ],
                          ),
                          const Spacer(),
                          FilterChip(
                            label: Text('Toutes (${tasks.length})'),
                            selected: _filter == TaskFilter.all,
                            onSelected: (_) =>
                                setState(() => _filter = TaskFilter.all),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: Text('Actives ($activeCount)'),
                            selected: _filter == TaskFilter.active,
                            onSelected: (_) =>
                                setState(() => _filter = TaskFilter.active),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: Text('Terminees ($doneCount)'),
                            selected: _filter == TaskFilter.done,
                            onSelected: (_) =>
                                setState(() => _filter = TaskFilter.done),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: filteredTasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final task = filteredTasks[index];
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOut,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Card(
                              elevation: task.isDone ? 0 : 2,
                              child: ListTile(
                                onTap: () => _openEditor(task: task),
                                leading: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      transitionBuilder: (child, animation) =>
                                          ScaleTransition(
                                            scale: animation,
                                            child: child,
                                          ),
                                      child: Checkbox(
                                        key: ValueKey(task.isDone),
                                        value: task.isDone,
                                        onChanged: (value) {
                                          tasksProvider.toggleDone(
                                            taskId: task.id,
                                            isDone: value ?? false,
                                          );
                                        },
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _priorityColor(task.priority),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          _priorityLabel(
                                            task.priority,
                                          ).substring(0, 1),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                title: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: task.isDone
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    decoration: task.isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                  child: Text(task.title),
                                ),
                                subtitle:
                                    (task.description.isEmpty &&
                                        task.reminderAt == null)
                                    ? null
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (task.description.isNotEmpty)
                                            AnimatedOpacity(
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              opacity: task.isDone ? 0.6 : 1,
                                              child: Text(
                                                task.description,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          if (task.reminderAt != null) ...[
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.alarm,
                                                  size: 14,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  _formatReminder(
                                                    task.reminderAt!,
                                                  ),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _priorityColor(
                                      task.priority,
                                    ).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _priorityLabel(task.priority),
                                    style: TextStyle(
                                      color: _priorityColor(task.priority),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: userId == null ? null : () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final int value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _StatPillText extends StatelessWidget {
  final String label;
  final String value;

  const _StatPillText({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _PriorityChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
