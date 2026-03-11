import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music_app/core/theme/colors.dart';
import 'package:music_app/core/theme/text_styles.dart';
import 'package:music_app/services/music_api_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _apiKeyController = TextEditingController();
  final _bearerTokenController = TextEditingController();
  late Box _settingsBox;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _settingsBox = await Hive.openBox('settings');
    final apiKey = _settingsBox.get('apiKey', defaultValue: '');
    final bearerToken = _settingsBox.get('bearerToken', defaultValue: '');
    _apiKeyController.text = apiKey;
    _bearerTokenController.text = bearerToken;
    
    MusicApiService.instance.setCredentials(
      apiKey: apiKey,
      bearerToken: bearerToken,
    );
  }

  Future<void> _saveSettings() async {
    await _settingsBox.put('apiKey', _apiKeyController.text);
    await _settingsBox.put('bearerToken', _bearerTokenController.text);
    
    MusicApiService.instance.setCredentials(
      apiKey: _apiKeyController.text,
      bearerToken: _bearerTokenController.text,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            title: '音乐源',
            children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.music_note, color: AppColors.primary, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Audius', style: AppTextStyles.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            '100万+首歌曲，免费完整播放，320kbps\n无需配置，直接使用',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: '认证 (可选)',
            children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Audius 免费使用，无需配置也可正常播放',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key (可选)',
                  hintText: '留空使用免费限额',
                  prefixIcon: Icon(Icons.key),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bearerTokenController,
                decoration: const InputDecoration(
                  labelText: 'Bearer Token (可选)',
                  hintText: '留空使用免费限额',
                  prefixIcon: Icon(Icons.token),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveSettings,
                child: const Text('保存'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: '关于',
            children: [
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('版本'),
                subtitle: const Text('1.0.0'),
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: const Icon(Icons.music_note),
                title: const Text('音乐源'),
                subtitle: const Text('Audius (完整播放)'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.headlineMedium),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}
