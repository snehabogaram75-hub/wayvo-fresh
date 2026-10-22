import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'main.dart' show dio;

class MyFilesPage extends StatefulWidget {
  const MyFilesPage({super.key});

  @override
  State<MyFilesPage> createState() => _MyFilesPageState();
}

class _MyFilesPageState extends State<MyFilesPage> {
  List<dynamic> files = [];
  bool loading = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  void snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> load() async {
    try {
      final r = await dio.get('/api/files');
      final data = r.data is String ? jsonDecode(r.data) : r.data;
      if (!mounted) return;
      setState(() {
        files = data['files'] ?? [];
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      snack('Could not load files');
    }
  }

  String fmtSize(dynamic b) {
    final n = (b is num) ? b.toDouble() : 0.0;
    if (n < 1024) return '${n.toInt()} B';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
    return '${(n / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String fmtDate(dynamic d) {
    final t = (d ?? '').toString();
    return t.length >= 16 ? t.substring(5, 16) : t;
  }

  String ext(String name) {
    final i = name.lastIndexOf('.');
    return i == -1 ? 'FILE' : name.substring(i + 1).toUpperCase();
  }

  IconData iconFor(String name) {
    final e = ext(name).toLowerCase();
    if (e == 'pdf') return Icons.picture_as_pdf_outlined;
    if (e == 'xls' || e == 'xlsx' || e == 'csv') {
      return Icons.table_chart_outlined;
    }
    if (e == 'ppt' || e == 'pptx') return Icons.slideshow_outlined;
    if (e == 'doc' || e == 'docx') return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Future<void> openFile(dynamic f) async {
    setState(() => busy = true);
    try {
      final dir = await getTemporaryDirectory();
      final safe = (f['filename'] ?? 'file')
          .toString()
          .replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
      final path = '${dir.path}/$safe';
      await dio.download('/api/files/${f['id']}/download', path);
      final res = await OpenFilex.open(path);
      if (res.type != ResultType.done) {
        snack('No app found to open this file');
      }
    } catch (e) {
      snack('Could not open file');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> askFile(dynamic f) async {
    final controller = TextEditingController();
    final q = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ask about ${f['filename']}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Leave empty to get a summary',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Ask'),
          ),
        ],
      ),
    );
    if (q == null) return;
    setState(() => busy = true);
    try {
      final r = await dio.post(
        '/api/files/${f['id']}/ask',
        data: {'message': q.trim()},
        options: Options(
          contentType: Headers.jsonContentType,
          sendTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      final data = r.data is String ? jsonDecode(r.data) : r.data;
      if (!mounted) return;
      if (data['success'] == true) {
        Navigator.pop<int>(context, data['chat_id'] as int);
      } else {
        snack(data['message'] ?? 'Could not answer');
      }
    } on DioException catch (e) {
      snack(
        (e.response?.data is Map ? e.response?.data['message'] : null) ??
            'Could not answer. Try again.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deleteFile(dynamic f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('"${f['filename']}" will be deleted permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await dio.delete('/api/files/${f['id']}');
      if (!mounted) return;
      setState(() => files.removeWhere((x) => x['id'] == f['id']));
      snack('File deleted');
    } catch (e) {
      snack('Delete failed. Try again.');
    }
  }

  Future<void> helpFile(dynamic f, String lang) async {
    setState(() => busy = true);
    try {
      final r = await dio.post(
        '/api/files/${f['id']}/helper',
        data: {'lang': lang},
        options: Options(
          contentType: Headers.jsonContentType,
          sendTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      final data = r.data is String ? jsonDecode(r.data) : r.data;
      if (!mounted) return;
      if (data['success'] == true) {
        Navigator.pop<int>(context, data['chat_id'] as int);
      } else {
        snack(data['message'] ?? 'Could not explain the file');
      }
    } on DioException catch (e) {
      snack(
        (e.response?.data is Map ? e.response?.data['message'] : null) ??
            'Could not explain the file. Try again.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> startQuiz(dynamic f) async {
    setState(() => busy = true);
    try {
      final r = await dio.post(
        '/api/files/${f['id']}/quiz',
        data: {'count': 8},
        options: Options(
          contentType: Headers.jsonContentType,
          sendTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      final data = r.data is String ? jsonDecode(r.data) : r.data;
      if (!mounted) return;
      if (data['success'] == true) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WayvoQuizPage(
              filename: (data['filename'] ?? f['filename']).toString(),
              questions: List<Map<String, dynamic>>.from(
                (data['questions'] as List).map(
                  (e) => Map<String, dynamic>.from(e as Map),
                ),
              ),
            ),
          ),
        );
      } else {
        snack(data['message'] ?? 'Could not create the quiz');
      }
    } on DioException catch (e) {
      snack(
        (e.response?.data is Map ? e.response?.data['message'] : null) ??
            'Could not create the quiz. Try again.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> showOptions(dynamic f) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Ask WAYVO'),
              onTap: () => Navigator.pop(ctx, 'ask'),
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('Explain in Telugu'),
              subtitle: const Text('What it is, key details, what to do next'),
              onTap: () => Navigator.pop(ctx, 'help_te'),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Explain in English'),
              onTap: () => Navigator.pop(ctx, 'help_en'),
            ),
            ListTile(
              leading: const Icon(Icons.quiz_outlined),
              title: const Text('Make a quiz'),
              onTap: () => Navigator.pop(ctx, 'quiz'),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open'),
              onTap: () => Navigator.pop(ctx, 'open'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == 'help_te' || choice == 'help_en') {
      await helpFile(f, choice == 'help_en' ? 'en' : 'te');
      return;
    }
    if (choice == 'quiz') {
      await startQuiz(f);
      return;
    }
    if (choice == 'ask') {
      await askFile(f);
    } else if (choice == 'open') {
      await openFile(f);
    } else if (choice == 'delete') {
      await deleteFile(f);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F2),
      appBar: AppBar(
        title: const Text('My Files'),
        backgroundColor: const Color(0xFFF8F7F2),
        elevation: 0,
      ),
      body: Stack(
        children: [
          loading
              ? const Center(child: CircularProgressIndicator())
              : files.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No files yet. Documents you upload in chat will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: files.length,
                        itemBuilder: (context, i) {
                          final f = files[i];
                          final name = (f['filename'] ?? 'file').toString();
                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: ListTile(
                              leading: Icon(iconFor(name), size: 28),
                              title: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${ext(name)} · ${fmtSize(f['size_bytes'])} · ${fmtDate(f['created_at'])}',
                              ),
                              trailing: const Icon(Icons.more_vert),
                              onTap: () => showOptions(f),
                            ),
                          );
                        },
                      ),
                    ),
          if (busy)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}


class WayvoQuizPage extends StatefulWidget {
  final String filename;
  final List<Map<String, dynamic>> questions;
  const WayvoQuizPage({
    super.key,
    required this.filename,
    required this.questions,
  });

  @override
  State<WayvoQuizPage> createState() => _WayvoQuizPageState();
}

class _WayvoQuizPageState extends State<WayvoQuizPage> {
  int index = 0;
  int score = 0;
  int? picked;
  final List<int> missed = [];

  void pick(int i) {
    if (picked != null) return;
    final correct = (widget.questions[index]['answer'] as num).toInt();
    setState(() {
      picked = i;
      if (i == correct) {
        score++;
      } else {
        missed.add(index);
      }
    });
  }

  void next() {
    setState(() {
      index++;
      picked = null;
    });
  }

  void restart() {
    setState(() {
      index = 0;
      score = 0;
      picked = null;
      missed.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.questions.length;
    final done = index >= total;
    return Scaffold(
      appBar: AppBar(
        title: Text(done ? 'Quiz result' : 'Question ${index + 1} of $total'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: done ? _result(total) : _question(total),
        ),
      ),
    );
  }

  Widget _question(int total) {
    final qd = widget.questions[index];
    final options = List<String>.from(
      (qd['options'] as List).map((e) => e.toString()),
    );
    final correct = (qd['answer'] as num).toInt();
    final explanation = (qd['explanation'] ?? '').toString();
    return ListView(
      children: [
        LinearProgressIndicator(
          value: (index + (picked == null ? 0 : 1)) / total,
        ),
        const SizedBox(height: 16),
        Text(
          qd['q'].toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => pick(i),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: picked == null
                      ? Colors.white
                      : (i == correct
                          ? const Color(0xFFDCFCE7)
                          : (i == picked
                              ? const Color(0xFFFEE2E2)
                              : Colors.white)),
                  border: Border.all(
                    color: picked == null
                        ? Colors.black26
                        : (i == correct
                            ? const Color(0xFF16A34A)
                            : (i == picked
                                ? const Color(0xFFDC2626)
                                : Colors.black12)),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  options[i],
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                ),
              ),
            ),
          ),
        if (picked != null) ...[
          if (explanation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(explanation, style: const TextStyle(height: 1.4)),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: next,
            child: Text(index + 1 == total ? 'See result' : 'Next'),
          ),
        ],
      ],
    );
  }

  Widget _result(int total) {
    final pct = total == 0 ? 0 : (score * 100 / total).round();
    return ListView(
      children: [
        const SizedBox(height: 12),
        Center(
          child: Text(
            '$score / $total',
            style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
          ),
        ),
        Center(child: Text('$pct% correct')),
        const SizedBox(height: 16),
        if (missed.isNotEmpty)
          const Text(
            'Review these:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        for (final m in missed)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '${widget.questions[m]['q']}\nAnswer: ${(widget.questions[m]['options'] as List)[(widget.questions[m]['answer'] as num).toInt()]}',
              style: const TextStyle(height: 1.4),
            ),
          ),
        const SizedBox(height: 20),
        FilledButton(onPressed: restart, child: const Text('Try again')),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}


class TutorPage extends StatefulWidget {
  const TutorPage({super.key});

  @override
  State<TutorPage> createState() => _TutorPageState();
}

class _TutorPageState extends State<TutorPage> {
  final clsC = TextEditingController();
  final boardC = TextEditingController();
  final subjectC = TextEditingController();
  final topicC = TextEditingController();
  final extraC = TextEditingController();
  String kind = 'worksheet';
  String lang = 'en';
  bool busy = false;

  static const kinds = <List<String>>[
    ['worksheet', 'Worksheet'],
    ['test', 'Test paper'],
    ['answers', 'Practice Q&A'],
    ['lesson', 'Lesson plan'],
    ['parent', 'Parent message'],
  ];

  @override
  void dispose() {
    clsC.dispose();
    boardC.dispose();
    subjectC.dispose();
    topicC.dispose();
    extraC.dispose();
    super.dispose();
  }

  void msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> generate() async {
    if (busy) return;
    if (subjectC.text.trim().isEmpty ||
        (kind != 'parent' && topicC.text.trim().isEmpty)) {
      msg('Please enter the subject and topic.');
      return;
    }
    setState(() => busy = true);
    try {
      final r = await dio.post(
        '/api/tutor/generate',
        data: {
          'kind': kind,
          'lang': lang,
          'class': clsC.text.trim(),
          'board': boardC.text.trim(),
          'subject': subjectC.text.trim(),
          'topic': topicC.text.trim(),
          'extra': extraC.text.trim(),
        },
        options: Options(
          contentType: Headers.jsonContentType,
          sendTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      final data = r.data is String ? jsonDecode(r.data) : r.data;
      if (!mounted) return;
      if (data['success'] == true) {
        Navigator.pop<int>(context, data['chat_id'] as int);
      } else {
        msg((data['message'] ?? 'Could not create it').toString());
      }
    } on DioException catch (e) {
      msg(
        ((e.response?.data is Map ? e.response?.data['message'] : null) ??
                'Could not create it. Try again.')
            .toString(),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(TextEditingController c, String label,
      {String? hint, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 2,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tutor Assistant')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('What do you want to create?',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final k in kinds)
                  ChoiceChip(
                    label: Text(k[1]),
                    selected: kind == k[0],
                    onSelected: (_) => setState(() => kind = k[0]),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            field(clsC, 'Class', hint: 'e.g. 8'),
            field(boardC, 'Board (optional)', hint: 'e.g. AP, TS, CBSE'),
            field(subjectC, 'Subject', hint: 'e.g. Maths'),
            field(
              topicC,
              kind == 'parent' ? 'Topic (optional)' : 'Topic',
              hint: 'e.g. Linear equations',
            ),
            field(
              extraC,
              kind == 'parent'
                  ? 'Student name and your notes'
                  : 'Extra notes (optional)',
              hint: kind == 'parent'
                  ? 'e.g. Ravi is good at algebra but careless in sums'
                  : 'e.g. include word problems',
              lines: 2,
            ),
            const Text('Language',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('English'),
                  selected: lang == 'en',
                  onSelected: (_) => setState(() => lang = 'en'),
                ),
                ChoiceChip(
                  label: const Text('Telugu'),
                  selected: lang == 'te',
                  onSelected: (_) => setState(() => lang = 'te'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy ? null : generate,
              child: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Generate'),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Creating... this can take up to 30 seconds.'),
              ),
          ],
        ),
      ),
    );
  }
}
