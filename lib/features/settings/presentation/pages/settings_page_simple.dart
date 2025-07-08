import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedLanguage = 'English';

  String _getCurrentLanguageDisplayName() {
    final currentLocale = context.locale;
    if (currentLocale.languageCode == 'fa') {
      return 'فارسی';
    } else if (currentLocale.languageCode == 'es') {
      return 'Español';
    } else {
      return 'English';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('settings'.tr()),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Info Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.chat_bubble,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'app_name'.tr(),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            'Version 1.0.0',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Peer-to-peer voice messaging application with no server required.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Language Selection
          Card(
            child: ListTile(
              title: Text('language'.tr()),
              subtitle: Text(_getCurrentLanguageDisplayName()),
              leading: Icon(
                Icons.language,
                color: Theme.of(context).primaryColor,
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showLanguageSelector();
              },
            ),
          ),

          const SizedBox(height: 24),

          // Theme Selection
          Card(
            child: ListTile(
              title: Text('theme'.tr()),
              subtitle: Text('system'.tr()),
              leading: Icon(
                Icons.palette,
                color: Theme.of(context).primaryColor,
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Theme settings coming soon!')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('language'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption('English', '🇺🇸', const Locale('en', 'US')),
            _buildLanguageOption('فارسی', '🇮🇷', const Locale('fa', 'IR')),
            _buildLanguageOption('Español', '🇪🇸', const Locale('es', 'ES')),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String language, String flag, Locale locale) {
    final isSelected = _getCurrentLanguageDisplayName() == language;
    return ListTile(
      title: Text(language),
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      trailing:
          isSelected ? const Icon(Icons.check, color: Colors.green) : null,
      onTap: () {
        context.setLocale(locale);
        Navigator.pop(context);
        setState(() {
          _selectedLanguage = language;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Language changed to $language')),
        );
      },
    );
  }
}
