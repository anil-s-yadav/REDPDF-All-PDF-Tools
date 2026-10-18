import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:redpdf_tools/theme/app_theme.dart';
import 'lock_pdf_screen.dart';
import 'unlock_pdf_screen.dart';
import 'image_to_pdf_screen.dart';
import 'compress_pdf_screen.dart';
import 'merge_pdf_screen.dart';
import 'split_pdf_screen.dart';
import 'add_pages_pdf_screen.dart';
import 'delete_pages_pdf_screen.dart';
import 'pdf_to_images_screen.dart';
import 'scan_document_screen.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  static bool cachedIsGridView = false;
  static bool hasLoadedPreference = false;

  static Future<void> initPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      cachedIsGridView = prefs.getBool('tools_grid_view') ?? false;
      hasLoadedPreference = true;
    } catch (_) {}
  }

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen>
    with AutomaticKeepAliveClientMixin {
  late bool _isGridView;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _isGridView = ToolsScreen.cachedIsGridView;
    if (!ToolsScreen.hasLoadedPreference) {
      _loadPreference();
    }
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isGrid = prefs.getBool('tools_grid_view') ?? false;
      ToolsScreen.cachedIsGridView = isGrid;
      ToolsScreen.hasLoadedPreference = true;
      if (mounted && _isGridView != isGrid) {
        setState(() {
          _isGridView = isGrid;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleView() async {
    setState(() {
      _isGridView = !_isGridView;
      ToolsScreen.cachedIsGridView = _isGridView;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tools_grid_view', _isGridView);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final appColors = Theme.of(context).appColors;

    final tools = [
      _ToolItem(
        title: 'Scan Documents',
        subtitle: 'Scan physical papers into crisp digital PDF',
        iconData: Icons.document_scanner_outlined,
        color: const Color(0xFF0284C7),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScanDocumentScreen()),
        ),
      ),
      _ToolItem(
        title: 'Image to PDF',
        subtitle: 'Convert your gallery or camera photos to PDF',
        iconData: Icons.camera_enhance_outlined,
        color: Colors.blueAccent,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ImageToPdfScreen()),
        ),
      ),
      _ToolItem(
        title: 'Lock PDF',
        subtitle: 'Secure your documents with military-grade encryption',
        iconData: Icons.lock_outline,
        color: Colors.redAccent,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LockPdfScreen()),
        ),
      ),
      _ToolItem(
        title: 'Unlock PDF',
        subtitle: 'Instant removal of PDF passwords and restrictions',
        iconData: Icons.lock_open_outlined,
        color: Colors.teal,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UnlockPdfScreen()),
        ),
      ),
      _ToolItem(
        title: 'Compress PDF',
        subtitle: 'Reduce PDF file size while maintaining high quality',
        iconData: Icons.compress_rounded,
        color: Colors.deepOrangeAccent,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CompressPdfScreen()),
        ),
      ),
      _ToolItem(
        title: 'Merge PDFs',
        subtitle: 'Combine multiple PDF files into one document',
        iconData: Icons.merge_type,
        color: Colors.indigo,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MergePdfScreen()),
        ),
      ),
      _ToolItem(
        title: 'Split PDF',
        subtitle: 'Extract pages or split PDF into multiple files',
        iconData: Icons.call_split,
        color: Colors.amber.shade700,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SplitPdfScreen()),
        ),
      ),
      _ToolItem(
        title: 'Add Pages',
        subtitle: 'Append other PDFs or images to your PDF',
        iconData: Icons.note_add_outlined,
        color: Colors.green,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddPagesPdfScreen()),
        ),
      ),
      _ToolItem(
        title: 'Delete Pages',
        subtitle: 'Remove unwanted pages from your PDF',
        iconData: Icons.auto_delete_outlined,
        color: Colors.pinkAccent,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DeletePagesPdfScreen()),
        ),
      ),
      _ToolItem(
        title: 'PDF to Images',
        subtitle: 'Convert PDF pages into high-quality images',
        iconData: Icons.image_outlined,
        color: Colors.deepPurpleAccent,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PdfToImagesScreen()),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        title: Text(
          'All Tools',
          style: TextStyle(
            color: appColors.text,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: appColors.background,
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: appColors.divider, height: 1),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: appColors.text,
            ),
            onPressed: _toggleView,
            tooltip: _isGridView
                ? 'Switch to List View'
                : 'Switch to Grid View',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isGridView
              ? GridView.builder(
                  key: const ValueKey('grid'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: tools.length,
                  itemBuilder: (context, index) {
                    final item = tools[index];
                    return _ToolGridCard(
                      title: item.title,
                      subtitle: item.subtitle,
                      iconData: item.iconData,
                      color: item.color,
                      onTap: item.onTap,
                    );
                  },
                )
              : ListView.separated(
                  key: const ValueKey('list'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  itemCount: tools.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final item = tools[index];
                    return _ToolListCard(
                      title: item.title,
                      subtitle: item.subtitle,
                      iconData: item.iconData,
                      color: item.color,
                      onTap: item.onTap,
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _ToolItem {
  final String title;
  final String subtitle;
  final IconData iconData;
  final Color color;
  final VoidCallback onTap;

  _ToolItem({
    required this.title,
    required this.subtitle,
    required this.iconData,
    required this.color,
    required this.onTap,
  });
}

class _ToolListCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData iconData;
  final Color color;
  final VoidCallback onTap;

  const _ToolListCard({
    required this.title,
    required this.subtitle,
    required this.iconData,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: appColors.divider ?? Colors.transparent),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(iconData, color: color, size: 30),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: appColors.text,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: appColors.subtitle?.withValues(alpha: 0.8),
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: appColors.subtitle?.withValues(alpha: 0.3),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolGridCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData iconData;
  final Color color;
  final VoidCallback onTap;

  const _ToolGridCard({
    required this.title,
    required this.subtitle,
    required this.iconData,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: appColors.divider ?? Colors.transparent),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(iconData, color: color, size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: appColors.text,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: appColors.subtitle?.withValues(alpha: 0.8),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
