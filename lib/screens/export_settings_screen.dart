import 'dart:io';
import 'package:flutter/material.dart';
import 'package:redpdf_tools/theme/app_theme.dart';
import 'processing_screen.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as spdf;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:redpdf_tools/providers/pdf_provider.dart';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:math' as math;
import 'package:redpdf_tools/providers/settings_provider.dart';
import 'package:redpdf_tools/models/pdf_history.dart';
import '../utils/file_utils.dart';
import 'package:path/path.dart' as p;

class ExportSettingsScreen extends StatefulWidget {
  final List<File> images;
  final String? defaultFileNamePrefix;
  final String? operationName;

  const ExportSettingsScreen({
    super.key,
    required this.images,
    this.defaultFileNamePrefix,
    this.operationName,
  });

  @override
  State<ExportSettingsScreen> createState() => _ExportSettingsScreenState();
}

class _ExportSettingsScreenState extends State<ExportSettingsScreen> {
  final TextEditingController _fileNameController = TextEditingController();
  final TextEditingController _userPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _ownerPasswordController =
      TextEditingController();

  bool _isHighCompression = false;
  bool _securityEnabled = false;
  bool _allowPrinting = true;
  bool _allowCopying = true;
  bool _obscureUserPassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureOwnerPassword = true;

  Future<Uint8List> _processImage(File file) async {
    if (_isHighCompression) {
      final compressed = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: 50, // High compression
      );
      return compressed ?? await file.readAsBytes();
    }
    return await file.readAsBytes();
  }

  Size _getPageFormat(SettingsProvider settings) {
    Size format;
    switch (settings.defaultPageSize) {
      case PdfPageSize.a4:
        format = spdf.PdfPageSize.a4;
        break;
      case PdfPageSize.letter:
        format = spdf.PdfPageSize.letter;
        break;
      case PdfPageSize.a3:
        format = spdf.PdfPageSize.a3;
        break;
      case PdfPageSize.legal:
        format = spdf.PdfPageSize.legal;
        break;
    }

    // Syncfusion handles orientation separately, but we can return the size object here.
    // If it's landscape, we swap width and height.
    if (settings.defaultOrientation == PdfPageOrientation.landscape) {
      return Size(format.height, format.width);
    }
    return format;
  }

  Future<ProcessResult> _generateAndSavePdfTask() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final document = spdf.PdfDocument();
    final pageFormat = _getPageFormat(settings);
    document.pageSettings.size = pageFormat;
    document.pageSettings.margins.all = 0;

    // Security Settings
    if (_securityEnabled) {
      final security = document.security;
      if (_userPasswordController.text.isNotEmpty) {
        security.userPassword = _userPasswordController.text;
      }
      if (_ownerPasswordController.text.isNotEmpty) {
        security.ownerPassword = _ownerPasswordController.text;
      }
      if (!_allowPrinting) {
        security.permissions.remove(spdf.PdfPermissionsFlags.print);
      }
      if (!_allowCopying) {
        security.permissions.remove(spdf.PdfPermissionsFlags.copyContent);
      }
    }

    for (var imageFile in widget.images) {
      final imageBytes = await _processImage(imageFile);
      final spdf.PdfBitmap image = spdf.PdfBitmap(imageBytes);

      final spdf.PdfPage page = document.pages.add();

      final double imgWidth = image.width.toDouble();
      final double imgHeight = image.height.toDouble();
      final double pageWidth = page.getClientSize().width;
      final double pageHeight = page.getClientSize().height;

      double drawWidth = pageWidth;
      double drawHeight = (imgHeight / imgWidth) * pageWidth;

      if (drawHeight > pageHeight) {
        drawHeight = pageHeight;
        drawWidth = (imgWidth / imgHeight) * pageHeight;
      }

      final double x = (pageWidth - drawWidth) / 2;
      final double y = (pageHeight - drawHeight) / 2;

      page.graphics.drawImage(
        image,
        Rect.fromLTWH(x, y, drawWidth, drawHeight),
      );
    }

    final List<int> bytesList = document.saveSync();
    final Uint8List bytes = Uint8List.fromList(bytesList);
    document.dispose();

    final dir = await getApplicationDocumentsDirectory();
    final enteredName = _fileNameController.text.trim();
    final prefix = widget.defaultFileNamePrefix ?? 'REDPDF';
    final baseName = enteredName.isEmpty
        ? FileUtils.generateDefaultFileName(prefix: prefix)
        : (enteredName.toLowerCase().endsWith('.pdf')
              ? enteredName.substring(0, enteredName.length - 4)
              : enteredName);

    final uniquePath = await FileUtils.getUniqueFilePath(
      dir.path,
      '$baseName.pdf',
    );
    final file = File(uniquePath);
    final finalFileName = p.basename(uniquePath);

    await file.writeAsBytes(bytes);

    // Save to history
    final history = PdfHistory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: finalFileName,
      path: file.path,
      sizeInBytes: bytes.length,
      createdAt: DateTime.now(),
    );

    if (mounted) {
      context.read<PdfProvider>().addHistory(history);
    }

    return ProcessResult(
      operation: widget.operationName ?? "Created",
      filePath: file.path,
      fileName: finalFileName,
      fileSize: bytes.length,
      totalPages: widget.images.length,
      password: _securityEnabled && _userPasswordController.text.isNotEmpty
          ? _userPasswordController.text
          : null,
    );
  }

  void _startProcessing() {
    if (_securityEnabled) {
      final password = _userPasswordController.text;
      final confirmPassword = _confirmPasswordController.text;

      if (password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a password'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (confirmPassword.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please confirm your password'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (password != confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwords do not match'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProcessingScreen(
          title: 'Generating PDF...',
          task: _generateAndSavePdfTask,
        ),
      ),
    );
  }

  double _getTotalOriginalSize() {
    double total = 0;
    for (var image in widget.images) {
      if (image.existsSync()) {
        total += image.lengthSync();
      }
    }
    return total;
  }

  String _getFormattedSize(double bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return "${(bytes / math.pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}";
  }

  String _getEstimatedSize() {
    double originalSize = _getTotalOriginalSize();
    double estimated = _isHighCompression
        ? originalSize * 0.3
        : originalSize * 0.8;
    return _getFormattedSize(estimated);
  }

  void _showOwnerPasswordInfo(BuildContext context) {
    final appColors = Theme.of(context).appColors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.security, color: appColors.primary),
            const SizedBox(width: 10),
            Text('Password Types', style: TextStyle(color: appColors.text)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Password:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: appColors.text,
              ),
            ),
            Text(
              'Required to open and view the PDF document.',
              style: TextStyle(color: appColors.subtitle),
            ),
            const SizedBox(height: 12),
            Text(
              'Owner Password:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: appColors.text,
              ),
            ),
            Text(
              'Required to change permissions (like printing or copying) and other administrative settings.',
              style: TextStyle(color: appColors.subtitle),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'GOT IT',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).appColors;
    final settings = Provider.of<SettingsProvider>(context);
    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        backgroundColor: appColors.background,
        centerTitle: true,
        title: Text(
          'Export Settings',
          style: TextStyle(color: appColors.text, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: appColors.text),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.opaque,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(
                        'COMPRESSION',
                        appColors,
                        topPadding: 0.0,
                      ),
                      Row(
                        children: [
                          _buildCompressionCard(
                            'Normal',
                            'Best quality',
                            Icons.high_quality,
                            !_isHighCompression,
                            appColors,
                            () {
                              setState(() => _isHighCompression = false);
                            },
                          ),
                          const SizedBox(width: 16),
                          _buildCompressionCard(
                            'Small File',
                            'Lower quality',
                            Icons.compress,
                            _isHighCompression,
                            appColors,
                            () {
                              setState(() => _isHighCompression = true);
                            },
                          ),
                        ],
                      ),

                      _buildSectionTitle('PAGE SETTINGS', appColors),
                      _buildSettingSelectorCard(
                        title: 'Page Size',
                        value: settings.pageSizeString,
                        icon: Icons.description_outlined,
                        appColors: appColors,
                        onTap: () => _showPageSizeDialog(context, settings),
                      ),
                      _buildSettingSelectorCard(
                        title: 'Page Orientation',
                        value: settings.orientationString,
                        icon: Icons.crop_portrait_rounded,
                        appColors: appColors,
                        onTap: () => _showOrientationDialog(context, settings),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionTitle('SECURITY', appColors),
                          Switch(
                            value: _securityEnabled,
                            onChanged: (val) =>
                                setState(() => _securityEnabled = val),
                            activeThumbColor: Colors.white,
                            activeTrackColor: appColors.primary,
                          ),
                        ],
                      ),
                      if (_securityEnabled) ...[
                        Text(
                          'User Password',
                          style: TextStyle(
                            color: appColors.subtitle,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: appColors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: appColors.divider ?? Colors.grey.shade200,
                            ),
                          ),
                          child: TextField(
                            controller: _userPasswordController,
                            obscureText: _obscureUserPassword,
                            style: TextStyle(color: appColors.text),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              border: InputBorder.none,
                              hintText: 'Set opening password',
                              hintStyle: TextStyle(
                                color: appColors.subtitle?.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureUserPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureUserPassword =
                                        !_obscureUserPassword;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Confirm Password',
                          style: TextStyle(
                            color: appColors.subtitle,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: appColors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color:
                                  (_confirmPasswordController.text.isNotEmpty &&
                                      _userPasswordController.text !=
                                          _confirmPasswordController.text)
                                  ? Colors.red
                                  : (appColors.divider ?? Colors.grey.shade200),
                            ),
                          ),
                          child: TextField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            style: TextStyle(color: appColors.text),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              border: InputBorder.none,
                              hintText: 'Confirm opening password',
                              hintStyle: TextStyle(
                                color: appColors.subtitle?.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        if (_confirmPasswordController.text.isNotEmpty &&
                            _userPasswordController.text !=
                                _confirmPasswordController.text) ...[
                          const SizedBox(height: 6),
                          const Padding(
                            padding: EdgeInsets.only(left: 16.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Passwords do not match',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              'Owner Password',
                              style: TextStyle(
                                color: appColors.subtitle,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _showOwnerPasswordInfo(context),
                              child: Icon(
                                Icons.help_outline,
                                size: 16,
                                color: appColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: appColors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: appColors.divider ?? Colors.grey.shade200,
                            ),
                          ),
                          child: TextField(
                            controller: _ownerPasswordController,
                            obscureText: _obscureOwnerPassword,
                            style: TextStyle(color: appColors.text),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              border: InputBorder.none,
                              hintText: 'Set administrative password',
                              hintStyle: TextStyle(
                                color: appColors.subtitle?.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureOwnerPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureOwnerPassword =
                                        !_obscureOwnerPassword;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ],

                      _buildSectionTitle('PERMISSIONS', appColors),
                      _buildPermissionCard(
                        'Allow Printing',
                        _allowPrinting,
                        appColors,
                        (val) => setState(() => _allowPrinting = val ?? false),
                      ),
                      _buildPermissionCard(
                        'Allow Copying',
                        _allowCopying,
                        appColors,
                        (val) => setState(() => _allowCopying = val ?? false),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: appColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
                border: Border(
                  top: BorderSide(
                    color: appColors.divider ?? Colors.grey.shade200,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'FILE NAME (OPTIONAL)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: appColors.subtitle,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 13,
                              color: appColors.subtitle,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Expected Size: ',
                              style: TextStyle(
                                color: appColors.subtitle,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _getEstimatedSize(),
                              style: TextStyle(
                                color: appColors.text,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: appColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: appColors.divider ?? Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Icon(
                            Icons.description_outlined,
                            size: 20,
                            color: appColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _fileNameController,
                              style: TextStyle(
                                color: appColors.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                                hintText: 'Enter file name (optional)',
                                hintStyle: TextStyle(
                                  color: appColors.subtitle?.withValues(
                                    alpha: 0.5,
                                  ),
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _fileNameController,
                            builder: (context, value, _) {
                              if (value.text.isNotEmpty) {
                                return GestureDetector(
                                  onTap: () => _fileNameController.clear(),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Icon(
                                      Icons.cancel,
                                      size: 18,
                                      color: appColors.subtitle?.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Text(
                                  '.pdf',
                                  style: TextStyle(
                                    color: appColors.subtitle?.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startProcessing,
                        icon: const Icon(
                          Icons.download,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: const Text(
                          'Save & Export PDF',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
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

  Widget _buildSectionTitle(
    String title,
    AppColors appColors, {
    double topPadding = 24.0,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: 12.0),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 1.2,
          color: appColors.subtitle,
        ),
      ),
    );
  }

  Widget _buildCompressionCard(
    String title,
    String subtitle,
    IconData icon,
    bool isSelected,
    AppColors appColors,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? appColors.primary!.withValues(alpha: 0.1)
                : appColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? appColors.primary!
                  : (appColors.divider ?? Colors.grey.shade300),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? appColors.primary : appColors.subtitle,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isSelected ? appColors.primary : appColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? appColors.primary!.withValues(alpha: 0.7)
                      : appColors.subtitle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingSelectorCard({
    required String title,
    required String value,
    required IconData icon,
    required AppColors appColors,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: appColors.divider ?? Colors.grey.shade200,
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: appColors.primary?.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: appColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: appColors.text,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: appColors.primary?.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          appColors.primary?.withValues(alpha: 0.25) ??
                          Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          color: appColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: appColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard(
    String title,
    bool isSelected,
    AppColors appColors,
    ValueChanged<bool?> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? appColors.primary!.withValues(alpha: 0.05)
            : appColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? appColors.primary!.withValues(alpha: 0.3)
              : (appColors.divider ?? Colors.grey.shade200),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: CheckboxListTile(
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: appColors.text,
            ),
          ),
          value: isSelected,
          onChanged: onChanged,
          activeColor: appColors.primary,
          checkColor: Colors.white,
          side: BorderSide(
            color:
                appColors.subtitle?.withValues(alpha: 0.3) ??
                Colors.grey.shade300,
            width: 2,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }

  void _showPageSizeDialog(BuildContext context, SettingsProvider settings) {
    final appColors = Theme.of(context).appColors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Select Page Size',
          style: TextStyle(
            color: appColors.text,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: PdfPageSize.values.map((size) {
            final isSelected = settings.defaultPageSize == size;
            return ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                size.toString().split('.').last.toUpperCase(),
                style: TextStyle(
                  color: isSelected ? appColors.primary : appColors.text,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check_circle_rounded, color: appColors.primary)
                  : null,
              onTap: () {
                settings.setDefaultPageSize(size);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showOrientationDialog(BuildContext context, SettingsProvider settings) {
    final appColors = Theme.of(context).appColors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Select Orientation',
          style: TextStyle(
            color: appColors.text,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: PdfPageOrientation.values.map((orientation) {
            final isSelected = settings.defaultOrientation == orientation;
            final name = orientation.toString().split('.').last;
            final label = name[0].toUpperCase() + name.substring(1);
            return ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                label,
                style: TextStyle(
                  color: isSelected ? appColors.primary : appColors.text,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check_circle_rounded, color: appColors.primary)
                  : null,
              onTap: () {
                settings.setDefaultOrientation(orientation);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    _userPasswordController.dispose();
    _confirmPasswordController.dispose();
    _ownerPasswordController.dispose();
    super.dispose();
  }
}
