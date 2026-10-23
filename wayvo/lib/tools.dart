import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart' show dio, AuthScreen;
import 'img_save.dart';
import 'package:share_plus/share_plus.dart';

String _errText(Object e, String fallback) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
  }
  return fallback;
}

Widget _heading(String t, String s) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(t, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(s, style: const TextStyle(color: Colors.black54, fontSize: 14)),
      const SizedBox(height: 18),
    ],
  );
}

void _openPage(BuildContext context, String title, Widget body) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: const Color(0xFFF8F7F2),
        appBar: AppBar(
          title: Text(title),
          backgroundColor: const Color(0xFFF8F7F2),
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: Padding(padding: const EdgeInsets.all(20), child: body),
      ),
    ),
  );
}

void _info(BuildContext context, String title, String text) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
      ],
    ),
  );
}

// ---------------- CODE ----------------

class CodeWorkspace extends StatefulWidget {
  const CodeWorkspace({super.key});

  @override
  State<CodeWorkspace> createState() => _CodeWorkspaceState();
}

class _CodeWorkspaceState extends State<CodeWorkspace> {
  final input = TextEditingController();
  String lang = 'Python';
  String result = '';
  bool busy = false;
  static const langs = [
    'Python', 'C', 'C++', 'Java', 'JavaScript', 'Dart', 'SQL', 'HTML/CSS',
  ];

