import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

enum CniCaptureSide { recto, verso }

class CniCameraPage extends StatefulWidget {
  const CniCameraPage({super.key, required this.side});

  final CniCaptureSide side;

  @override
  State<CniCameraPage> createState() => _CniCameraPageState();
}

class _CniCameraPageState extends State<CniCameraPage> {
  CameraController? _controller;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Camera init failed: $e';
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_controller == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await _controller!.takePicture();
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/cni_${widget.side.name}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(file.path).copy(path);
      if (!mounted) return;
      Navigator.of(context).pop(path);
    } catch (e) {
      setState(() => _error = 'Capture failed: $e');
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Camera CNI')),
        body: Center(child: Text(_error!)),
      );
    }
    final controller = _controller!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.side == CniCaptureSide.recto
              ? 'Scanner CNI - Recto'
              : 'Scanner CNI - Verso',
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(controller)),
          Positioned.fill(
            child: CustomPaint(
              painter: _CniOverlayPainter(side: widget.side),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              children: [
                if (widget.side == CniCaptureSide.recto)
                  const Text(
                    'Aligne la carte dans le cadre. Assure une bonne lumiere.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  )
                else
                  const Text(
                    'Aligne le verso dans le cadre (MRZ en bas).',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _capturing ? null : _capture,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Capturer'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CniOverlayPainter extends CustomPainter {
  _CniOverlayPainter({required this.side});

  final CniCaptureSide side;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.86,
      height: size.height * 0.55,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      paint,
    );

    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    if (side == CniCaptureSide.recto) {
      final rows = 8;
      for (var i = 1; i < rows; i++) {
        final y = rect.top + (rect.height / rows) * i;
        canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), guidePaint);
      }
    } else {
      final mrzHeight = rect.height * 0.25;
      final mrzTop = rect.bottom - mrzHeight;
      canvas.drawRect(
        Rect.fromLTWH(rect.left, mrzTop, rect.width, mrzHeight),
        guidePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
