import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as fs;
import 'dart:typed_data';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? _user;
  bool _isLoading = false;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  // INSCRIPTION avec sauvegarde des données personnalisées dans Firestore
  Future<String?> registerWithEmail({
    required String email,
    required String password,
    required String prenom,
    required String dateNaissance,
    required String niveauScolaire,
    required String adresse,
    required String telephone,
    XFile? photoFile,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      // 1. Création du compte dans Firebase Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      User? user = result.user;

      if (user != null) {
        // 2. Sauvegarde des infos complémentaires dans la collection 'users' de Firestore
        String? photoUrl;
        if (photoFile != null) {
          // upload photo under the new user's uid
          try {
            photoUrl = await _uploadProfilePhotoForUid(photoFile, user.uid);
          } catch (e) {
            // ignore upload error here; continue registration
            photoUrl = null;
          }
        }
        final data = {
          'uid': user.uid,
          'prenom': prenom,
          'email': email,
          'dateNaissance': dateNaissance,
          'niveauScolaire': niveauScolaire,
          'adresse': adresse,
          'telephone': telephone,
          'createdAt': FieldValue.serverTimestamp(),
        };
        if (photoUrl != null) data['photoUrl'] = photoUrl;
        await _db.collection('users').doc(user.uid).set(data);
      }

      return null; 
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return "Erreur d'enregistrement : $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // CONNEXION standard
  Future<String?> loginWithEmail(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return "Erreur de connexion : $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Update Firestore user profile fields (merge)
  Future<String?> updateProfile(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) return 'Utilisateur non connecté.';
    _isLoading = true;
    notifyListeners();
    try {
      await _db.collection('users').doc(user.uid).set(data, SetOptions(merge: true));
      return null;
    } catch (e) {
      return 'Erreur mise à jour: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update email with re-authentication (password-based)
  Future<String?> updateEmailWithReauth(String newEmail, String currentPassword) async {
    final user = _auth.currentUser;
    if (user == null) return 'Utilisateur non connecté.';
    if (user.email == null) return 'Email actuel introuvable.';
    _isLoading = true;
    notifyListeners();
    try {
      final cred = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
      // Some firebase_auth versions expose updateEmail on User; call dynamically to avoid analyzer issues
      await (user as dynamic).updateEmail(newEmail);
      await _db.collection('users').doc(user.uid).set({'email': newEmail}, SetOptions(merge: true));
      // reload user to reflect changes
      await user.reload();
      _user = _auth.currentUser;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Erreur mise à jour email: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update password with re-authentication (password-based)
  Future<String?> updatePasswordWithReauth(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) return 'Utilisateur non connecté.';
    if (user.email == null) return 'Email actuel introuvable pour ré-authentification.';
    _isLoading = true;
    notifyListeners();
    try {
      final cred = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
      // call updatePassword dynamically to avoid analyzer issues across versions
      await (user as dynamic).updatePassword(newPassword);
      await user.reload();
      _user = _auth.currentUser;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Erreur mise à jour mot de passe: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Upload profile photo (works with XFile from image_picker)
  Future<String?> uploadProfilePhoto(XFile file, {void Function(double)? onProgress}) async {
    final user = _auth.currentUser;
    if (user == null) return 'Utilisateur non connecté.';
    _isLoading = true;
    notifyListeners();
    try {
      final bytes = await file.readAsBytes();
      final name = file.name.replaceAll(RegExp(r"[^a-zA-Z0-9_.-]"), '_');
      final ext = name.contains('.') ? name.split('.').last : 'jpg';
      final path = 'profile_photos/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = fs.FirebaseStorage.instance.ref().child(path);
      final meta = fs.SettableMetadata(contentType: 'image/$ext');
      final uploadTask = ref.putData(Uint8List.fromList(bytes), meta);
      // report progress if requested
      uploadTask.snapshotEvents.listen((s) {
        final total = s.totalBytes ?? 0;
        final transferred = s.bytesTransferred;
        if (total > 0) {
          final p = transferred / total;
          try {
            onProgress?.call(p);
          } catch (_) {}
        }
      });
      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      await _db.collection('users').doc(user.uid).set({'photoUrl': url}, SetOptions(merge: true));
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Erreur upload photo: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Upload photo for a specific uid (used during registration before user is signed in)
  Future<String> _uploadProfilePhotoForUid(XFile file, String uid, {void Function(double)? onProgress}) async {
    final bytes = await file.readAsBytes();
    final name = file.name.replaceAll(RegExp(r"[^a-zA-Z0-9_.-]"), '_');
    final ext = name.contains('.') ? name.split('.').last : 'jpg';
    final path = 'profile_photos/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = fs.FirebaseStorage.instance.ref().child(path);
    final meta = fs.SettableMetadata(contentType: 'image/$ext');
    final uploadTask = ref.putData(Uint8List.fromList(bytes), meta);
    uploadTask.snapshotEvents.listen((s) {
      final total = s.totalBytes ?? 0;
      final transferred = s.bytesTransferred;
      if (total > 0) {
        final p = transferred / total;
        try {
          onProgress?.call(p);
        } catch (_) {}
      }
    });
    final snapshot = await uploadTask;
    final url = await snapshot.ref.getDownloadURL();
    return url;
  }

  // Delete Firestore user doc and attempt to delete Firebase Auth user
  Future<String?> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return 'Utilisateur non connecté.';
    _isLoading = true;
    notifyListeners();
    try {
      await _db.collection('users').doc(user.uid).delete();
      try {
        await user.delete();
      } catch (e) {
        // Deletion may require recent authentication. Preserve message.
        return 'Compte Firestore supprimé. Suppression du compte Auth requiert une ré-authentification: $e';
      }
      return null;
    } catch (e) {
      return 'Erreur suppression: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}