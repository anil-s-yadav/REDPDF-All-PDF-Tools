import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:redpdf_tools/providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import 'package:redpdf_tools/theme/app_theme.dart';
import 'package:saf/saf.dart';
import 'permission_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _cacheSize = '0 B';

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      int totalSize = await _getDirSize(tempDir);

      if (mounted) {
        setState(() {
          _cacheSize = _formatSize(totalSize);
        });
      }
    } catch (e) {
      debugPrint('Error calculating cache size: $e');
    }
  }

  Future<int> _getDirSize(Directory dir) async {
    int totalSize = 0;
    try {
      if (await dir.exists()) {
        await for (var entity in dir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting dir size: $e');
    }
    return totalSize;
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<void> _clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final entities = tempDir.listSync();
        for (final entity in entities) {
          if (entity is File) {
            await entity.delete();
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        }
      }

      await _calculateCacheSize();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text(
                  'Cache cleared successfully!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing cache: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  // ─── Rate Us Banner ─────────────────────────────────────────────────
  Widget _buildRateUsBanner(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => _launchUrl(
          "https://play.google.com/store/apps/details?id=com.legendarysoftware.redpdf.imagetopdf",
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF3D2008), const Color(0xFF2A1A05)]
                  : [
                      const Color(0xFFFFF7ED),
                      const Color(0xFFFFFBEB),
                      const Color(0xFFFEF3C7),
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? const Color(0xFFD97706).withValues(alpha: 0.3)
                  : const Color(0xFFFBBF24).withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFFFBBF24,
                ).withValues(alpha: isDark ? 0.1 : 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enjoying RedPDF?',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF92400E),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rate us 5 stars on Play Store!',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFFB45309),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(
                        5,
                        (index) => const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.star_rounded,
                            size: 22,
                            color: Color(0xFFFBBF24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isDark
                    ? const Color(0xFFFBBF24).withValues(alpha: 0.7)
                    : const Color(0xFFD97706),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Try Our Other Apps Banner (Matching Compress App) ───────────────
  Widget _buildOtherAppsBanner(BuildContext context, bool isDark) {
    final appColors = Theme.of(context).appColors;
    final primaryColor = appColors.primary ?? const Color(0xFFE53935);
    final cardColor = isDark
        ? (appColors.surface ?? const Color(0xFF1E293B))
        : (appColors.surface ?? Colors.white);
    final textColor =
        appColors.text ?? (isDark ? Colors.white : Colors.black87);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.22),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.09),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: 1,
            ),
            // BoxShadow(
            //   color: primaryColor.withValues(alpha: 0.14),
            //   blurRadius: 8,
            //   offset: const Offset(0, 2),
            // ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _launchUrl(
              'https://play.google.com/store/apps/dev?id=8832237281097064209',
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    height: 46,
                    width: 46,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Image.asset(
                      'lib/assets/google-play-store-icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                "More Apps",
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "RedPDF",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "Google Play Store • More Tools",
                          style: TextStyle(
                            color: textColor.withAlpha(150),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Section Header ─────────────────────────────────────────────────
  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    IconData? icon,
  }) {
    final appColors = Theme.of(context).appColors;
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 10, left: 24, right: 24),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: appColors.primary),
            const SizedBox(width: 8),
          ],
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1.5,
              color: appColors.subtitle?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Card Container ─────────────────────────────────────────────────
  Widget _buildCardContainer({
    required List<Widget> children,
    required BuildContext context,
  }) {
    final appColors = Theme.of(context).appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: children),
      ),
    );
  }

  // ─── List Tile ──────────────────────────────────────────────────────
  Widget _buildListTile(
    BuildContext context,
    IconData icon,
    String title, {
    Widget? trailing,
    VoidCallback? onTap,
    bool showDivider = true,
    Color? iconColor,
    Color? textColor,
    Color? iconBgColor,
    String? subtitle,
  }) {
    final appColors = Theme.of(context).appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconColor = iconColor ?? appColors.primary!;
    final effectiveIconBgColor =
        iconBgColor ??
        effectiveIconColor.withValues(alpha: isDark ? 0.15 : 0.1);

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: effectiveIconBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: effectiveIconColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: textColor ?? appColors.text,
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: appColors.subtitle?.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  trailing ??
                      Icon(
                        Icons.chevron_right_rounded,
                        color: appColors.subtitle?.withValues(alpha: 0.3),
                        size: 22,
                      ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 70),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: appColors.divider?.withValues(alpha: 0.5),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final appColors = Theme.of(context).appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: appColors.background,
      // appBar: AppBar(title: Text('Settings')),
      body: SafeArea(
        // top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // _buildHeader(context, isDark),
              _buildSectionHeader(context, 'General', icon: Icons.tune_rounded),
              _buildCardContainer(
                context: context,
                children: [
                  _buildListTile(
                    context,
                    Icons.dark_mode_rounded,
                    'Dark Mode',
                    subtitle: isDark ? 'Currently on' : 'Currently off',
                    iconColor: const Color(0xFF6366F1),
                    trailing: Switch.adaptive(
                      value: isDark,
                      onChanged: (val) => themeProvider.toggleDarkMode(val),
                      activeTrackColor: appColors.primary,
                    ),
                  ),
                  _buildListTile(
                    context,
                    Icons.insert_drive_file_rounded,
                    'Default Page Size',
                    subtitle: 'For new PDF documents',
                    iconColor: const Color(0xFF0EA5E9),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0EA5E9).withValues(alpha: 0.15)
                            : const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        settings.pageSizeString,
                        style: TextStyle(
                          color: const Color(0xFF0EA5E9),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    onTap: () => _showPageSizeDialog(context, settings),
                  ),
                  _buildListTile(
                    context,
                    Icons.screen_rotation_rounded,
                    'Default Orientation',
                    subtitle: 'Portrait or landscape',
                    iconColor: const Color(0xFF10B981),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        settings.orientationString,
                        style: TextStyle(
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    onTap: () => _showOrientationDialog(context, settings),
                    showDivider: false,
                  ),
                ],
              ),

              // ── Storage ──
              _buildSectionHeader(
                context,
                'Storage',
                icon: Icons.storage_rounded,
              ),
              _buildCardContainer(
                context: context,
                children: [
                  _buildListTile(
                    context,
                    Icons.folder_open_rounded,
                    'Storage Location',
                    subtitle: settings.storageLocationDisplay,
                    iconColor: const Color(0xFF3B82F6),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (settings.storageLocation.isNotEmpty)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () async {
                              await settings.resetStorageLocation();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              child: Icon(
                                Icons.refresh_rounded,
                                size: 18,
                                color: appColors.subtitle?.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: appColors.subtitle?.withValues(alpha: 0.3),
                          size: 22,
                        ),
                      ],
                    ),
                    onTap: () => _pickStoragePath(context, settings),
                    showDivider: true,
                  ),
                  _buildListTile(
                    context,
                    Icons.cleaning_services_rounded,
                    'Clear Cache',
                    subtitle: 'Free up space',
                    iconColor: const Color(0xFFEF4444),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                            : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _cacheSize,
                        style: TextStyle(
                          color: const Color(0xFFEF4444),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    onTap: () => _showClearCacheDialog(context),
                    showDivider: false,
                  ),
                ],
              ),

              // ── Permissions ──
              _buildSectionHeader(
                context,
                'Permissions',
                icon: Icons.security_rounded,
              ),
              _buildCardContainer(
                context: context,
                children: [
                  _buildListTile(
                    context,
                    Icons.verified_user_rounded,
                    'Permission Settings',
                    subtitle: 'Manage notifications, storage & camera access',
                    iconColor: const Color(0xFF10B981),
                    iconBgColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PermissionSettingsScreen(),
                      ),
                    ),
                    showDivider: false,
                  ),
                ],
              ),

              // ── About ──
              _buildSectionHeader(
                context,
                'About',
                icon: Icons.info_outline_rounded,
              ),
              _buildCardContainer(
                context: context,
                children: [
                  _buildListTile(
                    context,
                    Icons.description_rounded,
                    'Terms of Service',
                    iconColor: const Color(0xFF8B5CF6),
                    onTap: () => _launchUrl(
                      "https://anil-s-yadav.github.io/REDPDF-PrivacyPolicy/terms.html",
                    ),
                  ),
                  _buildListTile(
                    context,
                    Icons.shield_rounded,
                    'Privacy Policy',
                    iconColor: const Color(0xFF14B8A6),
                    showDivider: false,
                    onTap: () => _launchUrl(
                      "https://anil-s-yadav.github.io/REDPDF-PrivacyPolicy/",
                    ),
                  ),
                ],
              ), //  HIGHLIGHTED — Rate Us

              const SizedBox(height: 10),

              //  HIGHLIGHTED — Try Our Other Apps
              _buildOtherAppsBanner(context, isDark),
              const SizedBox(height: 14),
              _buildRateUsBanner(context, isDark),

              const SizedBox(height: 32),

              // ── Version footer ──
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite_rounded,
                            size: 14,
                            color: appColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Made with love by REDPDF',
                            style: TextStyle(
                              color: appColors.subtitle?.withValues(alpha: 0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Version 2.2.0 (9)',
                      style: TextStyle(
                        color: appColors.subtitle?.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Storage Location Picker ───────────────────────────────────────
  Future<void> _pickStoragePath(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    try {
      final saf = Saf();
      final dir = await saf.pickDirectory();
      if (dir != null) {
        await settings.setStorageLocation(dir.uri);
      }
    } catch (e) {
      debugPrint('Error picking storage directory: $e');
    }
  }

  // ─── Clear Cache Dialog ─────────────────────────────────────────────
  void _showClearCacheDialog(BuildContext context) {
    final appColors = Theme.of(context).appColors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.cleaning_services_rounded,
                color: Color(0xFFEF4444),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Clear Cache',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: appColors.text,
              ),
            ),
          ],
        ),
        content: Text(
          'This will free up $_cacheSize of storage. Cached files will be re-downloaded when needed.',
          style: TextStyle(
            color: appColors.subtitle,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: appColors.subtitle,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _clearCache();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Clear Now',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Page Size Dialog ───────────────────────────────────────────────
  void _showPageSizeDialog(BuildContext context, SettingsProvider settings) {
    final appColors = Theme.of(context).appColors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.insert_drive_file_rounded,
                color: Color(0xFF0EA5E9),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Page Size',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: appColors.text,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: PdfPageSize.values.map((size) {
            final isSelected = settings.defaultPageSize == size;
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: isSelected
                    ? appColors.primary?.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: Text(
                    size.toString().split('.').last.toUpperCase(),
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? appColors.primary : appColors.text,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: appColors.primary,
                        )
                      : null,
                  onTap: () {
                    settings.setDefaultPageSize(size);
                    Navigator.pop(context);
                  },
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Orientation Dialog ─────────────────────────────────────────────
  void _showOrientationDialog(BuildContext context, SettingsProvider settings) {
    final appColors = Theme.of(context).appColors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.screen_rotation_rounded,
                color: Color(0xFF10B981),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Orientation',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: appColors.text,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: PdfPageOrientation.values.map((orientation) {
            final isSelected = settings.defaultOrientation == orientation;
            final label =
                orientation.toString().split('.').last[0].toUpperCase() +
                orientation.toString().split('.').last.substring(1);
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: isSelected
                    ? appColors.primary?.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(
                    orientation.toString().contains('portrait')
                        ? Icons.stay_primary_portrait_rounded
                        : Icons.stay_primary_landscape_rounded,
                    color: isSelected ? appColors.primary : appColors.subtitle,
                  ),
                  title: Text(
                    label,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? appColors.primary : appColors.text,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: appColors.primary,
                        )
                      : null,
                  onTap: () {
                    settings.setDefaultOrientation(orientation);
                    Navigator.pop(context);
                  },
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String uri) async {
    if (!await launchUrl(Uri.parse(uri))) {
      throw Exception('Could not launch $uri');
    }
  }
}
