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
  late final PageController _galleryController;
  int _galleryIndex = 0;

  final List<String> _gallery = const [
    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=1200',
    'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=1200',
    'https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=1200',
    'https://images.unsplash.com/photo-1482192596544-9eb780fc7f66?w=1200',
  ];

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    final displayName = user?.userMetadata?['full_name'] ?? '';
    _displayNameController = TextEditingController(text: displayName);
    _galleryController = PageController();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _galleryController.dispose();
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
    final fullName = (user?.userMetadata?['full_name'] as String?)?.trim() ?? '';
    final displayName = fullName.isNotEmpty ? fullName : 'Profilias User';
    final isCompact = MediaQuery.of(context).size.width < 720;
    final webClientId = _authService.webClientId;
    final iosClientId = _authService.iosClientId;
    final avatarUrl =
        user?.userMetadata?['avatar_url'] as String? ??
            'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400';
    final coverUrl =
        user?.userMetadata?['cover_url'] as String? ??
            'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=1600';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          TextButton(onPressed: _signOut, child: const Text('Déconnexion')),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F5F2), Color(0xFFE9F1F0)],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _ProfileHeader(
                coverUrl: coverUrl,
                avatarUrl: avatarUrl,
                name: displayName,
                email: widget.email,
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 16 : 24,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionCard(
                        title: 'À propos',
                        child: Text(
                          'Bienvenue sur votre profil. Personnalisez votre photo, '
                          'votre couverture et vos informations.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Galerie',
                        child: Column(
                          children: [
                            AspectRatio(
                              aspectRatio: isCompact ? 16 / 10 : 16 / 7,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: PageView.builder(
                                  controller: _galleryController,
                                  itemCount: _gallery.length,
                                  onPageChanged: (index) {
                                    setState(() => _galleryIndex = index);
                                  },
                                  itemBuilder: (context, index) {
                                    return Image.network(
                                      _gallery[index],
                                      fit: BoxFit.cover,
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_gallery.length, (index) {
                                final active = index == _galleryIndex;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  width: active ? 20 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Préférences',
                        child: Column(
                          children: [
                            TextField(
                              controller: _displayNameController,
                              decoration: const InputDecoration(
                                labelText: 'Nom complet',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ElevatedButton(
                                onPressed: () => _updateDisplayName(
                                  _displayNameController.text,
                                ),
                                child: const Text('Mettre à jour'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (kDebugMode) ...[
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Debug',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Google Web Client ID: $webClientId'),
                              if (iosClientId.isNotEmpty)
                                Text('Google iOS Client ID: $iosClientId'),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.coverUrl,
    required this.avatarUrl,
    required this.name,
    required this.email,
  });

  final String coverUrl;
  final String avatarUrl;
  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 260,
          width: double.infinity,
          child: Image.network(
            coverUrl,
            fit: BoxFit.cover,
          ),
        ),
        Container(
          height: 260,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.1),
                Colors.black.withValues(alpha: 0.5),
              ],
            ),
          ),
        ),
        Positioned(
          left: 24,
          bottom: 16,
          child: Row(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: NetworkImage(avatarUrl),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