  Future<void> run(String action) async {
    final text = input.text.trim();
    if (text.isEmpty || busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      result = '';
    });
    try {
      final r = await dio.post(
        '/api/tools/code',
        data: {'action': action, 'language': lang, 'text': text},
        options: Options(
          contentType: Headers.jsonContentType,
          receiveTimeout: const Duration(seconds: 90),
        ),
      );
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      if (!mounted) return;
      setState(() {
        result = d['success'] == true
            ? (d['reply'] ?? '').toString()
            : (d['message'] ?? 'Failed').toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => result = _errText(e, 'Could not reach WAYVO. Try again.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _heading(
          'WAYVO Code',
          'Describe the code you want, or paste code to explain, debug, translate or optimize.',
        ),
        DropdownButtonFormField<String>(
          initialValue: lang,
          decoration: const InputDecoration(labelText: 'Language'),
          items: langs
              .map((x) => DropdownMenuItem(value: x, child: Text(x)))
              .toList(),
          onChanged: (v) => setState(() => lang = v ?? lang),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: input,
          minLines: 6,
          maxLines: 12,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'Example: write a function to reverse a string, or paste your code here',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton(
              onPressed: busy ? null : () => run('generate'),
              child: const Text('Generate code'),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => run('explain'),
              child: const Text('Explain'),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => run('debug'),
              child: const Text('Debug'),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => run('translate'),
              child: Text('Translate to $lang'),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => run('optimize'),
              child: const Text('Optimize'),
            ),
          ],
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(),
          ),
        if (result.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Result', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: result));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy'),
              ),
            ],
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SelectableText(
              result,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

// ---------------- IMAGE ----------------

class _ImageViewer extends StatefulWidget {
  final Uint8List bytes;
  final Future<void> Function() onDownload;
  final Future<void> Function() onShare;
  const _ImageViewer({
    required this.bytes,
    required this.onDownload,
    required this.onShare,
  });

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  final TransformationController tc = TransformationController();

  void _setScale(double v) {
    final sc = v.clamp(1.0, 6.0).toDouble();
    final sz = context.size ?? const Size(400, 600);
    final cx = sz.width / 2;
    final cy = sz.height / 2;
    tc.value = Matrix4.translationValues(-cx * (sc - 1), -cy * (sc - 1), 0) *
        Matrix4.diagonal3Values(sc, sc, 1);
  }

  double get _cur => tc.value.getMaxScaleOnAxis();

  @override
  void dispose() {
    tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Image'),
        actions: [
          IconButton(
            tooltip: 'Download',
            icon: const Icon(Icons.download),
            onPressed: widget.onDownload,
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share),
            onPressed: widget.onShare,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onDoubleTap: () => _setScale(_cur > 1.05 ? 1.0 : 2.5),
              child: InteractiveViewer(
                transformationController: tc,
                minScale: 1,
                maxScale: 6,
                child: Center(child: Image.memory(widget.bytes, fit: BoxFit.contain)),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  onPressed: () => _setScale(_cur / 1.5),
                  child: const Icon(Icons.zoom_out),
                ),
                const SizedBox(width: 16),
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  onPressed: () => _setScale(_cur * 1.5),
                  child: const Icon(Icons.zoom_in),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ImageWorkspace extends StatefulWidget {
  const ImageWorkspace({super.key});

  @override
  State<ImageWorkspace> createState() => _ImageWorkspaceState();
}

class _ImageWorkspaceState extends State<ImageWorkspace> {
  final prompt = TextEditingController();
  Uint8List? image;
  String error = '';
  bool busy = false;

  Future<void> generate() async {
    final p = prompt.text.trim();
    if (p.length < 3 || busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = '';
      image = null;
    });
    try {
      final r = await dio.post(
        '/api/tools/image',
        data: {'prompt': p},
        options: Options(
          contentType: Headers.jsonContentType,
          receiveTimeout: const Duration(seconds: 90),
        ),
      );
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      if (!mounted) return;
      if (d['success'] == true) {
        setState(() => image = base64Decode(d['data_b64'].toString()));
      } else {
        setState(() => error = (d['message'] ?? 'Could not generate the image').toString());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => error = _errText(e, 'Could not generate the image. Try again.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _download() async {
    if (image == null) return;
    try {
      final msg = await saveImage(
        image!,
        'wayvo-image-${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the image.')),
      );
    }
  }

  Future<void> _share() async {
    if (image == null) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Made with WAYVO',
          files: [
            XFile.fromData(image!, mimeType: 'image/jpeg', name: 'wayvo-image.jpg'),
          ],
        ),
      );
    } catch (_) {
      await _download();
    }
  }

  Future<void> _copyLink() async {
    if (image == null) return;
    try {
      final r = await dio.post(
        '/api/images/share',
        data: {'data_b64': base64Encode(image!)},
        options: Options(
          contentType: Headers.jsonContentType,
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      if (d['success'] == true) {
        await Clipboard.setData(ClipboardData(text: d['url'].toString()));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copied. Anyone with this link can view the image.')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text((d['message'] ?? 'Could not create the link').toString())),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errText(e, 'Could not create the link. Try again.'))),
      );
    }
  }

  void _openViewer() {
    if (image == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ImageViewer(
          bytes: image!,
          onDownload: _download,
          onShare: _share,
        ),
      ),
    );
  }

  @override
  void dispose() {
    prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _heading(
          'Image Generation',
          'Describe an image and WAYVO will create it. Generated images are saved in My Files.',
        ),
        TextField(
          controller: prompt,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Example: a red sports car on a mountain road at sunset',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: busy ? null : generate,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate Image'),
          ),
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.only(top: 18),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Generating image. This can take up to 30 seconds...')),
              ],
            ),
          ),
        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(error, style: const TextStyle(color: Colors.red)),
          ),
        if (image != null)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GestureDetector(onTap: _openViewer, child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: Image.memory(image!, fit: BoxFit.contain)))),
            ),
          ),
        if (image != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _openViewer,
                    icon: const Icon(Icons.zoom_in),
                    label: const Text('Zoom'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _download,
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _share,
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _copyLink,
                    icon: const Icon(Icons.link),
                    label: const Text('Link'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ---------------- PERSONALIZATION ----------------

class _StylePicker extends StatefulWidget {
  const _StylePicker();

  @override
  State<_StylePicker> createState() => _StylePickerState();
}

class _StylePickerState extends State<_StylePicker> {
  String style = 'short';
  static const opts = <List<String>>[
    ['short', 'Short', '2-4 lines, direct (default)'],
    ['balanced', 'Balanced', 'About 5-8 lines'],
    ['detailed', 'Detailed', 'Thorough explanations'],
  ];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => style = p.getString('resp_style') ?? 'short');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: opts
          .map(
            (o) => ListTile(
              title: Text(o[1]),
              subtitle: Text(o[2]),
              trailing: style == o[0]
                  ? const Icon(Icons.check_circle, color: Color(0xFF17152A))
                  : null,
              onTap: () async {
                setState(() => style = o[0]);
                final p = await SharedPreferences.getInstance();
                await p.setString('resp_style', o[0]);
              },
            ),
          )
          .toList(),
    );
  }
}

class PersonalizationWorkspace extends StatelessWidget {
  const PersonalizationWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _heading('Personalization', 'Choose how long WAYVO answers should be by default.'),
        const _StylePicker(),
        const SizedBox(height: 12),
        const Text(
          'You can still ask for short or detailed answers in any message. Language and tone options are coming soon.',
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}

// ---------------- SETTINGS ----------------

class VoiceSettings extends StatefulWidget {
  const VoiceSettings({super.key});

