import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/scan_state.dart';
import 'scan_controller.dart';

/// Guided capture: live camera preview + coverage checklist + per-target
/// instructions. On completion, asks for dimensions (until the AR measure
/// module lands, manual entry) and project details, then submits.
class ScanFlowScreen extends ConsumerStatefulWidget {
  const ScanFlowScreen({super.key});

  @override
  ConsumerState<ScanFlowScreen> createState() => _ScanFlowScreenState();
}

class _ScanFlowScreenState extends ConsumerState<ScanFlowScreen> {
  CameraController? _camera;
  String? _cameraError;

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
          orElse: () => cameras.first);
      final controller =
          CameraController(back, ResolutionPreset.high, enableAudio: false);
      await controller.initialize();
      if (mounted) setState(() => _camera = controller);
    } catch (e) {
      if (mounted) setState(() => _cameraError = 'Camera unavailable: $e');
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final cam = _camera;
    if (cam == null || cam.value.isTakingPicture) return;
    final file = await cam.takePicture();
    ref.read(scanControllerProvider.notifier).addShot(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(scanControllerProvider);

    if (session.isComplete) return const _FinishScanView();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(session.currentTarget.label),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: session.progress, minHeight: 4),
          Expanded(
            child: _cameraError != null
                ? Center(
                    child: Text(_cameraError!,
                        style: const TextStyle(color: Colors.white)))
                : _camera == null
                    ? const Center(child: CircularProgressIndicator())
                    : CameraPreview(_camera!),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            color: Colors.black,
            child: Column(
              children: [
                Text(
                  session.currentTarget.instruction,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                const Text('Move slowly · keep the phone level',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: session.shots.isEmpty
                          ? null
                          : () => ref
                              .read(scanControllerProvider.notifier)
                              .retakeLast(),
                      icon: const Icon(Icons.undo, color: Colors.white),
                      tooltip: 'Retake last',
                    ),
                    GestureDetector(
                      onTap: _capture,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 30),
                      ),
                    ),
                    IconButton(
                      onPressed: (session.currentTarget == ScanTarget.windows ||
                              session.currentTarget == ScanTarget.doors)
                          ? () => ref
                              .read(scanControllerProvider.notifier)
                              .skipCurrent()
                          : null,
                      icon: const Icon(Icons.skip_next, color: Colors.white),
                      tooltip: 'Skip (no windows/doors)',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dimensions + project naming + submit.
class _FinishScanView extends ConsumerStatefulWidget {
  const _FinishScanView();

  @override
  ConsumerState<_FinishScanView> createState() => _FinishScanViewState();
}

class _FinishScanViewState extends ConsumerState<_FinishScanView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController(text: 'My room');
  final _length = TextEditingController();
  final _width = TextEditingController();
  final _height = TextEditingController(text: '2.4');
  String _roomType = 'bedroom';
  bool _useAiDims = false;

  @override
  void dispose() {
    _name.dispose();
    _length.dispose();
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submit = ref.watch(scanSubmitProvider);

    ref.listen(scanSubmitProvider, (_, next) {
      final projectId = next.valueOrNull;
      if (projectId != null) {
        context.go('/project/$projectId');
      } else if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.error.toString())));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Finish scan')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Scan complete ✓',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text(
                'Add measured dimensions for the most accurate analysis. '
                'AR tap-to-measure arrives in the next update; for now enter '
                'tape-measure values or let AI estimate from photos.'),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Project name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _roomType,
              decoration: const InputDecoration(labelText: 'Room type'),
              items: AppConstants.roomTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _roomType = v ?? 'bedroom'),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Let AI estimate dimensions'),
              subtitle: const Text('Less accurate than measuring'),
              value: _useAiDims,
              onChanged: (v) => setState(() => _useAiDims = v),
            ),
            if (!_useAiDims) ...[
              Row(
                children: [
                  Expanded(child: _dimField(_length, 'Length (m)')),
                  const SizedBox(width: 8),
                  Expanded(child: _dimField(_width, 'Width (m)')),
                  const SizedBox(width: 8),
                  Expanded(child: _dimField(_height, 'Height (m)')),
                ],
              ),
            ],
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: submit.isLoading ? null : _submit,
              icon: submit.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: Text(
                  submit.isLoading ? 'Analyzing photos…' : 'Build room model'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dimField(TextEditingController c, String label) => TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (v) {
          if (_useAiDims) return null;
          final d = double.tryParse(v ?? '');
          return (d == null || d <= 0 || d > 30) ? 'Invalid' : null;
        },
      );

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_useAiDims) {
      ref.read(scanControllerProvider.notifier).setDimensions(
            double.parse(_length.text),
            double.parse(_width.text),
            double.parse(_height.text),
          );
    }
    ref
        .read(scanSubmitProvider.notifier)
        .submit(projectName: _name.text.trim(), roomType: _roomType);
  }
}
