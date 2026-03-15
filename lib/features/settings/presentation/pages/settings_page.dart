import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music_app/core/theme/colors.dart';
import 'package:music_app/core/theme/text_styles.dart';
import 'package:music_app/services/music_api_service.dart';

class SettingsPage extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged;
  final ThemeMode currentThemeMode;

  const SettingsPage({
    Key? key,
    required this.onThemeChanged,
    required this.currentThemeMode,
  }) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Box _settingsBox;
  late TextEditingController _customApiController;
  MusicSource _currentSource = MusicSource.kuwo;

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('settings');
    _customApiController = TextEditingController();
    _loadSettings();
  }

  void _loadSettings() {
    final savedTheme = _settingsBox.get('themeMode', defaultValue: 'dark');
    final savedSource = _settingsBox.get('musicSource', defaultValue: 'kuwo');
    final savedCustomUrl = _settingsBox.get('customApiUrl', defaultValue: '');
    
    setState(() {
      _currentSource = savedSource == 'custom' ? MusicSource.custom : MusicSource.kuwo;
      _customApiController.text = savedCustomUrl;
    });
  }

  @override
  void dispose() {
    _customApiController.dispose();
    super.dispose();
  }

  void _onSourceChanged(MusicSource source) {
    setState(() {
      _currentSource = source;
    });
    _settingsBox.put('musicSource', source == MusicSource.custom ? 'custom' : 'kuwo');
    
    if (source == MusicSource.custom && _customApiController.text.isNotEmpty) {
      MusicApiService.instance.setSource(source, customUrl: _customApiController.text);
      _settingsBox.put('customApiUrl', _customApiController.text);
    } else {
      MusicApiService.instance.setSource(source);
    }
  }

  void _onCustomUrlSaved() {
    if (_customApiController.text.isNotEmpty) {
      _settingsBox.put('customApiUrl', _customApiController.text);
      MusicApiService.instance.setSource(MusicSource.custom, customUrl: _customApiController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('自定义API已保存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('设置', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            title: '外观',
            children: [
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.dark_mode),
                      title: const Text('暗色模式'),
                      trailing: Switch(
                        value: widget.currentThemeMode == ThemeMode.dark,
                        onChanged: (value) {
                          widget.onThemeChanged(value ? ThemeMode.dark : ThemeMode.light);
                          _settingsBox.put('themeMode', value ? 'dark' : 'light');
                        },
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: '音乐源',
            children: [
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    RadioListTile<MusicSource>(
                      value: MusicSource.kuwo,
                      groupValue: _currentSource,
                      onChanged: (value) => _onSourceChanged(value!),
                      title: const Text('酷我音乐'),
                      subtitle: const Text('国内直连，搜索快，完整播放'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    const Divider(height: 1),
                    RadioListTile<MusicSource>(
                      value: MusicSource.custom,
                      groupValue: _currentSource,
                      onChanged: (value) => _onSourceChanged(value!),
                      title: const Text('自定义API'),
                      subtitle: const Text('输入第三方API地址'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    if (_currentSource == MusicSource.custom) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _customApiController,
                              decoration: InputDecoration(
                                labelText: 'API 地址',
                                hintText: '例如: https://api.example.com',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.save),
                                  onPressed: _onCustomUrlSaved,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '当前API: ${_customApiController.text.isEmpty ? "未设置" : _customApiController.text}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: '关于',
            children: [
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.info),
                      title: Text('版本'),
                      subtitle: Text('1.0.0'),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ],
                ),
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
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}
