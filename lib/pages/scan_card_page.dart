import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScanCardPage extends StatefulWidget {
  const ScanCardPage({super.key});

  @override
  State<ScanCardPage> createState() => _ScanCardPageState();
}

enum CardType { cni, chifa, ccp }
enum CniSide { recto, verso }

class _ScanCardPageState extends State<ScanCardPage> {
  final _client = Supabase.instance.client;
  final _imagePicker = ImagePicker();
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  CardType _type = CardType.cni;
  CniSide _cniSide = CniSide.recto;
  bool _loading = false;
  String? _imagePath;
  String _rawText = '';
  String? _cniRectoPath;
  String? _cniVersoPath;
  String _cniRectoText = '';
  String _cniVersoText = '';
  String? _error;

  final _cniNumero = TextEditingController();
  final _cniDateDelivrance = TextEditingController();
  final _cniLieuDelivrance = TextEditingController();
  final _cniDateExpiration = TextEditingController();
  final _cniNomPrenom = TextEditingController();
  final _cniNomAr = TextEditingController();
  final _cniPrenomAr = TextEditingController();
  final _cniDateNaissance = TextEditingController();
  final _cniLieuNaissance = TextEditingController();
  final _cniRh = TextEditingController();
  final _cniNomVerso = TextEditingController();
  final _cniPrenomVerso = TextEditingController();
  final _cniSexe = TextEditingController();
  final _cniDateLieuNaissance = TextEditingController();
  final _cniNin = TextEditingController();

  final _chifaImmatriculation = TextEditingController();
  final _chifaNomPrenom = TextEditingController();
  final _chifaDateNaissance = TextEditingController();
  final _chifaTypeCarte = TextEditingController();
  final _chifaNumeroSerie = TextEditingController();

  final _ccpNomPrenom = TextEditingController();
  final _ccpCompte = TextEditingController();
  final _ccpCle = TextEditingController();

