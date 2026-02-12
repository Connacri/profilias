import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;

import 'cni_camera_page.dart';
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
      if (_type == CardType.cni &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        final resultPath = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => CniCameraPage(
              side: _cniSide == CniSide.recto
                  ? CniCaptureSide.recto
                  : CniCaptureSide.verso,
            ),
          ),
        );
        if (resultPath != null) {
          file = XFile(resultPath);
        }
      } else if (defaultTargetPlatform == TargetPlatform.android ||
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

  Future<void> _loadAssetAndRun(String assetPath) async {
    setState(() {
      _error = null;
      _rawText = '';
    });
    try {
      final bytes = await rootBundle.load(assetPath);
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'asset_${DateTime.now().millisecondsSinceEpoch}_${assetPath.split('/').last}';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      setState(() {
        _imagePath = file.path;
        if (_type == CardType.cni) {
          if (_cniSide == CniSide.recto) {
            _cniRectoPath = file.path;
          } else {
            _cniVersoPath = file.path;
          }
        }
      });
      await _runOcr(file.path);
    } catch (e) {
      setState(() => _error = 'Test OCR impossible: $e');
    }
  }

  Future<void> _runOcr(String path) async {
    setState(() => _loading = true);
    try {
      if (_type == CardType.cni && _cniSide == CniSide.recto) {
        final tesseractText = await _runTesseract(path);
        if (tesseractText.trim().isNotEmpty) {
          setState(() => _rawText = tesseractText);
          _cniRectoText = tesseractText;
          _applyHeuristicsText(tesseractText, _splitLines(tesseractText));
        } else {
          await _runMlKit(path);
        }
      } else {
        await _runMlKit(path);
      }
    } catch (e) {
      setState(() => _error = 'OCR impossible: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _runMlKit(String path) async {
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
    _applyHeuristicsText(text, _extractOrderedLines(result));
  }

  Future<String> _runTesseract(String path) async {
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return '';
    }
    final processedPath = await _preprocessForOcr(path);
    return FlutterTesseractOcr.extractText(
      processedPath ?? path,
      language: 'ara+fra',
      args: {'preserve_interword_spaces': '1'},
    );
  }

  void _rerunOcr() {
    final path = _imagePath;
    if (path == null || path.isEmpty) return;
    _runOcr(path);
  }

  List<String> _splitLines(String text) {
    return text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  Future<String?> _preprocessForOcr(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;
      final grayscale = img.grayscale(image);
      final contrasted = img.adjustColor(
        grayscale,
        contrast: 1.2,
        gamma: 0.9,
      );
      final thresholded = _thresholdImage(contrasted, 150);
      final tempDir = await getTemporaryDirectory();
      final outPath =
          '${tempDir.path}/ocr_${DateTime.now().millisecondsSinceEpoch}.png';
      final outFile = File(outPath);
      await outFile.writeAsBytes(img.encodePng(thresholded));
      return outPath;
    } catch (_) {
      return null;
    }
  }

  img.Image _thresholdImage(img.Image src, int threshold) {
    final out = img.Image.from(src);
    for (var y = 0; y < out.height; y++) {
      for (var x = 0; x < out.width; x++) {
        final pixel = out.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final lum = (0.299 * r + 0.587 * g + 0.114 * b).round();
        final v = lum >= threshold ? 255 : 0;
        out.setPixelRgba(x, y, v, v, v, 255);
      }
    }
    return out;
  }

  void _applyHeuristicsText(String text, List<String> lines) {
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
    String findAfterArabicLabel(String label) {
      for (final line in lines) {
        if (line.contains(label)) {
          final index = lines.indexOf(line);
          if (index + 1 < lines.length) {
            return lines[index + 1];
          }
        }
      }
      return '';
    }
    String findSameLineValue(String label) {
      for (final line in lines) {
        if (line.toLowerCase().contains(label.toLowerCase())) {
          return line;
        }
      }
      return '';
    }

    if (_type == CardType.cni) {
      if (_cniSide == CniSide.recto) {
        final dateMatches = _findAllDates(text);
        final cniNumberMatch = RegExp(r'\b\d{8,12}\b').firstMatch(text);
        if (cniNumberMatch != null && _cniNumero.text.isEmpty) {
          _cniNumero.text = cniNumberMatch.group(0) ?? '';
        }
        final issueLine = findSameLineValue('تاريخ الإصدار');
        if (_cniDateDelivrance.text.isEmpty) {
          _cniDateDelivrance.text = _formatDateString(
                _extractFirstDate(issueLine) ??
                    (dateMatches.isNotEmpty ? dateMatches.first : ''),
              ) ??
              _cleanValue(issueLine);
        }
        final expiryLine = findSameLineValue('تاريخ الانتهاء');
        if (_cniDateExpiration.text.isEmpty) {
          _cniDateExpiration.text = _formatDateString(
                _extractFirstDate(expiryLine) ??
                    (dateMatches.length > 1 ? dateMatches[1] : ''),
              ) ??
              _cleanValue(expiryLine);
        }
        final issuePlaceLine = findSameLineValue('سلطة الإصدار');
        if (_cniLieuDelivrance.text.isEmpty) {
          _cniLieuDelivrance.text = _cleanValue(issuePlaceLine, keepCase: true);
        }
        final ninMatch = RegExp(r'\b\d{18}\b').firstMatch(text);
        if (ninMatch != null && _cniNin.text.isEmpty) {
          _cniNin.text = ninMatch.group(0) ?? '';
        }
        if (_cniNomAr.text.isEmpty) {
          final nomAr = findSameLineValue('اللقب');
          _cniNomAr.text = _stripArabicLabel(nomAr, 'اللقب');
        }
        if (_cniPrenomAr.text.isEmpty) {
          final prenomAr = findSameLineValue('الاسم');
          _cniPrenomAr.text = _stripArabicLabel(prenomAr, 'الاسم');
        }
        if (_cniDateNaissance.text.isEmpty) {
          final dobLine = findSameLineValue('تاريخ الميلاد');
          _cniDateNaissance.text = _formatDateString(
                _extractFirstDate(dobLine) ??
                    (dateMatches.length > 2 ? dateMatches[2] : ''),
              ) ??
              _cleanValue(dobLine);
        }
        if (_cniLieuNaissance.text.isEmpty) {
          final pobLine = findSameLineValue('مكان الميلاد');
          _cniLieuNaissance.text = _cleanValue(pobLine, keepCase: true);
        }
        if (_cniSexe.text.isEmpty) {
          final sexLine = findSameLineValue('الجنس');
          _cniSexe.text = _cleanValue(sexLine);
        }
        if (_cniRh.text.isEmpty) {
          final rhLine = findSameLineValue('Rh');
          _cniRh.text = _cleanValue(rhLine, keepCase: true);
        }
        if (_cniDateLieuNaissance.text.isEmpty) {
          _cniDateLieuNaissance.text = findAfterArabicLabel('تاريخ الميلاد');
        }
      } else {
        final mrzLines =
            lines.where((l) => l.startsWith('ID') || l.contains('<<<')).toList();
        if (mrzLines.length >= 3) {
          final line1 = mrzLines[0];
          final line2 = mrzLines[1];
          final line3 = mrzLines[2];
          final mrzNumber = RegExp(r'ID[A-Z]{3}(\d{8,12})')
              .firstMatch(line1)
              ?.group(1);
          if (mrzNumber != null && _cniNumero.text.isEmpty) {
            _cniNumero.text = mrzNumber;
          }
          final dobMatch = RegExp(r'\d{6}').firstMatch(line2)?.group(0);
          if (dobMatch != null && _cniDateNaissance.text.isEmpty) {
            _cniDateNaissance.text = _formatDateString(
                  _mrzDateToString(dobMatch),
                ) ??
                _mrzDateToString(dobMatch);
          }
          final expMatch = RegExp(r'\d{6}[A-Z]\d{6}')
              .firstMatch(line2)
              ?.group(0);
          if (expMatch != null && _cniDateExpiration.text.isEmpty) {
            final exp = expMatch.substring(7, 13);
            _cniDateExpiration.text = _formatDateString(
                  _mrzDateToString(exp),
                ) ??
                _mrzDateToString(exp);
          }
          final names = line3.split('<<');
          if (names.isNotEmpty && _cniNomVerso.text.isEmpty) {
            _cniNomVerso.text = _formatLatinNameUpper(names.first);
          }
          if (names.length > 1 && _cniPrenomVerso.text.isEmpty) {
            final prenoms = names.sublist(1).join(' ');
            _cniPrenomVerso.text = _formatLatinNameCapitalized(prenoms);
          }
        } else {
          final nomLine = lines.firstWhere(
            (l) => l.toLowerCase().contains('nom'),
            orElse: () => '',
          );
          final prenomLine = lines.firstWhere(
            (l) =>
                l.toLowerCase().contains('prénom') ||
                l.toLowerCase().contains('prenom'),
            orElse: () => '',
          );
          if (nomLine.isNotEmpty && _cniNomVerso.text.isEmpty) {
            _cniNomVerso.text = _formatLatinNameUpper(nomLine);
          } else {
            final candidates = lines.where((line) => line.isNotEmpty).toList();
            if (candidates.isNotEmpty && _cniNomVerso.text.isEmpty) {
              _cniNomVerso.text = _formatLatinNameUpper(
                _cleanValue(candidates[0]),
              );
            }
          }
          if (prenomLine.isNotEmpty && _cniPrenomVerso.text.isEmpty) {
            _cniPrenomVerso.text = _formatLatinNameCapitalized(prenomLine);
          } else {
            final candidates = lines.where((line) => line.isNotEmpty).toList();
            if (candidates.length > 1 && _cniPrenomVerso.text.isEmpty) {
              _cniPrenomVerso.text = _formatLatinNameCapitalized(
                _cleanValue(candidates[1]),
              );
            }
          }
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
    final parts = trimmed.split(RegExp(r'[-/.]'));
    if (parts.length != 3) {
      return null;
    }
    int? year;
    int? month;
    int? day;
    if (parts[0].length == 4) {
      year = int.tryParse(parts[0]);
      month = int.tryParse(parts[1]);
      day = int.tryParse(parts[2]);
    } else {
      day = int.tryParse(parts[0]);
      month = int.tryParse(parts[1]);
      year = int.tryParse(parts[2]);
    }
    if (day == null || month == null || year == null) {
      return null;
    }
    return DateTime(year, month, day);
  }

  String? _formatDateString(String value) {
    final parsed = _parseDate(value);
    if (parsed == null) return null;
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  String _cleanValue(String value, {bool keepCase = false}) {
    var cleaned = value.replaceAll(
      RegExp(r'\bnom\b\s*:?', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\bprenom\b\s*:?', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\bnom et prenom\b\s*:?', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\bsexe\b\s*:?', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\bgenre\b\s*:?', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\brh\b\s*:?', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll('تاريخ الميلاد:', '');
    cleaned = cleaned.replaceAll('مكان الميلاد:', '');
    cleaned = cleaned.replaceAll('الجنس:', '');
    cleaned = cleaned.replaceAll('اللقب:', '');
    cleaned = cleaned.replaceAll('الاسم:', '');
    cleaned = cleaned.replaceAll('رقم التعريف الوطني:', '');
    cleaned = cleaned.replaceAll('سلطة الإصدار:', '');
    cleaned = cleaned.replaceAll('تاريخ الإصدار:', '');
    cleaned = cleaned.replaceAll('تاريخ الانتهاء:', '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return keepCase ? cleaned : cleaned.toLowerCase();
  }

  String _stripArabicLabel(String line, String label) {
    if (line.contains(label)) {
      return line.replaceAll(label, '').replaceAll(':', '').trim();
    }
    return line.trim();
  }

  String _mrzDateToString(String yymmdd) {
    if (yymmdd.length != 6) return yymmdd;
    final year = int.tryParse(yymmdd.substring(0, 2));
    final month = yymmdd.substring(2, 4);
    final day = yymmdd.substring(4, 6);
    if (year == null) return yymmdd;
    final fullYear = year >= 50 ? 1900 + year : 2000 + year;
    return '$day/$month/$fullYear';
  }

  String _formatLatinNameUpper(String value) {
    final cleaned = _cleanValue(value);
    return cleaned.toUpperCase();
  }

  String _formatLatinNameCapitalized(String value) {
    final cleaned = _cleanValue(value);
    return cleaned
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) =>
            part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
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
        try {
          await _client.storage.from('cartes').uploadBinary(
                storagePath,
                bytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg'),
              );
          publicUrl = _client.storage.from('cartes').getPublicUrl(storagePath);
        } catch (e) {
          _error = 'Upload storage impossible: $e';
        }
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
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _rerunOcr,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Relancer OCR'),
                    ),
                    if (_type == CardType.cni)
                      OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _loadAssetAndRun(
                                  'assets/image-1770802397842.jpg',
                                ),
                        icon: const Icon(Icons.image),
                        label: const Text('Test CNI 1'),
                      ),
                    if (_type == CardType.cni)
                      OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _loadAssetAndRun(
                                  'assets/image-1770802406616.jpg',
                                ),
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Test CNI 2'),
                      ),
                    if (_imagePath != null)
                      Text(
                        isCompact ? 'Fichier selectionne' : _imagePath ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
                if (_imagePath != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_imagePath!),
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
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
