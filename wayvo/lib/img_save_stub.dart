import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

Future<String> saveImage(Uint8List bytes, String name) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$name');
  await f.writeAsBytes(bytes);
  await OpenFilex.open(f.path);
  return 'Image opened. Save it from the viewer.';
}
