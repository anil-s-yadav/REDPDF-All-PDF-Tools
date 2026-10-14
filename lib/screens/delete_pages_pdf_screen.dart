import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:redpdf_tools/theme/app_theme.dart';
import 'package:redpdf_tools/utils/file_utils.dart';
import 'package:pdf_manipulator/pdf_manipulator.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:provider/provider.dart';
import 'package:redpdf_tools/models/pdf_history.dart';
import 'package:redpdf_tools/providers/pdf_provider.dart';
import 'processing_screen.dart';
import '../widgets/pdf_file_thumbnail.dart';
import 'pdf_view_screen.dart';

class DeletePagesPdfScreen extends StatefulWidget {
  const DeletePagesPdfScreen({super.key});

  @override
  State<DeletePagesPdfScreen> createState() => _DeletePagesPdfScreenState();
}

class _DeletePagesPdfScreenState extends State<DeletePagesPdfScreen> {
  File? _selectedPdf;
  pdfx.PdfDocument? _pdfDocument;
  int _pageCount = 0;
  final Set<int> _pagesToDelete = {};
  bool _isLoading = false;

  @override
  void dispose() {
    _pdfDocument?.close();
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
        final doc = await pdfx.PdfDocument.openFile(file.path);
        final count = doc.pagesCount;

        await _pdfDocument?.close(); // Close old doc if any

        setState(() {
          _selectedPdf = file;
          _pdfDocument = doc;
          _pageCount = count;
          _pagesToDelete.clear();
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

  void _togglePage(int page) {
    setState(() {
      if (_pagesToDelete.contains(page)) {
        _pagesToDelete.remove(page);
      } else {
        _pagesToDelete.add(page);
      }
    });
  }

  Future<void> _startDeleting() async {
    if (_pagesToDelete.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 page to delete'),
        ),
      );
      return;
    }
    if (_pagesToDelete.length == _pageCount) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cannot delete all pages')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProcessingScreen(
          title: 'Deleting Pages...',
          task: () async {
            // pdfPageDeleter expects 1-based page numbers
            final outPath = await PdfManipulator().pdfPageDeleter(
              params: PDFPageDeleterParams(
                pdfPath: _selectedPdf!.path,
                pageNumbers: _pagesToDelete.toList()..sort(),
              ),
            );
            if (outPath == null) throw Exception('Delete failed');
            final file = File(outPath);
            final newPath = p.join(
              file.parent.path,
              '${FileUtils.generateDefaultFileName(prefix: 'DeletedPages')}.pdf',
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
              operation: 'Delete Pages',
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

  void _showFullScreenPreview(int pageNumber) {
    if (_pdfDocument == null) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: FutureBuilder<pdfx.PdfPageImage?>(
                  future: _renderLargePage(_pdfDocument!, pageNumber),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator(
                        color: Colors.white,
                      );
                    }
                    if (snapshot.hasData && snapshot.data != null) {
                      return Image.memory(
                        snapshot.data!.bytes,
                        fit: BoxFit.contain,
                      );
                    }
                    return const Text(
                      'Error loading preview',
                      style: TextStyle(color: Colors.white),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Page $pageNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<pdfx.PdfPageImage?> _renderLargePage(
    pdfx.PdfDocument document,
    int pageNumber,
  ) async {
    final page = await document.getPage(pageNumber);
    final image = await page.render(
      width: page.width * 2, // High resolution for preview
      height: page.height * 2,
      format: pdfx.PdfPageImageFormat.jpeg,
    );
    await page.close();
    return image;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        title: Text(
          'Delete PDF Pages',
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
                : _selectedPdf == null || _pdfDocument == null
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
                            color: Colors.pinkAccent.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.pinkAccent.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.auto_delete_rounded,
                                size: 40,
                                color: Colors.pinkAccent,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Select PDF to Delete Pages',
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
                    child: Column(
                    children: [
                      GestureDetector(
                        onTap: _openPdfPreview,
                        child: Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: appColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.redAccent,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withValues(alpha: 0.1),
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
                                  child: PdfFileThumbnail(file: _selectedPdf!),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                              const Icon(
                                Icons.remove_red_eye_outlined,
                                color: Colors.blueAccent,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Select pages to DELETE. Tap image to preview full size.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount:
                                    3, // Reduced to 3 for better thumbnail visibility
                                childAspectRatio:
                                    0.75, // Standard PDF aspect ratio
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 16,
                              ),
                          itemCount: _pageCount,
                          itemBuilder: (context, index) {
                            final page = index + 1;
                            final isSelected = _pagesToDelete.contains(page);

                            return Stack(
                              children: [
                                // Thumbnail
                                GestureDetector(
                                  onTap: () => _showFullScreenPreview(page),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: appColors.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.redAccent
                                            : (appColors.divider ??
                                                  Colors.transparent),
                                        width: isSelected ? 3 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.05,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.hardEdge,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        _PdfThumbnail(
                                          document: _pdfDocument!,
                                          pageNumber: page,
                                        ),
                                        if (isSelected)
                                          Container(
                                            color: Colors.redAccent.withValues(
                                              alpha: 0.2,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Checkbox for selection
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: Transform.scale(
                                    scale: 1.1,
                                    child: Checkbox(
                                      value: isSelected,
                                      activeColor: Colors.redAccent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      onChanged: (_) => _togglePage(page),
                                    ),
                                  ),
                                ),

                                // Page Number Label
                                Positioned(
                                  bottom: 4,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$page',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            if (_selectedPdf != null && _pdfDocument != null)
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
                      if (_pagesToDelete.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _startDeleting,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pinkAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Delete ${_pagesToDelete.length} Pages',
                              style: const TextStyle(
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

class _PdfThumbnail extends StatefulWidget {
  final pdfx.PdfDocument document;
  final int pageNumber;

  const _PdfThumbnail({required this.document, required this.pageNumber});

  @override
  State<_PdfThumbnail> createState() => _PdfThumbnailState();
}

class _PdfThumbnailState extends State<_PdfThumbnail> {
  Uint8List? _imageData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _renderPage();
  }

  @override
  void didUpdateWidget(_PdfThumbnail oldWidget) {
    if (oldWidget.document != widget.document ||
        oldWidget.pageNumber != widget.pageNumber) {
      _renderPage();
    }
    super.didUpdateWidget(oldWidget);
  }

  Future<void> _renderPage() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final page = await widget.document.getPage(widget.pageNumber);

      // Render small thumbnail for grid
      final pageImage = await page.render(
        width: page.width / 4,
        height: page.height / 4,
        format: pdfx.PdfPageImageFormat.jpeg,
      );

      if (mounted) {
        setState(() {
          _imageData = pageImage?.bytes;
          _isLoading = false;
        });
      }
      await page.close();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_imageData != null) {
      return Image.memory(_imageData!, fit: BoxFit.cover);
    }
    return const Center(child: Icon(Icons.error_outline, color: Colors.grey));
  }
}
