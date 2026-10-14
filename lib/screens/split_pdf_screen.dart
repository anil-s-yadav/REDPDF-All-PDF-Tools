import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:redpdf_tools/theme/app_theme.dart';
import 'package:redpdf_tools/utils/file_utils.dart';
import 'package:pdf_manipulator/pdf_manipulator.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:redpdf_tools/models/pdf_history.dart';
import 'package:redpdf_tools/providers/pdf_provider.dart';
import 'processing_screen.dart';
import 'pdf_view_screen.dart'; // Added to view the PDF
import '../widgets/pdf_file_thumbnail.dart';

class SplitPdfScreen extends StatefulWidget {
  const SplitPdfScreen({super.key});

  @override
  State<SplitPdfScreen> createState() => _SplitPdfScreenState();
}

class _SplitPdfScreenState extends State<SplitPdfScreen> {
  File? _selectedPdf;
  int _pageCount = 0;
  bool _isLoading = false;
  final TextEditingController _rangesController = TextEditingController();

  @override
  void dispose() {
    _rangesController.dispose();
    super.dispose();
  }

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
        final documentBytes = await file.readAsBytes();
        final document = PdfDocument(inputBytes: documentBytes);
        final count = document.pages.count;
        document.dispose();

        setState(() {
          _selectedPdf = file;
          _pageCount = count;
          _rangesController.text = '1-$count';
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

  void _openPdfPreview() {
    if (_selectedPdf == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewScreen(
          path: _selectedPdf!.path,
          title: p.basename(_selectedPdf!.path),
        ),
      ),
    );
  }

  Future<void> _startSplitting() async {
    final text = _rangesController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter split ranges')),
      );
      return;
    }

    // Basic validation of format: 1-2, 3-4, 5
    final parts = text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProcessingScreen(
          title: 'Splitting PDF...',
          task: () async {
            final paths = await PdfManipulator().splitPDF(
              params: PDFSplitterParams(
                pdfPath: _selectedPdf!.path,
                pageRanges: parts,
              ),
            );
            if (paths == null || paths.isEmpty) throw Exception('Split failed');

            if (paths.length == 1) {
              // Only 1 file created, return it directly
              final outPath = paths.first;
              final file = File(outPath);
              final newPath = p.join(
                file.parent.path,
                '${FileUtils.generateDefaultFileName(prefix: 'Split')}.pdf',
              );
              final renamedFile = await file.rename(newPath);
              final fileSize = await renamedFile.length();

              final history = PdfHistory(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: p.basename(renamedFile.path),
                path: renamedFile.path,
                sizeInBytes: fileSize,
                createdAt: DateTime.now(),
              );
              if (mounted) {
                context.read<PdfProvider>().addHistory(history);
              }

              return ProcessResult(
                operation: 'Split PDF',
                filePath: renamedFile.path,
                fileName: p.basename(renamedFile.path),
                fileSize: fileSize,
                totalPages: 0,
              );
            } else {
              // Multiple files created, zip them!
              final tempDir = await getTemporaryDirectory();
              final outZipPath = p.join(
                tempDir.path,
                '${FileUtils.generateDefaultFileName(prefix: 'Split_Archive')}.zip',
              );

              final archive = Archive();
              for (int i = 0; i < paths.length; i++) {
                final file = File(paths[i]);
                final bytes = await file.readAsBytes();
                // Naming them Part_1.pdf, Part_2.pdf...
                final archiveFile = ArchiveFile(
                  'Part_${i + 1}.pdf',
                  bytes.length,
                  bytes,
                );
                archive.addFile(archiveFile);
              }

              final encoder = ZipEncoder();
              final zipFile = File(outZipPath);
              await zipFile.writeAsBytes(encoder.encode(archive));
              final zipFileSize = await zipFile.length();

              final history = PdfHistory(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: p.basename(zipFile.path),
                path: zipFile.path,
                sizeInBytes: zipFileSize,
                createdAt: DateTime.now(),
              );
              if (mounted) {
                context.read<PdfProvider>().addHistory(history);
              }

              return ProcessResult(
                operation: 'Split PDF (Zipped)',
                filePath: zipFile.path,
                fileName: p.basename(zipFile.path),
                fileSize: zipFileSize,
                totalPages: 0,
              );
            }
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
          'Split PDF',
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
                            color: Colors.amber.shade700.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade700.withValues(
                                  alpha: 0.1,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.call_split_rounded,
                                size: 40,
                                color: Colors.amber.shade700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Select PDF to Split',
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
                    child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: _openPdfPreview,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: appColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: appColors.divider ?? Colors.transparent,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 60,
                                  height: 80,
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
                                        '$_pageCount pages',
                                        style: TextStyle(
                                          color: appColors.subtitle,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
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
                                const Icon(
                                  Icons.remove_red_eye_outlined,
                                  color: Colors.blueAccent,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Enter Page Ranges',
                          style: TextStyle(
                            color: appColors.text,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You can enter multiple pairs Ex. 1-5, 6-11, 12-20',
                          style: TextStyle(
                            // color: appColors.text,
                            // fontWeight: FontWeight.bold,
                            // fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _rangesController,
                          style: TextStyle(color: appColors.text),
                          decoration: InputDecoration(
                            hintText: 'e.g., 1-5, 6-10',
                            hintStyle: TextStyle(
                              color: appColors.subtitle?.withValues(alpha: 0.5),
                            ),
                            filled: true,
                            fillColor: appColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: appColors.divider ?? Colors.transparent,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: appColors.divider ?? Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                if (_pageCount > 1) {
                                  final half = _pageCount ~/ 2;
                                  _rangesController.text =
                                      '1-$half, ${half + 1}-$_pageCount';
                                }
                              },
                              icon: const Icon(Icons.vertical_split, size: 18),
                              label: const Text('Split in half'),
                              style: TextButton.styleFrom(
                                backgroundColor: appColors.primary?.withValues(
                                  alpha: 0.1,
                                ),
                                foregroundColor: appColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                if (_pageCount > 0) {
                                  _rangesController.text = List.generate(
                                    _pageCount,
                                    (i) => '${i + 1}-${i + 1}',
                                  ).join(', ');
                                }
                              },
                              icon: const Icon(Icons.view_array, size: 18),
                              label: const Text('Split every page'),
                              style: TextButton.styleFrom(
                                backgroundColor: appColors.primary?.withValues(
                                  alpha: 0.1,
                                ),
                                foregroundColor: appColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
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
                          onPressed: _startSplitting,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Split PDF',
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
