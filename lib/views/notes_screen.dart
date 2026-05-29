import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../providers/auth_provider.dart';
import '../providers/notes_provider.dart';
import '../widgets/logo_loader.dart';
import '../widgets/app_card.dart';

enum NoteSort { recent, alpha, tag, priorityDate }

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _searchController = TextEditingController();
  final _tagController = TextEditingController();
  List<String> _draftTags = [];
  String? _activeTag;
  bool _gridView = false;
  NoteSort _sort = NoteSort.recent;
  final List<Color> _tagPalette = const [
    Color(0xFFE74C3C),
    Color(0xFFF39C12),
    Color(0xFF2ECC71),
    Color(0xFF3498DB),
    Color(0xFF9B59B6),
    Color(0xFF16A085),
    Color(0xFF2C3E50),
    Color(0xFF8E44AD),
    Color(0xFFD35400),
    Color(0xFF27AE60),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _searchController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  String _normalizeTag(String value) {
    return value.trim().toLowerCase();
  }

  void _addTag(String value, void Function(void Function()) setModalState) {
    final tag = _normalizeTag(value);
    if (tag.isEmpty || _draftTags.contains(tag)) return;
    setModalState(() => _draftTags = [..._draftTags, tag]);
    _tagController.clear();
  }

  void _removeTag(String tag, void Function(void Function()) setModalState) {
    setModalState(() => _draftTags = _draftTags.where((t) => t != tag).toList());
  }

  int _defaultPriorityForTag(String tag) {
    switch (tag) {
      case 'urgent':
        return 3;
      case 'important':
        return 2;
      case 'normal':
        return 1;
      case 'low':
        return 0;
      default:
        return 0;
    }
  }

  int _priorityForTags(List<String> tags, Map<String, int> priorities) {
    var best = 0;
    for (final tag in tags) {
      final value = priorities[tag] ?? _defaultPriorityForTag(tag);
      if (value > best) best = value;
    }
    return best;
  }

  Color _colorForTag(String tag, Map<String, int> colors) {
    final override = colors[tag];
    if (override != null) return Color(override);
    switch (tag) {
      case 'urgent':
        return const Color(0xFFE74C3C);
      case 'important':
        return const Color(0xFFF39C12);
      case 'normal':
        return const Color(0xFF2ECC71);
      case 'low':
        return const Color(0xFF3498DB);
      default:
        final hue = (tag.hashCode % 360).toDouble();
        return HSLColor.fromAHSL(1.0, hue, 0.45, 0.62).toColor();
    }
  }

  Widget _buildTagChip(String tag, Map<String, int> colors) {
    final color = _colorForTag(tag, colors);
    return Chip(
      label: Text('#$tag', style: const TextStyle(fontSize: 12, color: Colors.white)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildNoteCard(
    Note note, {
    required bool compact,
    required Map<String, int> colors,
    required Map<String, int> priorities,
  }) {
    final priority = _priorityForTags(note.tags, priorities);
    final priorityLabel = priority >= 3
        ? 'Urgent'
        : priority == 2
            ? 'Important'
            : priority == 1
                ? 'Normal'
                : 'Bas';

    return AppCard(
      onTap: () => _openEditor(note: note),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(note.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            note.content,
            maxLines: compact ? 3 : 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(priorityLabel, style: const TextStyle(fontSize: 11)),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    _openEditor(note: note);
                  } else if (value == 'delete') {
                    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
                    await notesProvider.deleteNote(note.id);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Modifier')),
                  PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                ],
              ),
            ],
          ),
          if (note.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: note.tags.map((tag) => _buildTagChip(tag, colors)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openTagManager({
    required String userId,
    required List<String> tagList,
    required Map<String, int> colors,
    required Map<String, int> priorities,
  }) async {
    if (tagList.isEmpty) return;
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final localColors = Map<String, int>.from(colors);
    final localPriorities = Map<String, int>.from(priorities);

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> saveSettings() async {
              await notesProvider.updateTagSettings(
                userId: userId,
                colors: localColors,
                priorities: localPriorities,
              );
            }

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
                    'Tags et priorites',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Couleur et priorite globales par tag.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  ...tagList.map((tag) {
                    final currentPriority = localPriorities[tag] ?? _defaultPriorityForTag(tag);
                    final currentColor = _colorForTag(tag, localColors);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(radius: 10, backgroundColor: currentColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('#$tag', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              IconButton(
                                tooltip: 'Renommer',
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () async {
                                  final controller = TextEditingController(text: tag);
                                  final newTag = await showDialog<String>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Renommer le tag'),
                                      content: TextField(
                                        controller: controller,
                                        decoration: const InputDecoration(labelText: 'Nouveau nom'),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Annuler'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(context, controller.text),
                                          child: const Text('Renommer'),
                                        ),
                                      ],
                                    ),
                                  );

                                  final normalized = _normalizeTag(newTag ?? '');
                                  if (normalized.isEmpty || normalized == tag) return;

                                  await notesProvider.renameTagInNotes(
                                    userId: userId,
                                    oldTag: tag,
                                    newTag: normalized,
                                  );

                                  final storedColor = localColors.remove(tag);
                                  if (storedColor != null) {
                                    localColors[normalized] = storedColor;
                                  }
                                  final storedPriority = localPriorities.remove(tag);
                                  if (storedPriority != null) {
                                    localPriorities[normalized] = storedPriority;
                                  }
                                  await saveSettings();
                                  setModalState(() {});
                                },
                              ),
                              IconButton(
                                tooltip: 'Supprimer',
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Supprimer le tag'),
                                      content: Text('Supprimer "#$tag" de toutes les notes ?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Annuler'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Supprimer'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true) return;

                                  await notesProvider.deleteTagFromNotes(userId: userId, tag: tag);
                                  localColors.remove(tag);
                                  localPriorities.remove(tag);
                                  await saveSettings();
                                  setModalState(() {});
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _tagPalette
                                .map(
                                  (color) => GestureDetector(
                                    onTap: () async {
                                      localColors[tag] = color.value;
                                      await saveSettings();
                                      setModalState(() {});
                                    },
                                    child: CircleAvatar(
                                      radius: 12,
                                      backgroundColor: color,
                                      child: color.value == currentColor.value
                                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                                          : null,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                          DropdownButton<int>(
                            value: currentPriority,
                            onChanged: (value) async {
                              if (value == null) return;
                              localPriorities[tag] = value;
                              await saveSettings();
                              setModalState(() {});
                            },
                            items: const [
                              DropdownMenuItem(value: 3, child: Text('Priorite: Urgent')),
                              DropdownMenuItem(value: 2, child: Text('Priorite: Important')),
                              DropdownMenuItem(value: 1, child: Text('Priorite: Normal')),
                              DropdownMenuItem(value: 0, child: Text('Priorite: Bas')),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fermer'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openEditor({Note? note}) {
    _titleController.text = note?.title ?? '';
    _contentController.text = note?.content ?? '';
    _draftTags = [...(note?.tags ?? [])];
    _tagController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final notesProvider = Provider.of<NotesProvider>(context, listen: false);
        final userId = authProvider.user?.uid;

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
                    note == null ? 'Nouvelle note' : 'Modifier la note',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
                    controller: _contentController,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Contenu',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tagController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (value) => _addTag(value, setModalState),
                    decoration: InputDecoration(
                      labelText: 'Tags (ex: revision, examen)',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () => _addTag(_tagController.text, setModalState),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _draftTags
                          .map(
                            (tag) => Chip(
                              label: Text('#$tag'),
                              onDeleted: () => _removeTag(tag, setModalState),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
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
                                  final content = _contentController.text.trim();
                                  if (title.isEmpty || content.isEmpty) return;

                                  if (note == null) {
                                    await notesProvider.addNote(
                                      userId: userId,
                                      title: title,
                                      content: content,
                                      tags: _draftTags,
                                    );
                                  } else {
                                    await notesProvider.updateNote(
                                      noteId: note.id,
                                      title: title,
                                      content: content,
                                      tags: _draftTags,
                                    );
                                  }

                                  if (mounted) Navigator.pop(context);
                                },
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
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    return Scaffold(
      body: userId == null
          ? const Center(child: Text('Veuillez vous connecter pour voir vos notes.'))
          : StreamBuilder<Map<String, dynamic>>(
              stream: notesProvider.streamTagSettings(userId),
              builder: (context, settingsSnapshot) {
                final settings = settingsSnapshot.data ?? {};
                final colorMap = Map<String, int>.from(settings['colors'] as Map? ?? {});
                final priorityMap = Map<String, int>.from(settings['priorities'] as Map? ?? {});

                return StreamBuilder<List<Note>>(
                  stream: notesProvider.streamNotes(userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: LogoLoader());
                    }

                    final notes = snapshot.data ?? [];
                    if (notes.isEmpty) {
                      return const Center(child: Text('Aucune note pour le moment.'));
                    }
                    final query = _searchController.text.trim().toLowerCase();
                    final tags = <String>{};
                    final tagCounts = <String, int>{};
                    for (final note in notes) {
                      tags.addAll(note.tags);
                      for (final tag in note.tags) {
                        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
                      }
                    }
                    final tagList = tags.toList()..sort();

                    final filteredNotes = notes.where((note) {
                      if (_activeTag != null && !note.tags.contains(_activeTag)) return false;
                      if (query.isEmpty) return true;
                      final haystack = '${note.title} ${note.content} ${note.tags.join(' ')}'.toLowerCase();
                      return haystack.contains(query);
                    }).toList();

                    filteredNotes.sort((a, b) {
                      switch (_sort) {
                        case NoteSort.alpha:
                          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
                        case NoteSort.tag:
                          final aTag = a.tags.isNotEmpty ? a.tags.first : '';
                          final bTag = b.tags.isNotEmpty ? b.tags.first : '';
                          return aTag.compareTo(bTag);
                        case NoteSort.priorityDate:
                          final pDiff = _priorityForTags(b.tags, priorityMap) - _priorityForTags(a.tags, priorityMap);
                          if (pDiff != 0) return pDiff;
                          return b.updatedAt.compareTo(a.updatedAt);
                        case NoteSort.recent:
                        default:
                          return b.updatedAt.compareTo(a.updatedAt);
                      }
                    });

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Rechercher dans vos notes',
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
                        if (tagList.isNotEmpty)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: Row(
                              children: [
                                FilterChip(
                                  label: const Text('Tous'),
                                  selected: _activeTag == null,
                                  onSelected: (_) => setState(() => _activeTag = null),
                                ),
                                const SizedBox(width: 8),
                                ...tagList.map(
                                  (tag) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      label: Text('#$tag  (${tagCounts[tag] ?? 0})'),
                                      selected: _activeTag == tag,
                                      onSelected: (_) => setState(() => _activeTag = tag),
                                      selectedColor: _colorForTag(tag, colorMap).withValues(alpha: 0.25),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            children: [
                              DropdownButton<NoteSort>(
                                value: _sort,
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _sort = value);
                                },
                                items: const [
                                  DropdownMenuItem(value: NoteSort.recent, child: Text('Recent')),
                                  DropdownMenuItem(value: NoteSort.alpha, child: Text('A-Z')),
                                  DropdownMenuItem(value: NoteSort.tag, child: Text('Tags')),
                                  DropdownMenuItem(value: NoteSort.priorityDate, child: Text('Priorite + Date')),
                                ],
                              ),
                              IconButton(
                                tooltip: 'Configurer les tags',
                                onPressed: () => _openTagManager(
                                  userId: userId,
                                  tagList: tagList,
                                  colors: colorMap,
                                  priorities: priorityMap,
                                ),
                                icon: const Icon(Icons.local_offer_outlined),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => setState(() => _gridView = false),
                                icon: Icon(Icons.view_agenda_outlined, color: _gridView ? Theme.of(context).colorScheme.onSurfaceVariant : null),
                                tooltip: 'Vue liste',
                              ),
                              IconButton(
                                onPressed: () => setState(() => _gridView = true),
                                icon: Icon(Icons.grid_view_rounded, color: _gridView ? null : Theme.of(context).colorScheme.onSurfaceVariant),
                                tooltip: 'Vue grille',
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: filteredNotes.isEmpty
                              ? const Center(child: Text('Aucune note ne correspond a votre recherche.'))
                              : _gridView
                                  ? GridView.builder(
                                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        childAspectRatio: 0.95,
                                      ),
                                      itemCount: filteredNotes.length,
                                      itemBuilder: (context, index) {
                                        final note = filteredNotes[index];
                                        return _buildNoteCard(
                                          note,
                                          compact: true,
                                          colors: colorMap,
                                          priorities: priorityMap,
                                        );
                                      },
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                      itemCount: filteredNotes.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        final note = filteredNotes[index];
                                        return _buildNoteCard(
                                          note,
                                          compact: false,
                                          colors: colorMap,
                                          priorities: priorityMap,
                                        );
                                      },
                                    ),
                        ),
                      ],
                    );
                  },
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