  @override
  void dispose() {
    _recognizer.close();
    _cniNumero.dispose();
    _cniDateDelivrance.dispose();
    _cniLieuDelivrance.dispose();
    _cniDateExpiration.dispose();
    _cniNomPrenom.dispose();
    _cniNomAr.dispose();
    _cniPrenomAr.dispose();
    _cniDateNaissance.dispose();
    _cniLieuNaissance.dispose();
    _cniRh.dispose();
    _cniNomVerso.dispose();
    _cniPrenomVerso.dispose();
    _cniSexe.dispose();
    _cniDateLieuNaissance.dispose();
    _cniNin.dispose();
    _chifaImmatriculation.dispose();
    _chifaNomPrenom.dispose();
    _chifaDateNaissance.dispose();
    _chifaTypeCarte.dispose();
    _chifaNumeroSerie.dispose();
    _ccpNomPrenom.dispose();
    _ccpCompte.dispose();
    _ccpCle.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() {
      _error = null;
      _rawText = '';
    });
    try {
      XFile? file;
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        file = await _imagePicker.pickImage(source: ImageSource.camera);
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
        );
        final pickedPath = result?.files.single.path;
        if (pickedPath != null) {
          file = XFile(pickedPath);
        }
      }
      final picked = file;
      if (picked == null) {
        return;
      }
      setState(() {
        _imagePath = picked.path;
        if (_type == CardType.cni) {
          if (_cniSide == CniSide.recto) {
            _cniRectoPath = picked.path;
          } else {
            _cniVersoPath = picked.path;
          }
        }
      });
      await _runOcr(picked.path);
    } catch (e) {
      setState(() => _error = 'Erreur scan: $e');
    }
  }

  Future<void> _runOcr(String path) async {
    setState(() => _loading = true);
    try {
      final inputImage = InputImage.fromFilePath(path);
      final result = await _recognizer.processImage(inputImage);
      final text = result.text;
      setState(() => _rawText = text);
      if (_type == CardType.cni) {
        if (_cniSide == CniSide.recto) {
          _cniRectoText = text;
        } else {
          _cniVersoText = text;
        }
      }
      _applyHeuristics(result);
    } catch (e) {
      setState(() => _error = 'OCR impossible: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applyHeuristics(RecognizedText recognized) {
    final text = recognized.text;
    final lines = _extractOrderedLines(recognized);
    String findAfterLabel(List<String> labels) {
      for (final line in lines) {
        for (final label in labels) {
          if (line.toLowerCase().contains(label.toLowerCase())) {
            final index = lines.indexOf(line);
            if (index + 1 < lines.length) {
              return lines[index + 1];
            }
          }
        }
      }
      return '';
    }

    if (_type == CardType.cni) {
      if (_cniSide == CniSide.recto) {
        final ordered = lines.where((line) => line.isNotEmpty).toList();
        final dateMatches = _findAllDates(text);
        if (ordered.isNotEmpty && _cniNumero.text.isEmpty) {
          _cniNumero.text = ordered[0];
        }
        if (ordered.length > 1 && _cniLieuDelivrance.text.isEmpty) {
          _cniLieuDelivrance.text = ordered[1];
        }
        if (ordered.length > 2 && _cniDateDelivrance.text.isEmpty) {
          _cniDateDelivrance.text = _extractFirstDate(ordered[2]) ??
              (dateMatches.isNotEmpty ? dateMatches.first : '');
        }
        if (ordered.length > 3 && _cniDateExpiration.text.isEmpty) {
          _cniDateExpiration.text = _extractFirstDate(ordered[3]) ??
              (dateMatches.length > 1 ? dateMatches[1] : '');
        }
        final ninMatch = RegExp(r'\b\d{18}\b').firstMatch(text);
        if (ninMatch != null && _cniNin.text.isEmpty) {
          _cniNin.text = ninMatch.group(0) ?? '';
        }
        if (ordered.length > 5 && _cniNomAr.text.isEmpty) {
          _cniNomAr.text = ordered[5];
        }
        if (ordered.length > 6 && _cniPrenomAr.text.isEmpty) {
          _cniPrenomAr.text = ordered[6];
        }
        if (ordered.length > 7 && _cniDateNaissance.text.isEmpty) {
          _cniDateNaissance.text = _extractFirstDate(ordered[7]) ??
              (dateMatches.length > 2 ? dateMatches[2] : '');
        }
        if (ordered.length > 8 && _cniSexe.text.isEmpty) {
          _cniSexe.text = ordered[8];
        }
        if (ordered.length > 9 && _cniRh.text.isEmpty) {
          _cniRh.text = ordered[9];
        }
        if (ordered.length > 10 && _cniLieuNaissance.text.isEmpty) {
          _cniLieuNaissance.text = ordered[10];
        }
        _cniNomPrenom.text =
            _cniNomPrenom.text.isNotEmpty ? _cniNomPrenom.text : findAfterLabel(
          ['nom', 'prenom', 'nom et prenom'],
        );
        _cniDateLieuNaissance.text = _cniDateLieuNaissance.text.isNotEmpty
            ? _cniDateLieuNaissance.text
            : findAfterLabel(['naissance', 'date et lieu']);
      } else {
        final candidates = lines.where((line) => line.isNotEmpty).toList();
        if (candidates.isNotEmpty && _cniNomVerso.text.isEmpty) {
          _cniNomVerso.text = candidates[0];
        }
        if (candidates.length > 1 && _cniPrenomVerso.text.isEmpty) {
          _cniPrenomVerso.text = candidates[1];
        }
      }
    } else if (_type == CardType.chifa) {
      final dateMatch = _findFirstDate(text);
      _chifaImmatriculation.text = _chifaImmatriculation.text.isNotEmpty
          ? _chifaImmatriculation.text
          : findAfterLabel(['immatriculation', 'assure']);
      _chifaNomPrenom.text = _chifaNomPrenom.text.isNotEmpty
          ? _chifaNomPrenom.text
          : findAfterLabel(['nom', 'prenom', 'titulaire']);
      _chifaDateNaissance.text = _chifaDateNaissance.text.isNotEmpty
          ? _chifaDateNaissance.text
          : (findAfterLabel(['naissance', 'date de naissance']).isNotEmpty
              ? findAfterLabel(['naissance', 'date de naissance'])
              : dateMatch);
      _chifaTypeCarte.text = _chifaTypeCarte.text.isNotEmpty
          ? _chifaTypeCarte.text
          : findAfterLabel(['assure', 'ayant', 'type']);
      _chifaNumeroSerie.text = _chifaNumeroSerie.text.isNotEmpty
          ? _chifaNumeroSerie.text
          : findAfterLabel(['serie', 'num', 'numero']);
    } else {
      _ccpNomPrenom.text = _ccpNomPrenom.text.isNotEmpty
          ? _ccpNomPrenom.text
          : findAfterLabel(['nom', 'prenom', 'titulaire']);
      final compteMatch = RegExp(r'\b\d{10,12}\b').firstMatch(text);
      if (compteMatch != null && _ccpCompte.text.isEmpty) {
        _ccpCompte.text = compteMatch.group(0) ?? '';
      }
      final cleMatch = RegExp(r'\b\d{2}\b').firstMatch(text);
      if (cleMatch != null && _ccpCle.text.isEmpty) {
        _ccpCle.text = cleMatch.group(0) ?? '';
      }
      if (_ccpCompte.text.isEmpty) {
        final altMatch = RegExp(r'\b\d{6,14}\b').firstMatch(text);
        if (altMatch != null) {
          _ccpCompte.text = altMatch.group(0) ?? '';
        }
      }
    }
    setState(() {});
  }

  List<String> _extractOrderedLines(RecognizedText recognized) {
    final lines = <TextLine>[];
    for (final block in recognized.blocks) {
      lines.addAll(block.lines);
    }
    lines.sort((a, b) {
      final ay = a.boundingBox.top;
      final by = b.boundingBox.top;
      if (ay == by) {
        return a.boundingBox.left.compareTo(b.boundingBox.left);
      }
      return ay.compareTo(by);
    });
    return lines.map((line) => line.text.trim()).where((t) => t.isNotEmpty).toList();
  }

  List<String> _findAllDates(String text) {
    final matches = RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b')
        .allMatches(text);
    return matches.map((m) => m.group(0) ?? '').where((v) => v.isNotEmpty).toList();
  }

  String? _extractFirstDate(String text) {
    final match = RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b').firstMatch(text);
    return match?.group(0);
  }
  String _findFirstDate(String text) {
    final normalized = _normalizeText(text);
    final match = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b')
        .firstMatch(normalized);
    if (match == null) return '';
    final day = match.group(1) ?? '';
    final month = match.group(2) ?? '';
    final year = match.group(3) ?? '';
    return '$day/$month/$year';
  }

  DateTime? _parseDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (!RegExp(r'^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}$').hasMatch(trimmed)) {
      return null;
    }
    final parts = trimmed.split(RegExp(r'[-/.]'));
    if (parts.length != 3) {
      return null;
    }
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) {
      return null;
    }
    return DateTime(year, month, day);
  }

  String _extractPlace(String text) {
    final normalized = _normalizeText(text);
    final match = RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b')
        .firstMatch(normalized);
    if (match == null) return normalized.trim();
    final rest = normalized.substring(match.end).replaceAll(RegExp(r'[-,:]'), ' ');
    return rest.trim();
  }

  String _normalizeText(String text) {
    var value = text.toLowerCase();
    value = value
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ù', 'u')
        .replaceAll('ç', 'c');
    value = value.replaceAll(RegExp(r'\s+'), ' ');
    return value;
  }

  Future<void> _promptProfileUpdate(String userId) async {
    if (!context.mounted) return;
    final profile =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (!context.mounted) return;
    if (profile?['cni_auto_update_opt_out'] == true) {
      return;
    }
    final existingName = profile?['full_name']?.toString() ?? '';
    final existingDob = profile?['date_of_birth']?.toString() ?? '';
    final existingCity = profile?['city']?.toString() ?? '';

    final nameController = TextEditingController(text: _cniNomPrenom.text);
    final dobController = TextEditingController(
      text: _findFirstDate(_cniDateLieuNaissance.text),
    );
    final cityController = TextEditingController(
      text: _extractPlace(_cniDateLieuNaissance.text),
    );

    var overwrite = false;
    var dontAskAgain = false;
    final result = await showModalBottomSheet<bool>(
      // ignore: use_build_context_synchronously
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Mettre a jour le profil depuis la CNI',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom et prenoms',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dobController,
                    decoration: const InputDecoration(
                      labelText: 'Date de naissance (JJ/MM/AAAA)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cityController,
                    decoration: const InputDecoration(
                      labelText: 'Lieu de naissance',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: overwrite,
                    onChanged: (value) =>
                        setModalState(() => overwrite = value),
                    title: const Text('Ecraser les valeurs existantes'),
                    subtitle: Text(
                      'Actuel: $existingName | $existingDob | $existingCity',
                    ),
                  ),
                  SwitchListTile(
                    value: dontAskAgain,
                    onChanged: (value) =>
                        setModalState(() => dontAskAgain = value),
                    title: const Text('Ne plus demander'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          child: const Text('Ignorer'),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(true),
                          child: const Text('Mettre a jour'),
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

    if (result != true) {
      return;
    }

    final payload = <String, dynamic>{};
    if (nameController.text.trim().isNotEmpty &&
        (overwrite || existingName.isEmpty)) {
      payload['full_name'] = nameController.text.trim();
    }
    final parsedDob = _parseDate(dobController.text);
    if (parsedDob != null && (overwrite || existingDob.isEmpty)) {
      payload['date_of_birth'] = parsedDob.toIso8601String();
    }
    if (cityController.text.trim().isNotEmpty &&
        (overwrite || existingCity.isEmpty)) {
      payload['city'] = cityController.text.trim();
    }

    if (payload.isEmpty) {
      return;
    }
    await _client.from('profiles').update(payload).eq('id', userId);
    if (dontAskAgain) {
      await _client
          .from('profiles')
          .update({'cni_auto_update_opt_out': true}).eq('id', userId);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil mis a jour.')),
    );
  }

  Future<void> _save() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      setState(() => _error = 'Utilisateur non connecte.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      String? storagePath;
      String? publicUrl;
      if (_imagePath != null && _imagePath!.isNotEmpty) {
        final path = _imagePath!;
        final ext = path.split('.').last.toLowerCase();
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}.${ext.isEmpty ? 'jpg' : ext}';
        storagePath = 'users/${user.id}/${_type.name}/$fileName';
        final tempDir = await getTemporaryDirectory();
        final targetPath =
            '${tempDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final compressed = await FlutterImageCompress.compressAndGetFile(
          path,
          targetPath,
          quality: 75,
          minWidth: 1600,
          minHeight: 1600,
        );
        final fallbackPath = path;
        final compressedPath = compressed?.path;
        final bytes =
            await File(compressedPath ?? fallbackPath).readAsBytes();
        await _client.storage.from('cartes').uploadBinary(
              storagePath,
              bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        publicUrl = _client.storage.from('cartes').getPublicUrl(storagePath);
      }
      final payload = <String, dynamic>{
        'user_id': user.id,
        'type': _type.name,
        'raw_text': _rawText,
        'image_path': _imagePath,
        'image_storage_path': storagePath,
        'image_url': publicUrl,
        'cni_numero': _cniNumero.text.trim(),
        'cni_date_delivrance': _parseDate(_cniDateDelivrance.text),
        'cni_lieu_delivrance': _cniLieuDelivrance.text.trim(),
        'cni_date_expiration': _parseDate(_cniDateExpiration.text),
        'cni_nom_prenom': _cniNomPrenom.text.trim(),
        'cni_nom_ar': _cniNomAr.text.trim(),
        'cni_prenom_ar': _cniPrenomAr.text.trim(),
        'cni_nom_verso': _cniNomVerso.text.trim(),
        'cni_prenom_verso': _cniPrenomVerso.text.trim(),
        'cni_sexe': _cniSexe.text.trim(),
        'cni_date_lieu_naissance': _cniDateLieuNaissance.text.trim(),
        'cni_date_naissance': _parseDate(_cniDateNaissance.text),
        'cni_lieu_naissance': _cniLieuNaissance.text.trim(),
        'cni_rh': _cniRh.text.trim(),
        'cni_nin': _cniNin.text.trim(),
        'cni_recto_text': _cniRectoText,
        'cni_verso_text': _cniVersoText,
        'cni_recto_image_path': _cniRectoPath,
        'cni_verso_image_path': _cniVersoPath,
        'chifa_immatriculation': _chifaImmatriculation.text.trim(),
        'chifa_nom_prenom': _chifaNomPrenom.text.trim(),
        'chifa_date_naissance': _parseDate(_chifaDateNaissance.text),
        'chifa_type_carte': _chifaTypeCarte.text.trim(),
        'chifa_numero_serie': _chifaNumeroSerie.text.trim(),
        'ccp_nom_prenom': _ccpNomPrenom.text.trim(),
        'ccp_compte': _ccpCompte.text.trim(),
        'ccp_cle': _ccpCle.text.trim(),
      };
      await _client.from('cartes').insert(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carte enregistree.')),
      );
      if (_type == CardType.cni) {
        await _promptProfileUpdate(user.id);
      }
    } catch (e) {
      setState(() => _error = 'Sauvegarde impossible: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 800;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner une carte'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<CardType>(
                  segments: const [
                    ButtonSegment(value: CardType.cni, label: Text('CNI')),
                    ButtonSegment(value: CardType.chifa, label: Text('Chifa')),
                    ButtonSegment(value: CardType.ccp, label: Text('CCP')),
                  ],
                  selected: {_type},
                  onSelectionChanged: (value) {
                    setState(() => _type = value.first);
                  },
                ),
                if (_type == CardType.cni) ...[
                  const SizedBox(height: 12),
                  SegmentedButton<CniSide>(
                    segments: const [
                      ButtonSegment(value: CniSide.recto, label: Text('Recto')),
                      ButtonSegment(value: CniSide.verso, label: Text('Verso')),
                    ],
                    selected: {_cniSide},
                    onSelectionChanged: (value) {
                      setState(() => _cniSide = value.first);
                    },
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _pickImage,
                      icon: const Icon(Icons.document_scanner),
                      label: const Text('Scanner'),
                    ),
                    if (_imagePath != null)
                      Text(
                        isCompact ? 'Fichier selectionne' : _imagePath ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
                if (_rawText.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Texte detecte',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    child: Text(_rawText),
                  ),
                ],
                const SizedBox(height: 20),
                if (_type == CardType.cni) _buildCniForm(),
                if (_type == CardType.chifa) _buildChifaForm(),
                if (_type == CardType.ccp) _buildCcpForm(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _save,
                    child: const Text('Enregistrer dans Supabase'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          if (_loading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCniForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field('Numero de la carte', _cniNumero),
        _field('Date de delivrance', _cniDateDelivrance),
        _field('Lieu de delivrance', _cniLieuDelivrance),
        _field('Date d\'expiration', _cniDateExpiration),
        _field('Nom et prenoms (latin)', _cniNomPrenom),
        _field('Nom (arabe)', _cniNomAr),
        _field('Prenom (arabe)', _cniPrenomAr),
        _field('Nom (verso)', _cniNomVerso),
        _field('Prenom (verso)', _cniPrenomVerso),
        _field('Sexe', _cniSexe),
        _field('Date de naissance', _cniDateNaissance),
        _field('Lieu de naissance', _cniLieuNaissance),
        _field('Date et lieu de naissance (brut)', _cniDateLieuNaissance),
        _field('RH', _cniRh),
        _field('NIN', _cniNin),
      ],
    );
  }

  Widget _buildChifaForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field('Numero d\'immatriculation', _chifaImmatriculation),
        _field('Nom et prenom', _chifaNomPrenom),
        _field('Date de naissance', _chifaDateNaissance),
        _field('Type de carte', _chifaTypeCarte),
        _field('Numero de serie', _chifaNumeroSerie),
      ],
    );
  }

  Widget _buildCcpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field('Nom et prenom', _ccpNomPrenom),
        _field('Compte CCP', _ccpCompte),
        _field('Cle CCP', _ccpCle),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
