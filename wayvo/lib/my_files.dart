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
