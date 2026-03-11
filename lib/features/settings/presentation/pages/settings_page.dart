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
  MusicSource _selectedSource = MusicSource.audius;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _settingsBox = await Hive.openBox('settings');
    final apiKey = _settingsBox.get('apiKey', defaultValue: '');
    final bearerToken = _settingsBox.get('bearerToken', defaultValue: '');
    final sourceIndex = _settingsBox.get('sourceIndex', defaultValue: 1);
    _apiKeyController.text = apiKey;
    _bearerTokenController.text = bearerToken;
    setState(() {
      _selectedSource = MusicSource.values[sourceIndex];
    });
    
    MusicApiService.instance.setCredentials(
      apiKey: apiKey,
      bearerToken: bearerToken,
    );
    MusicApiService.instance.setSource(_selectedSource);
  }

  Future<void> _saveSettings() async {
    await _settingsBox.put('apiKey', _apiKeyController.text);
    await _settingsBox.put('bearerToken', _bearerTokenController.text);
    await _settingsBox.put('sourceIndex', _selectedSource.index);
    
    MusicApiService.instance.setCredentials(
      apiKey: _apiKeyController.text,
      bearerToken: _bearerTokenController.text,
    );
    MusicApiService.instance.setSource(_selectedSource);
    
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
            title: '选择音乐源',
            children: [
              const SizedBox(height: 8),
              _buildSourceOption(
                title: 'Deezer (默认)',
                subtitle: '30秒预览，需科学上网',
                source: MusicSource.deezer,
                icon: Icons.play_circle_outline,
              ),
              _buildSourceOption(
                title: 'Audius',
                subtitle: '完整播放，但中文搜索效果差',
                source: MusicSource.audius,
                icon: Icons.music_note,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Audius 认证 (可选)',
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
                        'Audius REST API 免费使用，无需配置',
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
                  hintText: '留空即可使用免费限额',
                  prefixIcon: Icon(Icons.key),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bearerTokenController,
                decoration: const InputDecoration(
                  labelText: 'Bearer Token (可选)',
                  hintText: '留空即可使用免费限额',
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
                title: const Text('当前音乐源'),
                subtitle: Text(_getSourceName(_selectedSource)),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceOption({
    required String title,
    required String subtitle,
    required MusicSource source,
    required IconData icon,
  }) {
    final isSelected = _selectedSource == source;
    return RadioListTile<MusicSource>(
      value: source,
      groupValue: _selectedSource,
      onChanged: (newValue) {
        setState(() {
          _selectedSource = newValue!;
        });
        _saveSettings();
      },
      title: Text(title, style: AppTextStyles.titleMedium),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
      secondary: Icon(icon, color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant),
      activeColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
    );
  }

  String _getSourceName(MusicSource source) {
    switch (source) {
      case MusicSource.audius:
        return 'Audius (完整播放)';
      case MusicSource.deezer:
        return 'Deezer (30秒预览)';
    }
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
