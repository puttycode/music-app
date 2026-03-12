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
  MusicSource _selectedSource = MusicSource.musicdl;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _settingsBox = await Hive.openBox('settings');
    final apiKey = _settingsBox.get('apiKey', defaultValue: '');
    final bearerToken = _settingsBox.get('bearerToken', defaultValue: '');
    final sourceIndex = _settingsBox.get('sourceIndex', defaultValue: 0);
    
    _apiKeyController.text = apiKey;
    _bearerTokenController.text = bearerToken;
    _selectedSource = MusicSource.values[sourceIndex];
    
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
            title: '音乐源',
            children: [
              const SizedBox(height: 8),
              _buildSourceOption(
                source: MusicSource.musicdl,
                title: 'MusicDL (推荐)',
                description: '支持网易云、QQ音乐、酷狗、酷我、咪咕等40+平台\n国内直连，无需VPN',
                icon: Icons.cloud,
              ),
              const SizedBox(height: 8),
              _buildSourceOption(
                source: MusicSource.audius,
                title: 'Audius',
                description: '海外音乐平台，100万+首歌曲\n需要VPN',
                icon: Icons.public,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: '认证 (可选，用于 Audius)',
            children: [
              const SizedBox(height: 16),
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
                        'MusicDL 免费使用，无需配置。Audius 需要 VPN',
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
                subtitle: Text(_selectedSource == MusicSource.musicdl ? 'MusicDL (40+平台)' : 'Audius'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceOption({
    required MusicSource source,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _selectedSource == source;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSource = source;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleMedium.copyWith(
                    color: isSelected ? AppColors.primary : null,
                  )),
                  const SizedBox(height: 4),
                  Text(description, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
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
