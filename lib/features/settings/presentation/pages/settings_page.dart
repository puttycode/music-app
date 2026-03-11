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
    final sourceIndex = _settingsBox.get('sourceIndex', defaultValue: 0);
    _apiKeyController.text = apiKey;
    setState(() {
      _selectedSource = MusicSource.values[sourceIndex];
    });
  }

  Future<void> _saveSettings() async {
    await _settingsBox.put('apiKey', _apiKeyController.text);
    await _settingsBox.put('sourceIndex', _selectedSource.index);
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
                title: 'Audius (推荐)',
                subtitle: '100万+首歌曲，免费完整播放，320kbps',
                source: MusicSource.audius,
                icon: Icons.music_note,
              ),
              _buildSourceOption(
                title: 'Deezer',
                subtitle: '30秒预览，需科学上网',
                source: MusicSource.deezer,
                icon: Icons.play_circle_outline,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'API Key (可选)',
            children: [
              const SizedBox(height: 8),
              Text(
                'Audius 可选配置，提升请求限制',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Audius API Key',
                  hintText: '留空使用免费限额',
                  prefixIcon: Icon(Icons.key),
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