  @override
  State<VoiceSettings> createState() => _VoiceSettingsState();
}

class _VoiceSettingsState extends State<VoiceSettings> {
  double rate = 0.5;
  String micLang = '';
  String gender = 'default';
  double pitch = 1.0;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() {
          rate = p.getDouble('tts_rate') ?? 0.5;
          micLang = p.getString('stt_locale') ?? '';
          gender = p.getString('tts_gender') ?? 'default';
          pitch = p.getDouble('tts_pitch') ?? 1.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Text('Speaking speed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Slider(
          value: rate,
          min: 0.3,
          max: 0.8,
          divisions: 5,
          label: rate.toStringAsFixed(1),
          onChanged: (v) => setState(() => rate = v),
          onChangeEnd: (v) async {
            final p = await SharedPreferences.getInstance();
            await p.setDouble('tts_rate', v);
          },
        ),
        const Text(
          'Slower on the left, faster on the right. Applies the next time you open the app.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 24),
        const Text('Voice style', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final g in const [
              ['default', 'Default'],
              ['female', 'Female'],
              ['male', 'Male'],
            ])
              ChoiceChip(
                label: Text(g[1]),
                selected: gender == g[0],
                onSelected: (_) async {
                  setState(() => gender = g[0]);
                  final p = await SharedPreferences.getInstance();
                  await p.setString('tts_gender', g[0]);
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Voice pitch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Slider(
          value: pitch,
          min: 0.7,
          max: 1.4,
          divisions: 7,
          label: pitch.toStringAsFixed(1),
          onChanged: (v) => setState(() => pitch = v),
          onChangeEnd: (v) async {
            final p = await SharedPreferences.getInstance();
            await p.setDouble('tts_pitch', v);
          },
        ),
        const Text(
          'Lower is deeper, higher is thinner. Female/Male picks a matching voice from your phone if it has one. Applies from the next reply.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 24),
        const Text('Microphone language', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        for (final o in const [
          ['', 'Phone default'],
          ['en_IN', 'English (India)'],
          ['te_IN', 'Telugu'],
        ])
          ListTile(
            title: Text(o[1]),
            trailing: micLang == o[0]
                ? const Icon(Icons.check_circle, color: Color(0xFF17152A))
                : null,
            onTap: () async {
              setState(() => micLang = o[0]);
              final p = await SharedPreferences.getInstance();
              if (o[0].isEmpty) {
                await p.remove('stt_locale');
              } else {
                await p.setString('stt_locale', o[0]);
              }
            },
          ),
        const Text(
          'Telugu needs the Telugu speech pack on your phone (Google app > Settings > Voice).',
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}

class PrivacyData extends StatelessWidget {
  const PrivacyData({super.key});

  Future<void> _deleteAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all chats?'),
        content: const Text(
          'All your chats and messages will be deleted permanently. Files in My Files stay.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    String note;
    try {
      await dio.post('/api/chats/delete_all');
      note = 'All chats deleted. Reopen the menu to refresh.';
    } catch (e) {
      note = 'Could not delete. Try again.';
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(note)));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Text(
          'Your chats are stored on the WAYVO server and are only visible to your account. Locked chats need your phone lock to open.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: () => _deleteAll(context),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete all my chats'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class AccountInfo extends StatefulWidget {
  const AccountInfo({super.key});

  @override
  State<AccountInfo> createState() => _AccountInfoState();
}

class _AccountInfoState extends State<AccountInfo> {
  String email = '';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => email = p.getString('email') ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(email.isEmpty ? 'Signed in' : email),
          subtitle: const Text('WAYVO account'),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: () async {
              final p = await SharedPreferences.getInstance();
              await p.remove('email');
              await p.remove('token');
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ),
      ],
    );
  }
}

class SettingsWorkspace extends StatelessWidget {
  const SettingsWorkspace({super.key});

  Widget _tile(
    IconData icon,
    String title,
    String sub,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(sub),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _heading('Settings', 'Manage your WAYVO experience.'),
        Card(
          elevation: 0,
          color: Colors.white,
          child: Column(
            children: [
              _tile(Icons.palette_outlined, 'Appearance', 'Light theme',
                  () => _info(context, 'Appearance', 'WAYVO uses the light theme for now. Dark mode is coming soon.')),
              _tile(Icons.chat_outlined, 'Chat', 'Default answer length',
                  () => _openPage(context, 'Answer length', const _StylePicker())),
              _tile(Icons.auto_awesome, 'AI & Personalization', 'Response style',
                  () => _openPage(context, 'AI & Personalization', const PersonalizationWorkspace())),
              _tile(Icons.mic_none, 'Voice', 'Speaking speed',
                  () => _openPage(context, 'Voice', const VoiceSettings())),
              _tile(Icons.notifications_outlined, 'Notifications', 'Reminders',
                  () => _info(context, 'Notifications', 'Reminders are not available yet. They will come with the Schedule feature.')),
              _tile(Icons.lock_outline, 'Privacy & Data', 'Delete your chats',
                  () => _openPage(context, 'Privacy & Data', const PrivacyData())),
              _tile(Icons.person_outline, 'Account', 'Email and log out',
                  () => _openPage(context, 'Account', const AccountInfo())),
              _tile(Icons.info_outline, 'About WAYVO', 'Version and website',
                  () => _info(context, 'About WAYVO', 'WAYVO personal AI assistant.\nWebsite: snehabogaram75-hub.github.io/wayvo-fresh')),
            ],
          ),
        ),
      ],
    );
  }
}
