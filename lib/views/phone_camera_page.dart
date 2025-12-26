import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PhoneCameraPage extends StatefulWidget {
  const PhoneCameraPage({super.key});

  @override
  State<PhoneCameraPage> createState() => _PhoneCameraPageState();
}

class _PhoneCameraPageState extends State<PhoneCameraPage> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  bool _loading = true;
  String? _error;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Web: permission gérée par le navigateur, permission_handler n’est pas nécessaire
      if (!kIsWeb) {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          setState(() {
            _error = "Permission caméra refusée.";
            _loading = false;
          });
          return;
        }
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _error = "Aucune caméra détectée sur cet appareil.";
          _loading = false;
        });
        return;
      }

      await _startCamera(_selectedIndex);
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = "Erreur caméra: $e";
        _loading = false;
      });
    }
  }

  Future<void> _startCamera(int index) async {
    // Stop ancienne caméra
    final old = _controller;
    _controller = null;
    await old?.dispose();

    final cam = _cameras[index];
    final controller = CameraController(
      cam,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    _controller = controller;

    await controller.initialize();
    if (!mounted) return;

    setState(() {});
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _selectedIndex = (_selectedIndex + 1) % _cameras.length;
    setState(() => _loading = true);
    try {
      await _startCamera(_selectedIndex);
    } catch (e) {
      setState(() => _error = "Erreur switch caméra: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Caméra du téléphone"),
        actions: [
          IconButton(
            tooltip: "Rafraîchir",
            onPressed: _init,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: "Changer caméra",
            onPressed: _switchCamera,
            icon: const Icon(Icons.cameraswitch),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _init)
              : (ctrl == null || !ctrl.value.isInitialized)
                  ? _ErrorView(message: "Caméra non initialisée.", onRetry: _init)
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: CameraPreview(ctrl),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 18,
                          child: _BottomBar(
                            onShot: () async {
                              try {
                                // Sur Web, takePicture marche selon browser/camera_web
                                final file = await ctrl.takePicture();
                                if (!mounted) return;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(kIsWeb
                                        ? "Photo capturée (web)."
                                        : "Photo capturée: ${file.path}"),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Erreur capture: $e")),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onShot});

  final VoidCallback onShot;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: onShot,
          icon: const Icon(Icons.camera_alt),
          label: const Text("Capturer"),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text("Réessayer"),
            ),
          ],
        ),
      ),
    );
  }
}
