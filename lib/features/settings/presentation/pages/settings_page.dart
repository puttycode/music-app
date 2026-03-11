import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music_app/core/theme/colors.dart';
import 'package:music_app/core/theme/text_styles.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _apiController = TextEditingController();
  late Box _settingsBox;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _settingsBox = await Hive.openBox('settings');
    final apiUrl = _settingsBox.get('apiUrl', defaultValue: '');
    _apiController.text = apiUrl;
  }

  Future<void> _saveApiUrl() async {
    await _settingsBox.put('apiUrl', _apiController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API 地址已保存')),
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
            title: 'API 配置',
            children: [
              const SizedBox(height: 8),
              Text(
                '如需完整播放音乐，请部署网易云解灰 API 后填写下方地址',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _apiController,
                decoration: const InputDecoration(
                  labelText: 'API 地址',
                  hintText: 'https://your-api.vercel.app',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveApiUrl,
                child: const Text('保存'),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('部署教程', style: AppTextStyles.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('1. Fork 这个项目:', style: AppTextStyles.bodySmall),
                    const SizedBox(height: 4),
                    SelectableText(
                      'https://github.com/iamfurina/unm-server',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
                    ),
                    const SizedBox(height: 12),
                    Text('2. 部署到 Vercel', style: AppTextStyles.bodySmall),
                    const SizedBox(height: 4),
                    Text('3. 将地址填入上方输入框', style: AppTextStyles.bodySmall),
                  ],
                ),
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
              ),
              ListTile(
                leading: const Icon(Icons.music_note),
                title: const Text('音乐 API'),
                subtitle: const Text('Deezer (30秒预览) + 自定义 API'),
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
