import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const TayyibWordApp());
}

class TayyibWordApp extends StatelessWidget {
  const TayyibWordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TayyibWord',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: false,
      ),
      home: const DocumentEditor(),
    );
  }
}

class DocumentEditor extends StatefulWidget {
  const DocumentEditor({super.key});

  @override
  State<DocumentEditor> createState() => _DocumentEditorState();
}

class _DocumentEditorState extends State<DocumentEditor> {
  final controller = TextEditingController();
  final focusNode = FocusNode();

  bool bold = false;
  bool italic = false;
  bool underline = false;
  bool strike = false;
  bool saved = true;

  double fontSize = 16;
  double zoom = 1;
  TextAlign alignment = TextAlign.left;
  String fileName = 'Document 1';

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      if (saved) setState(() => saved = false);
    });
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  Future<void> newDocument() async {
    setState(() {
      controller.clear();
      fileName = 'Document 1';
      saved = true;
    });
  }

  Future<void> openDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'md'],
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);

    setState(() {
      controller.text = file.readAsStringSync();
      fileName = result.files.single.name;
      saved = true;
    });
  }

  Future<void> saveDocument() async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Document',
      fileName: '$fileName.txt',
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (path == null) return;

    await File(path).writeAsString(controller.text);

    setState(() => saved = true);
  }

  void selectAll() {
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    focusNode.requestFocus();
  }

  void insertText(String text) {
    final selection = controller.selection;

    final start = selection.isValid
        ? selection.start
        : controller.text.length;

    final end = selection.isValid
        ? selection.end
        : controller.text.length;

    final updated = controller.text.replaceRange(start, end, text);

    controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(
        offset: start + text.length,
      ),
    );

    focusNode.requestFocus();
  }

  void findReplace() {
    final find = TextEditingController();
    final replace = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Find & Replace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: find,
              decoration: const InputDecoration(
                labelText: 'Find',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: replace,
              decoration: const InputDecoration(
                labelText: 'Replace with',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              final index = controller.text.indexOf(find.text);

              if (find.text.isNotEmpty && index >= 0) {
                controller.selection = TextSelection(
                  baseOffset: index,
                  extentOffset: index + find.text.length,
                );
              }
            },
            child: const Text('Find'),
          ),
          ElevatedButton(
            onPressed: () {
              if (find.text.isEmpty) return;

              setState(() {
                controller.text =
                    controller.text.replaceAll(find.text, replace.text);
                saved = false;
              });

              Navigator.pop(context);
            },
            child: const Text('Replace All'),
          ),
        ],
      ),
    );
  }

  void statistics() {
    final text = controller.text.trim();

    final words = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Document Statistics'),
        content: Text(
          'Words: $words\n'
          'Characters: ${controller.text.length}\n'
          'Characters without spaces: '
          '${controller.text.replaceAll(RegExp(r'\s'), '').length}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget tool(
    IconData icon,
    String label,
    VoidCallback action, {
    bool active = false,
  }) {
    return IconButton(
      tooltip: label,
      onPressed: action,
      icon: Icon(
        icon,
        color: active ? Colors.blue : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize * zoom,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      decoration: TextDecoration.combine([
        if (underline) TextDecoration.underline,
        if (strike) TextDecoration.lineThrough,
      ]),
      height: 1.5,
    );

    final text = controller.text.trim();
    final wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'TayyibWord — $fileName',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          tool(Icons.note_add, 'New', newDocument),
          tool(Icons.folder_open, 'Open', openDocument),
          tool(Icons.save, 'Save', saveDocument),
        ],
      ),
      body: Column(
        children: [
          Material(
            elevation: 2,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  tool(Icons.undo, 'Undo', controller.undo),
                  tool(Icons.redo, 'Redo', controller.redo),
                  tool(
                    Icons.select_all,
                    'Select All',
                    selectAll,
                  ),
                  tool(
                    Icons.format_bold,
                    'Bold',
                    () => setState(() => bold = !bold),
                    active: bold,
                  ),
                  tool(
                    Icons.format_italic,
                    'Italic',
                    () => setState(() => italic = !italic),
                    active: italic,
                  ),
                  tool(
                    Icons.format_underlined,
                    'Underline',
                    () => setState(() => underline = !underline),
                    active: underline,
                  ),
                  tool(
                    Icons.strikethrough_s,
                    'Strikethrough',
                    () => setState(() => strike = !strike),
                    active: strike,
                  ),
                  DropdownButton<double>(
                    value: fontSize,
                    underline: const SizedBox(),
                    items: const [
                      10,
                      12,
                      14,
                      16,
                      18,
                      20,
                      24,
                      28,
                      32,
                    ].map((value) {
                      return DropdownMenuItem<double>(
                        value: value.toDouble(),
                        child: Text('$value'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => fontSize = value);
                      }
                    },
                  ),
                  tool(
                    Icons.format_align_left,
                    'Align Left',
                    () => setState(() => alignment = TextAlign.left),
                  ),
                  tool(
                    Icons.format_align_center,
                    'Center',
                    () => setState(() => alignment = TextAlign.center),
                  ),
                  tool(
                    Icons.format_align_right,
                    'Align Right',
                    () => setState(() => alignment = TextAlign.right),
                  ),
                  tool(
                    Icons.format_align_justify,
                    'Justify',
                    () => setState(() => alignment = TextAlign.justify),
                  ),
                  tool(
                    Icons.format_list_bulleted,
                    'Bullets',
                    () => insertText('• '),
                  ),
                  tool(
                    Icons.format_list_numbered,
                    'Numbering',
                    () => insertText('1. '),
                  ),
                  tool(
                    Icons.format_indent_increase,
                    'Indent',
                    () => insertText('    '),
                  ),
                  tool(
                    Icons.search,
                    'Find & Replace',
                    findReplace,
                  ),
                  tool(
                    Icons.analytics_outlined,
                    'Statistics',
                    statistics,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFFE7E7E7),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    constraints: const BoxConstraints(
                      maxWidth: 820,
                      minHeight: 1050,
                    ),
                    padding: const EdgeInsets.all(60),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      maxLines: null,
                      textAlign: alignment,
                      style: style,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Start typing your document...',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 36,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Text(
                  saved ? 'Saved' : 'Unsaved changes',
                  style: TextStyle(
                    color: saved ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text('$wordCount words'),
                IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      zoom = (zoom - 0.1).clamp(0.6, 2.0);
                    });
                  },
                  icon: const Icon(Icons.remove, size: 18),
                ),
                Text('${(zoom * 100).round()}%'),
                IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      zoom = (zoom + 0.1).clamp(0.6, 2.0);
                    });
                  },
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
