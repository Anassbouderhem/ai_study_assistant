import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/notification_service.dart';

class NotesProvider with ChangeNotifier {
	final FirebaseFirestore _db = FirebaseFirestore.instance;
	final _notif = NotificationService();

	Stream<List<Note>> streamNotes(String userId) {
		return _db
				.collection('notes')
				.where('userId', isEqualTo: userId)
				.orderBy('updatedAt', descending: true)
				.snapshots()
				.map((snapshot) => snapshot.docs.map(Note.fromDoc).toList());
	}

	Stream<Map<String, dynamic>> streamTagSettings(String userId) {
		return _db
				.collection('tag_settings')
				.doc(userId)
				.snapshots()
				.map((doc) => doc.data() ?? {});
	}

	Future<void> addNote({
		required String userId,
		required String title,
		required String content,
		required List<String> tags,
	}) async {
		final now = DateTime.now();
		await _db.collection('notes').add({
			'userId': userId,
			'title': title,
			'content': content,
			'tags': tags,
			'createdAt': Timestamp.fromDate(now),
			'updatedAt': Timestamp.fromDate(now),
		});
		await _notif.showInstant(
			id: 1001,
			title: '📝 Note créée',
			body: '"$title" a été sauvegardée avec succès.',
		);
	}

	Future<void> updateNote({
		required String noteId,
		required String title,
		required String content,
		required List<String> tags,
	}) async {
		await _db.collection('notes').doc(noteId).update({
			'title': title,
			'content': content,
			'tags': tags,
			'updatedAt': Timestamp.fromDate(DateTime.now()),
		});
		await _notif.showInstant(
			id: 1002,
			title: '📝 Note mise à jour',
			body: '"$title" a été sauvegardée avec succès.',
		);
	}

	Future<void> deleteNote(String noteId) async {
		await _db.collection('notes').doc(noteId).delete();
	}

	Future<void> updateTagSettings({
		required String userId,
		required Map<String, int> colors,
		required Map<String, int> priorities,
	}) async {
		await _db.collection('tag_settings').doc(userId).set({
			'colors': colors,
			'priorities': priorities,
		}, SetOptions(merge: true));
	}

	Future<void> renameTagInNotes({
		required String userId,
		required String oldTag,
		required String newTag,
	}) async {
		final snapshot = await _db.collection('notes').where('userId', isEqualTo: userId).get();
		final batch = _db.batch();
		for (final doc in snapshot.docs) {
			final tags = List<String>.from(doc.data()['tags'] ?? []);
			if (!tags.contains(oldTag)) continue;
			final updatedTags = tags.map((tag) => tag == oldTag ? newTag : tag).toSet().toList();
			batch.update(doc.reference, {
				'tags': updatedTags,
				'updatedAt': Timestamp.fromDate(DateTime.now()),
			});
		}
		await batch.commit();
	}

	Future<void> deleteTagFromNotes({
		required String userId,
		required String tag,
	}) async {
		final snapshot = await _db.collection('notes').where('userId', isEqualTo: userId).get();
		final batch = _db.batch();
		for (final doc in snapshot.docs) {
			final tags = List<String>.from(doc.data()['tags'] ?? []);
			if (!tags.contains(tag)) continue;
			final updatedTags = tags.where((t) => t != tag).toList();
			batch.update(doc.reference, {
				'tags': updatedTags,
				'updatedAt': Timestamp.fromDate(DateTime.now()),
			});
		}
		await batch.commit();
	}
}