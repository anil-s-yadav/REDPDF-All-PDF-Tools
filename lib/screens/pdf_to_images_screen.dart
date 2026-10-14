import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:redpdf_tools/theme/app_theme.dart';
import 'package:redpdf_tools/utils/file_utils.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:provider/provider.dart';
import 'package:redpdf_tools/models/pdf_history.dart';
import 'package:redpdf_tools/providers/pdf_provider.dart';
import 'processing_screen.dart';
import 'pdf_view_screen.dart';
import '../widgets/pdf_file_thumbnail.dart';

class PdfToImagesScreen extends StatefulWidget {
  const PdfToImagesScreen({super.key});

  @override
  State<PdfToImagesScreen> createState() => _PdfToImagesScreenState();
}

class _PdfToImagesScreenState extends State<PdfToImagesScreen> {
  File? _selectedPdf;
  int _pageCount = 0;
  bool _isLoading = false;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _isLoading = true;
      });
      final file = File(result.files.single.path!);
      try {
        final doc = await pdfx.PdfDocument.openFile(file.path);
        final count = doc.pagesCount;
        await doc.close();
        setState(() {
          _selectedPdf = file;
          _pageCount = count;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Cannot read this PDF. It may be encrypted or corrupted.',
              ),
            ),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _extractImages() async {
    final tempDir = await getTemporaryDirectory();
    final outZipPath = p.join(
      tempDir.path,
      '${FileUtils.generateDefaultFileName(prefix: 'ExtractedImages')}.zip',
    );

    final doc = await pdfx.PdfDocument.openFile(_selectedPdf!.path);
    final archive = Archive();
    final baseName = p.basenameWithoutExtension(_selectedPdf!.path);

    for (int i = 1; i <= doc.pagesCount; i++) {
      final page = await doc.getPage(i);
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: pdfx.PdfPageImageFormat.jpeg,
      );
      if (pageImage != null) {
        final fileName = '${baseName}_page_$i.jpg';
        final archiveFile = ArchiveFile(
          fileName,
          pageImage.bytes.length,
          pageImage.bytes,
        );
        archive.addFile(archiveFile);
      }
      await page.close();
    }
    await doc.close();

    final encoder = ZipEncoder();
    final zipFile = File(outZipPath);
    await zipFile.writeAsBytes(encoder.encode(archive));

    return outZipPath;
  }

  Future<void> _startConversion() async {
    if (_selectedPdf == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProcessingScreen(
          title: 'Extracting Images...',
          task: () async {
            final outPath = await _extractImages();
            if (outPath == null) throw Exception('Extraction failed');
            final file = File(outPath);
            final fileSize = await file.length();

            final history = PdfHistory(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: p.basename(outPath),
              path: outPath,
              sizeInBytes: fileSize,
              createdAt: DateTime.now(),
            );
            if (mounted) {
              context.read<PdfProvider>().addHistory(history);
            }

            return ProcessResult(
              operation: 'PDF to Images',
              filePath: outPath,
              fileName: p.basename(outPath),
              fileSize: fileSize,
              totalPages: _pageCount,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        title: Text(
          'PDF to Images',
          style: TextStyle(color: appColors.text, fontWeight: FontWeight.bold),
        ),
        backgroundColor: appColors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: appColors.text),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedPdf == null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GestureDetector(
                      onTap: _pickPdf,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 36,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: appColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.deepPurpleAccent.withValues(
                              alpha: 0.3,
                            ),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.deepPurpleAccent.withValues(
                                  alpha: 0.1,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.image_outlined,
                                size: 40,
                                color: Colors.deepPurpleAccent,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Select PDF to Convert',
                              style: TextStyle(
                                color: appColors.text,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap to browse files from device',
                              style: TextStyle(
                                color: appColors.subtitle,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.deepPurpleAccent.withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.compare_arrows,
                              size: 64,
                              color: Colors.deepPurpleAccent,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'Ready to convert',
                            style: TextStyle(
                              color: appColors.text,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PdfViewScreen(
                                    path: _selectedPdf!.path,
                                    title: p.basename(_selectedPdf!.path),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: appColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: appColors.primary ?? Colors.blue,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (appColors.primary ?? Colors.blue)
                                        .withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 45,
                                    height: 60,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: PdfFileThumbnail(
                                        file: _selectedPdf!,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.basename(_selectedPdf!.path),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: appColors.text,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$_pageCount pages to extract as JPGs',
                                          style: TextStyle(
                                            color: appColors.subtitle,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Tap to preview PDF',
                                          style: TextStyle(
                                            color: Colors.blueAccent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Images will be saved as a ZIP file.',
                            style: TextStyle(color: appColors.subtitle),
                          ),
                        ],
                      ),
                    ),
                  ),
            if (_selectedPdf != null)
              Container(
                padding: const EdgeInsets.all(24),
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
                child: SafeArea(
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: TextButton.icon(
                          onPressed: _pickPdf,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Change PDF'),
                          style: TextButton.styleFrom(
                            backgroundColor: appColors.primary?.withValues(
                              alpha: 0.1,
                            ),
                            foregroundColor: appColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _startConversion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurpleAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Convert to Images',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
