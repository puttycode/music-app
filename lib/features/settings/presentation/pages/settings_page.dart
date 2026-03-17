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
  late TextEditingController _apiKeyController;
  late TextEditingController _downloadPathController;

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('settings');
    _customApiController = TextEditingController();
    _apiKeyController = TextEditingController();
    _downloadPathController = TextEditingController();
    _loadSettings();
  }

  void _loadSettings() {
    final savedCustomUrl = _settingsBox.get('customApiUrl', defaultValue: '');
    final savedApiKey = _settingsBox.get('apiKey', defaultValue: '');
    final savedDownloadPath = _settingsBox.get('downloadPath', defaultValue: '/storage/emulated/0/Music');
    
    setState(() {
      _customApiController.text = savedCustomUrl;
      _apiKeyController.text = savedApiKey;
      _downloadPathController.text = savedDownloadPath;
    });
  }

  @override
  void dispose() {
    _customApiController.dispose();
    _apiKeyController.dispose();
    _downloadPathController.dispose();
    super.dispose();
  }

  void _onCustomUrlSaved() {
    final url = _customApiController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    
    if (url.isNotEmpty) {
      _settingsBox.put('customApiUrl', url);
    }
    if (apiKey.isNotEmpty) {
      _settingsBox.put('apiKey', apiKey);
    }
    
    MusicApiService.instance.setSource(
      MusicSource.custom,
      customUrl: url.isNotEmpty ? url : null,
      apiKey: apiKey.isNotEmpty ? apiKey : null,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API 配置已保存')),
    );
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
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
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
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'API 配置',
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('自定义 API URL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customApiController,
                        decoration: const InputDecoration(
                          hintText: 'https://music-api.codeseek.me:37280',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.link),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('API 密钥', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _apiKeyController,
                        decoration: const InputDecoration(
                          hintText: 'your-secret-api-key',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.key),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _onCustomUrlSaved,
                          child: const Text('保存 API 配置'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '当前：${_customApiController.text.isEmpty ? "默认 API" : _customApiController.text}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: '下载',
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.folder),
                  title: const Text('下载路径'),
                  subtitle: Text(_downloadPathController.text),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _showDownloadPathDialog,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: '关于',
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const ListTile(
                  leading: Icon(Icons.info),
                  title: Text('版本'),
                  subtitle: Text('1.0.0'),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
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

  void _showDownloadPathDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置下载路径'),
        content: TextField(
          controller: _downloadPathController,
          decoration: const InputDecoration(
            hintText: '/storage/emulated/0/Music',
            labelText: '下载路径',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final path = _downloadPathController.text.trim();
              if (path.isNotEmpty) {
                _settingsBox.put('downloadPath', path);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('下载路径已保存')),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
