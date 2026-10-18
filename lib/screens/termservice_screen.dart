import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  Future<void> _openOnlineTerms() async {
    final uri = Uri.parse(
      'https://anil-s-yadav.github.io/REDPDF-PrivacyPolicy/terms.html',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Terms of Service"),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            tooltip: 'Open in Browser',
            onPressed: _openOnlineTerms,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('''
Terms of Service

Last Updated: October 2026

Welcome to RedPdf - All PDF Tools.

By downloading, installing, or using this application, you agree to the following terms:

1. Use of the App & Local Processing
RedPdf is provided for personal and lawful productivity use. All PDF operations (conversions, scanning, compression, merging, splitting, encryption) are executed 100% locally on your device. We do not upload, host, or view your files.

2. Free Tier & Advertising
The free tier is supported by third-party advertisements (such as Google AdMob). You agree to display of these advertisements during usage.

3. Premium Plan & Ad Removal
RedPdf provides an optional Premium Plan to remove all third-party advertisements.
- Payments and subscriptions are billed through Google Play In-App Billing.
- Subscriptions automatically renew unless cancelled at least 24 hours prior to the renewal date via your Google Play account settings.
- Refunds are governed by Google Play Store Refund Policies.

4. User Responsibility
You retain full ownership of all documents and files processed. You are responsible for maintaining backups of all important documents.

5. Limitation of Liability
This application is provided "as is" without warranty. The developer is not liable for data loss, document corruption, device issues, or consequential damages.

6. Modifications
We may update the application and these Terms at any time.

7. Contact
For support or inquiries, please contact:
anilyadav44x@gmail.com
''', style: TextStyle(fontSize: 15, height: 1.6)),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: _openOnlineTerms,
                  icon: const Icon(Icons.language_rounded),
                  label: const Text('View Full Terms Online'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
