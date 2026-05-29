import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Contrôleurs des champs demandés
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _adresseController = TextEditingController();
  final _dateNaissanceController = TextEditingController();
  XFile? _pickedPhoto;
  bool _obscurePassword = true;
  
  String? _selectedNiveau;
  final List<String> _niveauxScolaires = ['Bac +1', 'Bac +2', 'Bac +3', 'Master 1 (Bac +4)', 'Master 2 (Bac +5)', 'Doctorat'];

  @override
  void dispose() {
    _prenomController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _adresseController.dispose();
    _dateNaissanceController.dispose();
    super.dispose();
  }

  // Fonction pour afficher le calendrier natif
  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dateNaissanceController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    String? error = await authProvider.registerWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      prenom: _prenomController.text.trim(),
      dateNaissance: _dateNaissanceController.text,
      niveauScolaire: _selectedNiveau ?? 'Non spécifié',
      adresse: _adresseController.text.trim(),
      telephone: _phoneController.text.trim(),
      photoFile: _pickedPhoto,
    );

    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.redAccent));
    } else if (mounted) {
      // Ferme l'écran d'inscription pour revenir à la racine (qui basculera sur Home)
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Créer un compte"), backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Form(
                  key: _formKey,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(color: Color(0x2A1F2A44), blurRadius: 24, offset: Offset(0, 12)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Profil et etudes',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Georgia',
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Creez votre espace d etude personalise.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 24),

                        // Prénom
                        TextFormField(
                          controller: _prenomController,
                          decoration: const InputDecoration(labelText: 'Prenom', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline), filled: true),
                          validator: (v) => v!.isEmpty ? 'Champ obligatoire' : null,
                        ),
                        const SizedBox(height: 16),

                        // Date de naissance
                        TextFormField(
                          controller: _dateNaissanceController,
                          readOnly: true,
                          decoration: const InputDecoration(labelText: 'Date de naissance', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_month_outlined), filled: true),
                          onTap: () => _selectDate(context),
                          validator: (v) => v!.isEmpty ? 'Champ obligatoire' : null,
                        ),
                        const SizedBox(height: 16),

                        // Niveau scolaire
                        DropdownButtonFormField<String>(
                          value: _selectedNiveau,
                          decoration: const InputDecoration(labelText: 'Niveau scolaire', border: OutlineInputBorder(), prefixIcon: Icon(Icons.school_outlined), filled: true),
                          items: _niveauxScolaires.map((String value) {
                            return DropdownMenuItem<String>(value: value, child: Text(value));
                          }).toList(),
                          onChanged: (newValue) => setState(() => _selectedNiveau = newValue),
                          validator: (v) => v == null ? 'Selectionnez votre niveau' : null,
                        ),
                        const SizedBox(height: 16),

                        // Adresse
                        TextFormField(
                          controller: _adresseController,
                          decoration: const InputDecoration(labelText: 'Adresse', border: OutlineInputBorder(), prefixIcon: Icon(Icons.home_outlined), filled: true),
                          validator: (v) => v!.isEmpty ? 'Champ obligatoire' : null,
                        ),
                        const SizedBox(height: 16),

                        // Téléphone
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Telephone', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_android_outlined), filled: true),
                          validator: (v) => v!.isEmpty ? 'Champ obligatoire' : null,
                        ),
                        const SizedBox(height: 16),

                        // Photo de profil (optionnelle)
                        Row(
                          children: [
                            if (_pickedPhoto != null)
                              CircleAvatar(radius: 28, backgroundImage: FileImage(File(_pickedPhoto!.path)),)
                            else
                              const CircleAvatar(radius: 28, child: Icon(Icons.person)),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.photo_camera),
                              label: const Text('Ajouter une photo'),
                              onPressed: () async {
                                final source = await showModalBottomSheet<ImageSource?>(
                                  context: context,
                                  builder: (c) => Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Prendre une photo'), onTap: () => Navigator.of(c).pop(ImageSource.camera)),
                                      ListTile(leading: const Icon(Icons.photo_library), title: const Text('Choisir depuis la galerie'), onTap: () => Navigator.of(c).pop(ImageSource.gallery)),
                                      ListTile(leading: const Icon(Icons.close), title: const Text('Annuler'), onTap: () => Navigator.of(c).pop(null)),
                                    ],
                                  ),
                                );
                                if (source == null) return;
                                final xfile = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
                                if (xfile == null) return;
                                setState(() => _pickedPhoto = xfile);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Email
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Adresse Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined), filled: true),
                          validator: (v) => (v == null || !v.contains('@')) ? 'Email invalide' : null,
                        ),
                        const SizedBox(height: 16),

                        // Mot de passe
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            ),
                            filled: true,
                          ),
                          validator: (v) => v!.length < 6 ? 'Minimum 6 caracteres' : null,
                        ),
                        const SizedBox(height: 28),

                        authProvider.isLoading
                            ? const CircularProgressIndicator()
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _submit,
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                  child: const Text("S'inscrire", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}