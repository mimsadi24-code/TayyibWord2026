import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:archive/archive.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TayyibWord());
}

class TayyibWord extends StatelessWidget {
  const TayyibWord({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Tayyib Word',
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          quill.FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', 'US')],
        theme: ThemeData(useMaterial3: false, fontFamily: 'Arial'),
        home: const WordPage(),
      );
}

class WordPage extends StatefulWidget {
  const WordPage({super.key});
  @override
  State<WordPage> createState() => _WordPageState();
}

class _TextBoxModel {
  _TextBoxModel(this.text);
  _TextBoxModel.fromJson(Map<String, dynamic> j) : text = (j['text'] ?? '').toString() {
    width = (j['width'] as num?)?.toDouble() ?? 420;
    height = (j['height'] as num?)?.toDouble() ?? 90;
    x = (j['x'] as num?)?.toDouble() ?? 0;
    y = (j['y'] as num?)?.toDouble() ?? 0;
    bold = j['bold'] == true;
    final a = j['align'];
    align = a == 'center' ? TextAlign.center : a == 'right' ? TextAlign.right : TextAlign.left;
  }

  Map<String, dynamic> toJson() => {'text': text, 'width': width, 'height': height, 'x': x, 'y': y, 'bold': bold, 'align': align == TextAlign.center ? 'center' : align == TextAlign.right ? 'right' : 'left'};
  String text;
  double width = 420;
  double height = 90;
  double x = 0;
  double y = 0;
  TextAlign align = TextAlign.left;
  bool bold = false;
  void dispose() {}
}

class _TableModel {
  _TableModel(this.rows, this.cols) {
    cells = List.generate(rows, (_) => List.generate(cols, (_) => TextEditingController()));
  }
  int rows;
  int cols;
  late List<List<TextEditingController>> cells;
  double width = 620;
  double rowHeight = 42;
  String alignment = 'left';
  final Set<String> mergedCells = {};
  String borderStyle = 'grid';
  int selectedStartRow = -1, selectedStartCol = -1;
  int selectedEndRow = -1, selectedEndCol = -1;

  void selectCell(int r, int c) {
    if (selectedStartRow < 0) {
      selectedStartRow = selectedEndRow = r;
      selectedStartCol = selectedEndCol = c;
    } else {
      selectedEndRow = r;
      selectedEndCol = c;
    }
  }

  bool isSelected(int r, int c) {
    if (selectedStartRow < 0) return false;
    final r1 = math.min(selectedStartRow, selectedEndRow), r2 = math.max(selectedStartRow, selectedEndRow);
    final c1 = math.min(selectedStartCol, selectedEndCol), c2 = math.max(selectedStartCol, selectedEndCol);
    return r >= r1 && r <= r2 && c >= c1 && c <= c2;
  }

  String? mergedAnchorFor(int r, int c) {
    for (final key in mergedCells) {
      final p = key.split(':');
      if (p.length != 4) continue;
      final r1=int.tryParse(p[0]) ?? -1, c1=int.tryParse(p[1]) ?? -1, r2=int.tryParse(p[2]) ?? -1, c2=int.tryParse(p[3]) ?? -1;
      if (r >= r1 && r <= r2 && c >= c1 && c <= c2) return '$r1:$c1:$r2:$c2';
    }
    return null;
  }

  void dispose() {
    for (final row in cells) {
      for (final c in row) c.dispose();
    }
  }

  void addRow() {
    cells.add(List.generate(cols, (_) => TextEditingController()));
    rows++;
  }

  void addColumn() {
    for (final row in cells) row.add(TextEditingController());
    cols++;
  }

  void removeRow() {
    if (rows <= 1) return;
    final removed = cells.removeLast();
    for (final c in removed) c.dispose();
    rows--;
  }

  void removeColumn() {
    if (cols <= 1) return;
    for (final row in cells) row.removeLast().dispose();
    cols--;
  }
}

class _CommentModel {
  _CommentModel({required this.text, required this.comment, required this.start, required this.end, DateTime? created}) : created = created ?? DateTime.now();
  String text;
  String comment;
  int start;
  int end;
  DateTime created;
  Map<String, dynamic> toJson() => {
    'text': text, 'comment': comment, 'start': start, 'end': end, 'created': created.toIso8601String(),
  };
  static _CommentModel fromJson(Map<String, dynamic> j) => _CommentModel(
    text: '${j['text'] ?? ''}', comment: '${j['comment'] ?? ''}',
    start: (j['start'] as num?)?.toInt() ?? 0, end: (j['end'] as num?)?.toInt() ?? 0,
    created: DateTime.tryParse('${j['created'] ?? ''}'),
  );
}

class _TrackedChange {
  _TrackedChange({required this.before, required this.after, required this.start, required this.end, DateTime? created}) : created = created ?? DateTime.now();
  String before;
  String after;
  int start;
  int end;
  DateTime created;
  Map<String, dynamic> toJson() => {
    'before': before, 'after': after, 'start': start, 'end': end, 'created': created.toIso8601String(),
  };
  static _TrackedChange fromJson(Map<String, dynamic> j) => _TrackedChange(
    before: '${j['before'] ?? ''}', after: '${j['after'] ?? ''}',
    start: (j['start'] as num?)?.toInt() ?? 0, end: (j['end'] as num?)?.toInt() ?? 0,
    created: DateTime.tryParse('${j['created'] ?? ''}'),
  );
}


class _FootnoteModel {
  _FootnoteModel({required this.marker, required this.text});
  String marker;
  String text;
  Map<String,dynamic> toJson()=>{'marker':marker,'text':text};
  static _FootnoteModel fromJson(Map<String,dynamic> j)=>_FootnoteModel(marker:'${j['marker']??''}',text:'${j['text']??''}');
}

class _MergeRecipient {
  _MergeRecipient(this.name, this.email);
  String name;
  String email;
  Map<String,dynamic> toJson()=>{'name':name,'email':email};
  static _MergeRecipient fromJson(Map<String,dynamic> j)=>_MergeRecipient('${j['name']??''}','${j['email']??''}');
}

class _WordPageState extends State<WordPage> {
  final text = TextEditingController();
  late quill.QuillController _quill;
  bool _syncingQuill = false;
  final ribbon = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<TextEditingValue> _history = [];
  int _historyIndex = -1;
  bool _restoringHistory = false;

  int tab = 1;
  double zoom = .90;
  double size = 11;
  String font = 'Calibri';
  bool bold = false, italic = false, underline = false, strike = false;
  bool bullets = false, numbering = false;
  int indent = 0;
  double lineSpacing = 1.25;
  TextAlign align = TextAlign.left;
  Color textColor = Colors.black;
  Color? highlightColor;
  String documentName = 'Document1';
  String? insertedImagePath;
  final List<_TableModel> tables = [];
  final List<_TextBoxModel> textBoxes = [];
  int selectedTextBox = -1;
  int selectedTable = -1;
  int? pageNumber;
  String pageSizeName = 'A4';
  bool landscape = false;
  double marginTop = 70, marginBottom = 70, marginLeft = 82, marginRight = 82;
  int columns = 1;
  Color pageColor = Colors.white;
  String watermark = '';
  bool showRuler = true;
  String viewMode = 'Print Layout';
  bool trackChanges = false;
  final List<_CommentModel> commentModels = [];
  final List<String> comments = [];
  final List<String> citations = [];
  final List<_FootnoteModel> footnotes = [];
  final List<_FootnoteModel> endnotes = [];
  final List<_MergeRecipient> mergeData = [];
  String themeName = 'Office';
  String fontSetName = 'Office';
  String chartData = '12,28,20,35,24,42';
  String smartArtData = 'One|Two|Three';
  bool showParagraphBorders = false;
  String headerText = '';
  String footerText = '';
  String pageBorderStyle = 'None';
  bool superscript = false, subscript = false;
  bool showFormattingMarks = false;
  String styleName = 'Normal';
  String shapeKind = '';
  bool documentProtected = false;
  String protectionPassword = '';
  final List<String> changeLog = [];
  final List<_TrackedChange> trackedChanges = [];
  final List<String> mailRecipients = [];
  String wordArtText = '';
  String smartArtType = '';
  String chartType = '';
  bool dropCap = false;
  String equationText = '';
  final List<String> bookmarks = [];
  final List<String> indexEntries = [];
  String bibliographyStyle = 'APA';
  bool showGridlines = false;
  bool layoutPreview = false;
  bool keepWithNext = false;
  bool pageBreakBefore = false;
  bool showLineNumbers = false;
  bool hyphenation = false;
  bool differentFirstPage = false;
  bool differentOddEven = false;
  String tableStyle = 'Table Grid';
  double imageWidth = 420, imageHeight = 240;
  bool imageLockedAspect = true;
  String imageWrap = 'In Line';
  String imageCrop = 'None';
  String arrangeMode = 'In Front';
  String signatureText = '';
  String quickPartText = '';
  String coverTitle = '';

  final tabs = const ['Office', 'Home', 'Insert', 'Page Layout', 'References', 'Mailings', 'Review', 'View'];
  int get words {
    final x = text.text.trim();
    return x.isEmpty ? 0 : x.split(RegExp(r'\s+')).length;
  }

  @override
  void initState() {
    super.initState();
    _quill = quill.QuillController.basic();
    _quill.addListener(_syncFromQuill);
    _history.add(text.value);
    _historyIndex = 0;
    text.addListener(_recordHistory);
  }

  @override
  void dispose() {
    _quill.removeListener(_syncFromQuill);
    _quill.dispose();
    text.removeListener(_recordHistory);
    text.dispose();
    ribbon.dispose();
    for (final t in tables) t.dispose();
    for (final b in textBoxes) b.dispose();
    super.dispose();
  }

  void _syncFromQuill() {
    if (_syncingQuill) return;
    final plain = _quill.document.toPlainText();
    final sel = _quill.selection;
    final base = math.max(0, math.min(sel.baseOffset, plain.length));
    final extent = math.max(0, math.min(sel.extentOffset, plain.length));
    _syncingQuill = true;
    text.value = TextEditingValue(text: plain, selection: TextSelection(baseOffset: base, extentOffset: extent));
    _syncingQuill = false;
  }

