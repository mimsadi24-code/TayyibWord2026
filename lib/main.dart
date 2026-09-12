// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const TayyibWordApp());

class TayyibWordApp extends StatelessWidget {
  const TayyibWordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TayyibWord',
      theme: ThemeData(
        useMaterial3: false,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF185ABD)),
      ),
      home: const TayyibWordHome(),
    );
  }
}

class TayyibWordHome extends StatelessWidget {
  const TayyibWordHome({super.key});

  static const engine = MethodChannel('tayyibword/engine');

  Future<void> newDocument() => engine.invokeMethod('newDocument');
  Future<void> openDocument() => engine.invokeMethod('openDocument');

  Widget button(IconData icon, String text, VoidCallback action) {
    return SizedBox(
      width: 72,
      child: InkWell(
        onTap: action,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26),
            const SizedBox(height: 2),
            Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget group(String name, List<Widget> children) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFFD0D6DD))),
      ),
      child: Column(
        children: [
          Expanded(child: Row(children: children)),
          Text(name, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE7E7E7),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 46,
              color: const Color(0xFF185ABD),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.description, color: Colors.white),
                  const SizedBox(width: 9),
                  const Text(
                    'TayyibWord',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Document',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(width: 14),
                ],
              ),
            ),

            Container(
              height: 34,
              color: const Color(0xFF124A8A),
              child: Row(
                children: [
                  button(Icons.save, 'Save', () {}),
                  button(Icons.undo, 'Undo', () {}),
                  button(Icons.redo, 'Redo', () {}),
                ],
              ),
            ),

            Container(
              height: 82,
              color: const Color(0xFFF5F6F8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    group('Clipboard', [
                      button(Icons.content_paste, 'Paste', () {}),
                    ]),
                    group('Font', [
                      button(Icons.format_bold, 'Bold', () {}),
                      button(Icons.format_italic, 'Italic', () {}),
                      button(Icons.format_underlined, 'Underline', () {}),
                    ]),
                    group('Paragraph', [
                      button(Icons.format_align_left, 'Align', () {}),
                      button(Icons.format_list_bulleted, 'Bullets', () {}),
                      button(Icons.format_list_numbered, 'Numbering', () {}),
                    ]),
                    group('Document', [
                      button(Icons.note_add, 'New', newDocument),
                      button(Icons.folder_open, 'Open', openDocument),
                    ]),
                  ],
                ),
              ),
            ),

            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 720),
                    padding: const EdgeInsets.all(32),
                    color: Colors.white,
                    child: Column(
                      children: [
                        const Icon(
                          Icons.description,
                          size: 78,
                          color: Color(0xFF185ABD),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'TayyibWord',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Word 2007-inspired interface powered by the native '
                          'Collabora / LibreOffice document engine.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 28),
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: newDocument,
                              icon: const Icon(Icons.note_add),
                              label: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                child: Text('Blank document'),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: openDocument,
                              icon: const Icon(Icons.folder_open),
                              label: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                child: Text('Open DOC / DOCX'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        const Text(
                          'The document editing engine is native Collabora/LibreOffice, '
                          'not a Flutter TextField.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Container(
              height: 28,
              color: const Color(0xFF185ABD),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: const Row(
                children: [
                  Text('Ready',
                      style: TextStyle(color: Colors.white, fontSize: 11)),
                  Spacer(),
                  Text(
                    'ARM64 • Collabora Engine',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
