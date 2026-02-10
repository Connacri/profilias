import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.email});

  final String email;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _authService = AuthService();
  late final TextEditingController _displayNameController;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    final displayName = user?.userMetadata?['full_name'] ?? '';
    _displayNameController = TextEditingController(text: displayName);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _updateDisplayName(String value) async {
    await _authService.updateDisplayName(value);
  }

  Future<void> _signOut() async {
    await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id ?? 'inconnu';
    final provider = user?.appMetadata['provider'] ?? 'inconnu';
    final createdAt = user?.createdAt ?? 'inconnu';
    final webClientId = _authService.webClientId;
    final iosClientId = _authService.iosClientId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilias'),
        actions: [
          TextButton(onPressed: _signOut, child: const Text('Déconnexion')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Profil', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text('Email: ${widget.email}'),
          Text('User ID: $userId'),
          Text('Provider: $provider'),
          Text('Créé le: $createdAt'),
          if (kDebugMode) ...[
            const SizedBox(height: 12),
            Text('Google Web Client ID: $webClientId'),
            if (iosClientId.isNotEmpty)
              Text('Google iOS Client ID: $iosClientId'),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _displayNameController,
            decoration: const InputDecoration(labelText: 'Nom complet'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _updateDisplayName(_displayNameController.text),
            child: const Text('Mettre à jour'),
          ),
        ],
      ),
    );
  }
}
