import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CardsListPage extends StatefulWidget {
  const CardsListPage({super.key});

  @override
  State<CardsListPage> createState() => _CardsListPageState();
}

class _CardsListPageState extends State<CardsListPage> {
  final _client = Supabase.instance.client;
  String _filter = 'all';
  int _refreshToken = 0;

  Future<List<Map<String, dynamic>>> _fetchCards() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    var query = _client.from('cartes').select().eq('user_id', user.id);
    if (_filter != 'all') {
      query = query.eq('type', _filter);
    }
    final data = await query.order('created_at', ascending: false);
    final cards = (data as List).cast<Map<String, dynamic>>();
    await _hydrateSignedUrls(cards);
    return cards;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes cartes'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              children: [
                _filterChip('all', 'Toutes'),
                _filterChip('cni', 'CNI'),
                _filterChip('chifa', 'Chifa'),
                _filterChip('ccp', 'CCP'),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchCards(),
              key: ValueKey(_refreshToken),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final cards = snapshot.data ?? [];
                if (cards.isEmpty) {
                  return const Center(child: Text('Aucune carte.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: cards.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    final type = (card['type'] ?? '').toString();
                    final title = _titleFor(card);
                    final subtitle = _subtitleFor(card);
                    final imageUrl = card['image_url'] as String?;
                    return Card(
                      child: ListTile(
                        leading: imageUrl != null && imageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imageUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : CircleAvatar(
                                child: Text(type.isNotEmpty
                                    ? type.substring(0, 1).toUpperCase()
                                    : '?'),
                              ),
                        title: Text(title),
                        subtitle: Text(subtitle),
                        onTap: () => _openDetails(card),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _filter = value);
      },
    );
  }

  String _titleFor(Map<String, dynamic> card) {
    final type = (card['type'] ?? '').toString();
    if (type == 'cni') {
      return (card['cni_nom_prenom'] ?? 'CNI').toString();
    }
    if (type == 'chifa') {
      return (card['chifa_nom_prenom'] ?? 'Chifa').toString();
    }
    if (type == 'ccp') {
      return (card['ccp_nom_prenom'] ?? 'CCP').toString();
    }
    return 'Carte';
  }

  String _subtitleFor(Map<String, dynamic> card) {
    final type = (card['type'] ?? '').toString();
    if (type == 'cni') {
      return 'NIN: ${(card['cni_nin'] ?? '-').toString()}';
    }
    if (type == 'chifa') {
      return 'Immatriculation: ${(card['chifa_immatriculation'] ?? '-').toString()}';
    }
    if (type == 'ccp') {
      return 'Compte: ${(card['ccp_compte'] ?? '-').toString()}';
    }
    return '';
  }

  void _openDetails(Map<String, dynamic> card) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CardDetailsPage(
          card: card,
          onUpdated: () => setState(() => _refreshToken += 1),
          onDeleted: () => setState(() => _refreshToken += 1),
        ),
      ),
    );
  }

  Future<void> _hydrateSignedUrls(List<Map<String, dynamic>> cards) async {
    final futures = cards.map((card) async {
      final imageUrl = card['image_url'] as String?;
      final storagePath = card['image_storage_path'] as String?;
      if ((imageUrl == null || imageUrl.isEmpty) &&
          storagePath != null &&
          storagePath.isNotEmpty) {
        try {
          final signed = await _client.storage
              .from('cartes')
              .createSignedUrl(storagePath, 3600);
          card['image_url'] = signed;
        } catch (_) {
          // ignore, fallback to placeholder
        }
      }
    }).toList();
    await Future.wait(futures);
  }
}

class _CardDetailsPage extends StatelessWidget {
  const _CardDetailsPage({
    required this.card,
    required this.onUpdated,
    required this.onDeleted,
  });

