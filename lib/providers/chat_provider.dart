import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/chat_message.dart';

class ChatProvider with ChangeNotifier {
	bool _isSending = false;
	static const String _welcomeMessage =
			"Bonjour ! Je suis votre assistant d'etude. Posez-moi une question, je peux expliquer, resumer, ou vous aider a reviser.";
	static const List<String> _groqModels = <String>[
		'llama-3.1-8b-instant',
		'llama-3.1-70b-versatile',
		'mixtral-8x7b-32768',
	];
	static const Duration _groqTimeout = Duration(seconds: 20);
	final Map<String, List<ChatMessage>> _messagesByUser = <String, List<ChatMessage>>{};
	final Map<String, StreamController<List<ChatMessage>>> _controllers = <String, StreamController<List<ChatMessage>>>{};
	final Set<String> _welcomeShownForUser = <String>{};

	bool get isSending => _isSending;

	Stream<List<ChatMessage>> streamMessages(String userId) async* {
		_ensureWelcomeMessage(userId);
		// Emet la valeur initiale
		yield List<ChatMessage>.unmodifiable(_messagesByUser[userId] ?? <ChatMessage>[]);
		
		// Emet les futures mises à jour via un broadcast controller
		final controller = _controllers.putIfAbsent(userId, () => StreamController<List<ChatMessage>>.broadcast());
		yield* controller.stream;
	}

	void _ensureWelcomeMessage(String userId) {
		if (_welcomeShownForUser.contains(userId)) return;
		final messages = _messagesByUser[userId];
		if (messages != null && messages.isNotEmpty) return;
		_welcomeShownForUser.add(userId);
		_appendMessage(
			userId,
			ChatMessage(
				id: DateTime.now().microsecondsSinceEpoch.toString(),
				userId: userId,
				role: 'assistant',
				content: _welcomeMessage,
				createdAt: DateTime.now(),
			),
		);
	}

	void _pushMessages(String userId) {
		final controller = _controllers[userId];
		if (controller == null || controller.isClosed) return;
		controller.add(List<ChatMessage>.unmodifiable(_messagesByUser[userId] ?? <ChatMessage>[]));
	}

	void _appendMessage(String userId, ChatMessage message) {
		final messages = _messagesByUser.putIfAbsent(userId, () => <ChatMessage>[]);
		messages.add(message);
		_pushMessages(userId);
	}

	Future<String?> sendMessage({
		required String userId,
		required String text,
	}) async {
		final apiKey = AppConfig.groqApiKey;
		if (apiKey.isEmpty) {
			return 'Clé API Groq manquante. Ajoutez GROQ_API_KEY dans .env.';
		}

		_isSending = true;
		notifyListeners();

		try {
			_appendMessage(
				userId,
				ChatMessage(
					id: DateTime.now().microsecondsSinceEpoch.toString(),
					userId: userId,
					role: 'user',
					content: text,
					createdAt: DateTime.now(),
				),
			);

			final history = List<ChatMessage>.from(_messagesByUser[userId] ?? <ChatMessage>[]);
			if (history.length > 12) {
				history.removeRange(0, history.length - 12);
			}

			final promptBuffer = StringBuffer('Conversation:\n');
			for (final msg in history) {
				final role = msg.role == 'user' ? 'Utilisateur' : 'Assistant';
				promptBuffer.writeln('$role: ${msg.content}');
			}
			promptBuffer.writeln('Assistant:');
			final reply = await _requestGroqReply(
				apiKey: apiKey,
				messages: history,
			);
			_appendMessage(
				userId,
				ChatMessage(
					id: DateTime.now().microsecondsSinceEpoch.toString(),
					userId: userId,
					role: 'assistant',
					content: reply,
					createdAt: DateTime.now(),
				),
			);

			return null;
		} on TimeoutException {
			return 'Temps depasse. Reessayez.';
		} on StateError catch (e) {
			return e.message;
		} catch (e) {
			return 'Erreur Groq: $e';
		} finally {
			_isSending = false;
			notifyListeners();
		}
	}

	Future<String> _requestGroqReply({
		required String apiKey,
		required List<ChatMessage> messages,
	}) async {
		final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
		final requestMessages = <Map<String, String>>[
			{
				'role': 'system',
				'content': 'Tu es un assistant d\'etude utile et concis.',
			},
			...messages.map((msg) => {
				'role': msg.role == 'assistant' ? 'assistant' : 'user',
				'content': msg.content,
			}),
		];

		Object? lastError;
		for (final modelName in _groqModels) {
			try {
				final response = await http
						.post(
							uri,
							headers: <String, String>{
								'Authorization': 'Bearer $apiKey',
								'Content-Type': 'application/json',
							},
							body: jsonEncode({
								'model': modelName,
								'messages': requestMessages,
								'temperature': 0.7,
							}),
						)
						.timeout(_groqTimeout);

				if (response.statusCode != 200) {
					final errorMessage = _extractGroqError(response.body);
					throw StateError(errorMessage ?? 'Erreur Groq ${response.statusCode}');
				}

				final data = jsonDecode(response.body) as Map<String, dynamic>;
				final choices = data['choices'] as List<dynamic>?;
				final firstChoice = (choices != null && choices.isNotEmpty) ? choices.first as Map<String, dynamic>? : null;
				final message = firstChoice?['message'] as Map<String, dynamic>?;
				final content = message?['content']?.toString();
				if (content == null || content.trim().isEmpty) {
					throw StateError('Reponse Groq vide.');
				}
				return content.trim();
			} catch (e) {
				lastError = e;
			}
		}

		throw StateError('Aucun modele Groq disponible. Derniere erreur: $lastError');
	}

	String? _extractGroqError(String body) {
		try {
			final data = jsonDecode(body) as Map<String, dynamic>;
			final error = data['error'] as Map<String, dynamic>?;
			return error?['message']?.toString();
		} catch (_) {
			return null;
		}
	}

	@override
	void dispose() {
		for (final controller in _controllers.values) {
			controller.close();
		}
		_controllers.clear();
		_messagesByUser.clear();
		super.dispose();
	}
}