  void _setPlainText(String value) {
    _syncingQuill = true;
    final old = _quill.document.toPlainText();
    if (old.isNotEmpty) {
      _quill.replaceText(0, old.length, value, TextSelection.collapsed(offset: value.length));
    } else if (value.isNotEmpty) {
      _quill.replaceText(0, 0, value, TextSelection.collapsed(offset: value.length));
    }
    text.value = TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length));
    _syncingQuill = false;
  }

  void _formatSelection(quill.Attribute attribute, bool enabled) {
    if (documentProtected) { toast('Document is protected'); return; }
    final s = _quill.selection;
    if (!s.isValid || s.isCollapsed) { toast('Select text first'); return; }
    _quill.formatSelection(enabled ? attribute : quill.Attribute.clone(attribute, null));
    _syncFromQuill();
  }

  void _recordHistory() {
    if (_restoringHistory) return;
    final v = text.value;
    if (trackChanges && !_restoringHistory && _history.isNotEmpty && _history.last.text != v.text) {
      final before = _history.last.text;
      final oldSel = _history.last.selection;
      final start = math.max(0, math.min(oldSel.start, before.length));
      final end = math.max(start, math.min(oldSel.end, before.length));
      trackedChanges.add(_TrackedChange(before: before, after: v.text, start: start, end: end));
      changeLog.add('Change ${trackedChanges.length}: ${before.length} → ${v.text.length} characters');
      if (trackedChanges.length > 100) trackedChanges.removeAt(0);
      if (changeLog.length > 100) changeLog.removeAt(0);
    }
    if (_historyIndex >= 0 && _history[_historyIndex].text == v.text && _history[_historyIndex].selection == v.selection) return;
    if (_historyIndex < _history.length - 1) _history.removeRange(_historyIndex + 1, _history.length);
    _history.add(v);
    if (_history.length > 100) _history.removeAt(0);
    _historyIndex = _history.length - 1;
    if (mounted) setState(() {});
  }

  void _applyHistory(int index) {
    if (index < 0 || index >= _history.length) return;
    _restoringHistory = true;
    _setPlainText(_history[index].text);
    _quill.updateSelection(_history[index].selection, quill.ChangeSource.local);
    _restoringHistory = false;
    setState(() => _historyIndex = index);
  }

  void undo() => _applyHistory(_historyIndex - 1);
  void redo() => _applyHistory(_historyIndex + 1);

  void _resetHistory() {
    _history.clear();
    _history.add(text.value);
    _historyIndex = 0;
  }

  Future<Directory> _docs() => getApplicationDocumentsDirectory();

  Map<String, dynamic> _documentJson() => {
    'format': 'twd', 'version': 8, 'name': documentName, 'text': text.text,
    'quillDelta': _quill.document.toDelta().map((x) => x.toJson()).toList(),
    'font': font, 'size': size, 'bold': bold, 'italic': italic, 'underline': underline,
    'strike': strike, 'align': align == TextAlign.center ? 'center' : align == TextAlign.right ? 'right' : 'left',
    'textColor': textColor.value, 'highlightColor': highlightColor?.value,
    'pageSize': pageSizeName, 'landscape': landscape, 'margins': [marginTop, marginRight, marginBottom, marginLeft],
    'columns': columns, 'pageColor': pageColor.value, 'watermark': watermark, 'showRuler': showRuler,
    'viewMode': viewMode, 'trackChanges': trackChanges,
    'comments': commentModels.map((x) => x.toJson()).toList(),
    'legacyComments': comments, 'trackedChanges': trackedChanges.map((x) => x.toJson()).toList(),
    'citations': citations,
    'footnotes': footnotes.map((x)=>x.toJson()).toList(), 'endnotes': endnotes.map((x)=>x.toJson()).toList(),
    'mergeData': mergeData.map((x)=>x.toJson()).toList(), 'themeName': themeName, 'fontSetName': fontSetName,
    'chartData': chartData, 'smartArtData': smartArtData, 'showParagraphBorders': showParagraphBorders,
    'headerText': headerText, 'footerText': footerText, 'pageBorderStyle': pageBorderStyle,
    'superscript': superscript, 'subscript': subscript, 'showFormattingMarks': showFormattingMarks,
    'styleName': styleName, 'shapeKind': shapeKind, 'documentProtected': documentProtected,
    'changeLog': changeLog, 'mailRecipients': mailRecipients,
    'wordArtText': wordArtText, 'smartArtType': smartArtType, 'chartType': chartType, 'dropCap': dropCap, 'equationText': equationText, 'bookmarks': bookmarks, 'indexEntries': indexEntries, 'bibliographyStyle': bibliographyStyle,
    'pageNumber': pageNumber, 'insertedImagePath': insertedImagePath,
    'showGridlines': showGridlines, 'showLineNumbers': showLineNumbers, 'hyphenation': hyphenation,
    'differentFirstPage': differentFirstPage, 'differentOddEven': differentOddEven, 'tableStyle': tableStyle, 'layoutPreview': layoutPreview, 'keepWithNext': keepWithNext, 'pageBreakBefore': pageBreakBefore,
    'imageWidth': imageWidth, 'imageHeight': imageHeight, 'imageLockedAspect': imageLockedAspect, 'imageWrap': imageWrap, 'arrangeMode': arrangeMode, 'objectX': objectX, 'objectY': objectY, 'objectRotation': objectRotation, 'objectWrap': objectWrap,
    'signatureText': signatureText, 'quickPartText': quickPartText, 'coverTitle': coverTitle,
    'textBoxes': textBoxes.map((b) => b.toJson()).toList(),
    'tables': tables.map((t) => {'rows': t.rows, 'cols': t.cols, 'width': t.width, 'rowHeight': t.rowHeight,
      'cells': t.cells.map((r) => r.map((c) => c.text).toList()).toList(), 'alignment': t.alignment, 'mergedCells': t.mergedCells.toList(), 'borderStyle': t.borderStyle}).toList(),
  };

  Future<void> saveDocument() async {
    final controller = TextEditingController(text: documentName);
    final name = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: const Text('Save Tayyib Word document'),
      content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'File name', suffixText: '.twd')),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(c, controller.text.trim()), child: const Text('Save'))],
    ));
    controller.dispose();
    if (name == null || name.isEmpty) return;
    final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final dir = await _docs();
    await File('${dir.path}/$safe.twd').writeAsString(jsonEncode(_documentJson()));
    if (!mounted) return;
    setState(() => documentName = safe);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved: $safe.twd')));
  }

  Future<void> openDocument() async {
    final dir = await _docs();
    final files = dir.listSync().whereType<File>().where((f) => f.path.toLowerCase().endsWith('.twd') || f.path.toLowerCase().endsWith('.txt') || f.path.toLowerCase().endsWith('.docx')).toList();
    if (files.isEmpty) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No saved documents yet.'))); return; }
    final picked = await showDialog<File>(context: context, builder: (c) => SimpleDialog(
      title: const Text('Open document'), children: [for (final f in files) SimpleDialogOption(onPressed: () => Navigator.pop(c, f), child: Align(alignment: Alignment.centerLeft, child: Text(f.uri.pathSegments.last)))],
    ));
    if (picked == null) return;
    if (picked.path.toLowerCase().endsWith('.docx')) { await _importDocx(picked); return; }
    final raw = await picked.readAsString();
    if (picked.path.toLowerCase().endsWith('.txt')) { _setPlainText(raw); _resetHistory(); setState(() => documentName = picked.uri.pathSegments.last.replaceFirst(RegExp(r'\.txt$'), '')); return; }
    _loadDocumentJson(jsonDecode(raw) as Map<String, dynamic>);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document restored with formatting and layout.')));
  }

  void _loadDocumentJson(Map<String, dynamic> j) {
    for (final t in tables) t.dispose();
    final newTables = <_TableModel>[];
    for (final raw in (j['tables'] as List? ?? const [])) {
      final m = raw as Map<String, dynamic>; final t = _TableModel((m['rows'] as num?)?.toInt() ?? 1, (m['cols'] as num?)?.toInt() ?? 1);
      t.width = (m['width'] as num?)?.toDouble() ?? 620; t.rowHeight = (m['rowHeight'] as num?)?.toDouble() ?? 42; t.alignment = '${m['alignment'] ?? 'left'}'; t.borderStyle = '${m['borderStyle'] ?? 'grid'}'; t.mergedCells.addAll((m['mergedCells'] as List? ?? const []).map((e) => '$e'));
      final cells = m['cells'] as List? ?? const [];
      for (var r = 0; r < t.rows && r < cells.length; r++) { final row = cells[r] as List? ?? const []; for (var c = 0; c < t.cols && c < row.length; c++) t.cells[r][c].text = '${row[c]}'; }
      newTables.add(t);
    }
    final boxes = (j['textBoxes'] as List? ?? const []).map((x) => _TextBoxModel.fromJson(x as Map<String, dynamic>)).toList();
    _restoringHistory = true;
    final deltaRaw = j['quillDelta'];
    if (deltaRaw is List && deltaRaw.isNotEmpty) {
      try {
        final doc = quill.Document.fromJson(List<dynamic>.from(deltaRaw));
        _quill.dispose();
        _quill = quill.QuillController(document: doc);
        _quill.addListener(_syncFromQuill);
        _syncFromQuill();
      } catch (_) { _setPlainText('${j['text'] ?? ''}'); }
    } else { _setPlainText('${j['text'] ?? ''}'); }
    _restoringHistory = false;
    setState(() {
      documentName = '${j['name'] ?? 'Document1'}'; font = '${j['font'] ?? 'Calibri'}'; size = (j['size'] as num?)?.toDouble() ?? 11;
      bold = j['bold'] == true; italic = j['italic'] == true; underline = j['underline'] == true; strike = j['strike'] == true;
      final a = j['align']; align = a == 'center' ? TextAlign.center : a == 'right' ? TextAlign.right : TextAlign.left;
      textColor = Color((j['textColor'] as num?)?.toInt() ?? Colors.black.value); highlightColor = j['highlightColor'] == null ? null : Color((j['highlightColor'] as num).toInt());
      pageSizeName = '${j['pageSize'] ?? 'A4'}'; landscape = j['landscape'] == true; final m = (j['margins'] as List?)?.map((x) => (x as num).toDouble()).toList() ?? [70,82,70,82];
      marginTop = m.elementAtOrNull(0) ?? 70; marginRight = m.elementAtOrNull(1) ?? 82; marginBottom = m.elementAtOrNull(2) ?? 70; marginLeft = m.elementAtOrNull(3) ?? 82;
      columns = (j['columns'] as num?)?.toInt() ?? 1; pageColor = Color((j['pageColor'] as num?)?.toInt() ?? Colors.white.value); watermark = '${j['watermark'] ?? ''}'; showRuler = j['showRuler'] != false;
      viewMode = '${j['viewMode'] ?? 'Print Layout'}'; trackChanges = j['trackChanges'] == true;
      commentModels..clear()..addAll((j['comments'] as List? ?? const []).whereType<Map>().map((e) => _CommentModel.fromJson(Map<String,dynamic>.from(e))));
      comments..clear()..addAll((j['legacyComments'] as List? ?? const []).map((e) => '$e'));
      footnotes..clear()..addAll((j['footnotes'] as List? ?? const []).whereType<Map>().map((e)=>_FootnoteModel.fromJson(Map<String,dynamic>.from(e)))); endnotes..clear()..addAll((j['endnotes'] as List? ?? const []).whereType<Map>().map((e)=>_FootnoteModel.fromJson(Map<String,dynamic>.from(e))));
      mergeData..clear()..addAll((j['mergeData'] as List? ?? const []).whereType<Map>().map((e)=>_MergeRecipient.fromJson(Map<String,dynamic>.from(e))));
      trackedChanges..clear()..addAll((j['trackedChanges'] as List? ?? const []).whereType<Map>().map((e) => _TrackedChange.fromJson(Map<String,dynamic>.from(e)))); citations..clear()..addAll((j['citations'] as List? ?? const []).map((e) => '$e')); themeName='${j['themeName']??'Office'}'; fontSetName='${j['fontSetName']??'Office'}'; chartData='${j['chartData']??'12,28,20,35,24,42'}'; smartArtData='${j['smartArtData']??'One|Two|Three'}'; showParagraphBorders=j['showParagraphBorders']==true;
      headerText = '${j['headerText'] ?? ''}'; footerText = '${j['footerText'] ?? ''}'; pageBorderStyle = '${j['pageBorderStyle'] ?? 'None'}';
      superscript = j['superscript'] == true; subscript = j['subscript'] == true; showFormattingMarks = j['showFormattingMarks'] == true; styleName = '${j['styleName'] ?? 'Normal'}'; shapeKind = '${j['shapeKind'] ?? ''}'; documentProtected = j['documentProtected'] == true;
      changeLog..clear()..addAll((j['changeLog'] as List? ?? const []).map((e) => '$e')); mailRecipients..clear()..addAll((j['mailRecipients'] as List? ?? const []).map((e) => '$e'));
      wordArtText = '${j['wordArtText'] ?? ''}'; smartArtType = '${j['smartArtType'] ?? ''}'; chartType = '${j['chartType'] ?? ''}'; dropCap = j['dropCap'] == true; equationText = '${j['equationText'] ?? ''}'; bookmarks..clear()..addAll((j['bookmarks'] as List? ?? const []).map((e) => '$e')); indexEntries..clear()..addAll((j['indexEntries'] as List? ?? const []).map((e) => '$e')); bibliographyStyle = '${j['bibliographyStyle'] ?? 'APA'}';
      pageNumber = (j['pageNumber'] as num?)?.toInt(); insertedImagePath = j['insertedImagePath'] as String?; objectX = (j['objectX'] as num?)?.toDouble() ?? 0; objectY = (j['objectY'] as num?)?.toDouble() ?? 0; objectRotation = (j['objectRotation'] as num?)?.toDouble() ?? 0; objectWrap = '${j['objectWrap'] ?? 'In Line'}';
      tables..clear()..addAll(newTables); textBoxes..clear()..addAll(boxes); selectedTextBox = boxes.isEmpty ? -1 : 0;
    });
    _resetHistory();
  }

  String _xmlUnescape(String x) => x.replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&quot;', '"').replaceAll('&apos;', "'").replaceAll(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.tryParse(m.group(1)!) ?? 32));

  Future<void> _importDocx(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final entry = archive.findFile('word/document.xml');
      if (entry == null) { toast('DOCX document.xml not found'); return; }
      final xml = utf8.decode(entry.content as List<int>, allowMalformed: true);
      String partText(String name) {
        final e=archive.findFile(name); if(e==null)return ''; var x=utf8.decode(e.content as List<int>,allowMalformed:true); x=x.replaceAll(RegExp(r'<w:br[^>]*/>'),'\n').replaceAll(RegExp(r'</w:p>'),'\n').replaceAll(RegExp(r'<[^>]+>'),''); return _xmlUnescape(x).trim();
      }
      final importedHeader=partText('word/header1.xml');
      final importedFooter=partText('word/footer1.xml');
      // OOXML recovery: restore basic tables, headers/footers and paragraph text.
      final importedTables = <_TableModel>[];
      for (final tm in RegExp(r'<w:tbl[\s\S]*?</w:tbl>', caseSensitive: false).allMatches(xml)) {
        final tbl = tm.group(0)!;
        final rowsXml = RegExp(r'<w:tr[\s\S]*?</w:tr>', caseSensitive: false).allMatches(tbl).toList();
        if (rowsXml.isEmpty) continue;
        final rowCells = <List<String>>[];
        for (final rm in rowsXml) {
          final cells=<String>[];
          for (final cm in RegExp(r'<w:tc[\s\S]*?</w:tc>', caseSensitive: false).allMatches(rm.group(0)!)) {
            var v=cm.group(0)!; v=v.replaceAll(RegExp(r'<w:br[^>]*/>',caseSensitive:false),'\n'); v=v.replaceAll(RegExp(r'<[^>]+>'),'');
            cells.add(_xmlUnescape(v).trim());
          }
          if(cells.isNotEmpty) rowCells.add(cells);
        }
        final cols=rowCells.fold<int>(1,(m,r)=>math.max(m,r.length));
        final t=_TableModel(math.max(1,rowCells.length),cols);
        for(var r=0;r<rowCells.length;r++){for(var c=0;c<rowCells[r].length;c++){t.cells[r][c].text=rowCells[r][c];}}
        importedTables.add(t);
      }
      for (final t in tables) t.dispose();
      tables..clear()..addAll(importedTables);
      var body = xml.replaceAll(RegExp(r'<w:tbl[\s\S]*?</w:tbl>', caseSensitive: false), '');
      body = body.replaceAll(RegExp(r'<w:tab[^>]*/>'), '\t');
      body = body.replaceAll(RegExp(r'<w:br[^>]*/>'), '\n');
      body = body.replaceAll(RegExp(r'</w:p>'), '\n');
      body = body.replaceAll(RegExp(r'</w:tr>'), '\n');
      body = body.replaceAll(RegExp(r'</w:tc>'), '\t');
      body = body.replaceAll(RegExp(r'<[^>]+>'), '');
      body = body.replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&quot;', '"').replaceAll('&apos;', "'");
      body = body.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
      if (body.isEmpty) body = '(Empty DOCX document)';
      _restoringHistory = true;
      _setPlainText(body);
      _restoringHistory = false;
      _resetHistory();
      if (mounted) setState(() {
        documentName = file.uri.pathSegments.last.replaceFirst(RegExp(r'\.docx$', caseSensitive: false), '');
        headerText = importedHeader; footerText = importedFooter;
        tab = 1;
      });
      toast('DOCX imported. Text, paragraphs and tables were recovered.');
    } catch (e) {
      toast('DOCX import failed: $e');
    }
  }

  Future<void> exportPdf() async {
    final doc = pw.Document();
    final sizeMap = <String, pw.PdfPageFormat>{
      'A4': pw.PdfPageFormat.a4,
      'A5': pw.PdfPageFormat.a5,
      'Letter': pw.PdfPageFormat.letter,
      'Legal': pw.PdfPageFormat.legal,
    };
    var format = sizeMap[pageSizeName] ?? pw.PdfPageFormat.a4;
    if (landscape) format = format.landscape;
    final chunks = text.text.split('--- PAGE BREAK ---');
    final content = chunks.map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    final body = content.isEmpty ? [''] : content;
    doc.addPage(pw.MultiPage(
      pageFormat: format,
      margin: pw.EdgeInsets.fromLTRB(marginLeft, marginTop, marginRight, marginBottom),
      header: (ctx) { final show = !(differentFirstPage && ctx.pageNumber == 1); final even = ctx.pageNumber % 2 == 0; final h = (differentOddEven && even) ? (headerText.isEmpty ? '' : '$headerText  •  Even') : headerText; return !show || h.isEmpty ? pw.SizedBox() : pw.Container(alignment: pw.Alignment.center, margin: const pw.EdgeInsets.only(bottom: 8), child: pw.Text(h, style: pw.TextStyle(fontSize: math.max(8, size - 1)))); },
      footer: (ctx) { final show = !(differentFirstPage && ctx.pageNumber == 1); final even = ctx.pageNumber % 2 == 0; final f = (differentOddEven && even) ? (footerText.isEmpty ? '' : '$footerText  •  Even') : footerText; return !show ? pw.SizedBox() : pw.Container(alignment: pw.Alignment.center, margin: const pw.EdgeInsets.only(top: 8), child: pw.Text(f.isNotEmpty ? '$f   ${ctx.pageNumber}' : '${ctx.pageNumber}', style: const pw.TextStyle(fontSize: 8))); },
      build: (_) {
        final widgets = <pw.Widget>[];
        for (var i = 0; i < body.length; i++) {
          final lines = body[i].split('\n');
          if (columns <= 1) {
            widgets.add(pw.Text(lines.join('\n'), style: pw.TextStyle(fontSize: size)));
          } else {
            widgets.add(pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              for (var col = 0; col < columns; col++)
                pw.Expanded(child: pw.Padding(padding: pw.EdgeInsets.only(right: col == columns - 1 ? 0 : 12), child: pw.Text(lines.sublist((lines.length * col) ~/ columns, (lines.length * (col + 1)) ~/ columns).join('\n'), style: pw.TextStyle(fontSize: size)))),
            ]));
          }
          if (i < body.length - 1) widgets.add(pw.SizedBox(height: 18));
        }
        return widgets;
      },
    ));
    await Printing.sharePdf(bytes: await doc.save(), filename: '$documentName.pdf');
  }

  Future<void> exportDocx() async {
    String esc(String x) => x.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;').replaceAll("'",'&apos;');
    final sizeMap = <String, List<int>>{
      'A4': [11906, 16838], 'A5': [8391, 11906], 'Letter': [12240, 15840], 'Legal': [12240, 20160]
    };
    final ps = sizeMap[pageSizeName] ?? sizeMap['A4']!;
    final pwv = landscape ? ps[1] : ps[0], phv = landscape ? ps[0] : ps[1];
    final bodyParts = <String>[];
    String runXml(String value, Map<String, dynamic> attrs) {
      final rpr = StringBuffer('<w:rPr>');
      if (attrs['bold'] == true) rpr.write('<w:b/>');
      if (attrs['italic'] == true) rpr.write('<w:i/>');
      if (attrs['underline'] != null && attrs['underline'] != false) rpr.write('<w:u w:val="single"/>');
      if (attrs['strike'] == true) rpr.write('<w:strike/>');
      if (attrs['script'] == 'super') rpr.write('<w:vertAlign w:val="superscript"/>');
      if (attrs['script'] == 'sub') rpr.write('<w:vertAlign w:val="subscript"/>');
      final fam = attrs['font'];
      if (fam is String && fam.isNotEmpty) rpr.write('<w:rFonts w:ascii="${esc(fam)}" w:hAnsi="${esc(fam)}"/>');
      final fs = attrs['size'];
      if (fs != null) { final n = double.tryParse('$fs'); if (n != null) rpr.write('<w:sz w:val="${(n * 2).round()}"/>'); }
      rpr.write('</w:rPr>');
      return '<w:r>$rpr<w:t xml:space="preserve">${esc(value)}</w:t></w:r>';
    }
    final paragraphRuns = StringBuffer();
    String paragraph() => '<w:p><w:pPr><w:jc w:val="${align == TextAlign.center ? 'center' : align == TextAlign.right ? 'right' : align == TextAlign.justify ? 'both' : 'left'}"/><w:spacing w:line="${(lineSpacing * 240).round()}" w:lineRule="auto"/></w:pPr>$paragraphRuns</w:p>';
    for (final op in _quill.document.toDelta().toJson()) {
      final insert = op['insert'];
      if (insert is! String) continue;
      final attrs = Map<String, dynamic>.from((op['attributes'] as Map?)?.cast<String, dynamic>() ?? const {});
      final parts = insert.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty) paragraphRuns.write(runXml(parts[i], attrs));
        if (i < parts.length - 1) { bodyParts.add(paragraph()); paragraphRuns.clear(); }
      }
    }
    if (paragraphRuns.isNotEmpty || bodyParts.isEmpty) bodyParts.add(paragraph());
    for (var i = 0; i < bodyParts.length; i++) {
      if (bodyParts[i].contains('--- PAGE BREAK ---')) bodyParts[i] = '<w:p><w:r><w:br w:type="page"/></w:r></w:p>';
    }
    for (final t in tables) {
      final rows = StringBuffer('<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblBorders><w:top w:val="single"/><w:left w:val="single"/><w:bottom w:val="single"/><w:right w:val="single"/><w:insideH w:val="single"/><w:insideV w:val="single"/></w:tblBorders></w:tblPr>');
      for (var rr=0; rr<t.rows; rr++) {
        rows.write('<w:tr>');
        for (var cc=0; cc<t.cols; cc++) {
          final anchor=t.mergedAnchorFor(rr,cc);
          if(anchor!=null){ final p=anchor.split(':').map((x)=>int.tryParse(x)??0).toList(); if(rr!=p[0]||cc!=p[1]) continue; final span=p[3]-p[1]+1; rows.write('<w:tc><w:tcPr>${span>1?'<w:gridSpan w:val="$span"/>':''}</w:tcPr><w:p><w:r><w:t xml:space="preserve">${esc(t.cells[rr][cc].text)}</w:t></w:r></w:p></w:tc>');
          } else { rows.write('<w:tc><w:p><w:r><w:t xml:space="preserve">${esc(t.cells[rr][cc].text)}</w:t></w:r></w:p></w:tc>'); }
        }
        rows.write('</w:tr>');
      }
      rows.write('</w:tbl>'); bodyParts.add(rows.toString());
    }
    if(footnotes.isNotEmpty){ bodyParts.add('<w:p><w:r><w:t>Footnotes</w:t></w:r></w:p>'); for(final f in footnotes){bodyParts.add('<w:p><w:r><w:t>[${esc(f.marker)}] ${esc(f.text)}</w:t></w:r></w:p>');} }
    if(endnotes.isNotEmpty){ bodyParts.add('<w:p><w:r><w:t>Endnotes</w:t></w:r></w:p>'); for(final f in endnotes){bodyParts.add('<w:p><w:r><w:t>[${esc(f.marker)}] ${esc(f.text)}</w:t></w:r></w:p>');} }
    final refs = StringBuffer();
    final rels = StringBuffer('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
    if (headerText.isNotEmpty) { refs.write('<w:headerReference w:type="default" r:id="rId2"/>'); rels.write('<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>'); }
    if (footerText.isNotEmpty) { refs.write('<w:footerReference w:type="default" r:id="rId3"/>'); rels.write('<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>'); }
    rels.write('</Relationships>');
    final variants = '${differentFirstPage ? '<w:titlePg/>' : ''}${differentOddEven ? '<w:evenAndOddHeaders/>' : ''}';
    final sect = '<w:sectPr>$refs$variants<w:pgSz w:w="$pwv" w:h="$phv"/><w:pgMar w:top="${marginTop.round()}" w:right="${marginRight.round()}" w:bottom="${marginBottom.round()}" w:left="${marginLeft.round()}"/>${columns > 1 ? '<w:cols w:num="$columns"/>' : ''}</w:sectPr>';
    final documentXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:body>${bodyParts.join()}$sect</w:body></w:document>';
    final archive = Archive();
    void add(String name, String value) { final data = utf8.encode(value); archive.addFile(ArchiveFile(name, data.length, data)); }
    var ct = '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>';
    if (headerText.isNotEmpty) ct += '<Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>';
    if (footerText.isNotEmpty) ct += '<Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>';
    ct += '</Types>';
    add('[Content_Types].xml', ct);
    add('_rels/.rels','<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>');
    add('word/_rels/document.xml.rels', rels.toString());
    add('word/document.xml', documentXml);
    add('word/settings.xml','<?xml version="1.0" encoding="UTF-8"?><w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:zoom w:percent="100"/></w:settings>');
    if (headerText.isNotEmpty) add('word/header1.xml','<?xml version="1.0" encoding="UTF-8"?><w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:t>${esc(headerText)}</w:t></w:r></w:p></w:hdr>');
    if (footerText.isNotEmpty) add('word/footer1.xml','<?xml version="1.0" encoding="UTF-8"?><w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:t>${esc(footerText)}</w:t></w:r></w:p></w:ftr>');
    final bytes = ZipEncoder().encode(archive);
    if (bytes == null) return;
    final dir = await _docs(); final file = File('${dir.path}/$documentName.docx');
    await file.writeAsBytes(bytes, flush: true);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DOCX saved: ${file.path}')));
  }

  Future<void> openExternalFile() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['twd','txt','docx']);
    if (r?.files.single.path == null) return;
    final f = File(r!.files.single.path!);
    if (f.path.toLowerCase().endsWith('.docx')) { await _importDocx(f); return; }
    final raw = await f.readAsString();
    if (f.path.toLowerCase().endsWith('.twd')) _loadDocumentJson(jsonDecode(raw) as Map<String, dynamic>); else { _setPlainText(raw); _resetHistory(); }
    if (mounted) setState(() => documentName = f.uri.pathSegments.last.replaceFirst(RegExp(r'\.(twd|txt)$', caseSensitive: false), '')); 
  }

  Future<void> unlockDocument() async {
    if (!documentProtected) return;
    final c = TextEditingController();
    final v = await showDialog<String>(context: context, builder: (d) => AlertDialog(
      title: const Text('Unlock Document'),
      content: TextField(controller: c, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Unlock'))],
    ));
    c.dispose();
    if (v == null) return;
    if (v == protectionPassword) setState(() { documentProtected = false; }); else toast('Incorrect password');
  }

  void newDocument() {
    _restoringHistory = true;
    _setPlainText('');
    _restoringHistory = false;
    _resetHistory();
    for (final t in tables) t.dispose();
    for (final b in textBoxes) b.dispose();
    setState(() {
      tables.clear();
      textBoxes.clear();
      commentModels.clear();
      trackedChanges.clear();
      selectedTextBox = -1;
      insertedImagePath = null;
      selectedTable = -1;
      pageNumber = null;
      documentName = 'Document1';
      bold = italic = underline = strike = false;
      bullets = numbering = false;
      indent = 0;
      lineSpacing = 1.25;
      align = TextAlign.left;
      size = 11;
      font = 'Calibri';
      textColor = Colors.black;
      highlightColor = null;
      tab = 1;
      pageSizeName = 'A4'; landscape = false; marginTop = marginBottom = 70; marginLeft = marginRight = 82; columns = 1; pageColor = Colors.white; watermark = ''; showRuler = true; viewMode = 'Print Layout'; trackChanges = false; comments.clear(); citations.clear();
      headerText = ''; footerText = ''; pageBorderStyle = 'None'; superscript = subscript = false; showFormattingMarks = false; styleName = 'Normal'; shapeKind = ''; documentProtected = false; protectionPassword = ''; changeLog.clear(); mailRecipients.clear(); wordArtText = ''; smartArtType = ''; chartType = ''; dropCap = false; equationText = ''; bookmarks.clear(); indexEntries.clear(); bibliographyStyle = 'APA'; footnotes.clear(); endnotes.clear(); mergeData.clear(); themeName='Office'; fontSetName='Office'; chartData='12,28,20,35,24,42'; smartArtData='One|Two|Three'; showParagraphBorders=false;
    });
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: const Color(0xffe7e7e7),
        body: SafeArea(
          child: Column(
            children: [
              titleBar(),
              tabBar(),
              if (tab == 1) homeRibbon() else if (tab == 2) insertRibbon() else otherRibbon(),
              if (tab == 1) richToolbar(),
              Expanded(child: document()),
              status(),
            ],
          ),
        ),
      );

  Widget titleBar() => Container(
        height: 58,
        color: const Color(0xff185abd),
        child: Row(children: [
          icon(Icons.save_outlined, saveDocument),
          icon(Icons.picture_as_pdf, exportPdf),
          icon(Icons.description_outlined, exportDocx),
          icon(Icons.folder_open, openExternalFile),
          icon(Icons.undo, undo),
          icon(Icons.redo, redo),
          const SizedBox(width: 4),
          Expanded(child: Center(child: Text('$documentName - Tayyib Word', style: const TextStyle(color: Colors.white, fontSize: 18)))),
          icon(Icons.search, findText),
          icon(Icons.more_vert, () {}),
        ]),
      );

  Widget icon(IconData x, VoidCallback onTap) => SizedBox(width: 48, height: 58, child: IconButton(onPressed: onTap, icon: Icon(x, color: Colors.white, size: 25)));

  Widget tabBar() => Container(
        height: 48,
        color: const Color(0xff185abd),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: List.generate(tabs.length, (n) {
            final on = n == tab;
            return InkWell(
              onTap: () => setState(() => tab = n),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 25),
                color: on ? Colors.white : Colors.transparent,
                alignment: Alignment.center,
                child: Text(tabs[n], style: TextStyle(color: on ? const Color(0xff185abd) : Colors.white, fontSize: 15, fontWeight: on ? FontWeight.w600 : FontWeight.normal)),
              ),
            );
          })),
        ),
      );

  Widget richToolbar() => Container(
    height: 54,
    color: const Color(0xfffafafa),
    child: quill.QuillSimpleToolbar(
      controller: _quill,
      config: quill.QuillSimpleToolbarConfig(
        multiRowsDisplay: false,
        showHeaderStyle: true,
        showFontFamily: true,
        showFontSize: true,
        showBoldButton: true,
        showItalicButton: true,
        showUnderLineButton: true,
        showStrikeThrough: true,
        showColorButton: true,
        showBackgroundColorButton: true,
        showAlignmentButtons: true,
        showListBullets: true,
        showListNumbers: true,
        showIndent: true,
        showLink: true,
        showClearFormat: true,
        showUndo: true,
        showRedo: true,
      ),
    ),
  );

  Widget homeRibbon() => Container(
        height: 172,
        color: Colors.white,
        child: Scrollbar(
          controller: ribbon,
          thumbVisibility: true,
          child: SingleChildScrollView(controller: ribbon, scrollDirection: Axis.horizontal, child: Row(children: [clipboard(), fontGroup(), paragraph(), editing()])),
        ),
      );

  Widget otherRibbon() {
    if (tab == 0) return Container(height: 172, color: Colors.white, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: fileRibbon()));
    switch (tab) {
      case 3: return pageLayoutRibbon();
      case 4: return referencesRibbon();
      case 5: return mailingsRibbon();
      case 6: return reviewRibbon();
      case 7: return viewRibbon();
      default: return const SizedBox(height: 172);
    }
  }

  Widget ribbonShell(List<Widget> groups) => Container(height: 172, color: Colors.white, child: Scrollbar(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: groups))));
  Widget pageLayoutRibbon() => ribbonShell([
    group('Themes', 360, Row(children: [btn(Icons.palette_outlined, 'Themes', chooseTheme), btn(Icons.format_color_text, 'Fonts', chooseFontSet)])),
    group('Page Setup', 560, Row(children: [btn(Icons.margin, 'Margins', pageMargins), btn(Icons.crop_portrait, 'Orientation', pageOrientation), btn(Icons.description_outlined, 'Size', pageSize), btn(Icons.view_column, 'Columns', pageColumns), btn(Icons.insert_page_break, 'Breaks', insertPageBreak)])),
    group('Page Background', 430, Row(children: [btn(Icons.water_drop_outlined, 'Watermark', insertWatermark), btn(Icons.format_color_fill, 'Page Color', choosePageColor), btn(Icons.border_outer, 'Page Borders', choosePageBorder)])),
    group('Paragraph', 300, Row(children: [btn(Icons.format_indent_decrease, 'Indent −', () => setState(() => indent = math.max(0, indent - 1))), btn(Icons.format_indent_increase, 'Indent +', () => setState(() => indent = math.min(6, indent + 1))), btn(Icons.format_line_spacing, 'Spacing', chooseSpacing)])),
    group('Arrange', 390, Row(children: [btn(Icons.wrap_text, 'Wrap', chooseImageWrap), btn(Icons.layers, 'Arrange', chooseArrange), btn(Icons.open_with, 'Position', objectTransformSettings), btn(Icons.text_rotation_none, 'Rotate', objectTransformSettings)])),
    group('Page Options', 650, Row(children: [btn(Icons.format_list_numbered, 'Line No.', () => setState(() => showLineNumbers = !showLineNumbers)), btn(Icons.grid_on, 'Gridlines', () => setState(() => showGridlines = !showGridlines)), btn(Icons.text_rotation_none, 'Hyphenation', () => setState(() => hyphenation = !hyphenation)), btn(Icons.looks_one_outlined, 'First Page', () => setState(() => differentFirstPage = !differentFirstPage)), btn(Icons.swap_vert, 'Odd/Even', () => setState(() => differentOddEven = !differentOddEven)), btn(Icons.pages_outlined, 'Layout Preview', () => setState(() => layoutPreview = !layoutPreview))])),
  ]);
  Widget referencesRibbon() => ribbonShell([
    group('Table of Contents', 300, Row(children: [cmd(Icons.menu_book_outlined, 'TOC', onTap: insertToc), cmd(Icons.format_list_numbered, 'Index', onTap: insertIndexField), cmd(Icons.note_add_outlined, 'Footnote', onTap: ()=>insertFootnote()), cmd(Icons.notes_outlined, 'Endnote', onTap: ()=>insertFootnote(endnote:true))])),
    group('Footnotes', 250, Row(children: [btn(Icons.note_add_outlined, 'Footnote', insertFootnote), btn(Icons.note_outlined, 'Endnote', insertEndnote)])),
    group('Citations', 420, Row(children: [btn(Icons.format_quote, 'Citation', insertCitation), btn(Icons.menu_book, 'Bibliography', insertBibliography), btn(Icons.bookmark_border, 'Bookmark', addBookmark), btn(Icons.list_alt, 'Index', addIndexEntry)])),
  ]);
  Widget mailingsRibbon() => ribbonShell([
    group('Mail Merge', 500, Row(children: [btn(Icons.mail_outline, 'Start', mailMergeStart), btn(Icons.people_outline, 'Recipients', addRecipients), btn(Icons.preview_outlined, 'Preview', mailMergePreview), btn(Icons.merge_type, 'Insert Field', () => insertAtCursor('«NAME»')), btn(Icons.done_all, 'Finish', mergeMailMerge)])),
  ]);
  Widget reviewRibbon() => ribbonShell([
    group('Proofing', 250, Row(children: [btn(Icons.spellcheck, 'Spelling', spellingCheck), btn(Icons.calculate_outlined, 'Word Count', showWordCount), btn(Icons.menu_open, 'Paragraph', paragraphMarks)])),
    group('Comments', 250, Row(children: [btn(Icons.comment_outlined, 'Comment', addCommentAtSelection), btn(Icons.forum_outlined, 'Manage', manageComments)])),
    group('Changes', 470, Row(children: [btn(Icons.track_changes, 'Track', toggleTrackChanges), btn(Icons.fact_check_outlined, 'Review', reviewChanges), btn(Icons.compare_arrows, 'Compare', compareDocumentsReal), btn(Icons.lock_outline, 'Protect', protectSettings)])),
  ]);
  Widget viewRibbon() => ribbonShell([
    group('Views', 330, Row(children: [
      btn(Icons.article_outlined, 'Print Layout', () => setState(() => viewMode = 'Print Layout')),
      btn(Icons.menu_book, 'Read', () => setState(() => viewMode = 'Read')),
      btn(Icons.web, 'Web', () => setState(() => viewMode = 'Web')),
    ])),
    group('Show', 230, Row(children: [
      btn(Icons.straighten, 'Ruler', toggleRuler),
      btn(Icons.list_alt, 'Navigation', navigationPaneReal),
      btn(Icons.format_align_left, 'Marks', paragraphMarks),
    ])),
    group('Zoom', 210, Row(children: [
      btn(Icons.zoom_out, '100%', () => setState(() => zoom = 1)),
      btn(Icons.fit_screen, 'Page', () => setState(() => zoom = .90)),
      btn(Icons.zoom_in, '+', () => setState(() => zoom = math.min(1.5, zoom + .1))),
    ])),
  ]);

  Widget insertRibbon() => Container(
        height: 172,
        color: Colors.white,
        child: Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              group('Pages', 180, Row(children: [cmd(Icons.insert_page_break, 'Page Break', onTap: insertPageBreak), cmd(Icons.format_list_numbered, 'Page No.', onTap: insertPageNumber)])),
              group('Tables', 300, Row(children: [cmd(Icons.table_chart_outlined, 'Table', onTap: insertTable), cmd(Icons.add_box_outlined, 'Add Row', onTap: addTableRow), cmd(Icons.view_column, 'Add Col', onTap: addTableColumn), cmd(Icons.delete_sweep_outlined, 'Delete', onTap: deleteTable), cmd(Icons.merge_type, 'Merge', onTap: mergeSelectedTableCells), cmd(Icons.call_split, 'Split', onTap: splitMergedTableCells)])),
              group('Illustrations', 690, Row(children: [cmd(Icons.image_outlined, 'Pictures', onTap: pickImage), cmd(Icons.photo_size_select_large, 'Picture', onTap: pictureSettings), cmd(Icons.crop, 'Crop', onTap: cropPicture), cmd(Icons.wrap_text, 'Wrap', onTap: chooseImageWrap), cmd(Icons.layers, 'Arrange', onTap: chooseArrange), cmd(Icons.open_with, 'Position', onTap: objectTransformSettings), cmd(Icons.change_history, 'Shapes', onTap: insertShape), cmd(Icons.account_tree_outlined, 'SmartArt', onTap: insertSmartArt), cmd(Icons.bar_chart, 'Chart', onTap: insertChart), cmd(Icons.delete_outline, 'Remove', onTap: removeImage), cmd(Icons.close, 'Shape Off', onTap: removeShape)])),
              group('Links', 150, Row(children: [cmd(Icons.link, 'Link', onTap: insertLink)])),
              group('Text', 560, Row(children: [cmd(Icons.text_fields, 'Text Box', onTap: insertTextBox), cmd(Icons.edit_note, 'Edit', onTap: editSelectedTextBox), cmd(Icons.delete_outline, 'Delete', onTap: deleteSelectedTextBox), cmd(Icons.format_align_left, 'Align', onTap: cycleTextBoxAlign), cmd(Icons.add_box, 'Bigger', onTap: growTextBox), cmd(Icons.remove_circle_outline, 'Smaller', onTap: shrinkTextBox), cmd(Icons.calendar_today, 'Date', onTap: insertDate), cmd(Icons.access_time, 'Time', onTap: insertTime), cmd(Icons.draw, 'Signature', onTap: insertSignature), cmd(Icons.inventory_2_outlined, 'Quick Part', onTap: insertQuickPart)])),
              group('Symbols', 360, Row(children: [cmd(Icons.functions, 'Symbol', onTap: insertSymbol), cmd(Icons.calculate, 'Equation', onTap: insertEquation), cmd(Icons.format_drop_cap, 'Drop Cap', onTap: toggleDropCap)])),
            ]),
          ),
        ),
      );

  Widget fileRibbon() => Row(children: [
        group('Office Button', 180, Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 78, height: 100, child: InkWell(onTap: newDocument, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.apps, size: 34), Text('New', style: TextStyle(fontSize: 11))]))),
        ])),
        group('Quick actions', 300, Row(children: [btn(Icons.folder_open, 'Open', openDocument), btn(Icons.save_outlined, 'Save', saveDocument)])),
      ]);

  Widget clipboard() => group('Clipboard', 245, Row(children: [cmd(Icons.content_paste, 'Paste', large: true, onTap: paste), const SizedBox(width: 5), Column(mainAxisAlignment: MainAxisAlignment.center, children: [small(Icons.content_cut, 'Cut', cut), small(Icons.copy, 'Copy', copy), small(Icons.select_all, 'Select All', selectAll)])]));

  Widget fontGroup() => group('Font', 535, Column(children: [
        Row(children: [box(font, 180, (v) => setState(() => font = v)), const SizedBox(width: 4), box(size.toStringAsFixed(0), 58, (v) { final n = double.tryParse(v); if (n != null) setState(() => size = n.clamp(6, 96)); }), btn(Icons.text_decrease, 'Decrease', () => setState(() => size = math.max(6, size - 1))), btn(Icons.text_increase, 'Increase', () => setState(() => size = math.min(96, size + 1)))]),
        Expanded(child: Row(children: [fmt('B', bold, () { final n=!bold; setState(()=>bold=n); _formatSelection(quill.Attribute.bold,n); }, bold: true), fmt('I', italic, () { final n=!italic; setState(()=>italic=n); _formatSelection(quill.Attribute.italic,n); }, italic: true), fmt('U', underline, () { final n=!underline; setState(()=>underline=n); _formatSelection(quill.Attribute.underline,n); }, under: true), fmt('abc', strike, () { final n=!strike; setState(()=>strike=n); _formatSelection(quill.Attribute.strikeThrough,n); }), txt('x₂', subscript, toggleSubscript), txt('x²', superscript, toggleSuperscript), txt('A', textColor != Colors.black, () => setState(() => textColor = textColor == Colors.black ? Colors.red : Colors.black)), txt('▰', highlightColor != null, () => setState(() => highlightColor = highlightColor == null ? const Color(0xffffeb3b) : null)), txt('⌫', false, () { setState(() { bold = italic = underline = strike = false; textColor = Colors.black; highlightColor = null; }); })]))
      ]));

  Widget paragraph() => group('Paragraph', 510, Row(children: [txt('•', bullets, () => toggleList(false)), txt('1.', numbering, () => toggleList(true)), txt('⇤', indent > 0, () => setState(() => indent = math.max(0, indent - 1))), txt('⇥', indent < 6, () => setState(() => indent = math.min(6, indent + 1))), btn(Icons.format_align_left, 'Left', () => setState(() => align = TextAlign.left)), btn(Icons.format_align_center, 'Center', () => setState(() => align = TextAlign.center)), btn(Icons.format_align_right, 'Right', () => setState(() => align = TextAlign.right)), btn(Icons.format_align_justify, 'Justify', () => setState(() => align = TextAlign.justify)), txt('↕', lineSpacing > 1.25, () => setState(() => lineSpacing = lineSpacing >= 1.75 ? 1.0 : lineSpacing + .25)), txt('A↕', false, sortSelected), txt('¶', showFormattingMarks, paragraphMarks)]));

  Widget editing() => group('Editing', 230, Row(children: [btn(Icons.search, 'Find', findText), btn(Icons.find_replace, 'Replace', replaceText), btn(Icons.select_all, 'Select', selectAll)]));

  Widget group(String title, double w, Widget body) => Container(width: w, height: 165, margin: const EdgeInsets.only(left: 4, top: 4, bottom: 3), padding: const EdgeInsets.symmetric(horizontal: 6), decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xffdddddd)))), child: Column(children: [Expanded(child: body), Text(title, style: const TextStyle(fontSize: 11)), const SizedBox(height: 3)]));

  Widget box(String v, double w, ValueChanged<String> f) => Container(width: w, height: 34, decoration: BoxDecoration(border: Border.all(color: const Color(0xffbdbdbd)), color: Colors.white), child: PopupMenuButton<String>(onSelected: f, itemBuilder: (c) => ['Calibri', 'Arial', 'Times New Roman', 'Georgia', 'Courier New'].map((x) => PopupMenuItem<String>(value: x, child: Text(x))).toList(), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 7), child: Row(children: [Expanded(child: Text(v, style: const TextStyle(fontSize: 13))), const Icon(Icons.arrow_drop_down, size: 18)]))));

  Widget cmd(IconData x, String t, {bool large = false, VoidCallback? onTap}) => SizedBox(width: large ? 78 : 70, height: large ? 100 : 70, child: InkWell(onTap: onTap ?? () {}, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(x, size: large ? 34 : 24), Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))])));
  Widget btn(IconData x, String t, VoidCallback f) => SizedBox(width: 43, height: 48, child: InkWell(onTap: f, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(x, size: 21), const SizedBox(height: 2), Text(t, style: const TextStyle(fontSize: 8))])));
  Widget small(IconData x, String t, VoidCallback f) => SizedBox(width: 125, height: 38, child: InkWell(onTap: f, child: Row(children: [Icon(x, size: 21), const SizedBox(width: 7), Text(t, style: const TextStyle(fontSize: 11))])));
  Widget txt(String x, dynamic state, [VoidCallback? f]) { final on = state is bool && state; return Container(width: 43, height: 48, color: on ? const Color(0xffe5f1fb) : Colors.transparent, child: InkWell(onTap: f ?? () {}, child: Center(child: Text(x, style: const TextStyle(fontSize: 17))))); }
  Widget fmt(String x, bool on, VoidCallback f, {bool bold = false, bool italic = false, bool under = false}) => Container(width: 43, height: 48, color: on ? const Color(0xffe5f1fb) : Colors.transparent, child: InkWell(onTap: f, child: Center(child: Text(x, style: TextStyle(fontSize: 20, fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontStyle: italic ? FontStyle.italic : FontStyle.normal, decoration: under ? TextDecoration.underline : null)))));

  void toast(String message) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))); }
  Future<void> chooseTheme() async { final v=await simpleChoice('Theme', ['Office','Modern','Classic','Minimal']); if(v==null)return; setState((){themeName=v; if(v=='Classic'){textColor=Colors.black;} if(v=='Modern'){textColor=const Color(0xff185abd);} if(v=='Minimal'){textColor=const Color(0xff333333);}}); toast('Theme applied: $v'); }
  Future<void> choosePageColor() async { final v=await simpleChoice('Page Color', ['White','Light Blue','Ivory','Light Gray']); if(v==null)return; setState(() => pageColor = {'White':Colors.white,'Light Blue':const Color(0xfff3f8ff),'Ivory':const Color(0xfffffcf0),'Light Gray':const Color(0xfff5f5f5)}[v]!); }
  Future<void> chooseFontSet() async { final v=await simpleChoice('Font Set', ['Office','Classic','Modern']); if(v==null)return; setState((){fontSetName=v; font=v=='Classic'?'Times New Roman':v=='Modern'?'Aptos':'Calibri';}); toast('Font set applied: $v'); }
  Future<void> insertWatermark() async { final c=TextEditingController(text: watermark); final v=await showDialog<String>(context:context,builder:(d)=>AlertDialog(title:const Text('Watermark'),content:TextField(controller:c,decoration:const InputDecoration(labelText:'Watermark text')),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),ElevatedButton(onPressed:()=>Navigator.pop(d,c.text.trim()),child:const Text('Apply'))])); c.dispose(); if(v!=null)setState(()=>watermark=v); }
  Future<void> pageBorders() async { await choosePageBorder(); }
  Future<void> pageMargins() async { final v=await simpleChoice('Margins', ['Normal','Narrow','Moderate','Wide']); if(v==null)return; setState(() { if(v=='Narrow'){marginLeft=marginRight=48;marginTop=marginBottom=48;} else if(v=='Wide'){marginLeft=marginRight=110;marginTop=marginBottom=90;} else if(v=='Moderate'){marginLeft=marginRight=68;marginTop=marginBottom=60;} else {marginLeft=marginRight=82;marginTop=marginBottom=70;} }); }
  Future<void> pageOrientation() async { final v=await simpleChoice('Orientation', ['Portrait','Landscape']); if(v!=null)setState(()=>landscape=v=='Landscape'); }
  Future<void> pageSize() async { final v=await simpleChoice('Page Size', ['A4','A5','Letter','Legal']); if(v!=null)setState(()=>pageSizeName=v); }
  Future<void> pageColumns() async { final v=await simpleChoice('Columns', ['1','2','3']); if(v!=null)setState(()=>columns=int.parse(v)); }
  Future<void> chooseSpacing() async { final v=await simpleChoice('Line Spacing', ['1.0','1.15','1.25','1.5','2.0']); if(v!=null)setState(()=>lineSpacing=double.parse(v)); }
  Future<String?> simpleChoice(String title, List<String> values) async => showDialog<String>(context:context,builder:(d)=>SimpleDialog(title:Text(title),children:[for(final v in values)SimpleDialogOption(onPressed:()=>Navigator.pop(d,v),child:Text(v))]));
  Future<void> insertFootnote({bool endnote=false}) async {
    final c=TextEditingController();
    final v=await showDialog<String>(context:context,builder:(d)=>AlertDialog(title:Text(endnote?'Insert Endnote':'Insert Footnote'),content:TextField(controller:c,maxLines:4,decoration:const InputDecoration(hintText:'Footnote text')),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),ElevatedButton(onPressed:()=>Navigator.pop(d,c.text.trim()),child:const Text('Insert'))]));
    c.dispose(); if(v==null||v.isEmpty)return; final n=(endnote?endnotes:footnotes).length+1; final m=_FootnoteModel(marker:'$n',text:v); setState(()=> (endnote?endnotes:footnotes).add(m)); insertAtCursor(' [$n]');
  }

  void generateToc(){
    final lines=text.text.split('\n'); final heads=<String>[];
    for(final line in lines){final x=line.trim(); if(x.isNotEmpty && x.length<100 && (x.startsWith('# ')||x.toUpperCase()==x && x.length>2)) heads.add(x.replaceFirst(RegExp(r'^#+\s*'),''));}
    if(heads.isEmpty){toast('Add headings first');return;}
    insertAtCursor('\nTABLE OF CONTENTS\n'+heads.asMap().entries.map((e)=>'${e.key+1}. ${e.value}').join('\n')+'\n');
  }

  Future<void> mergeMailMerge() async {
    if(mergeData.isEmpty){toast('Add recipients first');return;}
    final raw=text.text; final lines=<String>[];
    for(final r in mergeData){lines.add(raw.replaceAll('«NAME»',r.name).replaceAll('«EMAIL»',r.email));}
    _setPlainText(lines.join('\n\n')); toast('Merged ${mergeData.length} records');
  }

  Future<void> manageMergeData() async {
    final n=TextEditingController(), e=TextEditingController();
    final v=await showDialog<List<String>>(context:context,builder:(d)=>AlertDialog(title:const Text('Add Recipient'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:n,decoration:const InputDecoration(labelText:'Name')),TextField(controller:e,decoration:const InputDecoration(labelText:'Email'))]),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),ElevatedButton(onPressed:()=>Navigator.pop(d,[n.text.trim(),e.text.trim()]),child:const Text('Add'))])); n.dispose();e.dispose(); if(v!=null&&v[0].isNotEmpty)setState(()=>mergeData.add(_MergeRecipient(v[0],v[1])));
  }

  Future<void> insertIndexField() async { final c=TextEditingController(); final v=await showDialog<String>(context:context,builder:(d)=>AlertDialog(title:const Text('Index Entry'),content:TextField(controller:c,decoration:const InputDecoration(labelText:'Entry')),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),ElevatedButton(onPressed:()=>Navigator.pop(d,c.text.trim()),child:const Text('Mark'))])); c.dispose(); if(v!=null&&v.isNotEmpty){setState(()=>indexEntries.add(v)); insertAtCursor(' {XE "$v"} ');} }

  Future<void> insertCitation() async { final c=TextEditingController(); final v=await showDialog<String>(context:context,builder:(d)=>AlertDialog(title:const Text('Add Citation'),content:TextField(controller:c,decoration:const InputDecoration(hintText:'Author, title, year')),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),ElevatedButton(onPressed:()=>Navigator.pop(d,c.text.trim()),child:const Text('Insert'))])); c.dispose(); if(v!=null&&v.isNotEmpty){citations.add(v);insertAtCursor('[$v]');} }
  void mailMergeStart()=>toast('Mail Merge ready — use Recipients, insert «NAME» / «EMAIL», then Finish');
  void mailMergeRecipients()=>toast('Recipients list ready');
  void mailMergePreview(){if(mergeData.isEmpty){toast('No recipients');return;} final r=mergeData.first; showDialog(context:context,builder:(d)=>AlertDialog(title:const Text('Mail Merge Preview'),content:Text(text.text.replaceAll('«NAME»',r.name).replaceAll('«EMAIL»',r.email)),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Close'))]));}
  void spellingCheck(){ final bad=['teh','recieve','adress']; final found=bad.where((w)=>text.text.toLowerCase().contains(w)).toList(); toast(found.isEmpty?'No common spelling errors found':'Possible errors: ${found.join(', ')}'); }
  void showWordCount()=>toast('Words: $words  •  Characters: ${text.text.length}');
  Future<void> addComment() async { final c=TextEditingController(); final v=await showDialog<String>(context:context,builder:(d)=>AlertDialog(title:const Text('New Comment'),content:TextField(controller:c,maxLines:4,decoration:const InputDecoration(hintText:'Write a comment')),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),ElevatedButton(onPressed:()=>Navigator.pop(d,c.text.trim()),child:const Text('Add'))])); c.dispose(); if(v!=null&&v.isNotEmpty){comments.add(v);toast('Comment added');} }
  void toggleTrackChanges(){setState(()=>trackChanges=!trackChanges);toast(trackChanges?'Track Changes: On':'Track Changes: Off');}
  void compareDocuments()=>toast('Compare is available for documents saved by Tayyib Word');
  void protectDocument()=>toast('Document protection settings opened');
  void toggleRuler(){setState(()=>showRuler=!showRuler);}
  void navigationPane()=>toast('Navigation pane: headings and search');

  Future<void> editHeaderFooter() async {
    final h = TextEditingController(text: headerText), f = TextEditingController(text: footerText);
    final result = await showDialog<List<String>>(context: context, builder: (d) => AlertDialog(
      title: const Text('Header & Footer'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: h, decoration: const InputDecoration(labelText: 'Header')), TextField(controller: f, decoration: const InputDecoration(labelText: 'Footer'))]),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(d, [h.text, f.text]), child: const Text('Apply'))],
    ));
    h.dispose(); f.dispose();
    if (result != null) setState(() { headerText = result[0]; footerText = result[1]; });
  }

  Future<void> choosePageBorder() async {
    final v = await simpleChoice('Page Borders', ['None', 'Box', 'Shadow', 'Double']);
    if (v != null) setState(() => pageBorderStyle = v);
  }

  Future<void> insertShape() async {
    final v = await simpleChoice('Insert Shape', ['Rectangle', 'Rounded Rectangle', 'Circle', 'Arrow', 'Line', 'Triangle']);
    if (v != null) setState(() => shapeKind = v);
  }

  void removeShape() => setState(() => shapeKind = '');

  Future<void> chooseStyle() async {
    final v = await simpleChoice('Styles', ['Normal', 'Title', 'Subtitle', 'Heading 1', 'Heading 2', 'Heading 3', 'Quote']);
    if (v == null) return;
    setState(() {
      styleName = v;
      if (v == 'Title') { size = 26; bold = true; align = TextAlign.center; }
      else if (v == 'Subtitle') { size = 18; italic = true; align = TextAlign.center; }
      else if (v == 'Heading 1') { size = 20; bold = true; align = TextAlign.left; }
      else if (v == 'Heading 2') { size = 16; bold = true; align = TextAlign.left; }
      else if (v == 'Heading 3') { size = 14; bold = true; align = TextAlign.left; }
      else if (v == 'Quote') { size = 12; italic = true; indent = math.min(3, indent + 1); }
      else { size = 11; bold = false; italic = false; align = TextAlign.left; }
    });
  }

  void toggleSuperscript() => setState(() { superscript = !superscript; if (superscript) subscript = false; });
  void toggleSubscript() => setState(() { subscript = !subscript; if (subscript) superscript = false; });

  Future<void> paragraphMarks() async {
    setState(() => showFormattingMarks = !showFormattingMarks);
    toast(showFormattingMarks ? 'Formatting marks: On' : 'Formatting marks: Off');
  }

  Future<void> addCommentAtSelection() async {
    final s = _quill.selection;
    final a = s.isValid ? math.max(0, math.min(s.start, s.end)) : 0;
    final b = s.isValid ? math.max(a, math.min(s.end, text.text.length)) : 0;
    final selected = a < b ? text.text.substring(a, b) : 'Document';
    final c = TextEditingController();
    final v = await showDialog<String>(context: context, builder: (d) => AlertDialog(
      title: Text('Comment on: ${selected.length > 35 ? '${selected.substring(0, 35)}…' : selected}'),
      content: TextField(controller: c, maxLines: 4, decoration: const InputDecoration(hintText: 'Write a comment')),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Add'))],
    ));
    c.dispose();
    if (v != null && v.isNotEmpty) {
      setState(() => commentModels.add(_CommentModel(text: selected.replaceAll('\n', ' '), comment: v, start: a, end: b)));
      toast('Comment anchored to selection');
    }
  }

  Future<void> manageComments() async {
    if (commentModels.isEmpty && comments.isEmpty) { toast('No comments'); return; }
    final remove = await showDialog<int>(context: context, builder: (d) => SimpleDialog(
      title: const Text('Comments'),
      children: [
        for (var i = 0; i < commentModels.length; i++) SimpleDialogOption(
          onPressed: () => Navigator.pop(d, i),
          child: Text('${i + 1}. ${commentModels[i].text} → ${commentModels[i].comment}'),
        ),
      ],
    ));
    if (remove != null && remove >= 0 && remove < commentModels.length) setState(() => commentModels.removeAt(remove));
  }

  Future<void> reviewChanges() async {
    if(trackedChanges.isEmpty){toast('No tracked changes yet');return;}
    final action=await showDialog<String>(context:context,builder:(d)=>SimpleDialog(title:const Text('Review Changes'),children:[for(int i=0;i<trackedChanges.length;i++) ListTile(title:Text('Change ${i+1}'),subtitle:Text('Before: ${trackedChanges[i].before.length} → After: ${trackedChanges[i].after.length} chars'),onTap:()=>Navigator.pop(d,'$i')) ,const Divider(),SimpleDialogOption(onPressed:()=>Navigator.pop(d,'accept'),child:const Text('Accept All')),SimpleDialogOption(onPressed:()=>Navigator.pop(d,'reject'),child:const Text('Reject All'))]));
    if(action==null)return; if(action=='accept'){setState(()=>trackedChanges.clear());toast('All changes accepted');return;} if(action=='reject'){if(trackedChanges.isNotEmpty)_setPlainText(trackedChanges.first.before);setState(()=>trackedChanges.clear());toast('All changes rejected');return;} final i=int.tryParse(action); if(i==null||i<0||i>=trackedChanges.length)return; final ch=trackedChanges[i]; final a=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:Text('Change ${i+1}'),content:Text('Before:
${ch.before}

After:
${ch.after}'),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Reject')),ElevatedButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Accept'))])); if(a!=null)setState(()=>trackedChanges.removeAt(i));
  }

  Future<void> addRecipients() async {
    final c = TextEditingController(text: mailRecipients.join('\n'));
    final v = await showDialog<String>(context: context, builder: (d) => AlertDialog(title: const Text('Mail Merge Recipients'), content: TextField(controller: c, maxLines: 8, decoration: const InputDecoration(hintText: 'One recipient per line')), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Save'))]));
    c.dispose();
    if (v != null) setState(() { mailRecipients..clear()..addAll(v.split('\n').map((x) => x.trim()).where((x) => x.isNotEmpty)); });
  }

  Future<void> protectSettings() async {
    final c = TextEditingController();
    final v = await showDialog<String>(context: context, builder: (d) => AlertDialog(title: const Text('Protect Document'), content: TextField(controller: c, obscureText: true, decoration: const InputDecoration(labelText: 'Password (empty = remove protection)')), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Apply'))]));
    c.dispose();
    if (v == null) return;
    setState(() { protectionPassword = v; documentProtected = v.isNotEmpty; });
    toast(documentProtected ? 'Document protection enabled' : 'Document protection removed');
  }

  Future<void> compareDocumentsReal() async {
    final c = TextEditingController();
    final v = await showDialog<String>(context: context, builder: (d) => AlertDialog(title: const Text('Compare text'), content: TextField(controller: c, maxLines: 8, decoration: const InputDecoration(hintText: 'Paste the other document text here')), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Compare'))]));
    c.dispose();
    if (v == null) return;
    final a = text.text.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toSet(), b = v.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toSet();
    final added = b.difference(a).length, removed = a.difference(b).length;
    toast('Compare: $added words added, $removed words removed');
  }

  Future<void> navigationPaneReal() async {
    final headings = text.text.split('\n').where((x) => RegExp(r'^(#|[A-Z][A-Z0-9 ]{3,})').hasMatch(x.trim()) && x.trim().isNotEmpty).toList();
    await showDialog<void>(context: context, builder: (d) => AlertDialog(title: const Text('Navigation Pane'), content: SizedBox(width: 360, child: ListView(shrinkWrap: true, children: [if (headings.isEmpty) const ListTile(title: Text('No headings detected')), for (final h in headings) ListTile(leading: const Icon(Icons.title), title: Text(h.trim()))])), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Close'))]));
  }

  Future<void> pickImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null || !mounted) return;
    setState(() => insertedImagePath = picked.path);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image inserted')));
  }

  void removeImage() => setState(() => insertedImagePath = null);

  Future<void> insertTable() async {
    int rows = 3, cols = 3;
    final result = await showDialog<List<int>>(context: context, builder: (d) => StatefulBuilder(builder: (d, setD) => AlertDialog(
          title: const Text('Insert Table'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _counter('Rows', rows, (v) => setD(() => rows = v)),
            _counter('Columns', cols, (v) => setD(() => cols = v)),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(d, [rows, cols]), child: const Text('Insert'))],
        )));
    if (result == null) return;
    final model = _TableModel(result[0], result[1]);
    setState(() { tables.add(model); selectedTable = tables.length - 1; });
  }

  Widget _counter(String label, int value, ValueChanged<int> change) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Row(children: [IconButton(onPressed: () => change(math.max(1, value - 1)), icon: const Icon(Icons.remove)), Text('$value'), IconButton(onPressed: () => change(math.min(label == 'Rows' ? 30 : 15, value + 1)), icon: const Icon(Icons.add))])]);

  void addTableRow() { if (selectedTable < 0 || selectedTable >= tables.length) return; setState(() => tables[selectedTable].addRow()); }
  void addTableColumn() { if (selectedTable < 0 || selectedTable >= tables.length) return; setState(() => tables[selectedTable].addColumn()); }

  Future<void> deleteTable() async {
    if (selectedTable < 0 || selectedTable >= tables.length) return;
    final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Delete table?'), content: const Text('This will remove the selected table.'), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete'))]));
    if (ok != true) return;
    final t = tables.removeAt(selectedTable); t.dispose();
    setState(() => selectedTable = -1);
  }

  Future<void> tableSettings() async {
    if (selectedTable < 0 || selectedTable >= tables.length) return;
    final t = tables[selectedTable];
    double width = t.width, height = t.rowHeight;
    final result = await showDialog<List<double>>(context: context, builder: (d) => StatefulBuilder(builder: (d, setD) => AlertDialog(
          title: const Text('Table Size'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Width: ${width.round()} px'), Slider(value: width, min: 250, max: 700, onChanged: (v) => setD(() => width = v)),
            Text('Row height: ${height.round()} px'), Slider(value: height, min: 28, max: 90, onChanged: (v) => setD(() => height = v)), DropdownButtonFormField<String>(value: tableStyle, decoration: const InputDecoration(labelText:'Table style'), items: const [DropdownMenuItem(value:'Table Grid',child:Text('Table Grid')),DropdownMenuItem(value:'Light Shading',child:Text('Light Shading')),DropdownMenuItem(value:'No Borders',child:Text('No Borders'))], onChanged:(v){if(v!=null)setState(()=>tableStyle=v);}),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(d, [width, height]), child: const Text('Apply'))],
        )));
    if (result == null) return;
    setState(() { t.width = result[0]; t.rowHeight = result[1]; });
  }

  Widget tableEditor() {
    if (tables.isEmpty) return const SizedBox.shrink();
    return Column(children: [for (int i = 0; i < tables.length; i++) _singleTableEditor(i)]);
  }

  Widget _singleTableEditor(int index) {
    final t = tables[index];
    final borderColor = tableStyle == 'No Borders' ? Colors.transparent : tableStyle == 'Light Shading' ? const Color(0xffb8c7d9) : const Color(0xff777777);
    return GestureDetector(
      onLongPress: () { setState(() => selectedTable = index); tableSettings(); },
      child: Container(
        width: t.width, margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(border: Border.all(color: selectedTable == index ? const Color(0xff185abd) : const Color(0xff777777), width: selectedTable == index ? 2 : 1)),
        child: Column(children: [
          for (var r=0; r<t.rows; r++) Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var c=0; c<t.cols; c++) ..._tableCellWidgets(t,index,r,c,borderColor),
          ]),
        ]),
      ),
    );
  }

  List<Widget> _tableCellWidgets(_TableModel t, int tableIndex, int r, int c, Color borderColor) {
    final key=t.mergedAnchorFor(r,c);
    if (key != null) {
      final p=key.split(':').map((x)=>int.tryParse(x)??0).toList();
      final r1=p[0],c1=p[1],r2=p[2],c2=p[3];
      if (r!=r1 || c!=c1) return const [];
      final span=c2-c1+1;
      return [Expanded(flex:span, child:SizedBox(height: t.rowHeight, child:_cellBox(t.cells[r][c], t.isSelected(r,c), borderColor, ()=>setState(() { selectedTable=tableIndex; t.selectCell(r,c); }))))];
    }
    return [Expanded(child:SizedBox(height: t.rowHeight, child:_cellBox(t.cells[r][c], t.isSelected(r,c), borderColor, ()=>setState(() { selectedTable=tableIndex; t.selectCell(r,c); }))))];
  }

  Widget _cellBox(TextEditingController cell, bool selected, Color borderColor, VoidCallback onTap, {double height = 42}) => GestureDetector(
    onTap: onTap,
    child: Container(height: height, decoration: BoxDecoration(color:selected?const Color(0xffdbeafe):null,border:Border.all(color:borderColor,width:.7)), child: TextField(controller:cell,maxLines:3,style:TextStyle(fontFamily:font,fontSize:size),decoration:const InputDecoration(border:InputBorder.none,isDense:true,contentPadding:EdgeInsets.all(6))),),
  );

  void mergeSelectedTableCells() {
    if (selectedTable < 0 || selectedTable >= tables.length) { toast('Select a table first'); return; }
    final t = tables[selectedTable];
    if (t.selectedStartRow < 0) { toast('Tap two corner cells to select a range'); return; }
    final r1 = math.min(t.selectedStartRow, t.selectedEndRow), r2 = math.max(t.selectedStartRow, t.selectedEndRow);
    final c1 = math.min(t.selectedStartCol, t.selectedEndCol), c2 = math.max(t.selectedStartCol, t.selectedEndCol);
    if (r1 == r2 && c1 == c2) { toast('Select more than one cell'); return; }
    final values=<String>[];
    for (var r=r1; r<=r2; r++) { for (var c=c1; c<=c2; c++) { final v=t.cells[r][c].text.trim(); if(v.isNotEmpty) values.add(v); } }
    for (var r=r1; r<=r2; r++) { for (var c=c1; c<=c2; c++) { if(r!=r1 || c!=c1) t.cells[r][c].clear(); } }
    t.cells[r1][c1].text=values.join(' • ');
    t.mergedCells.removeWhere((k) { final p=k.split(':'); if(p.length!=4)return false; final a=int.tryParse(p[0])??-1,b=int.tryParse(p[1])??-1,c=int.tryParse(p[2])??-1,d=int.tryParse(p[3])??-1; return a>=r1&&b>=c1&&c<=r2&&d<=c2; });
    t.mergedCells.add('$r1:$c1:$r2:$c2');
    toast('Selected cells merged');
    setState(() {});
  }

  void splitMergedTableCells() {
    if (selectedTable < 0 || selectedTable >= tables.length) { toast('Select a table first'); return; }
    final t = tables[selectedTable];
    String? hit;
    if (t.selectedStartRow >= 0) hit=t.mergedAnchorFor(t.selectedStartRow,t.selectedStartCol);
    if (hit == null && t.mergedCells.isNotEmpty) hit=t.mergedCells.last;
    if (hit == null) { toast('No merged cells'); return; }
    t.mergedCells.remove(hit);
    toast('Merged cells split');
    setState(() {});
  }

  Future<void> objectTransformSettings() async {
    double x = objectX, y = objectY, rot = objectRotation;
    final result = await showDialog<List<double>>(context: context, builder: (d) => StatefulBuilder(builder: (d, setD) => AlertDialog(
      title: const Text('Object Position & Rotation'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Horizontal: ${x.round()}'), Slider(value: x.clamp(-250,250), min: -250, max: 250, onChanged: (v) => setD(() => x = v)),
        Text('Vertical: ${y.round()}'), Slider(value: y.clamp(-250,250), min: -250, max: 250, onChanged: (v) => setD(() => y = v)),
        Text('Rotation: ${rot.round()}°'), Slider(value: rot.clamp(-180,180), min: -180, max: 180, onChanged: (v) => setD(() => rot = v)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(d, [x,y,rot]), child: const Text('Apply'))],
    )));
    if (result == null) return;
    setState(() { objectX=result[0]; objectY=result[1]; objectRotation=result[2]; });
  }

  void insertPageBreak() {
    if (documentProtected) { toast('Document is protected'); return; }
    insertAtCursor('\n\n--- PAGE BREAK ---\n\n');
  }

  void insertPageNumber() {
    setState(() => pageNumber = (pageNumber ?? 0) + 1);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Page number inserted: ${pageNumber!}')));
  }

  Future<void> insertLink() async {
    final label = TextEditingController(); final url = TextEditingController(text: 'https://');
    final result = await showDialog<List<String>>(context: context, builder: (d) => AlertDialog(title: const Text('Insert Hyperlink'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: label, decoration: const InputDecoration(labelText: 'Text')), TextField(controller: url, decoration: const InputDecoration(labelText: 'URL'))]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(d, [label.text.trim(), url.text.trim()]), child: const Text('Insert'))]));
    label.dispose(); url.dispose(); if (result == null || result[0].isEmpty || result[1].isEmpty) return;
    insertAtCursor('${result[0]} <${result[1]}>');
    final uri = Uri.tryParse(result[1]); if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) { try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {} }
  }

  Future<void> insertTextBox() async {
    final c = TextEditingController();
    final value = await showDialog<String>(context: context, builder: (d) => AlertDialog(title: const Text('Insert Text Box'), content: TextField(controller: c, autofocus: true, maxLines: 5, decoration: const InputDecoration(hintText: 'Type text for the box')), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Insert'))]));
    c.dispose();
    if (value == null || value.isEmpty) return;
    setState(() { textBoxes.add(_TextBoxModel(value)); selectedTextBox = textBoxes.length - 1; });
  }

  Future<void> editSelectedTextBox() async {
    if (selectedTextBox < 0 || selectedTextBox >= textBoxes.length) return;
    final b = textBoxes[selectedTextBox];
    final c = TextEditingController(text: b.text);
    final value = await showDialog<String>(context: context, builder: (d) => AlertDialog(title: const Text('Edit Text Box'), content: TextField(controller: c, autofocus: true, maxLines: 6), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Update'))]));
    c.dispose();
    if (value == null || value.isEmpty) return;
    setState(() => b.text = value);
  }

  void deleteSelectedTextBox() {
    if (selectedTextBox < 0 || selectedTextBox >= textBoxes.length) return;
    setState(() { textBoxes.removeAt(selectedTextBox); selectedTextBox = textBoxes.isEmpty ? -1 : math.min(selectedTextBox, textBoxes.length - 1); });
  }

  void cycleTextBoxAlign() {
    if (selectedTextBox < 0 || selectedTextBox >= textBoxes.length) return;
    final b = textBoxes[selectedTextBox];
    setState(() => b.align = b.align == TextAlign.left ? TextAlign.center : b.align == TextAlign.center ? TextAlign.right : TextAlign.left);
  }

  void growTextBox() {
    if (selectedTextBox < 0 || selectedTextBox >= textBoxes.length) return;
    setState(() { final b = textBoxes[selectedTextBox]; b.width = math.min(650, b.width + 40); b.height = math.min(260, b.height + 20); });
  }

  void shrinkTextBox() {
    if (selectedTextBox < 0 || selectedTextBox >= textBoxes.length) return;
    setState(() { final b = textBoxes[selectedTextBox]; b.width = math.max(180, b.width - 40); b.height = math.max(60, b.height - 20); });
  }

  Future<void> pictureSettings() async {
    if (insertedImagePath == null) { toast('Insert a picture first'); return; }
    double w=imageWidth,h=imageHeight;
    final r=await showDialog<List<double>>(context:context,builder:(d)=>StatefulBuilder(builder:(d,sd)=>AlertDialog(title:const Text('Picture Size'),content:Column(mainAxisSize:MainAxisSize.min,children:[Text('Width: ${w.round()} px'),Slider(value:w,min:80,max:650,onChanged:(v)=>sd(()=>w=v)),Text('Height: ${h.round()} px'),Slider(value:h,min:60,max:500,onChanged:(v)=>sd(()=>h=v)),SwitchListTile(value:imageLockedAspect,onChanged:(v)=>sd(()=>imageLockedAspect=v),title:const Text('Lock aspect ratio'))]),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),ElevatedButton(onPressed:()=>Navigator.pop(d,[w,h]),child:const Text('Apply'))])));
    if(r!=null)setState(() { imageWidth=r[0]; imageHeight=r[1]; });
  }
  Future<void> cropPicture() async {
    if(insertedImagePath==null){toast('Insert a picture first');return;}
    final v=await simpleChoice('Crop', ['None','Square','16:9','4:3']); if(v!=null)setState(()=>imageCrop=v);
  }
  Future<void> chooseImageWrap() async { final v=await simpleChoice('Wrap Text',['In Line','Square','Tight','Top and Bottom','Behind Text','In Front of Text']); if(v!=null)setState(()=>imageWrap=v); }
  Future<void> chooseArrange() async { final v=await simpleChoice('Arrange',['In Front','Bring Forward','Send Backward','Behind Text']); if(v!=null)setState(()=>arrangeMode=v); }
  Future<void> insertSignature() async { final c=TextEditingController(text:signatureText); final v=await showDialog<String>(context:context,builder:(d)=>AlertDialog(title:const Text('Signature Line'),content:TextField(controller:c,decoration:const InputDecoration(labelText:'Signer name')),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),ElevatedButton(onPressed:()=>Navigator.pop(d,c.text.trim()),child:const Text('Insert'))])); c.dispose(); if(v!=null&&v.isNotEmpty){setState(()=>signatureText=v);insertAtCursor('\n____________________________\n$v\n');}}
  Future<void> insertQuickPart() async { final c=TextEditingController(text:quickPartText); final v=await showDialog<String>(context:context,builder:(d)=>AlertDialog(title:const Text('Quick Part'),content:TextField(controller:c,maxLines:4,decoration:const InputDecoration(hintText:'Reusable text')),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),ElevatedButton(onPressed:()=>Navigator.pop(d,c.text.trim()),child:const Text('Insert'))])); c.dispose(); if(v!=null&&v.isNotEmpty){setState(()=>quickPartText=v);insertAtCursor(v);}}

  void insertDate() => insertAtCursor('${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}');
  void insertTime() { final n = DateTime.now(); insertAtCursor('${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}'); }

  Future<void> insertSymbol() async {
    const symbols = ['©', '®', '™', '✓', '★', '→', '←', '↑', '↓', '±', '×', '÷', '∞', '§', '¶', '€', '£', '¥', '৳', 'π', 'α', 'β', 'Ω'];
    final s = await showDialog<String>(
      context: context,
      builder: (d) => SimpleDialog(
        title: const Text('Insert Symbol'),
        children: [
          Wrap(children: [
            for (final x in symbols)
              Padding(padding: const EdgeInsets.all(3), child: OutlinedButton(onPressed: () => Navigator.pop(d, x), child: Text(x, style: const TextStyle(fontSize: 20)))),
          ]),
        ],
      ),
    );
    if (s != null) insertAtCursor(s);
  }

  void insertAtCursor(String value) {
    if (documentProtected) { toast('Document is protected'); return; }
    final sel = _quill.selection;
    final start = sel.isValid ? math.min(sel.start, sel.end) : _quill.document.length - 1;
    final length = sel.isValid ? (sel.end - sel.start).abs() : 0;
    _quill.replaceText(math.max(0, start), length, value, TextSelection.collapsed(offset: math.max(0, start) + value.length));
    _syncFromQuill();
  }

  void selectAll() => _quill.updateSelection(TextSelection(baseOffset: 0, extentOffset: math.max(0, _quill.document.length - 1)), quill.ChangeSource.local);

  Future<void> copy() async { final s = _quill.selection; if (!s.isValid || s.isCollapsed) return; final raw = _quill.document.toPlainText(); await Clipboard.setData(ClipboardData(text: raw.substring(math.min(s.start, s.end), math.max(s.start, s.end)))); }
  Future<void> cut() async { final s = _quill.selection; if (!s.isValid || s.isCollapsed || documentProtected) return; final a=math.min(s.start,s.end), b=math.max(s.start,s.end); final raw=_quill.document.toPlainText(); await Clipboard.setData(ClipboardData(text: raw.substring(a,b))); _quill.replaceText(a,b-a,'',TextSelection.collapsed(offset:a)); _syncFromQuill(); }
  Future<void> paste() async { final d = await Clipboard.getData(Clipboard.kTextPlain); final v = d?.text; if (v != null && v.isNotEmpty) insertAtCursor(v); }

  void toggleList(bool numberedList) {
    if (documentProtected) { toast('Document is protected'); return; }
    final attr = numberedList ? quill.Attribute.ol : quill.Attribute.ul;
    _quill.formatSelection(attr);
    _syncFromQuill();
    setState(() { bullets = !numberedList; numbering = numberedList; });
  }

  void sortSelected() {
    final s = _quill.selection;
    if (!s.isValid || s.isCollapsed) return;
    final a = math.min(s.start, s.end), b = math.max(s.start, s.end);
    final raw = _quill.document.toPlainText();
    final lines = raw.substring(a, b).split('\n')..sort((x, y) => x.toLowerCase().compareTo(y.toLowerCase()));
    final rep = lines.join('\n');
    _quill.replaceText(a, b - a, rep, TextSelection(baseOffset: a, extentOffset: a + rep.length));
    _syncFromQuill();
  }

  Future<void> insertWordArt() async {
    final c = TextEditingController(text: wordArtText.isEmpty ? 'Tayyib Word' : wordArtText);
    final v = await showDialog<String>(context: context, builder: (d) => AlertDialog(title: const Text('WordArt'), content: TextField(controller: c, decoration: const InputDecoration(labelText: 'WordArt text')), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Insert'))]));
    c.dispose(); if (v == null || v.isEmpty) return; setState(() => wordArtText = v); toast('WordArt inserted');
  }

  Future<void> insertSmartArt() async {
    final v = await showDialog<String>(context: context, builder: (d) => SimpleDialog(title: const Text('SmartArt'), children: [for (final x in ['List','Process','Cycle','Hierarchy','Relationship']) SimpleDialogOption(onPressed: () => Navigator.pop(d, x), child: Text(x))]));
    if (v == null) return; setState(() => smartArtType = v); toast('SmartArt: $v');
  }

  Future<void> editChartData() async { final c=TextEditingController(text:chartData); final v=await showDialog<String>(context:context,builder:(d)=>AlertDialog(title:const Text('Chart Data'),content:TextField(controller:c,decoration:const InputDecoration(hintText:'12,28,20,35')),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),ElevatedButton(onPressed:()=>Navigator.pop(d,c.text.trim()),child:const Text('Apply'))])); c.dispose(); if(v!=null&&v.isNotEmpty)setState(()=>chartData=v); }

  Future<void> insertChart() async {
    final v = await showDialog<String>(context: context, builder: (d) => SimpleDialog(title: const Text('Chart'), children: [for (final x in ['Column','Bar','Line','Pie']) SimpleDialogOption(onPressed: () => Navigator.pop(d, x), child: Text(x))]));
    if (v == null) return; setState(() => chartType = v); await editChartData(); toast('Chart: $v');
  }

  Future<void> insertEquation() async {
    final c = TextEditingController(text: equationText);
    final v = await showDialog<String>(context: context, builder: (d) => AlertDialog(title: const Text('Equation'), content: TextField(controller: c, maxLines: 3, decoration: const InputDecoration(hintText: 'Example: x² + y² = z²')), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Insert'))]));
    c.dispose(); if (v == null || v.isEmpty) return; setState(() => equationText = v); insertAtCursor('  $v  '); toast('Equation inserted');
  }

  void toggleDropCap() { setState(() => dropCap = !dropCap); toast(dropCap ? 'Drop Cap enabled' : 'Drop Cap disabled'); }

  Future<void> addBookmark() async {
    final c = TextEditingController(); final v = await showDialog<String>(context: context, builder: (d) => AlertDialog(title: const Text('Bookmark'), content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Bookmark name')), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Add'))])); c.dispose(); if (v == null || v.isEmpty) return; bookmarks.add(v); toast('Bookmark added: $v');
  }

  Future<void> addIndexEntry() async {
    final c = TextEditingController(text: text.selection.isValid && !text.selection.isCollapsed ? text.text.substring(text.selection.start, text.selection.end) : ''); final v = await showDialog<String>(context: context, builder: (d) => AlertDialog(title: const Text('Mark Index Entry'), content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Index entry')), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Mark'))])); c.dispose(); if (v == null || v.isEmpty) return; indexEntries.add(v); toast('Index entry marked');
  }

  Future<void> insertBibliography() async {
    final c = TextEditingController(); final v = await showDialog<String>(context: context, builder: (d) => AlertDialog(title: const Text('Bibliography'), content: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<String>(value: bibliographyStyle, items: const [DropdownMenuItem(value: 'APA', child: Text('APA')), DropdownMenuItem(value: 'MLA', child: Text('MLA')), DropdownMenuItem(value: 'Chicago', child: Text('Chicago'))], onChanged: (x) => bibliographyStyle = x ?? 'APA'), TextField(controller: c, decoration: const InputDecoration(labelText: 'Source / author / title'))]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Insert'))])); c.dispose(); if (v == null || v.isEmpty) return; citations.add(v); insertAtCursor('\n[$bibliographyStyle] $v\n');
  }

  Future<void> findText() async {
    final c = TextEditingController();
    final q = await showDialog<String>(context: context, builder: (d) => AlertDialog(title: const Text('Find'), content: TextField(controller: c, autofocus: true), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Find'))]));
    c.dispose();
    if (q == null || q.isEmpty) return;
    final raw = _quill.document.toPlainText();
    var at = raw.indexOf(q, _quill.selection.isValid ? _quill.selection.end : 0);
    if (at < 0) at = raw.indexOf(q);
    if (at >= 0) { _quill.updateSelection(TextSelection(baseOffset: at, extentOffset: at + q.length), quill.ChangeSource.local); _syncFromQuill(); }
    else if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Text not found')));
  }

  Future<void> replaceText() async {
    final f = TextEditingController(), r = TextEditingController();
    final result = await showDialog<List<String>>(context: context, builder: (d) => AlertDialog(title: const Text('Find and Replace'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: f, decoration: const InputDecoration(labelText: 'Find')), TextField(controller: r, decoration: const InputDecoration(labelText: 'Replace with'))]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(d, [f.text, r.text, 'one']), child: const Text('Replace')), ElevatedButton(onPressed: () => Navigator.pop(d, [f.text, r.text, 'all']), child: const Text('Replace All'))]));
    f.dispose(); r.dispose();
    if (result == null || result[0].isEmpty) return;
    final q = result[0], rep = result[1];
    final raw = _quill.document.toPlainText();
    if (result[2] == 'all') {
      _setPlainText(raw.replaceAll(q, rep));
    } else {
      final at = raw.indexOf(q);
      if (at >= 0) {
        _quill.replaceText(at, q.length, rep, TextSelection.collapsed(offset: at + rep.length));
        _syncFromQuill();
      }
    }
  }

  Widget document() => Container(color: const Color(0xffe7e7e7), child: Column(children: [if(showRuler) rulerH(), Expanded(child: Row(children: [if(showRuler) rulerV(), Expanded(child: SingleChildScrollView(child: Center(child: Transform.scale(scale: zoom, alignment: Alignment.topCenter, child: layoutPreview ? paginatedLayout() : paper()))))]))]));

  int _pageLineCapacity() {
    final base = pageSizeName == 'A5' ? const Size(559, 794) : pageSizeName == 'Letter' ? const Size(612, 792) : pageSizeName == 'Legal' ? const Size(612, 1008) : const Size(794, 1123);
    final page = landscape ? Size(base.height, base.width) : base;
    final usableH = math.max(220.0, page.height - marginTop - marginBottom - 90);
    return math.max(5, (usableH / math.max(10, size * 1.45)).floor());
  }

  int _pageCharsPerLine() {
    final base = pageSizeName == 'A5' ? const Size(559, 794) : pageSizeName == 'Letter' ? const Size(612, 792) : pageSizeName == 'Legal' ? const Size(612, 1008) : const Size(794, 1123);
    final page = landscape ? Size(base.height, base.width) : base;
    return math.max(20, ((page.width - marginLeft - marginRight) / math.max(5, size * .52)).floor());
  }

  List<String> _wrapParagraph(String value, int width) {
    if (value.isEmpty) return [''];
    final words = value.split(RegExp(r'\\s+'));
    final out = <String>[];
    var line = '';
    for (final word in words) {
      if (word.length > width && line.isEmpty) {
        for (var i = 0; i < word.length; i += width) {
          out.add(word.substring(i, math.min(i + width, word.length)));
        }
        line = '';
      } else if (line.isEmpty) {
        line = word;
      } else if ((line.length + 1 + word.length) <= width) {
        line = '$line $word';
      } else {
        out.add(line);
        line = word;
      }
    }
    if (line.isNotEmpty) out.add(line);
    return out.isEmpty ? [''] : out;
  }

  List<String> _layoutPages() {
    final raw = _quill.document.toPlainText().replaceAll('\r', '');
    final paragraphs = raw.split('\n');
    final linesPerPage = _pageLineCapacity();
    final charsPerLine = _pageCharsPerLine();
    final pages = <String>[];
    var pageLines = <String>[];

    void flush() {
      if (pageLines.isNotEmpty || pages.isEmpty) pages.add(pageLines.join('\n'));
      pageLines = <String>[];
    }

    for (var i = 0; i < paragraphs.length; i++) {
      var para = paragraphs[i];
      final forced = para.contains('--- PAGE BREAK ---');
      para = para.replaceAll('--- PAGE BREAK ---', '').trimRight();
      final beforeBreak = pageBreakBefore && para.trim().isNotEmpty;
      if (forced || (beforeBreak && pageLines.isNotEmpty)) flush();
      if (para.isEmpty) {
        if (pageLines.length < linesPerPage) pageLines.add('');
        continue;
      }
      final wrapped = _wrapParagraph(para, charsPerLine);
      final keep = keepWithNext && i < paragraphs.length - 1 && paragraphs[i + 1].trim().isNotEmpty;
      if (keep && pageLines.length + wrapped.length + 1 > linesPerPage && pageLines.isNotEmpty) flush();
      var offset = 0;
      while (offset < wrapped.length) {
        final room = linesPerPage - pageLines.length;
        if (room <= 0) flush();
        final take = math.min(room, wrapped.length - offset);
        pageLines.addAll(wrapped.sublist(offset, offset + take));
        offset += take;
        if (offset < wrapped.length) flush();
      }
    }
    flush();
    return pages;
  }

  Widget paginatedLayout() {
    final pages = _layoutPages();
    return Column(children: [for (int i = 0; i < pages.length; i++) _layoutPage(pages[i], i + 1, pages.length)]);
  }

  Widget _layoutPage(String body, int number, int total) {
    final base = pageSizeName == 'A5' ? const Size(559, 794) : pageSizeName == 'Letter' ? const Size(612, 792) : pageSizeName == 'Legal' ? const Size(612, 1008) : const Size(794, 1123);
    final page = landscape ? Size(base.height, base.width) : base;
    final border = pageBorderStyle == 'Box' ? Border.all(color: const Color(0xff555555), width: 2) : pageBorderStyle == 'Double' ? Border.all(color: const Color(0xff333333), width: 4) : Border.all(color: const Color(0xffd0d0d0));
    final shadow = const [BoxShadow(color: Color(0x33000000), blurRadius: 5, offset: Offset(0, 2))];
    final even = number % 2 == 0;
    final showHeader = !(differentFirstPage && number == 1);
    final showFooter = !(differentFirstPage && number == 1);
    final h = (differentOddEven && even) ? (headerText.isEmpty ? '' : '$headerText  •  Even') : headerText;
    final f = (differentOddEven && even) ? (footerText.isEmpty ? '' : '$footerText  •  Even') : footerText;
    return Container(width: page.width, height: page.height, margin: const EdgeInsets.symmetric(vertical: 18), padding: EdgeInsets.fromLTRB(marginLeft, marginTop, marginRight, marginBottom), decoration: BoxDecoration(color: pageColor, border: border, boxShadow: shadow), child: Stack(children: [
      if (watermark.isNotEmpty) Positioned.fill(child: IgnorePointer(child: Center(child: Transform.rotate(angle: -math.pi / 6, child: Opacity(opacity: .10, child: Text(watermark, style: const TextStyle(fontSize: 54, fontWeight: FontWeight.bold))))))),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (showHeader && h.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(h, textAlign: TextAlign.center, style: TextStyle(fontFamily: font, fontSize: math.max(9.0, size - 1)))),
        Expanded(child: _previewColumns(body)),
        if (showFooter) Padding(padding: const EdgeInsets.only(top: 12), child: Text(f.isNotEmpty ? '$f   $number' : '$number', textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: Colors.black54))),
      ]),
    ]));
  }

  Widget _previewColumns(String body) {
    final lines = body.split('\n');
    final n = math.max(1, columns);
    Widget one(List<String> xs, int start) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (var i=0;i<xs.length;i++) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [if(showLineNumbers) SizedBox(width:34, child:Text('${start+i+1}',textAlign:TextAlign.right,style:const TextStyle(fontSize:8,color:Colors.black38))), const SizedBox(width:6), Expanded(child:Text(xs[i],style:TextStyle(fontFamily:font,fontSize:size,height:1.45,color:textColor)))] )]);
    }
    if (n == 1) return one(lines,0);
    final per = (lines.length / n).ceil();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int c = 0; c < n; c++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: c == n - 1 ? 0 : 16),
              child: one(lines.skip(c * per).take(per).toList(), c * per),
            ),
          ),
      ],
    );
  }

  Widget rulerH() => SizedBox(height: 34, child: CustomPaint(painter: HRuler()));
  Widget rulerV() => SizedBox(width: 42, child: CustomPaint(painter: VRuler()));

  Widget paper() {
    final base = pageSizeName == 'A5' ? const Size(559, 794) : pageSizeName == 'Letter' ? const Size(612, 792) : pageSizeName == 'Legal' ? const Size(612, 1008) : const Size(794, 1123);
    final page = landscape ? Size(base.height, base.width) : base;
    final border = pageBorderStyle == 'Box' ? Border.all(color: const Color(0xff555555), width: 2) : pageBorderStyle == 'Double' ? Border.all(color: const Color(0xff333333), width: 4) : Border.all(color: const Color(0xffd0d0d0));
    final shadow = pageBorderStyle == 'Shadow' ? const [BoxShadow(color: Color(0x55000000), blurRadius: 9, offset: Offset(0, 3))] : const [BoxShadow(color: Color(0x33000000), blurRadius: 5, offset: Offset(0, 2))];
    return Container(width: page.width, constraints: BoxConstraints(minHeight: page.height), margin: const EdgeInsets.symmetric(vertical: 18), padding: EdgeInsets.fromLTRB(marginLeft + indent * 24, marginTop, marginRight, marginBottom), decoration: BoxDecoration(color: pageColor, border: border, boxShadow: shadow), child: Stack(children: [
      if (watermark.isNotEmpty) Positioned.fill(child: IgnorePointer(child: Center(child: Transform.rotate(angle: -math.pi / 6, child: Opacity(opacity: .10, child: Text(watermark, style: const TextStyle(fontSize: 54, fontWeight: FontWeight.bold))))))),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (headerText.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(headerText, textAlign: TextAlign.center, style: TextStyle(fontFamily: font, fontSize: math.max(9.0, size - 1), fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
        if (insertedImagePath != null) Align(alignment: imageWrap == 'Right' ? Alignment.centerRight : imageWrap == 'Left' ? Alignment.centerLeft : Alignment.center, child: Padding(padding: const EdgeInsets.only(bottom: 16), child: SizedBox(width: imageWidth, height: imageHeight, child: ClipRect(child: Image.file(File(insertedImagePath!), fit: imageCrop == 'Square' ? BoxFit.cover : BoxFit.contain)))),),
        if (pageNumber != null) Align(alignment: Alignment.center, child: Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('Page $pageNumber', style: const TextStyle(fontSize: 10, color: Colors.black54)))),
        if (tables.isNotEmpty) tableEditor(),
        for (int bi = 0; bi < textBoxes.length; bi++) _textBoxWidget(bi),
        if (shapeKind.isNotEmpty) Transform.translate(offset: Offset(objectX, objectY), child: Transform.rotate(angle: objectRotation * math.pi / 180, child: _shapeWidget())),
        if (wordArtText.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Center(child: Text(wordArtText, style: TextStyle(fontFamily: font, fontSize: size * 2.0, fontWeight: FontWeight.bold, color: textColor, shadows: const [Shadow(blurRadius: 3, offset: Offset(2,2))])))),
        if (smartArtType.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border.all(width: 2), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [for (final x in smartArtData.split('|')) Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Chip(label: Text(x))) ]))),
        if (chartType.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Container(height: 170, padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all()), child: CustomPaint(painter: _ChartPainter(chartType, chartData)))),
        if (equationText.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Center(child: Text(equationText, style: const TextStyle(fontFamily: 'serif', fontSize: 22)))),
        if (dropCap && text.text.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 2), child: Align(alignment: Alignment.centerLeft, child: Text(text.text.substring(0, 1), style: TextStyle(fontFamily: font, fontSize: size * 3.2, fontWeight: FontWeight.bold)))),
        Container(
          constraints: const BoxConstraints(minHeight: 720),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.black12))),
          child: quill.QuillEditor.basic(
            controller: _quill,
            config: quill.QuillEditorConfig(
              readOnly: documentProtected,
              padding: EdgeInsets.zero,
              expands: false,
              scrollable: true,
              placeholder: 'Start typing your document…',
              autoFocus: false,
            ),
          ),
        ),
        if (footnotes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Divider(), const Text('Footnotes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), for(final f in footnotes) Text('[${f.marker}] ${f.text}', style: const TextStyle(fontSize: 9))])),
        if (endnotes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Divider(), const Text('Endnotes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), for(final f in endnotes) Text('[${f.marker}] ${f.text}', style: const TextStyle(fontSize: 9))])),
        if (showFormattingMarks) Padding(padding: const EdgeInsets.only(top: 8), child: Text('¶  Formatting marks are shown', style: TextStyle(color: Colors.black38, fontSize: 9))),
        if (footerText.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 14), child: Text(footerText, textAlign: TextAlign.center, style: TextStyle(fontFamily: font, fontSize: math.max(9.0, size - 1), fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
      ]),
    ]));
  }

  Widget _shapeWidget() {
    Widget child;
    if (shapeKind == 'Circle') child = const CircleAvatar(radius: 42, child: Icon(Icons.circle_outlined, size: 54));
    else if (shapeKind == 'Arrow') child = const Icon(Icons.arrow_forward, size: 90);
    else if (shapeKind == 'Line') child = const SizedBox(width: 220, child: Divider(thickness: 3));
    else if (shapeKind == 'Triangle') child = const Icon(Icons.change_history, size: 100);
    else child = Container(width: 210, height: 90, decoration: BoxDecoration(border: Border.all(width: 2), borderRadius: BorderRadius.circular(shapeKind == 'Rounded Rectangle' ? 16 : 2)), alignment: Alignment.center, child: Text(shapeKind, style: const TextStyle(fontSize: 13)));
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Center(child: child));
  }

  Widget _textBoxWidget(int index) {
    final b = textBoxes[index]; final selected = selectedTextBox == index;
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: GestureDetector(
      onTap: () => setState(() => selectedTextBox = index),
      onPanUpdate: (d) => setState(() { b.x += d.delta.dx; b.y += d.delta.dy; }),
      child: Transform.translate(offset: Offset(b.x, b.y), child: AnimatedContainer(duration: const Duration(milliseconds: 100), width: b.width, height: b.height, alignment: Alignment.center, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: selected ? const Color(0xff1565c0) : const Color(0xff777777), width: selected ? 2 : 1), borderRadius: BorderRadius.circular(4), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 3, offset: Offset(0, 1))]), child: Text(b.text, textAlign: b.align, style: TextStyle(fontFamily: font, fontSize: size, fontWeight: b.bold ? FontWeight.bold : FontWeight.normal, color: textColor))))));
  }

  Widget status() { final totalPages = math.max(1, _layoutPages().length); return Container(height: 43, color: const Color(0xfff3f3f3), child: Row(children: [const SizedBox(width: 18), Text('Page 1 of $totalPages'), const SizedBox(width: 30), Text('words $words'), const SizedBox(width: 30), const Icon(Icons.language, size: 18), const SizedBox(width: 5), const Text('English (United States)'), if (showLineNumbers) const Padding(padding: EdgeInsets.only(left: 18), child: Text('Line Numbers')), if (hyphenation) const Padding(padding: EdgeInsets.only(left: 18), child: Text('Hyphenation')), if (trackChanges) const Padding(padding: EdgeInsets.only(left: 18), child: Text('Track Changes')), if (documentProtected) const Padding(padding: EdgeInsets.only(left: 18), child: Icon(Icons.lock, size: 16)), const Spacer(), const Text('−', style: TextStyle(fontSize: 20)), SizedBox(width: 135, child: Slider(value: zoom, min: .5, max: 1.5, onChanged: (v) => setState(() => zoom = v))), const Text('+', style: TextStyle(fontSize: 20)), const SizedBox(width: 10), Text('${(zoom * 100).round()}%'), const SizedBox(width: 18)])); }
}

