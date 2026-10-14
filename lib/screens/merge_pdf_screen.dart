import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:redpdf_tools/theme/app_theme.dart';
import 'package:redpdf_tools/utils/file_utils.dart';
import 'package:pdf_manipulator/pdf_manipulator.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:redpdf_tools/models/pdf_history.dart';
import 'package:redpdf_tools/providers/pdf_provider.dart';
import 'processing_screen.dart';
import 'pdf_view_screen.dart';
import '../widgets/pdf_file_thumbnail.dart';

class MergePdfScreen extends StatefulWidget {
  const MergePdfScreen({super.key});

  @override
  State<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _SelectedPdf {
  final String id;
  final File file;
  _SelectedPdf({required this.file}) : id = UniqueKey().toString();
}

class _MergePdfScreenState extends State<MergePdfScreen> {
  final List<_SelectedPdf> _selectedPdfs = [];

  Future<void> _pickPdfs() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        for (var file in result.files) {
          if (file.path != null) {
            _selectedPdfs.add(_SelectedPdf(file: File(file.path!)));
          }
        }
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedPdfs.removeAt(index);
    });
  }

  void _reorderFiles(int oldIndex, int newIndex) {
    setState(() {
      final file = _selectedPdfs.removeAt(oldIndex);
      _selectedPdfs.insert(newIndex, file);
    });
  }

  void _openPdfPreview(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PdfViewScreen(path: file.path, title: p.basename(file.path)),
      ),
    );
  }

  Future<void> _startMerging() async {
    if (_selectedPdfs.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 2 PDFs to merge')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProcessingScreen(
          title: 'Merging PDFs...',
          task: () async {
            final paths = _selectedPdfs.map((f) => f.file.path).toList();
            final outPath = await PdfManipulator().mergePDFs(
              params: PDFMergerParams(pdfsPaths: paths),
            );
            if (outPath == null) throw Exception('Merge failed');
            final file = File(outPath);
            final newPath = p.join(
              file.parent.path,
              '${FileUtils.generateDefaultFileName(prefix: 'Merged')}.pdf',
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
              operation: 'Merge PDFs',
              filePath: renamedFile.path,
              fileName: p.basename(renamedFile.path),
              fileSize: fileSize,
              totalPages: 0,
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
          'Merge PDFs',
          style: TextStyle(color: appColors.text, fontWeight: FontWeight.bold),
        ),
        backgroundColor: appColors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: appColors.text),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_selectedPdfs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Text(
                  'Drag to reorder. Tap image to view. Tap (X) to remove.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: appColors.subtitle,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            _selectedPdfs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GestureDetector(
                      onTap: _pickPdfs,
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
                            color: Colors.indigo.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.merge_type_rounded,
                                size: 40,
                                color: Colors.indigo,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Select PDFs to Merge',
                              style: TextStyle(
                                color: appColors.text,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap to choose 2 or more PDF files',
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
                    child: ReorderableGridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio:
                              0.70, // Slightly taller to fit filename
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: _selectedPdfs.length,
                    onReorder: _reorderFiles,
                    itemBuilder: (context, index) {
                      final item = _selectedPdfs[index];
                      final file = item.file;
                      return Container(
                        key: ValueKey(item.id),
                        decoration: BoxDecoration(
                          color: appColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: appColors.divider ?? Colors.transparent,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _openPdfPreview(file),
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8),
                                      ),
                                      child: PdfFileThumbnail(file: file),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: appColors.surface,
                                    borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(8),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.drag_indicator,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      Expanded(
                                        child: Text(
                                          p.basename(file.path),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: appColors.text,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Positioned(
                              top: -8,
                              right: -8,
                              child: IconButton(
                                icon: const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.redAccent,
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                onPressed: () => _removeFile(index),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            if (_selectedPdfs.isNotEmpty)
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
                          onPressed: _pickPdfs,
                          icon: const Icon(Icons.add),
                          label: const Text('Add more PDFs'),
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
                      if (_selectedPdfs.length >= 2) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _startMerging,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: appColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Merge PDFs',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
    );
  }
}
