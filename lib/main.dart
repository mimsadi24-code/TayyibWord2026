import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  double objectX = 0.0;
  double objectY = 0.0;
  double objectRotation = 0.0;
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
            void toggleList(bool numbered) {
    setState(() {
      if (numbered) {
        numbering = !numbering;
        if (numbering) bullets = false;
      } else {
        bullets = !bullets;
        if (bullets) numbering = false;
      }
    });
  }

  void insertAtCursor(String value) {
    if (documentProtected) {
      toast('Document is protected');
      return;
    }
    final s = text.selection;
    final start = math.max(0, math.min(s.start, text.text.length));
    final end = math.max(start, math.min(s.end, text.text.length));
    final newText = text.text.replaceRange(start, end, value);
    _setPlainText(newText);
    final pos = start + value.length;
    text.selection = TextSelection.collapsed(offset: pos);
    _quill.updateSelection(
      TextSelection.collapsed(offset: pos),
      quill.ChangeSource.local,
    );
  }

  Future<void> paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) insertAtCursor(data!.text!);
  }

  void cut() {
    final s = text.selection;
    if (!s.isValid || s.isCollapsed) {
      toast('Select text first');
      return;
    }
    final selected = text.text.substring(s.start, s.end);
    Clipboard.setData(ClipboardData(text: selected));
    insertAtCursor('');
  }

  void copy() {
    final s = text.selection;
    if (!s.isValid || s.isCollapsed) {
      toast('Select text first');
      return;
    }
    Clipboard.setData(
      ClipboardData(text: text.text.substring(s.start, s.end)),
    );
    toast('Copied');
  }

  void selectAll() {
    text.selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.text.length,
    );
    _quill.updateSelection(
      text.selection,
      quill.ChangeSource.local,
    );
  }

  Future<void> findText() async {
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Find'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search text',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, c.text),
            child: const Text('Find'),
          ),
        ],
      ),
    );
    c.dispose();
    if (v == null || v.isEmpty) return;

    final index = text.text.toLowerCase().indexOf(v.toLowerCase());
    if (index < 0) {
      toast('Text not found');
      return;
    }

    text.selection = TextSelection(
      baseOffset: index,
      extentOffset: index + v.length,
    );
    _quill.updateSelection(
      text.selection,
      quill.ChangeSource.local,
    );
  }

  Future<void> replaceText() async {
    final find = TextEditingController();
    final replace = TextEditingController();

    final result = await showDialog<List<String>>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Find and Replace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: find,
              decoration: const InputDecoration(
                labelText: 'Find',
              ),
            ),
            TextField(
              controller: replace,
              decoration: const InputDecoration(
                labelText: 'Replace with',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              d,
              [find.text, replace.text],
            ),
            child: const Text('Replace All'),
          ),
        ],
      ),
    );

    find.dispose();
    replace.dispose();

    if (result == null || result[0].isEmpty) return;

    final newText = text.text.replaceAll(
      result[0],
      result[1],
    );

    _setPlainText(newText);
    toast('Replacement completed');
  }

  Future<void> insertLink() async {
    final c = TextEditingController();

    final v = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Insert Link'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(
            labelText: 'URL',
            hintText: 'https://example.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, c.text.trim()),
            child: const Text('Insert'),
          ),
        ],
      ),
    );

    c.dispose();

    if (v == null || v.isEmpty) return;

    final uri = Uri.tryParse(v);
    if (uri == null) {
      toast('Invalid URL');
      return;
    }

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> insertDate() async {
    final now = DateTime.now();
    insertAtCursor(
      '${now.day.toString().padLeft(2, '0')}/'
      '${now.month.toString().padLeft(2, '0')}/'
      '${now.year}',
    );
  }

  Future<void> insertTime() async {
    final now = TimeOfDay.now();
    insertAtCursor(
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}',
    );
  }

  Future<void> insertSymbol() async {
    final v = await simpleChoice(
      'Symbol',
      [
        '©',
        '®',
        '™',
        '§',
        '±',
        '×',
        '÷',
        '≤',
        '≥',
        '≠',
        '∞',
        '√',
        'π',
        '→',
        '←',
        '↑',
        '↓',
        '★',
        '♥',
        '✓',
      ],
    );

    if (v != null) insertAtCursor(v);
  }

  Future<void> insertEquation() async {
    final c = TextEditingController();

    final v = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Equation'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(
            hintText: 'Example: a² + b² = c²',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, c.text),
            child: const Text('Insert'),
          ),
        ],
      ),
    );

    c.dispose();

    if (v != null && v.isNotEmpty) {
      setState(() => equationText = v);
      insertAtCursor(v);
    }
  }

  Future<void> insertPageBreak() async {
    insertAtCursor('\n--- PAGE BREAK ---\n');
  }

  Future<void> insertPageNumber() async {
    setState(() => pageNumber = 1);
    insertAtCursor('PAGE ');
  }

  Future<void> pickImage() async {
    if (documentProtected) {
      toast('Document is protected');
      return;
    }

    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );

    if (picked == null) return;

    setState(() {
      insertedImagePath = picked.path;
      imageWidth = 420;
      imageHeight = 240;
    });
  }

  void removeImage() {
    setState(() {
      insertedImagePath = null;
    });
  }

  Future<void> pictureSettings() async {
    final w = TextEditingController(
      text: imageWidth.toStringAsFixed(0),
    );
    final h = TextEditingController(
      text: imageHeight.toStringAsFixed(0),
    );

    final v = await showDialog<List<String>>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Picture Size'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: w,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Width',
              ),
            ),
            TextField(
              controller: h,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Height',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              d,
              [w.text, h.text],
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    w.dispose();
    h.dispose();

    if (v == null) return;

    final nw = double.tryParse(v[0]);
    final nh = double.tryParse(v[1]);

    if (nw == null || nh == null) return;

    setState(() {
      imageWidth = nw;
      imageHeight = nh;
    });
  }

  Future<void> cropPicture() async {
    if (insertedImagePath == null) {
      toast('Insert a picture first');
      return;
    }
    setState(() => imageCrop = 'Cropped');
    toast('Picture crop mode enabled');
  }

  Future<void> chooseImageWrap() async {
    final v = await simpleChoice(
      'Text Wrapping',
      [
        'In Line',
        'Square',
        'Tight',
        'Through',
        'Top and Bottom',
        'Behind Text',
        'In Front',
      ],
    );

    if (v != null) {
      setState(() => imageWrap = v);
    }
  }

  Future<void> chooseArrange() async {
    final v = await simpleChoice(
      'Arrange',
      [
        'In Front',
        'Behind Text',
        'Bring Forward',
        'Send Backward',
      ],
    );

    if (v != null) {
      setState(() => arrangeMode = v);
    }
  }

  Future<void> objectTransformSettings() async {
    final x = TextEditingController(
      text: objectX.toStringAsFixed(0),
    );
    final y = TextEditingController(
      text: objectY.toStringAsFixed(0),
    );
    final r = TextEditingController(
      text: objectRotation.toStringAsFixed(0),
    );

    final v = await showDialog<List<String>>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Object Position'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: x,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'X',
              ),
            ),
            TextField(
              controller: y,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Y',
              ),
            ),
            TextField(
              controller: r,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Rotation',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              d,
              [x.text, y.text, r.text],
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    x.dispose();
    y.dispose();
    r.dispose();

    if (v == null) return;

    setState(() {
      objectX = double.tryParse(v[0]) ?? 0;
      objectY = double.tryParse(v[1]) ?? 0;
      objectRotation = double.tryParse(v[2]) ?? 0;
    });
  }

  Future<void> insertTextBox() async {
    final c = TextEditingController();

    final v = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Insert Text Box'),
        content: TextField(
          controller: c,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Type text',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              d,
              c.text,
            ),
            child: const Text('Insert'),
          ),
        ],
      ),
    );

    c.dispose();

    if (v == null) return;

    setState(() {
      textBoxes.add(_TextBoxModel(v));
      selectedTextBox = textBoxes.length - 1;
    });
  }

  Future<void> editSelectedTextBox() async {
    if (selectedTextBox < 0 ||
        selectedTextBox >= textBoxes.length) {
      toast('Select a text box first');
      return;
    }

    final box = textBoxes[selectedTextBox];
    final c = TextEditingController(text: box.text);

    final v = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Edit Text Box'),
        content: TextField(
          controller: c,
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, c.text),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    c.dispose();

    if (v != null) {
      setState(() => box.text = v);
    }
  }

  void deleteSelectedTextBox() {
    if (selectedTextBox < 0 ||
        selectedTextBox >= textBoxes.length) {
      toast('Select a text box first');
      return;
    }

    setState(() {
      textBoxes[selectedTextBox].dispose();
      textBoxes.removeAt(selectedTextBox);
      selectedTextBox =
          textBoxes.isEmpty ? -1 : math.min(
            selectedTextBox,
            textBoxes.length - 1,
          );
    });
  }

  void cycleTextBoxAlign() {
    if (selectedTextBox < 0 ||
        selectedTextBox >= textBoxes.length) {
      toast('Select a text box first');
      return;
    }

    final box = textBoxes[selectedTextBox];

    setState(() {
      if (box.align == TextAlign.left) {
        box.align = TextAlign.center;
      } else if (box.align == TextAlign.center) {
        box.align = TextAlign.right;
      } else {
        box.align = TextAlign.left;
      }
    });
  }

  void growTextBox() {
    if (selectedTextBox < 0 ||
        selectedTextBox >= textBoxes.length) {
      toast('Select a text box first');
      return;
    }

    setState(() {
      textBoxes[selectedTextBox].width =
          math.min(900, textBoxes[selectedTextBox].width + 40);
      textBoxes[selectedTextBox].height =
          math.min(500, textBoxes[selectedTextBox].height + 20);
    });
  }

  void shrinkTextBox() {
    if (selectedTextBox < 0 ||
        selectedTextBox >= textBoxes.length) {
      toast('Select a text box first');
      return;
    }

    setState(() {
      textBoxes[selectedTextBox].width =
          math.max(120, textBoxes[selectedTextBox].width - 40);
      textBoxes[selectedTextBox].height =
          math.max(50, textBoxes[selectedTextBox].height - 20);
    });
  }

  void toggleDropCap() {
    setState(() => dropCap = !dropCap);
    toast(dropCap ? 'Drop Cap enabled' : 'Drop Cap disabled');
  }

  void insertSignature() {
    insertAtCursor(
      signatureText.isEmpty ? 'Signature: __________' : signatureText,
    );
  }

  void insertQuickPart() {
    insertAtCursor(
      quickPartText.isEmpty ? '[Quick Part]' : quickPartText,
    );
  }

  Future<void> insertSmartArt() async {
    final v = await simpleChoice(
      'SmartArt',
      [
        'Process',
        'Cycle',
        'Hierarchy',
        'Relationship',
        'Matrix',
        'Pyramid',
      ],
    );

    if (v != null) {
      setState(() => smartArtType = v);
      toast('SmartArt: $v');
    }
  }

  Future<void> insertChart() async {
    final v = await simpleChoice(
      'Chart Type',
      [
        'Column',
        'Bar',
        'Line',
        'Pie',
      ],
    );

    if (v != null) {
      setState(() => chartType = v);
      toast('Chart inserted: $v');
    }
  }

  Future<void> insertTable() async {
    final r = TextEditingController(text: '3');
    final c = TextEditingController(text: '3');

    final v = await showDialog<List<String>>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Insert Table'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: r,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Rows',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: c,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Columns',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              d,
              [r.text, c.text],
            ),
            child: const Text('Insert'),
          ),
        ],
      ),
    );

    r.dispose();
    c.dispose();

    if (v == null) return;

    final rows = math.max(
      1,
      int.tryParse(v[0]) ?? 3,
    );
    final cols = math.max(
      1,
      int.tryParse(v[1]) ?? 3,
    );

    setState(() {
      tables.add(_TableModel(rows, cols));
      selectedTable = tables.length - 1;
    });
  }

  void addTableRow() {
    if (selectedTable < 0 ||
        selectedTable >= tables.length) {
      toast('Select a table first');
      return;
    }

    setState(() => tables[selectedTable].addRow());
  }

  void addTableColumn() {
    if (selectedTable < 0 ||
        selectedTable >= tables.length) {
      toast('Select a table first');
      return;
    }

    setState(() => tables[selectedTable].addColumn());
  }

  void deleteTable() {
    if (selectedTable < 0 ||
        selectedTable >= tables.length) {
      toast('Select a table first');
      return;
    }

    setState(() {
      tables[selectedTable].dispose();
      tables.removeAt(selectedTable);
      selectedTable =
          tables.isEmpty ? -1 : math.min(
            selectedTable,
            tables.length - 1,
          );
    });
  }

  void mergeSelectedTableCells() {
    if (selectedTable < 0 ||
        selectedTable >= tables.length) {
      toast('Select a table first');
      return;
    }

    final t = tables[selectedTable];

    if (t.selectedStartRow < 0) {
      toast('Select cells first');
      return;
    }

    final r1 = math.min(
      t.selectedStartRow,
      t.selectedEndRow,
    );
    final r2 = math.max(
      t.selectedStartRow,
      t.selectedEndRow,
    );
    final c1 = math.min(
      t.selectedStartCol,
      t.selectedEndCol,
    );
    final c2 = math.max(
      t.selectedStartCol,
      t.selectedEndCol,
    );

    if (r1 == r2 && c1 == c2) {
      toast('Select more than one cell');
      return;
    }

    setState(() {
      t.mergedCells.add('$r1:$c1:$r2:$c2');
    });
  }

  void splitMergedTableCells() {
    if (selectedTable < 0 ||
        selectedTable >= tables.length) {
      toast('Select a table first');
      return;
    }

    final t = tables[selectedTable];

    if (t.selectedStartRow < 0) {
      toast('Select merged cells first');
      return;
    }

    final r1 = math.min(
      t.selectedStartRow,
      t.selectedEndRow,
    );
    final r2 = math.max(
      t.selectedStartRow,
      t.selectedEndRow,
    );
    final c1 = math.min(
      t.selectedStartCol,
      t.selectedEndCol,
    );
    final c2 = math.max(
      t.selectedStartCol,
      t.selectedEndCol,
    );

    setState(() {
      t.mergedCells.remove(
        '$r1:$c1:$r2:$c2',
      );
    });
  }

  Future<void> tableProperties() async {
    if (selectedTable < 0 ||
        selectedTable >= tables.length) {
      toast('Select a table first');
      return;
    }

    final t = tables[selectedTable];

    final width = TextEditingController(
      text: t.width.toStringAsFixed(0),
    );

    final height = TextEditingController(
      text: t.rowHeight.toStringAsFixed(0),
    );

    final v = await showDialog<List<String>>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Table Properties'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: width,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Table Width',
              ),
            ),
            TextField(
              controller: height,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Row Height',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              d,
              [width.text, height.text],
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    width.dispose();
    height.dispose();

    if (v == null) return;

    setState(() {
      t.width = double.tryParse(v[0]) ?? t.width;
      t.rowHeight = double.tryParse(v[1]) ?? t.rowHeight;
    });
  }
                if (showHeader && h.isNotEmpty)
        Positioned(top: -8, left: 0, right: 0, child: Text(h, textAlign: TextAlign.center, style: TextStyle(fontFamily: font, fontSize: 10, color: Colors.grey.shade700))),
      if (showFooter && f.isNotEmpty)
        Positioned(bottom: -8, left: 0, right: 0, child: Text(f, textAlign: TextAlign.center, style: TextStyle(fontFamily: font, fontSize: 10, color: Colors.grey.shade700))),
      Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 22),
          child: Text(
            body,
            textAlign: alignment,
            style: TextStyle(
              fontFamily: font,
              fontSize: size,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              decoration: underline
                  ? TextDecoration.underline
                  : strike
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
              height: lineSpacing,
            ),
          ),
        ),
      ),
      if (pageNumber != null && showFooter)
        Positioned(
          bottom: -8,
          right: 0,
          child: Text(
            '${pageNumber! + number - 1}',
            style: TextStyle(fontFamily: font, fontSize: 10),
          ),
        ),
    ]));
  }

  Widget paper() {
    final base = pageSizeName == 'A5'
        ? const Size(559, 794)
        : pageSizeName == 'Letter'
            ? const Size(612, 792)
            : pageSizeName == 'Legal'
                ? const Size(612, 1008)
                : const Size(794, 1123);

    final page = landscape ? Size(base.height, base.width) : base;

    return Container(
      width: page.width,
      constraints: BoxConstraints(minHeight: page.height),
      padding: EdgeInsets.fromLTRB(
        marginLeft,
        marginTop,
        marginRight,
        marginBottom,
      ),
      decoration: BoxDecoration(
        color: pageColor,
        border: pageBorderStyle == 'Box'
            ? Border.all(color: Colors.grey.shade600, width: 2)
            : pageBorderStyle == 'Double'
                ? Border.all(color: Colors.grey.shade700, width: 4)
                : Border.all(color: Colors.grey.shade300),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (watermark.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Transform.rotate(
                    angle: -math.pi / 6,
                    child: Opacity(
                      opacity: .10,
                      child: Text(
                        watermark,
                        style: const TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (headerText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    headerText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: font,
                      fontSize: 10,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              Expanded(
                child: QuillEditor.basic(
                  controller: _quill,
                  config: QuillEditorConfig(
                    placeholder: 'Start typing...',
                    expands: false,
                    padding: EdgeInsets.zero,
                    scrollable: false,
                    autoFocus: false,
                  ),
                ),
              ),
              if (footerText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    footerText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: font,
                      fontSize: 10,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
            ],
          ),
          if (insertedImagePath != null)
            Positioned(
              left: math.max(0, objectX),
              top: math.max(0, objectY),
              child: Transform.rotate(
                angle: objectRotation * math.pi / 180,
                child: Image.file(
                  File(insertedImagePath!),
                  width: imageWidth,
                  height: imageHeight,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          for (int i = 0; i < textBoxes.length; i++)
            Positioned(
              left: math.max(0, textBoxes[i].x),
              top: math.max(0, textBoxes[i].y),
              child: GestureDetector(
                onTap: () => setState(() => selectedTextBox = i),
                child: Container(
                  width: textBoxes[i].width,
                  height: textBoxes[i].height,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selectedTextBox == i
                        ? const Color(0x22aaaaaa)
                        : Colors.transparent,
                    border: Border.all(
                      color: selectedTextBox == i
                          ? const Color(0xff185abd)
                          : Colors.grey.shade500,
                    ),
                  ),
                  child: Text(
                    textBoxes[i].text,
                    textAlign: textBoxes[i].align,
                    style: TextStyle(
                      fontFamily: font,
                      fontSize: size,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget rulerH() {
    return Container(
      height: 28,
      color: Colors.white,
      child: CustomPaint(
        painter: HRuler(
          zoom: zoom,
          marginLeft: marginLeft,
        ),
      ),
    );
  }

  Widget rulerV() {
    return SizedBox(
      width: 28,
      child: CustomPaint(
        painter: VRuler(
          zoom: zoom,
          marginTop: marginTop,
        ),
      ),
    );
  }

  Widget toolbarButton(
    IconData icon,
    String tooltip,
    VoidCallback action,
  ) {
    return IconButton(
      tooltip: tooltip,
      onPressed: action,
      icon: Icon(icon),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget topToolbar() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            toolbarButton(Icons.save, 'Save', saveDocument),
            toolbarButton(Icons.folder_open, 'Open', openDocument),
            toolbarButton(Icons.undo, 'Undo', undo),
            toolbarButton(Icons.redo, 'Redo', redo),
            const VerticalDivider(width: 8),
            toolbarButton(Icons.content_cut, 'Cut', cut),
            toolbarButton(Icons.content_copy, 'Copy', copy),
            toolbarButton(Icons.content_paste, 'Paste', paste),
            toolbarButton(Icons.select_all, 'Select All', selectAll),
            const VerticalDivider(width: 8),
            toolbarButton(Icons.search, 'Find', findText),
            toolbarButton(
              Icons.find_replace,
              'Replace',
              replaceText,
            ),
            toolbarButton(
              Icons.comment,
              'Comment',
              addCommentAtSelection,
            ),
            toolbarButton(
              Icons.rate_review,
              'Review Changes',
              reviewChanges,
            ),
          ],
        ),
      ),
    );
  }

  Widget formattingToolbar() {
    return Container(
      color: const Color(0xfff5f5f5),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Bold',
              onPressed: () {
                setState(() => bold = !bold);
                _quill.formatSelection(
                  bold ? quill.Attribute.bold : quill.Attribute.bold.unset,
                );
              },
              icon: Icon(
                Icons.format_bold,
                color: bold ? const Color(0xff185abd) : null,
              ),
            ),
            IconButton(
              tooltip: 'Italic',
              onPressed: () {
                setState(() => italic = !italic);
                _quill.formatSelection(
                  italic
                      ? quill.Attribute.italic
                      : quill.Attribute.italic.unset,
                );
              },
              icon: Icon(
                Icons.format_italic,
                color: italic ? const Color(0xff185abd) : null,
              ),
            ),
            IconButton(
              tooltip: 'Underline',
              onPressed: () {
                setState(() => underline = !underline);
                _quill.formatSelection(
                  underline
                      ? quill.Attribute.underline
                      : quill.Attribute.underline.unset,
                );
              },
              icon: Icon(
                Icons.format_underline,
                color: underline ? const Color(0xff185abd) : null,
              ),
            ),
            IconButton(
              tooltip: 'Strikethrough',
              onPressed: () {
                setState(() => strike = !strike);
                _quill.formatSelection(
                  strike
                      ? quill.Attribute.strikeThrough
                      : quill.Attribute.strikeThrough.unset,
                );
              },
              icon: const Icon(Icons.strikethrough_s),
            ),
            IconButton(
              tooltip: 'Bulleted List',
              onPressed: () => toggleList(false),
              icon: const Icon(Icons.format_list_bulleted),
            ),
            IconButton(
              tooltip: 'Numbered List',
              onPressed: () => toggleList(true),
              icon: const Icon(Icons.format_list_numbered),
            ),
            IconButton(
              tooltip: 'Align Left',
              onPressed: () {
                setState(() => alignment = TextAlign.left);
                _quill.formatSelection(quill.Attribute.leftAlignment);
              },
              icon: const Icon(Icons.format_align_left),
            ),
            IconButton(
              tooltip: 'Align Center',
              onPressed: () {
                setState(() => alignment = TextAlign.center);
                _quill.formatSelection(quill.Attribute.centerAlignment);
              },
              icon: const Icon(Icons.format_align_center),
            ),
            IconButton(
              tooltip: 'Align Right',
              onPressed: () {
                setState(() => alignment = TextAlign.right);
                _quill.formatSelection(quill.Attribute.rightAlignment);
              },
              icon: const Icon(Icons.format_align_right),
            ),
            IconButton(
              tooltip: 'Justify',
              onPressed: () {
                setState(() => alignment = TextAlign.justify);
                _quill.formatSelection(quill.Attribute.justifyAlignment);
              },
              icon: const Icon(Icons.format_align_justify),
            ),
          ],
        ),
      ),
    );
  }
              Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader && h.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                h,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: font,
                  fontSize: math.max(9.0, size - 1),
                ),
              ),
            ),
          Expanded(child: _previewColumns(body)),
          if (showFooter)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                f.isNotEmpty ? '$f   $number' : '$number',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.black54,
                ),
              ),
            ),
        ],
      ),
    ]));
  }

  Widget _previewColumns(String body) {
    final lines = body.split('\n');
    final n = math.max(1, columns);

    Widget one(List<String> xs, int start) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < xs.length)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showLineNumbers)
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${start + i + 1}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 8,
                        color: Colors.black38,
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    xs[i],
                    style: TextStyle(
                      fontFamily: font,
                      fontSize: size,
                      height: 1.45,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
        ],
      );
    }

    if (n == 1) return one(lines, 0);

    final per = (lines.length / n).ceil();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int c = 0; c < n; c++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: c == n - 1 ? 0 : 16,
              ),
              child: one(
                lines.skip(c * per).take(per).toList(),
                c * per,
              ),
            ),
          ),
      ],
    );
  }

  Widget rulerH() =>
      SizedBox(height: 34, child: CustomPaint(painter: HRuler()));

  Widget rulerV() =>
      SizedBox(width: 42, child: CustomPaint(painter: VRuler()));

  Widget paper() {
    final base = pageSizeName == 'A5'
        ? const Size(559, 794)
        : pageSizeName == 'Letter'
            ? const Size(612, 792)
            : pageSizeName == 'Legal'
                ? const Size(612, 1008)
                : const Size(794, 1123);

    final page = landscape
        ? Size(base.height, base.width)
        : base;

    final border = pageBorderStyle == 'Box'
        ? Border.all(color: const Color(0xff555555), width: 2)
        : pageBorderStyle == 'Double'
            ? Border.all(
                color: const Color(0xff333333),
                width: 4,
              )
            : Border.all(
                color: const Color(0xffd0d0d0),
              );

    final shadow = pageBorderStyle == 'Shadow'
        ? const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 9,
              offset: Offset(0, 3),
            )
          ]
        : const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 5,
              offset: Offset(0, 2),
            )
          ];

    return Container(
      width: page.width,
      constraints: BoxConstraints(minHeight: page.height),
      margin: const EdgeInsets.symmetric(vertical: 18),
      padding: EdgeInsets.fromLTRB(
        marginLeft + indent * 24,
        marginTop,
        marginRight,
        marginBottom,
      ),
      decoration: BoxDecoration(
        color: pageColor,
        border: border,
        boxShadow: shadow,
      ),
      child: Stack(
        children: [
          if (watermark.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Transform.rotate(
                    angle: -math.pi / 6,
                    child: Opacity(
                      opacity: .10,
                      child: Text(
                        watermark,
                        style: const TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (headerText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    headerText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: font,
                      fontSize: math.max(9.0, size - 1),
                      fontWeight:
                          bold ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),

              if (insertedImagePath != null)
                Align(
                  alignment: imageWrap == 'Right'
                      ? Alignment.centerRight
                      : imageWrap == 'Left'
                          ? Alignment.centerLeft
                          : Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SizedBox(
                      width: imageWidth,
                      height: imageHeight,
                      child: ClipRect(
                        child: Image.file(
                          File(insertedImagePath!),
                          fit: imageCrop == 'Square'
                              ? BoxFit.cover
                              : BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),

              if (pageNumber != null)
                Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Page $pageNumber',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),

              if (tables.isNotEmpty) tableEditor(),

              for (int bi = 0; bi < textBoxes.length; bi++)
                _textBoxWidget(bi),

              if (shapeKind.isNotEmpty)
                Transform.translate(
                  offset: Offset(objectX, objectY),
                  child: Transform.rotate(
                    angle: objectRotation * math.pi / 180,
                    child: _shapeWidget(),
                  ),
                ),

              if (wordArtText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      wordArtText,
                      style: TextStyle(
                        fontFamily: font,
                        fontSize: size * 2.0,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        shadows: const [
                          Shadow(
                            blurRadius: 3,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              if (smartArtType.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final x in smartArtData.split('|'))
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            child: Chip(label: Text(x)),
                          ),
                      ],
                    ),
                  ),
                ),

              if (chartType.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Container(
                    height: 170,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(),
                    ),
                    child: CustomPaint(
                      painter:
                          _ChartPainter(chartType, chartData),
                    ),
                  ),
                ),

              if (equationText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text(
                      equationText,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 22,
                      ),
                    ),
                  ),
                ),

              if (dropCap && text.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      text.text.substring(0, 1),
                      style: TextStyle(
                        fontFamily: font,
                        fontSize: size * 3.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              Container(
                constraints: const BoxConstraints(minHeight: 720),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.black12),
                  ),
                ),
                child: quill.QuillEditor.basic(
                  controller: _quill,
                  config: quill.QuillEditorConfig(
                    padding: EdgeInsets.zero,
                    expands: false,
                    scrollable: true,
                    placeholder: 'Start typing your document…',
                    autoFocus: false,
                  ),
                ),
              ),

              if (footnotes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      const Text(
                        'Footnotes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      for (final f in footnotes)
                        Text(
                          '[${f.marker}] ${f.text}',
                          style: const TextStyle(fontSize: 9),
                        ),
                    ],
                  ),
                ),

              if (endnotes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      const Text(
                        'Endnotes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      for (final f in endnotes)
                        Text(
                          '[${f.marker}] ${f.text}',
                          style: const TextStyle(fontSize: 9),
                        ),
                    ],
                  ),
                ),

              if (showFormattingMarks)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '¶  Formatting marks are shown',
                    style: TextStyle(
                      color: Colors.black38,
                      fontSize: 9,
                    ),
                  ),
                ),

              if (footerText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    footerText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: font,
                      fontSize: math.max(9.0, size - 1),
                      fontWeight:
                          bold ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shapeWidget() {
    Widget child;

    if (shapeKind == 'Circle') {
      child = const CircleAvatar(
        radius: 42,
        child: Icon(
          Icons.circle_outlined,
          size: 54,
        ),
      );
    } else if (shapeKind == 'Arrow') {
      child = const Icon(
        Icons.arrow_forward,
        size: 90,
      );
    } else if (shapeKind == 'Line') {
      child = const SizedBox(
        width: 220,
        child: Divider(thickness: 3),
      );
    } else if (shapeKind == 'Triangle') {
      child = const Icon(
        Icons.change_history,
        size: 100,
      );
    } else {
      child = Container(
        width: 210,
        height: 90,
        decoration: BoxDecoration(
          border: Border.all(width: 2),
          borderRadius: BorderRadius.circular(
            shapeKind == 'Rounded Rectangle' ? 16 : 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          shapeKind,
          style: const TextStyle(fontSize: 13),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(child: child),
    );
  }

  Widget _textBoxWidget(int index) {
    final b = textBoxes[index];
    final selected = selectedTextBox == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () =>
            setState(() => selectedTextBox = index),
        onPanUpdate: (d) => setState(() {
          b.x += d.delta.dx;
          b.y += d.delta.dy;
        }),
        child: Transform.translate(
          offset: Offset(b.x, b.y),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: b.width,
            height: b.height,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: selected
                    ? const Color(0xff1565c0)
                    : const Color(0xff777777),
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              b.text,
              textAlign: b.align,
              style: TextStyle(
                fontFamily: font,
                fontSize: size,
                fontWeight:
                    b.bold ? FontWeight.bold : FontWeight.normal,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget status() {
    final totalPages =
        math.max(1, _layoutPages().length);

    return Container(
      height: 43,
      color: const Color(0xfff3f3f3),
      child: Row(
        children: [
          const SizedBox(width: 18),
          Text('Page 1 of $totalPages'),
          const SizedBox(width: 30),
          Text('words $words'),
          const SizedBox(width: 30),
          const Icon(Icons.language, size: 18),
          const SizedBox(width: 5),
          const Text('English (United States)'),
          if (showLineNumbers)
            const Padding(
              padding: EdgeInsets.only(left: 18),
              child: Text('Line Numbers'),
            ),
          if (hyphenation)
            const Padding(
              padding: EdgeInsets.only(left: 18),
              child: Text('Hyphenation'),
            ),
          if (trackChanges)
            const Padding(
              padding: EdgeInsets.only(left: 18),
              child: Text('Track Changes'),
            ),
          if (documentProtected)
            const Padding(
              padding: EdgeInsets.only(left: 18),
              child: Icon(Icons.lock, size: 16),
            ),
          const Spacer(),
          const Text(
            '−',
            style: TextStyle(fontSize: 20),
          ),
          SizedBox(
            width: 135,
            child: Slider(
              value: zoom,
              min: .5,
              max: 1.5,
              onChanged: (v) =>
                  setState(() => zoom = v),
            ),
          ),
          const Text(
            '+',
            style: TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 10),
          Text('${(zoom * 100).round()}%'),
          const SizedBox(width: 18),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final String type;
  final String data;

  _ChartPainter(this.type, this.data);

  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final fill = Paint()
      ..style = PaintingStyle.fill;

    final base = Offset(25, s.height - 25);

    c.drawLine(
      base,
      Offset(s.width - 15, base.dy),
      p,
    );

    c.drawLine(
      base,
      Offset(base.dx, 15),
      p,
    );

    final vals = data
        .split(',')
        .map((x) => double.tryParse(x.trim()) ?? 0)
        .toList();

    for (int i = 0; i < vals.length; i++) {
      final x = 35 + i * 45.0;
      final h = math.min(
        120.0,
        math.max(5.0, vals[i] * 2.0),
      );

      if (type == 'Line') {
        final y = s.height - 25 - h;

        c.drawCircle(
          Offset(x, y),
          3,
          fill,
        );

        if (i > 0) {
          final px = 35 + (i - 1) * 45.0;

          final ph = math.min(
            120.0,
            math.max(
              5.0,
              vals[i - 1] * 2.0,
            ),
          );

          c.drawLine(
            Offset(
              px,
              s.height - 25 - ph,
            ),
            Offset(x, y),
            p,
          );
        }
      } else if (type == 'Pie') {
        if (i == 0) {
          c.drawArc(
            Rect.fromLTWH(55, 20, 110, 110),
            0,
            math.pi * 1.35,
            true,
            p,
          );
        }
      } else {
        c.drawRect(
          Rect.fromLTWH(
            x,
            s.height - 25 - h,
            24,
            h,
          ),
          fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) =>
      false;
}

class HRuler extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = const Color(0xff777777)
      ..strokeWidth = 1;

    const y = 23.0;

    c.drawLine(
      const Offset(0, y),
      Offset(s.width, y),
      p,
    );

    for (double x = 0; x < s.width; x += 10) {
      final n = x.round() % 100;
      final h = n == 0
          ? 14
          : n == 50
              ? 10
              : 6;

      c.drawLine(
        Offset(x, y),
        Offset(x, y - h),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) =>
      false;
}

class VRuler extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = const Color(0xff777777)
      ..strokeWidth = 1;

    for (double y = 0; y < s.height; y += 10) {
      final n = y.round() % 100;

      final w = n == 0
          ? 14
          : n == 50
              ? 10
              : 6;

      c.drawLine(
        Offset(s.width, y),
        Offset(s.width - w, y),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) =>
      false;
}