class _ChartPainter extends CustomPainter {
  final String type; final String data; _ChartPainter(this.type,this.data);
  @override void paint(Canvas c, Size s) { final p = Paint()..style = PaintingStyle.stroke..strokeWidth = 2; final fill = Paint()..style = PaintingStyle.fill; final base = Offset(25, s.height - 25); c.drawLine(base, Offset(s.width - 15, base.dy), p); c.drawLine(base, Offset(base.dx, 15), p); final vals=data.split(',').map((x)=>double.tryParse(x.trim())??0).toList(); for (int i = 0; i < vals.length; i++) { final x = 35 + i * 45.0; final h = math.min(120, math.max(5, vals[i] * 2)); if (type == 'Line') { final y = s.height - 25 - h; c.drawCircle(Offset(x,y), 3, fill); if (i > 0) { final px = 35 + (i-1) * 45.0; final ph = math.min(120, math.max(5, vals[i-1] * 2)); c.drawLine(Offset(px, s.height-25-ph), Offset(x,y), p); } } else if (type == 'Pie') { if (i == 0) c.drawArc(Rect.fromLTWH(55,20,110,110), 0, math.pi*1.35, true, p); } else { c.drawRect(Rect.fromLTWH(x, s.height-25-h, 24, h), fill); } } }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
class HRuler extends CustomPainter {
  @override
  void paint(Canvas c, Size s) { final p = Paint()..color = const Color(0xff777777)..strokeWidth = 1; const y = 23.0; c.drawLine(const Offset(0, y), Offset(s.width, y), p); for (double x = 0; x < s.width; x += 10) { final n = x.round() % 100; final h = n == 0 ? 14 : n == 50 ? 10 : 6; c.drawLine(Offset(x, y), Offset(x, y - h), p); } }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
class VRuler extends CustomPainter {
  @override
  void paint(Canvas c, Size s) { final p = Paint()..color = const Color(0xff777777)..strokeWidth = 1; for (double y = 0; y < s.height; y += 10) { final n = y.round() % 100; final w = n == 0 ? 14 : n == 50 ? 10 : 6; c.drawLine(Offset(s.width, y), Offset(s.width - w, y), p); } }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
