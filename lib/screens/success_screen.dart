import 'package:flutter/material.dart';
import 'package:redpdf_tools/screens/navigation.dart';
import 'package:redpdf_tools/screens/pdf_view_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:redpdf_tools/theme/app_theme.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import 'package:redpdf_tools/providers/settings_provider.dart';
import 'package:redpdf_tools/providers/pdf_provider.dart';
import 'package:redpdf_tools/models/pdf_history.dart';
import '../utils/file_utils.dart';
import 'package:path/path.dart' as p;

import 'package:redpdf_tools/utils/rate_us_utils.dart';

class SuccessScreen extends StatefulWidget {
  final String operation;
  final String filePath;
  final String fileName;
  final int fileSize;
  final int totalPages;
  final String? password;

  const SuccessScreen({
    super.key,
    required this.operation,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.totalPages,
    this.password,
  });

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> {
  late String _currentFileName;

  @override
  void initState() {
    super.initState();
    _currentFileName = widget.fileName;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _saveToDownloads(context);
      RateUsUtils.showRateUsDialog(context);
    });
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _sharePdf() {
    SharePlus.instance.share(
      ShareParams(
        files: [XFile(widget.filePath)],
        text: 'Check out my document!',
      ),
    );
  }

  void _openPdf(BuildContext context) {
    if (_currentFileName.toLowerCase().endsWith('.zip')) {
      SharePlus.instance.share(
        ShareParams(
          files: [XFile(widget.filePath)],
          text: 'Exported Images from RedPdf',
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewScreen(
          path: widget.filePath,
          title: _currentFileName,
          initialPassword: widget.password,
        ),
      ),
    );
  }

  void _goHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => Navigation()),
      (route) => route.isFirst,
    );
  }

  Future<void> _saveToDownloads(BuildContext context) async {
    try {
      final settings = context.read<SettingsProvider>();
      final savedPath = await FileUtils.saveToDevice(
        sourcePath: widget.filePath,
        fileName: _currentFileName,
        storageLocation: settings.storageLocation,
      );

      if (savedPath != null) {
        final folderName = settings.storageLocationDisplay;
        final finalFileName = savedPath.startsWith('content://')
            ? _currentFileName
            : p.basename(savedPath);
        // 7. Success message
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to $folderName/$finalFileName'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('Save to device error: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showRenameAndSaveDialog() async {
    final appColors = Theme.of(context).appColors;
    final ext = p.extension(_currentFileName);
    final baseName = p.basenameWithoutExtension(_currentFileName);
    final controller = TextEditingController(text: baseName);
    controller.selection = TextSelection.collapsed(offset: baseName.length);

    final newBaseName = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: appColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Rename and Save Again',
                style: TextStyle(
                  color: appColors.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter a new file name:',
                    style: TextStyle(
                      color: appColors.subtitle,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: appColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: appColors.divider ?? Colors.grey.shade300,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            onChanged: (_) => setDialogState(() {}),
                            style: TextStyle(
                              color: appColors.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              hintText: 'Enter file name',
                            ),
                          ),
                        ),
                        if (controller.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              controller.clear();
                              setDialogState(() {});
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                Icons.cancel,
                                size: 18,
                                color: appColors.subtitle?.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ),
                        Text(
                          ext,
                          style: TextStyle(
                            color: appColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: appColors.subtitle),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final trimmed = controller.text.trim();
                    if (trimmed.isNotEmpty) {
                      Navigator.pop(dialogCtx, trimmed);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save Again',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (newBaseName != null && newBaseName.trim().isNotEmpty) {
      final finalName = '${newBaseName.trim()}$ext';
      try {
        final settings = context.read<SettingsProvider>();
        final savedPath = await FileUtils.saveToDevice(
          sourcePath: widget.filePath,
          fileName: finalName,
          storageLocation: settings.storageLocation,
        );

        if (savedPath != null) {
          if (mounted) {
            context.read<PdfProvider>().addHistory(
              PdfHistory(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: finalName,
                path: savedPath,
                sizeInBytes: widget.fileSize,
                createdAt: DateTime.now(),
              ),
            );
          }

          setState(() {
            _currentFileName = finalName;
          });

          if (!mounted) return;
          final folderName = settings.storageLocationDisplay;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved as $folderName/$finalName'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              showCloseIcon: true,
            ),
          );
        }
      } catch (e) {
        debugPrint('Save error: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _askPassword(BuildContext context) async {
    if (widget.password != null && widget.password!.isNotEmpty) {
      return widget.password;
    }

    final appColors = Theme.of(context).appColors;
    String? password;
    final textController = TextEditingController();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: appColors.surface,
          title: Text(
            'Password Required',
            style: TextStyle(
              color: appColors.text,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: textController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Enter PDF password',
              hintStyle: TextStyle(color: appColors.subtitle),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: appColors.divider ?? Colors.grey),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: appColors.primary ?? Colors.blue),
              ),
            ),
            style: TextStyle(color: appColors.text),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                password = null;
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: appColors.subtitle),
              ),
            ),
            TextButton(
              onPressed: () {
                password = textController.text;
                Navigator.of(context).pop();
              },
              child: Text('Open', style: TextStyle(color: appColors.primary)),
            ),
          ],
        );
      },
    );
    return password;
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
          'Success',
          style: TextStyle(color: appColors.text, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: appColors.text),
        actions: [
          TextButton(
            onPressed: () => _goHome(context),
            child: Text(
              'Done',
              style: TextStyle(
                color: appColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(width: 20),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 200),
        child: SafeArea(
          child: Column(
            children: [
              // const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 60,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'PDF ${widget.operation} Successfully!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: appColors.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your document has been processed\nSaved location: Download/RedPdf/',
                style: TextStyle(
                  // fontSize: 16,
                  color: appColors.subtitle,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => _openPdf(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: appColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color: appColors.divider ?? Colors.transparent,
                    ),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: 14,
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: ClipRRect(
                          borderRadius: BorderRadiusGeometry.circular(10),
                          child: _currentFileName.toLowerCase().endsWith('.pdf')
                              ? AbsorbPointer(
                                  child: PdfViewer.file(
                                    widget.filePath,
                                    passwordProvider: () =>
                                        _askPassword(context),
                                    params: PdfViewerParams(
                                      keyHandlerParams:
                                          const PdfViewerKeyHandlerParams(
                                            enabled: false,
                                          ),
                                      errorBannerBuilder:
                                          (
                                            context,
                                            error,
                                            stackTrace,
                                            documentRef,
                                          ) => const SizedBox.shrink(),
                                    ),
                                  ),
                                )
                              : Container(
                                  color: Colors.purple.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: const Icon(
                                    Icons.folder_zip,
                                    color: Colors.purple,
                                    size: 30,
                                  ),
                                ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentFileName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: appColors.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.totalPages > 0
                                  ? '${_formatSize(widget.fileSize)} • ${widget.totalPages} Pages'
                                  : (_currentFileName.toLowerCase().endsWith(
                                          '.zip',
                                        )
                                        ? '${_formatSize(widget.fileSize)} • ZIP Archive'
                                        : _formatSize(widget.fileSize)),
                              style: TextStyle(
                                color: appColors.subtitle,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: appColors.primary!.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.open_in_new,
                          color: appColors.primary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_currentFileName.toLowerCase().endsWith('.zip')) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: appColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color:
                          appColors.divider ??
                          Colors.grey.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.folder_zip_outlined,
                          color: Colors.purple,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ZIP Archive Created',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: appColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'File is saved to your device, open the file in your File Manager to view all extracted pages.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: appColors.subtitle,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // const SizedBox(height: 40),

              // const SizedBox(height: 32),
              // TextButton.icon(
              //   onPressed: () => _goHome(context),
              //   icon: Icon(Icons.home, color: appColors.subtitle),
              //   label: Text(
              //     'Back to Home',
              //     style: TextStyle(color: appColors.subtitle, fontSize: 16),
              //   ),
              // ),
              // const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: appColors.background,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _sharePdf,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                  ),
                  icon: const Icon(Icons.share, color: Colors.white, size: 20),
                  label: Text(
                    _currentFileName.toLowerCase().endsWith('.zip')
                        ? 'Share ZIP'
                        : 'Share PDF',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _showRenameAndSaveDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appColors.primary?.withValues(alpha: 0.12),
                    foregroundColor: appColors.primary,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    side: BorderSide(
                      color: appColors.primary ?? Colors.redAccent,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  icon: Icon(
                    Icons.drive_file_rename_outline_rounded,
                    color: appColors.primary,
                    size: 20,
                  ),
                  label: Text(
                    'Rename and save again',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: appColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _goHome(context),
                  icon: Icon(Icons.home, color: appColors.subtitle, size: 18),
                  label: Text(
                    'Back to Home',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: appColors.subtitle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