  final Map<String, dynamic> card;
  final VoidCallback onUpdated;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final entries = card.entries
        .where((entry) => entry.value != null && entry.value.toString().isNotEmpty)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Details carte'),
        actions: [
          IconButton(
            onPressed: () async {
              final updated = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => _EditCardPage(card: card),
                ),
              );
              if (updated == true) {
                onUpdated();
              }
            },
            icon: const Icon(Icons.edit),
            tooltip: 'Modifier',
          ),
          IconButton(
            onPressed: () async {
              final ok = await _confirmDelete(context);
              if (!ok) return;
              final client = Supabase.instance.client;
              final id = card['id'];
              final storagePath = card['image_storage_path'] as String?;
              if (storagePath != null && storagePath.isNotEmpty) {
                try {
                  await client.storage.from('cartes').remove([storagePath]);
                } catch (_) {}
              }
              await client.from('cartes').delete().eq('id', id);
              if (context.mounted) {
                onDeleted();
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.delete),
            tooltip: 'Supprimer',
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(entry.value.toString()),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la carte ?'),
        content: const Text('Cette action est irreversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _EditCardPage extends StatefulWidget {
  const _EditCardPage({required this.card});

  final Map<String, dynamic> card;

  @override
  State<_EditCardPage> createState() => _EditCardPageState();
}

class _EditCardPageState extends State<_EditCardPage> {
  final _client = Supabase.instance.client;
  final _controllers = <String, TextEditingController>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final fields = _fieldsForType(widget.card['type']?.toString() ?? '');
    for (final field in fields) {
      _controllers[field] =
          TextEditingController(text: widget.card[field]?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.card['type']?.toString() ?? '';
    final fields = _fieldsForType(type);
    final labels = _labelsForType(type);
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier la carte')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
                child: ListView(
                children: fields
                    .map(
                      (field) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: _controllers[field],
                          decoration: InputDecoration(
                            labelText: labels[field] ?? field,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _fieldsForType(String type) {
    if (type == 'cni') {
      return [
        'cni_numero',
        'cni_date_delivrance',
        'cni_lieu_delivrance',
        'cni_date_expiration',
        'cni_nom_prenom',
        'cni_nom_ar',
        'cni_prenom_ar',
        'cni_nom_verso',
        'cni_prenom_verso',
        'cni_sexe',
        'cni_date_naissance',
        'cni_lieu_naissance',
        'cni_rh',
        'cni_date_lieu_naissance',
        'cni_nin',
      ];
    }
    if (type == 'chifa') {
      return [
        'chifa_immatriculation',
        'chifa_nom_prenom',
        'chifa_date_naissance',
        'chifa_type_carte',
        'chifa_numero_serie',
      ];
    }
    return ['ccp_nom_prenom', 'ccp_compte', 'ccp_cle'];
  }

  Map<String, String> _labelsForType(String type) {
    if (type == 'cni') {
      return {
        'cni_numero': 'Numero de la carte',
        'cni_date_delivrance': 'Date de delivrance',
        'cni_lieu_delivrance': 'Lieu de delivrance',
        'cni_date_expiration': 'Date d\'expiration',
        'cni_nom_prenom': 'Nom et prenoms (latin)',
        'cni_nom_ar': 'Nom (arabe)',
        'cni_prenom_ar': 'Prenom (arabe)',
        'cni_nom_verso': 'Nom (verso)',
        'cni_prenom_verso': 'Prenom (verso)',
        'cni_sexe': 'Sexe',
        'cni_date_naissance': 'Date de naissance',
        'cni_lieu_naissance': 'Lieu de naissance',
        'cni_rh': 'RH',
        'cni_date_lieu_naissance': 'Date et lieu de naissance',
        'cni_nin': 'NIN',
      };
    }
    if (type == 'chifa') {
      return {
        'chifa_immatriculation': 'Numero d\'immatriculation',
        'chifa_nom_prenom': 'Nom et prenom',
        'chifa_date_naissance': 'Date de naissance',
        'chifa_type_carte': 'Type de carte',
        'chifa_numero_serie': 'Numero de serie',
      };
    }
    return {
      'ccp_nom_prenom': 'Nom et prenom',
      'ccp_compte': 'Compte CCP',
      'ccp_cle': 'Cle CCP',
    };
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{};
      _controllers.forEach((key, controller) {
        payload[key] = controller.text.trim();
      });
      await _client.from('cartes').update(payload).eq('id', widget.card['id']);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
