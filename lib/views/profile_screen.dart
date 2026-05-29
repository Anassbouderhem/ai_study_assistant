import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/theme_provider.dart';
import '../widgets/logo_loader.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _editing = false;
  final Map<String, dynamic> _form = {};
  bool _uploading = false;
  double? _uploadProgress;
  final _dateController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  final TextEditingController _adresseController = TextEditingController();
  String? _selectedNiveau;
  final List<String> _niveauxScolaires = [
    'Bac',
    'Bac +1',
    'Bac +2',
    'Bac +3',
    'Master 1',
    'Master 2',
    'Doctorat',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final uid = auth.user?.uid;
    if (uid == null)
      return const Center(child: Text('Veuillez vous connecter.'));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LogoLoader(size: 96));
        }
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final prenom = data['prenom'] ?? '';
        final email = data['email'] ?? auth.user?.email ?? '';
        final niveau = data['niveauScolaire'] ?? '';
        final telephone = data['telephone'] ?? '';
        final photo = data['photoUrl'] ?? '';

        if (!_editing) {
          _form['prenom'] = prenom;
          _form['email'] = email;
          _form['niveauScolaire'] = niveau;
          _form['telephone'] = telephone;
          // populate controllers so fields appear filled when editing
          _prenomController.text = prenom;
          _emailController.text = email;
          _telephoneController.text = telephone;
          _adresseController.text = data['adresse'] ?? '';
          _dateController.text = data['dateNaissance'] ?? '';
          _selectedNiveau = niveau.isNotEmpty ? niveau : null;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundImage: (photo != null && photo.isNotEmpty)
                        ? NetworkImage(photo)
                        : null,
                    child: (photo == null || photo.isEmpty)
                        ? const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.white70,
                          )
                        : null,
                  ),
                  if (_uploading)
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: _uploadProgress != null
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: CircularProgressIndicator(
                                      value: _uploadProgress,
                                      strokeWidth: 3,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${((_uploadProgress ?? 0) * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              )
                            : const CircularProgressIndicator(
                                color: Colors.white,
                              ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'La photo est téléchargée — pas besoin d\'URL',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 8),
              if (_editing)
                TextButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: _uploading
                      ? const Text('Envoi...')
                      : const Text('Changer la photo'),
                  onPressed: _uploading
                      ? null
                      : () async {
                          final source =
                              await showModalBottomSheet<ImageSource?>(
                                context: context,
                                builder: (c) => Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.camera_alt),
                                      title: const Text('Prendre une photo'),
                                      onTap: () => Navigator.of(
                                        c,
                                      ).pop(ImageSource.camera),
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.photo_library),
                                      title: const Text(
                                        'Choisir depuis la galerie',
                                      ),
                                      onTap: () => Navigator.of(
                                        c,
                                      ).pop(ImageSource.gallery),
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.close),
                                      title: const Text('Annuler'),
                                      onTap: () => Navigator.of(c).pop(null),
                                    ),
                                  ],
                                ),
                              );
                          if (source == null) return;
                          final xfile = await ImagePicker().pickImage(
                            source: source,
                            maxWidth: 1600,
                            imageQuality: 85,
                          );
                          if (xfile == null) return;
                          setState(() {
                            _uploading = true;
                            _uploadProgress = 0;
                          });
                          final err = await auth.uploadProfilePhoto(
                            xfile,
                            onProgress: (p) {
                              if (!mounted) return;
                              setState(() => _uploadProgress = p);
                            },
                          );
                          setState(() {
                            _uploading = false;
                            _uploadProgress = null;
                          });
                          if (err != null) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(err),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        },
                ),
              if (_editing)
                TextButton.icon(
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Changer le mot de passe'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () async {
                    final res = await _showChangePasswordDialog(context, auth);
                    if (res != null) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    } else {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mot de passe mis à jour'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return SwitchListTile(
                    title: const Text('Mode Sombre'),
                    value: themeProvider.isDarkMode,
                    onChanged: (value) {
                      themeProvider.toggleTheme(value);
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(_editing ? 'Annuler' : 'Modifier'),
                    onPressed: () {
                      setState(() {
                        _editing = !_editing;
                      });
                    },
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Déconnexion'),
                    onPressed: () async {
                      await auth.signOut();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _prenomController,
                      decoration: const InputDecoration(labelText: 'Prénom'),
                      readOnly: !_editing,
                      onSaved: (v) =>
                          _form['prenom'] = v ?? _prenomController.text,
                    ),
                    const SizedBox(height: 8),
                    // Date de naissance
                    TextFormField(
                      controller: _dateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Date de naissance',
                        border: OutlineInputBorder(),
                      ),
                      onTap: !_editing
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate:
                                    DateTime.tryParse(
                                      (_form['dateNaissance'] ?? '').replaceAll(
                                        '/',
                                        '-',
                                      ),
                                    ) ??
                                    DateTime(2000),
                                firstDate: DateTime(1950),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                final formatted =
                                    '${picked.day}/${picked.month}/${picked.year}';
                                setState(() {
                                  _dateController.text = formatted;
                                  _form['dateNaissance'] = formatted;
                                });
                              }
                            },
                      onSaved: (v) => _form['dateNaissance'] = v ?? '',
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Champ obligatoire' : null,
                    ),
                    const SizedBox(height: 8),
                    // Adresse
                    TextFormField(
                      controller: _adresseController,
                      decoration: const InputDecoration(
                        labelText: 'Adresse',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: !_editing,
                      onSaved: (v) =>
                          _form['adresse'] = v ?? _adresseController.text,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Champ obligatoire' : null,
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      readOnly: !_editing,
                      onSaved: (v) =>
                          _form['email'] = v ?? _emailController.text,
                    ),
                    const SizedBox(height: 8),
                    _editing
                        ? DropdownButtonFormField<String>(
                            value: _selectedNiveau,
                            decoration: const InputDecoration(
                              labelText: 'Niveau scolaire',
                            ),
                            items: _niveauxScolaires
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedNiveau = v),
                            onSaved: (v) =>
                                _form['niveauScolaire'] = v ?? _selectedNiveau,
                            validator: (v) => v == null || v.isEmpty
                                ? 'Selectionnez votre niveau'
                                : null,
                          )
                        : TextFormField(
                            initialValue: _form['niveauScolaire'],
                            decoration: const InputDecoration(
                              labelText: 'Niveau scolaire',
                            ),
                            readOnly: true,
                            onSaved: (v) =>
                                _form['niveauScolaire'] = v ?? _selectedNiveau,
                          ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _telephoneController,
                      decoration: const InputDecoration(labelText: 'Téléphone'),
                      readOnly: !_editing,
                      onSaved: (v) =>
                          _form['telephone'] = v ?? _telephoneController.text,
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 16),
                    if (_editing)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              child: const Text('Sauvegarder'),
                              onPressed: () async {
                                if (!_formKey.currentState!.validate()) return;
                                _formKey.currentState!.save();
                                final currentAuthEmail = auth.user?.email ?? '';
                                final newEmail =
                                    (_form['email'] ?? '') as String;
                                if (newEmail.isNotEmpty &&
                                    newEmail != currentAuthEmail) {
                                  // need re-auth
                                  final pwd = await _askForPassword(context);
                                  if (pwd == null) return; // user cancelled
                                  final err = await auth.updateEmailWithReauth(
                                    newEmail,
                                    pwd,
                                  );
                                  if (err != null) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(err),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                    return;
                                  }
                                }
                                // update other fields in Firestore (photoUrl is managed by upload)
                                final dataToSave = Map<String, dynamic>.from(
                                  _form,
                                );
                                // ensure date and niveau values are included from controllers/selection
                                dataToSave['dateNaissance'] =
                                    _dateController.text;
                                dataToSave['adresse'] = _adresseController.text;
                                dataToSave['niveauScolaire'] =
                                    _selectedNiveau ?? _form['niveauScolaire'];
                                dataToSave.remove('photoUrl');
                                final res = await auth.updateProfile(
                                  dataToSave,
                                );
                                if (res != null) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                } else {
                                  setState(() {
                                    _editing = false;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                            ),
                            child: const Text('Supprimer compte'),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Confirmation'),
                                  content: const Text(
                                    'Confirmer la suppression de votre compte ? Cette action est irréversible.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(c).pop(false),
                                      child: const Text('Annuler'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(c).pop(true),
                                      child: const Text(
                                        'Supprimer',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                final res = await auth.deleteAccount();
                                if (res != null) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _askForPassword(BuildContext context) async {
    String? password;
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Ré-authentification requise'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Entrez votre mot de passe actuel pour confirmer la modification de l\'email.',
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              obscureText: true,
              onChanged: (v) => password = v,
              decoration: const InputDecoration(
                labelText: 'Mot de passe actuel',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(null),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(password),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showChangePasswordDialog(
    BuildContext context,
    AuthProvider auth,
  ) async {
    String? current;
    String? next;
    String? confirm;
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Changer le mot de passe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: (v) => current = v,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe actuel',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => next = v,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nouveau mot de passe',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => confirm = v,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmer le nouveau mot de passe',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop('cancelled'),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              if (next == null || confirm == null || next != confirm) {
                Navigator.of(c).pop('Les mots de passe ne correspondent pas.');
                return;
              }
              if (current == null || current!.isEmpty) {
                Navigator.of(c).pop('Mot de passe actuel requis.');
                return;
              }
              final err = await auth.updatePasswordWithReauth(current!, next!);
              Navigator.of(c).pop(err);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }
}
