import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:redpdf_tools/theme/app_theme.dart';
import 'export_settings_screen.dart';

class ScanDocumentScreen extends StatefulWidget {
  const ScanDocumentScreen({super.key});

  @override
  State<ScanDocumentScreen> createState() => _ScanDocumentScreenState();
}

class _ScanDocumentScreenState extends State<ScanDocumentScreen> {
  final List<File> _scannedImages = [];
  bool _isScanning = false;
  DocumentScanner? _documentScanner;

  static const Color _accentColor = Color(0xFF0284C7);

  @override
  void initState() {
    super.initState();
    _documentScanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: const {DocumentFormat.jpeg, DocumentFormat.pdf},
        mode: ScannerMode.full,
        isGalleryImport: true,
        pageLimit: 100,
      ),
    );
  }

  @override
  void dispose() {
    _documentScanner?.close();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);

    try {
      final result = await _documentScanner!.scanDocument();
      if (result.images != null && result.images!.isNotEmpty) {
        final newFiles = result.images!
            .map((path) => File(path))
            .where((f) => f.existsSync())
            .toList();

        if (newFiles.isNotEmpty && mounted) {
          setState(() {
            _scannedImages.addAll(newFiles);
          });
        }
      }
    } catch (e) {
      debugPrint("Document scanning error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Document scanner error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _cropImage(int index) async {
    final appColors = Theme.of(context).appColors;
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: _scannedImages[index].path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Page',
            toolbarColor: appColors.primary ?? Colors.red,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Page',
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
        ],
      );

      if (croppedFile != null && mounted) {
        setState(() {
          _scannedImages[index] = File(croppedFile.path);
        });
      }
    } catch (e) {
      debugPrint("Error cropping image: $e");
    }
  }

  void _removeImage(int index) {
    setState(() {
      _scannedImages.removeAt(index);
    });
  }

  void _continueToExport() {
    if (_scannedImages.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExportSettingsScreen(
          images: _scannedImages,
          defaultFileNamePrefix: 'ScannedDoc',
          operationName: 'Document Scanned',
        ),
      ),
    );
  }

  Widget _buildTopScanCard(AppColors appColors) {
    return GestureDetector(
      onTap: _isScanning ? null : _startScan,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: appColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _accentColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: _isScanning
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: _accentColor,
                      ),
                    )
                  : const Icon(
                      Icons.document_scanner_rounded,
                      size: 40,
                      color: _accentColor,
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              _isScanning ? 'Opening Scanner...' : 'Scan Documents',
              style: TextStyle(
                color: appColors.text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isScanning
                  ? 'Please wait while camera loads...'
                  : 'Tap to scan papers with auto-edge detection & AI cleanup',
              textAlign: TextAlign.center,
              style: TextStyle(color: appColors.subtitle, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).appColors;

    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        backgroundColor: appColors.background,
        elevation: 0,
        title: Text(
          'Scan Documents',
          style: TextStyle(color: appColors.text, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: appColors.text),
        actions: [
          if (_scannedImages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.document_scanner_rounded),
              tooltip: 'Scan More Pages',
              onPressed: _isScanning ? null : _startScan,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_scannedImages.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                child: _buildTopScanCard(appColors),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Scanned Pages (${_scannedImages.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: appColors.text,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _isScanning ? null : _startScan,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Scan More'),
                          style: TextButton.styleFrom(
                            foregroundColor: _accentColor,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.touch_app_rounded,
                                size: 12,
                                color: _accentColor,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'HOLD TO REORDER',
                                style: TextStyle(
                                  color: _accentColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: ReorderableGridView.builder(
                    itemCount: _scannedImages.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.75, // Document aspect ratio
                        ),
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        final element = _scannedImages.removeAt(oldIndex);
                        _scannedImages.insert(newIndex, element);
                      });
                    },
                    itemBuilder: (context, index) {
                      return Container(
                        key: ValueKey(_scannedImages[index].path),
                        decoration: BoxDecoration(
                          color: appColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                appColors.divider ??
                                Colors.grey.withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: () => _cropImage(index),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Image.file(
                                    _scannedImages[index],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            // Page badge
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Page ${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            // Crop action button
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: GestureDetector(
                                onTap: () => _cropImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.crop,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                            // Delete page button
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Bottom Export Bar
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: appColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _continueToExport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.picture_as_pdf_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Export ${_scannedImages.length} ${_scannedImages.length == 1 ? "Page" : "Pages"} to PDF',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
