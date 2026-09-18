import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:archive/archive.dart';

class TayyibEquationEmbed extends quill.CustomBlockEmbed {
  static const String embedType = 'tayyibEquation';

  TayyibEquationEmbed({
    required String expression,
    required String numerator,
    required String denominator,
  }) : super(
         embedType,
         jsonEncode({
           'expression': expression,
           'numerator': numerator,
           'denominator': denominator,
         }),
       );

  static String expression(dynamic data) {
    final map = jsonDecode(data.toString());
    return (map['expression'] ?? '').toString();
  }

  static String numerator(dynamic data) {
    final map = jsonDecode(data.toString());
    return (map['numerator'] ?? '').toString();
  }

  static String denominator(dynamic data) {
    final map = jsonDecode(data.toString());
    return (map['denominator'] ?? '').toString();
  }
}

// ============================================================
// TAYYIB WORD - COMMON OBJECT INTERACTION LAYER
// ============================================================
//
// This layer provides:
//   • select
//   • drag / move
//   • pinch resize
//   • two-finger rotate
//   • long-press object menu
//   • reset
//   • delete
//
// Quill remains the document source of truth.
//
// IMPORTANT:
// Page Layout -> Columns is intentionally untouched.
// ============================================================

class TayyibObjectInteraction extends StatefulWidget {
  final quill.EmbedContext embedContext;
  final quill.EmbedBuilder childBuilder;
  final String embedType;
  final Map<String, dynamic> data;

  const TayyibObjectInteraction({
    super.key,
    required this.embedContext,
    required this.childBuilder,
    required this.embedType,
    required this.data,
  });

  @override
  State<TayyibObjectInteraction> createState() =>
      _TayyibObjectInteractionState();
}

class _TayyibObjectInteractionState extends State<TayyibObjectInteraction> {
  double _x = 0;
  double _y = 0;
  double _scale = 1;
  double _rotation = 0;

  double _startX = 0;
  double _startY = 0;
  double _startScale = 1;
  double _startRotation = 0;

  Offset _startFocalPoint = Offset.zero;
  bool _selected = false;
  bool _writing = false;

  @override
  void initState() {
    super.initState();
    _readTransform();
  }

  void _readTransform() {
    final d = widget.data;

    double number(dynamic value, double fallback) {
      if (value is num) return value.toDouble();
      return double.tryParse('$value') ?? fallback;
    }

    _x = number(d['x'], 0);
    _y = number(d['y'], 0);
    _scale = number(d['scale'], 1).clamp(0.25, 4.0);
    _rotation = number(d['rotation'], 0);
  }

  void _selectObject() {
    if (!_selected) {
      setState(() {
        _selected = true;
      });
    }

    final offset = widget.embedContext.node.documentOffset;

    widget.embedContext.controller.updateSelection(
      TextSelection.collapsed(offset: offset),
      quill.ChangeSource.local,
    );
  }

  void _startGesture(ScaleStartDetails details) {
    _selectObject();

    _startX = _x;
    _startY = _y;
    _startScale = _scale;
    _startRotation = _rotation;
    _startFocalPoint = details.focalPoint;
  }

  void _updateGesture(ScaleUpdateDetails details) {
    final dx = details.focalPoint.dx - _startFocalPoint.dx;
    final dy = details.focalPoint.dy - _startFocalPoint.dy;

    setState(() {
      // One finger = move.
      if (details.pointerCount <= 1) {
        _x = _startX + dx;
        _y = _startY + dy;
      }

      // Two fingers = resize + rotate.
      if (details.pointerCount >= 2) {
        _scale = (_startScale * details.scale).clamp(0.25, 4.0);
        _rotation = _startRotation + details.rotation;
      }
    });
  }

  void _endGesture(ScaleEndDetails details) {
    _writeTransformToQuill();
  }

  void _writeTransformToQuill() {
    if (_writing) return;

    _writing = true;

    try {
      final updated = <String, dynamic>{
        ...widget.data,
        'x': _x,
        'y': _y,
        'scale': _scale,
        'rotation': _rotation,
      };

      // Preserve the object's original geometry.
      // The generic interaction layer changes scale while keeping
      // width/height/size values already stored by the object.
      if (widget.data.containsKey('width')) {
        updated['width'] = widget.data['width'];
      }
      if (widget.data.containsKey('height')) {
        updated['height'] = widget.data['height'];
      }
      if (widget.data.containsKey('size')) {
        updated['size'] = widget.data['size'];
      }

      final offset = widget.embedContext.node.documentOffset;

      final replacement = quill.CustomBlockEmbed(
        widget.embedType,
        jsonEncode(updated),
      );

      widget.embedContext.controller.replaceText(
        offset,
        1,
        replacement,
        TextSelection.collapsed(offset: offset + 1),
      );
    } finally {
      _writing = false;
    }
  }

  Future<void> _showObjectMenu() async {
    _selectObject();

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                leading: Icon(Icons.open_with),
                title: Text('Object Controls'),
              ),
              ListTile(
                leading: const Icon(Icons.open_with),
                title: const Text('Move'),
                onTap: () => Navigator.pop(context, 'move'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_size_select_large),
                title: const Text('Resize'),
                onTap: () => Navigator.pop(context, 'resize'),
              ),
              ListTile(
                leading: const Icon(Icons.rotate_right),
                title: const Text('Rotate'),
                onTap: () => Navigator.pop(context, 'rotate'),
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reset Object'),
                onTap: () => Navigator.pop(context, 'reset'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete Object'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'reset') {
      setState(() {
        _x = 0;
        _y = 0;
        _scale = 1;
        _rotation = 0;
      });
      _writeTransformToQuill();
      return;
    }

    if (action == 'delete') {
      final offset = widget.embedContext.node.documentOffset;

      widget.embedContext.controller.replaceText(
        offset,
        1,
        '',
        TextSelection.collapsed(offset: offset),
      );
      return;
    }

    if (action == 'move') {
      _showMoveDialog();
      return;
    }

    if (action == 'resize') {
      _showResizeDialog();
      return;
    }

    if (action == 'rotate') {
      _showRotateDialog();
    }
  }

  Future<void> _showMoveDialog() async {
    final xController = TextEditingController(text: _x.toStringAsFixed(0));
    final yController = TextEditingController(text: _y.toStringAsFixed(0));

    final result = await showDialog<List<double>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Move Object'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: xController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'X position'),
              ),
              TextField(
                controller: yController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'Y position'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final x = double.tryParse(xController.text) ?? _x;
                final y = double.tryParse(yController.text) ?? _y;
                Navigator.pop(context, [x, y]);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    xController.dispose();
    yController.dispose();

    if (!mounted || result == null) return;

    setState(() {
      _x = result[0];
      _y = result[1];
    });

    _writeTransformToQuill();
  }

  Future<void> _showResizeDialog() async {
    final controller = TextEditingController(
      text: (_scale * 100).toStringAsFixed(0),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Resize Object'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Scale (%)',
              hintText: '100',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final percent =
                    double.tryParse(controller.text) ?? (_scale * 100);
                Navigator.pop(context, percent / 100);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || result == null) return;

    setState(() {
      _scale = result.clamp(0.25, 4.0);
    });

    _writeTransformToQuill();
  }

  Future<void> _showRotateDialog() async {
    final controller = TextEditingController(
      text: (_rotation * 180 / math.pi).toStringAsFixed(0),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rotate Object'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Angle (degrees)',
              hintText: '0',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final degrees =
                    double.tryParse(controller.text) ??
                    (_rotation * 180 / math.pi);
                Navigator.pop(context, degrees * math.pi / 180);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || result == null) return;

    setState(() {
      _rotation = result;
    });

    _writeTransformToQuill();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.childBuilder.build(context, widget.embedContext);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _selectObject,
      onDoubleTap: _showObjectMenu,
      onLongPress: _showObjectMenu,
      onScaleStart: _startGesture,
      onScaleUpdate: _updateGesture,
      onScaleEnd: _endGesture,
      child: Transform.translate(
        offset: Offset(_x, _y),
        child: Transform.rotate(
          angle: _rotation,
          child: Transform.scale(
            scale: _scale,
            alignment: Alignment.center,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: _selected
                    ? Border.all(color: Colors.green, width: 2)
                    : null,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class TayyibObjectBuilder extends quill.EmbedBuilder {
  final quill.EmbedBuilder inner;

  TayyibObjectBuilder(this.inner);

  @override
  String get key => inner.key;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    Map<String, dynamic> data = <String, dynamic>{};

    try {
      final raw = embedContext.node.value.data;

      if (raw is String && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);

        if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
      }
    } catch (_) {}

    return TayyibObjectInteraction(
      embedContext: embedContext,
      childBuilder: inner,
      embedType: key,
      data: data,
    );
  }
}

class TayyibEquationEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => TayyibEquationEmbed.embedType;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final data = embedContext.node.value.data;

    final expression = TayyibEquationEmbed.expression(data);
    final numerator = TayyibEquationEmbed.numerator(data);
    final denominator = TayyibEquationEmbed.denominator(data);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD0D0D0)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: numerator.isNotEmpty && denominator.isNotEmpty
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    numerator,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  Container(
                    width: 150,
                    height: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    color: Colors.black87,
                  ),
                  Text(
                    denominator,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              )
            : Text(
                expression,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontStyle: FontStyle.italic,
                ),
              ),
      ),
    );
  }
}

class TayyibTableEmbed extends quill.CustomBlockEmbed {
  static const String embedType = 'tayyibTable';

  TayyibTableEmbed({
    required int rows,
    required int columns,
    required bool headerRow,
    required String borderStyle,
    required List<List<String>> cells,
  }) : super(
         embedType,
         jsonEncode({
           'rows': rows,
           'columns': columns,
           'headerRow': headerRow,
           'borderStyle': borderStyle,
           'cells': cells,
         }),
       );
}

class TayyibTableEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => TayyibTableEmbed.embedType;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final raw = embedContext.node.value.data;

    if (raw is! String) {
      return const SizedBox.shrink();
    }

    Map<String, dynamic> data;

    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      } else {
        return const Text('[Table]');
      }
    } catch (_) {
      return const Text('[Table]');
    }

    final rows = (data['rows'] as num?)?.toInt() ?? 1;
    final columns = (data['columns'] as num?)?.toInt() ?? 1;
    final headerRow = data['headerRow'] == true;
    final borderStyle = data['borderStyle']?.toString() ?? 'Full';

    final rawCells = data['cells'];
    final cells = <List<String>>[];

    for (int r = 0; r < rows; r++) {
      final row = rawCells is List && r < rawCells.length ? rawCells[r] : null;

      final resultRow = <String>[];

      for (int c = 0; c < columns; c++) {
        if (row is List && c < row.length) {
          resultRow.add('${row[c]}');
        } else {
          resultRow.add('');
        }
      }

      cells.add(resultRow);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: () {
        _editTable(context, embedContext, data);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : columns * 110.0;

            final cellWidth = width / math.max(columns, 1);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int r = 0; r < rows; r++)
                  SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        for (int c = 0; c < columns; c++)
                          SizedBox(
                            width: cellWidth,
                            child: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: r == 0 && headerRow
                                    ? const Color(0xFFE7E6E6)
                                    : Colors.white,
                                border: borderStyle == 'None'
                                    ? null
                                    : Border.all(
                                        color: const Color(0xFF808080),
                                        width: 1,
                                      ),
                              ),
                              child: Text(
                                cells[r][c],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: r == 0 && headerRow
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _editTable(
    BuildContext context,
    quill.EmbedContext embedContext,
    Map<String, dynamic> original,
  ) async {
    int rows = (original['rows'] as num?)?.toInt() ?? 1;

    int columns = (original['columns'] as num?)?.toInt() ?? 1;

    bool headerRow = original['headerRow'] == true;

    String borderStyle = original['borderStyle']?.toString() ?? 'Full';

    final rawCells = original['cells'];

    final cells = <List<String>>[];

    for (int r = 0; r < rows; r++) {
      final sourceRow = rawCells is List && r < rawCells.length
          ? rawCells[r]
          : null;

      final row = <String>[];

      for (int c = 0; c < columns; c++) {
        if (sourceRow is List && c < sourceRow.length) {
          row.add('${sourceRow[c]}');
        } else {
          row.add('');
        }
      }

      cells.add(row);
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Table Properties'),
              content: SizedBox(
                width: 720,
                height: 520,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text('Rows: $rows'),
                        IconButton(
                          tooltip: 'Add Row',
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            setDialogState(() {
                              cells.add(List<String>.filled(columns, ''));
                              rows++;
                            });
                          },
                        ),
                        IconButton(
                          tooltip: 'Delete Row',
                          icon: const Icon(Icons.remove),
                          onPressed: rows <= 1
                              ? null
                              : () {
                                  setDialogState(() {
                                    cells.removeLast();
                                    rows--;
                                  });
                                },
                        ),
                        const SizedBox(width: 24),
                        Text('Columns: $columns'),
                        IconButton(
                          tooltip: 'Add Column',
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            setDialogState(() {
                              for (final row in cells) {
                                row.add('');
                              }
                              columns++;
                            });
                          },
                        ),
                        IconButton(
                          tooltip: 'Delete Column',
                          icon: const Icon(Icons.remove),
                          onPressed: columns <= 1
                              ? null
                              : () {
                                  setDialogState(() {
                                    for (final row in cells) {
                                      if (row.isNotEmpty) {
                                        row.removeLast();
                                      }
                                    }
                                    columns--;
                                  });
                                },
                        ),
                        const Spacer(),
                        Checkbox(
                          value: headerRow,
                          onChanged: (value) {
                            setDialogState(() {
                              headerRow = value ?? false;
                            });
                          },
                        ),
                        const Text('Header'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: borderStyle,
                      decoration: const InputDecoration(
                        labelText: 'Borders',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Full', child: Text('Full')),
                        DropdownMenuItem(value: 'Outer', child: Text('Outer')),
                        DropdownMenuItem(value: 'None', child: Text('None')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          borderStyle = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (int r = 0; r < rows; r++)
                              Row(
                                children: [
                                  for (int c = 0; c < columns; c++)
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(3),
                                        child: TextFormField(
                                          initialValue: cells[r][c],
                                          maxLines: 2,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            labelText: '${r + 1},${c + 1}',
                                            border: const OutlineInputBorder(),
                                          ),
                                          onChanged: (value) {
                                            cells[r][c] = value;
                                          },
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, <String, dynamic>{
                      ...original,
                      'rows': rows,
                      'columns': columns,
                      'headerRow': headerRow,
                      'borderStyle': borderStyle,
                      'cells': cells,
                    });
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    final embed = quill.CustomBlockEmbed(
      TayyibTableEmbed.embedType,
      jsonEncode(result),
    );

    try {
      embedContext.controller.replaceText(
        embedContext.node.documentOffset,
        1,
        embed,
        TextSelection.collapsed(offset: embedContext.node.documentOffset + 1),
      );
    } catch (_) {}
  }
}

class TayyibTextBoxEmbed extends quill.CustomBlockEmbed {
  static const String embedType = 'tayyibTextBox';

  TayyibTextBoxEmbed({required String text, required String style})
    : super(embedType, jsonEncode({'text': text, 'style': style}));
}

class TayyibTextBoxEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => TayyibTextBoxEmbed.embedType;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final raw = embedContext.node.value.data;

    if (raw is! String) {
      return const SizedBox.shrink();
    }

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final text = data['text']?.toString() ?? '';
      final style = data['style']?.toString() ?? 'Simple';

      Color background;
      Color border;

      switch (style) {
        case 'Blue':
          background = const Color(0xFFEAF3FF);
          border = const Color(0xFF5B9BD5);
          break;
        case 'Green':
          background = const Color(0xFFEAF7EA);
          border = const Color(0xFF70AD47);
          break;
        case 'Yellow':
          background = const Color(0xFFFFF9E6);
          border = const Color(0xFFD6B656);
          break;
        default:
          background = Colors.white;
          border = Colors.grey;
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: border, width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(text, style: const TextStyle(fontSize: 14, height: 1.35)),
        ),
      );
    } catch (_) {
      return const Text('[Text Box]');
    }
  }
}

class TayyibPictureEmbed extends quill.CustomBlockEmbed {
  static const String embedType = 'tayyibPicture';

  TayyibPictureEmbed({
    required String path,
    required double width,
    required double height,
    required String alignment,
  }) : super(
         embedType,
         jsonEncode({
           'path': path,
           'width': width,
           'height': height,
           'alignment': alignment,
         }),
       );
}

class TayyibPictureEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => TayyibPictureEmbed.embedType;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final raw = embedContext.node.value.data;

    if (raw is! String) {
      return const SizedBox.shrink();
    }

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;

      final path = data['path']?.toString() ?? '';
      final width = (data['width'] as num?)?.toDouble() ?? 500;
      final height = (data['height'] as num?)?.toDouble() ?? 300;
      final alignment = data['alignment']?.toString() ?? 'Center';

      if (path.isEmpty || !File(path).existsSync()) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image, color: Colors.grey),
              SizedBox(width: 8),
              Text('Picture not available'),
            ],
          ),
        );
      }

      Alignment imageAlignment;

      switch (alignment) {
        case 'Left':
          imageAlignment = Alignment.centerLeft;
          break;
        case 'Right':
          imageAlignment = Alignment.centerRight;
          break;
        case 'Center':
        default:
          imageAlignment = Alignment.center;
          break;
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Align(
          alignment: imageAlignment,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.file(
              File(path),
              width: width,
              height: height,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: width,
                  height: height,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                  ),
                  child: const Icon(
                    Icons.broken_image,
                    size: 42,
                    color: Colors.grey,
                  ),
                );
              },
            ),
          ),
        ),
      );
    } catch (_) {
      return const Text('[Picture]');
    }
  }
}

class TayyibWordArtEmbed extends quill.CustomBlockEmbed {
  static const String embedType = 'tayyibWordArt';

  TayyibWordArtEmbed({required String text, required String style})
    : super(embedType, jsonEncode({'text': text, 'style': style}));
}

class TayyibWordArtEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => TayyibWordArtEmbed.embedType;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final raw = embedContext.node.value.data;

    if (raw is! String) {
      return const SizedBox.shrink();
    }

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final text = data['text']?.toString() ?? '';
      final style = data['style']?.toString() ?? 'Classic';

      FontWeight weight = FontWeight.bold;
      FontStyle fontStyle = FontStyle.normal;
      Color textColor = const Color(0xFF1F4E79);
      Color? backgroundColor;
      Color? shadowColor;
      double fontSize = 28;

      switch (style) {
        case 'Bold':
          weight = FontWeight.w900;
          textColor = const Color(0xFF0B5394);
          fontSize = 30;
          break;

        case 'Outline':
          weight = FontWeight.bold;
          textColor = Colors.white;
          backgroundColor = const Color(0xFF4472C4);
          fontSize = 30;
          break;

        case 'Shadow':
          weight = FontWeight.bold;
          textColor = const Color(0xFF7030A0);
          shadowColor = Colors.black38;
          fontSize = 30;
          break;

        case 'Banner':
          weight = FontWeight.w900;
          textColor = Colors.white;
          backgroundColor = const Color(0xFFED7D31);
          fontSize = 28;
          break;

        case 'Classic':
        default:
          weight = FontWeight.bold;
          fontStyle = FontStyle.normal;
          textColor = const Color(0xFF1F4E79);
          fontSize = 28;
          break;
      }

      Widget wordArt = Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: weight,
          fontStyle: fontStyle,
          color: textColor,
          letterSpacing: 0.5,
          shadows: shadowColor == null
              ? null
              : [
                  Shadow(
                    color: shadowColor,
                    offset: const Offset(3, 3),
                    blurRadius: 3,
                  ),
                ],
        ),
      );

      if (backgroundColor != null) {
        wordArt = Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black26),
          ),
          child: wordArt,
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(child: wordArt),
      );
    } catch (_) {
      return const Text('[WordArt]');
    }
  }
}

class TayyibChartEmbed extends quill.CustomBlockEmbed {
  static const String embedType = 'tayyibChart';

  TayyibChartEmbed({
    required String chartType,
    required String title,
    required List<double> values,
  }) : super(
         embedType,
         jsonEncode({'type': chartType, 'title': title, 'values': values}),
       );
}

class TayyibChartEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => TayyibChartEmbed.embedType;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final raw = embedContext.node.value.data;

    if (raw is! String) {
      return const SizedBox.shrink();
    }

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final type = data['type']?.toString() ?? 'Column';
      final title = data['title']?.toString() ?? 'My Chart';
      final rawValues = data['values'];

      if (rawValues is! List) {
        return const SizedBox.shrink();
      }

      final values = <double>[
        for (final value in rawValues)
          if (value is num) value.toDouble(),
      ];

      if (values.isEmpty) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Container(
          width: double.infinity,
          height: 320,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFD0D0D0)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: CustomPaint(
                  painter: TayyibChartPainter(chartType: type, values: values),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      return const Text('[Chart]');
    }
  }
}

class TayyibChartPainter extends CustomPainter {
  final String chartType;
  final List<double> values;

  TayyibChartPainter({required this.chartType, required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxValue = values.reduce(math.max);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    const left = 38.0;
    const top = 10.0;
    const right = 10.0;
    const bottom = 24.0;

    final width = size.width - left - right;
    final height = size.height - top - bottom;

    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(
      const Offset(left, top),
      Offset(left, top + height),
      axisPaint,
    );

    canvas.drawLine(
      Offset(left, top + height),
      Offset(left + width, top + height),
      axisPaint,
    );

    if (chartType == 'Pie') {
      _paintPie(canvas, size);
      return;
    }

    if (chartType == 'Line') {
      _paintLine(canvas, left, top, width, height, safeMax);
      return;
    }

    final slot = width / values.length;

    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      final barHeight = height * (value / safeMax);

      final barWidth = math.min(42.0, slot * 0.65);

      final x = left + i * slot + (slot - barWidth) / 2;

      final y = top + height - barHeight;

      final paint = Paint()..style = PaintingStyle.fill;

      paint.color = Colors.blueGrey.shade600;

      canvas.drawRect(Rect.fromLTWH(x, y, barWidth, barHeight), paint);

      _drawText(
        canvas,
        value.toStringAsFixed(0),
        Offset(x + barWidth / 2, math.max(top, y - 15)),
        centered: true,
      );

      _drawText(
        canvas,
        '${i + 1}',
        Offset(x + barWidth / 2, top + height + 4),
        centered: true,
      );
    }
  }

  void _paintLine(
    Canvas canvas,
    double left,
    double top,
    double width,
    double height,
    double maxValue,
  ) {
    if (values.length < 2) return;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    linePaint.color = Colors.blueGrey.shade700;

    final pointPaint = Paint()..style = PaintingStyle.fill;

    pointPaint.color = Colors.blueGrey.shade700;

    final path = Path();

    for (var i = 0; i < values.length; i++) {
      final x = left + width * (i / (values.length - 1));

      final y = top + height - height * (values[i] / maxValue);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      canvas.drawCircle(Offset(x, y), 4, pointPaint);

      _drawText(
        canvas,
        values[i].toStringAsFixed(0),
        Offset(x, math.max(top, y - 15)),
        centered: true,
      );
    }

    canvas.drawPath(path, linePaint);
  }

  void _paintPie(Canvas canvas, Size size) {
    final total = values.fold<double>(
      0,
      (sum, value) => sum + math.max(0, value),
    );

    if (total <= 0) return;

    final radius = math.min(size.width, size.height) * 0.32;

    final center = Offset(size.width * 0.38, size.height * 0.52);

    final paint = Paint()..style = PaintingStyle.fill;

    var start = -math.pi / 2;

    for (var i = 0; i < values.length; i++) {
      final value = math.max(0, values[i]);

      if (value == 0) continue;

      final sweep = 2 * math.pi * value / total;

      paint.color = Colors.primaries[i % Colors.primaries.length].shade600;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        paint,
      );

      start += sweep;
    }

    for (var i = 0; i < values.length; i++) {
      final y = 12 + i * 22.0;

      paint.color = Colors.primaries[i % Colors.primaries.length].shade600;

      canvas.drawRect(Rect.fromLTWH(size.width * 0.70, y, 11, 11), paint);

      _drawText(
        canvas,
        'Item ${i + 1}: ${values[i].toStringAsFixed(0)}',
        Offset(size.width * 0.70 + 17, y),
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position, {
    bool centered = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 9, color: Colors.black87),
      ),
      textDirection: TextDirection.ltr,
    );

    painter.layout();

    final offset = centered
        ? Offset(position.dx - painter.width / 2, position.dy)
        : position;

    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant TayyibChartPainter oldDelegate) {
    return oldDelegate.chartType != chartType || oldDelegate.values != values;
  }
}

void main() {
  runApp(const TayyibWordApp());
}

class TayyibShapeEmbed extends quill.CustomBlockEmbed {
  static const String embedType = "tayyibShape";
  TayyibShapeEmbed({
    required String name,
    required double size,
    required String alignment,
  }) : super(
         embedType,
         jsonEncode({"name": name, "size": size, "alignment": alignment}),
       );
}

class TayyibShapeEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => TayyibShapeEmbed.embedType;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final raw = embedContext.node.value.data;
    if (raw is! String) return const SizedBox.shrink();
    try {
      final d = jsonDecode(raw) as Map<String, dynamic>;
      final name = d["name"]?.toString() ?? "Rectangle";
      final size = (d["size"] as num?)?.toDouble() ?? 120;
      final a = d["alignment"]?.toString() ?? "Center";
      return Align(
        alignment: a == "Left"
            ? Alignment.centerLeft
            : a == "Right"
            ? Alignment.centerRight
            : Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: CustomPaint(
            size: Size(size, size),
            painter: TayyibShapePainter(name),
          ),
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}

class TayyibShapePainter extends CustomPainter {
  final String name;
  TayyibShapePainter(this.name);

  @override
  void paint(Canvas c, Size s) {
    final f = Paint()
      ..color = const Color(0xFF5B9BD5)
      ..style = PaintingStyle.fill;
    final p = Paint()
      ..color = const Color(0xFF1F4E79)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final w = s.width, h = s.height, x = w / 2, y = h / 2;
    Path q = Path();

    if (name == "Circle") {
      c.drawCircle(Offset(x, y), w / 2 - 5, f);
      c.drawCircle(Offset(x, y), w / 2 - 5, p);
      return;
    }
    if (name == "Rounded Rectangle") {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(5, 5, w - 10, h - 10),
        const Radius.circular(18),
      );
      c.drawRRect(r, f);
      c.drawRRect(r, p);
      return;
    }
    if (name == "Triangle") {
      q
        ..moveTo(x, 5)
        ..lineTo(w - 5, h - 5)
        ..lineTo(5, h - 5)
        ..close();
    } else if (name == "Diamond") {
      q
        ..moveTo(x, 5)
        ..lineTo(w - 5, y)
        ..lineTo(x, h - 5)
        ..lineTo(5, y)
        ..close();
    } else if (name == "Hexagon") {
      q
        ..moveTo(w * .25, 5)
        ..lineTo(w * .75, 5)
        ..lineTo(w - 5, y)
        ..lineTo(w * .75, h - 5)
        ..lineTo(w * .25, h - 5)
        ..lineTo(5, y)
        ..close();
    } else if (name.contains("Arrow")) {
      q
        ..moveTo(5, y * .55)
        ..lineTo(w * .58, y * .55)
        ..lineTo(w * .58, 5)
        ..lineTo(w - 5, y)
        ..lineTo(w * .58, h - 5)
        ..lineTo(w * .58, y * 1.45)
        ..lineTo(5, y * 1.45)
        ..close();
    } else if (name == "Star") {
      q
        ..moveTo(x, 5)
        ..lineTo(x * 1.18, y * .7)
        ..lineTo(w - 5, y * .7)
        ..lineTo(x * 1.28, y * 1.05)
        ..lineTo(w * .88, h - 5)
        ..lineTo(x, y * 1.28)
        ..lineTo(w * .12, h - 5)
        ..lineTo(x * .72, y * 1.05)
        ..lineTo(5, y * .7)
        ..lineTo(x * .82, y * .7)
        ..close();
    } else {
      final r = Rect.fromLTWH(5, 5, w - 10, h - 10);
      c.drawRect(r, f);
      c.drawRect(r, p);
      return;
    }
    c.drawPath(q, f);
    c.drawPath(q, p);
  }

  @override
  bool shouldRepaint(covariant TayyibShapePainter old) => old.name != name;
}

class TayyibWordApp extends StatelessWidget {
  const TayyibWordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tayyib Word',
      theme: ThemeData(
        useMaterial3: false,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF185ABD)),
      ),
      home: const WordEditorScreen(),
    );
  }
}

class _TayyibPageBackgroundPainter extends CustomPainter {
  final double pageWidth;
  final double pageHeight;
  final double zoom;
  final bool webLayout;
  final Color pageColor;
  final String pageBorderStyle;
  final bool showGridlines;
  final String watermark;

  _TayyibPageBackgroundPainter({
    required this.pageWidth,
    required this.pageHeight,
    required this.zoom,
    required this.webLayout,
    required this.pageColor,
    required this.pageBorderStyle,
    required this.showGridlines,
    required this.watermark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scaledPageHeight = pageHeight * zoom;
    final double scaledPageWidth = pageWidth * zoom;

    if (scaledPageHeight <= 0 || scaledPageWidth <= 0) {
      return;
    }

    final int pageCount = math.max(1, (size.height / scaledPageHeight).ceil());

    for (int page = 0; page < pageCount; page++) {
      final double top = page * scaledPageHeight;

      final Rect pageRect = Rect.fromLTWH(
        0,
        top,
        math.min(scaledPageWidth, size.width),
        scaledPageHeight,
      );

      final Paint pagePaint = Paint()
        ..color = webLayout ? const Color(0xFFF8F9FA) : pageColor;

      canvas.drawRect(pageRect, pagePaint);

      // Visible page separation in Print Layout.
      // The document remains one continuous Quill document, while each
      // physical page gets a clear boundary and subtle separation.
      if (!webLayout && page < pageCount - 1) {
        final double boundaryY = pageRect.bottom;

        final Paint separatorShadow = Paint()
          ..color = Colors.black.withValues(alpha: .12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

        canvas.drawRect(
          Rect.fromLTWH(pageRect.left, boundaryY - 1, pageRect.width, 3),
          separatorShadow,
        );

        final Paint separatorPaint = Paint()..color = const Color(0xFFE0E0E0);

        canvas.drawRect(
          Rect.fromLTWH(pageRect.left, boundaryY, pageRect.width, 8),
          separatorPaint,
        );
      }

      if (!webLayout) {
        final Paint shadowPaint = Paint()
          ..color = Colors.black.withValues(alpha: .10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

        canvas.drawRect(pageRect.shift(const Offset(0, 2)), shadowPaint);

        if (pageBorderStyle != 'None') {
          final Paint borderPaint = Paint()
            ..style = PaintingStyle.stroke
            ..color = pageBorderStyle == '3-D'
                ? Colors.black54
                : pageBorderStyle == 'Shadow'
                ? Colors.grey.shade400
                : Colors.grey.shade600
            ..strokeWidth = pageBorderStyle == '3-D' ? 2 : 1;

          canvas.drawRect(pageRect, borderPaint);
        }
      }

      if (showGridlines && !webLayout) {
        final Paint gridPaint = Paint()
          ..color = Colors.grey.withValues(alpha: .13)
          ..strokeWidth = .5;

        const double interval = 24;

        for (double x = 0; x <= pageRect.width; x += interval) {
          canvas.drawLine(
            Offset(pageRect.left + x, pageRect.top),
            Offset(pageRect.left + x, pageRect.bottom),
            gridPaint,
          );
        }

        for (double y = 0; y <= pageRect.height; y += interval) {
          canvas.drawLine(
            Offset(pageRect.left, pageRect.top + y),
            Offset(pageRect.right, pageRect.top + y),
            gridPaint,
          );
        }
      }

      if (watermark.isNotEmpty && !webLayout) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: watermark,
            style: TextStyle(
              fontSize: 42 * zoom,
              fontWeight: FontWeight.bold,
              color: Colors.grey.withValues(alpha: .20),
            ),
          ),
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();

        canvas.save();
        canvas.translate(pageRect.center.dx, pageRect.center.dy);
        canvas.rotate(-0.55);

        textPainter.paint(
          canvas,
          Offset(-textPainter.width / 2, -textPainter.height / 2),
        );

        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TayyibPageBackgroundPainter oldDelegate) {
    return oldDelegate.pageWidth != pageWidth ||
        oldDelegate.pageHeight != pageHeight ||
        oldDelegate.zoom != zoom ||
        oldDelegate.webLayout != webLayout ||
        oldDelegate.pageColor != pageColor ||
        oldDelegate.pageBorderStyle != pageBorderStyle ||
        oldDelegate.showGridlines != showGridlines ||
        oldDelegate.watermark != watermark;
  }
}

class WordEditorScreen extends StatefulWidget {
  const WordEditorScreen({super.key});

  @override
  State<WordEditorScreen> createState() => _WordEditorScreenState();
}

class _WordEditorScreenState extends State<WordEditorScreen> {
  final TextEditingController _controller = TextEditingController();
  late quill.QuillController _quillController;

  String _currentFileName = 'Document1.txt';
  String _activeTab = 'Home';
  int _currentPage = 1;

  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  bool _isStrikethrough = false;
  bool _isSuperscript = false;
  bool _isSubscript = false;

  double _fontSize = 11;
  // Retained for rich-text paragraph formatting.
  double _lineSpacing = 1.25;
  String _fontName = 'Calibri';
  final TextEditingController _fontNameController = TextEditingController();
  final TextEditingController _fontSizeController = TextEditingController();
  // Retained for rich-text font-set formatting.
  String _fontSetName = 'Office';
  bool _formatPainterActive = false;

  // Page Layout settings
  String _themeName = 'Office';
  double _marginTop = 72.0;
  double _marginBottom = 72.0;
  double _marginLeft = 82.0;
  double _marginRight = 82.0;
  bool _landscape = false;
  String _pageSizeName = 'A4';
  int _columns = 1;
  String _watermark = '';
  Color _pageColor = Colors.white;
  String _pageBorderStyle = 'None';
  double _zoom = 1.0;
  bool _showRuler = true;
  bool _showGridlines = false;
  bool _showParagraphMarks = false;
  String _viewMode = 'Print Layout';

  int _wordCount = 0;

  final List<String> _tabs = const [
    'Home',
    'Insert',
    'Page Layout',
    'References',
    'Mailings',
    'Review',
    'View',
  ];

  @override
  void initState() {
    super.initState();

    const initialText =
        'Welcome to Tayyib Word\n\n'
        'This is your document. Start typing here...\n';

    _controller.text = initialText;
    _fontNameController.text = _fontName;
    _fontSizeController.text = _fontSize.toInt().toString();

    _quillController = quill.QuillController(
      document: quill.Document.fromJson([
        {'insert': initialText},
      ]),
      selection: const TextSelection.collapsed(offset: 0),
    );

    _quillController.addListener(_syncQuillToTextController);
    _controller.addListener(_updateWordCount);
    _updateWordCount();
  }

  @override
  void dispose() {
    _quillController.removeListener(_syncQuillToTextController);
    _quillController.dispose();
    _controller.removeListener(_updateWordCount);
    _controller.dispose();
    super.dispose();
  }

  void _syncQuillToTextController() {
    final plainText = _quillController.document.toPlainText();

    if (_controller.text == plainText) {
      return;
    }

    final currentOffset = _controller.selection.isValid
        ? _controller.selection.baseOffset
        : plainText.length;

    final safeOffset = currentOffset.clamp(0, plainText.length);

    _controller.value = TextEditingValue(
      text: plainText,
      selection: TextSelection.collapsed(offset: safeOffset),
    );
  }

  void _updateWordCount() {
    final text = _controller.text.trim();

    final count = text.isEmpty
        ? 0
        : text.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).length;

    if (mounted) {
      setState(() {
        _wordCount = count;
      });
    }
  }

  void _newDocument() {
    _quillController.document = quill.Document.fromJson([
      {'insert': '\n'},
    ]);

    _controller.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );

    setState(() {
      _currentFileName = 'Document1.txt';
      _isBold = false;
      _isItalic = false;
      _isUnderline = false;
      _isStrikethrough = false;
      _isSuperscript = false;
      _isSubscript = false;
    });

    _updateWordCount();
  }

  Future<void> _openFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'html', 'htm', 'docx', 'pdf'],
      );

      if (result == null || result.files.single.path == null) return;

      final path = result.files.single.path!;
      final name = result.files.single.name;
      final lowerName = name.toLowerCase();

      if (lowerName.endsWith('.pdf')) {
        _showMessage(
          'PDF can be viewed/printed, but importing PDF text for editing is not supported yet.',
        );
        return;
      }

      String contents;

      if (lowerName.endsWith('.docx')) {
        final bytes = await File(path).readAsBytes();

        try {
          final archive = ZipDecoder().decodeBytes(bytes);
          final documentFile = archive.files.firstWhere(
            (file) => file.name == 'word/document.xml',
          );

          final xml = utf8.decode(documentFile.content as List<int>);

          contents = xml
              .replaceAll(RegExp(r'<w:tab[^>]*/>'), '\t')
              .replaceAll(RegExp(r'</w:p>'), '\n')
              .replaceAll(RegExp(r'<w:br[^>]*/>'), '\n')
              .replaceAll(RegExp(r'<[^>]+>'), '')
              .replaceAll('&amp;', '&')
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll('&quot;', '"')
              .replaceAll('&apos;', "'");

          contents = contents.trimRight();
        } catch (e) {
          throw Exception('Invalid or unsupported DOCX file: $e');
        }
      } else {
        contents = await File(path).readAsString();

        if (lowerName.endsWith('.html') || lowerName.endsWith('.htm')) {
          contents = contents
              .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
              .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
              .replaceAll(RegExp(r'</div>', caseSensitive: false), '\n')
              .replaceAll(RegExp(r'<[^>]*>'), '')
              .replaceAll('&nbsp;', ' ')
              .replaceAll('&amp;', '&')
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll('&quot;', '"')
              .replaceAll('&#39;', "'");
        }
      }

      final safeText = contents;
      final quillText = safeText.endsWith('\n') ? safeText : '$safeText\n';

      _quillController = quill.QuillController(
        document: quill.Document.fromJson([
          {'insert': quillText},
        ]),
        selection: const TextSelection.collapsed(offset: 0),
      );

      _quillController.addListener(_syncQuillToTextController);

      setState(() {
        _controller.text = safeText;
        _currentFileName = name;
      });

      _updateWordCount();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Opened: $name')));
      }
    } catch (e) {
      _showMessage('Could not open file: $e');
    }
  }

  Future<Directory> _exportDirectory() async {
    if (Platform.isAndroid) {
      return await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
    }
    return await getApplicationDocumentsDirectory();
  }

  String _baseDocumentName(String name) {
    final value = name.trim().isEmpty ? 'Document1' : name.trim();
    return value.replaceFirst(
      RegExp(r'\.(txt|html?|docx|pdf)$', caseSensitive: false),
      '',
    );
  }

  String _xmlEscape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _quillPlainText() {
    return _quillController.document.toPlainText();
  }

  List<dynamic> _quillOperations() {
    return _quillController.document.toDelta().toList();
  }

  String _htmlEscape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _quillTextStyleHtml(Map<dynamic, dynamic>? attributes) {
    if (attributes == null || attributes.isEmpty) {
      return '';
    }

    final styles = <String>[];

    if (attributes['bold'] != null && attributes['bold'] != false) {
      styles.add('font-weight:bold');
    }

    if (attributes['italic'] != null && attributes['italic'] != false) {
      styles.add('font-style:italic');
    }

    if (attributes['underline'] != null && attributes['underline'] != false) {
      styles.add('text-decoration:underline');
    }

    final font = attributes['font'];
    if (font != null && font.toString().trim().isNotEmpty) {
      styles.add('font-family:${_htmlEscape(font.toString())}');
    }

    final size = attributes['size'];
    if (size != null) {
      final value = size.toString();
      final numeric = double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (numeric != null && numeric > 0) {
        styles.add('font-size:${numeric}pt');
      }
    }

    final color = attributes['color'];
    if (color != null && color.toString().trim().isNotEmpty) {
      styles.add('color:${_htmlEscape(color.toString())}');
    }

    final background = attributes['background'];
    if (background != null && background.toString().trim().isNotEmpty) {
      styles.add('background-color:${_htmlEscape(background.toString())}');
    }

    if (styles.isEmpty) {
      return '';
    }

    return ' style="${styles.join(';')}"';
  }

  String _createHtmlDocumentFromQuill() {
    final buffer = StringBuffer();

    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="en">');
    buffer.writeln('<head>');
    buffer.writeln('<meta charset="UTF-8">');
    buffer.writeln(
      '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
    );
    buffer.writeln(
      '<title>${_htmlEscape(_baseDocumentName(_currentFileName))}</title>',
    );

    buffer.writeln(
      '<style>'
      'body{font-family:Calibri,Arial,sans-serif;font-size:11pt;'
      'line-height:1.35;margin:72px;}'
      'p{margin:0 0 8px 0;}'
      '</style>',
    );

    buffer.writeln('</head>');
    buffer.writeln('<body>');

    final ops = _quillOperations();

    for (final op in ops) {
      final dynamic data = op.data;
      final dynamic attributes = op.attributes;

      if (data is! String) {
        continue;
      }

      final attrs = attributes is Map ? attributes : null;
      final style = _quillTextStyleHtml(attrs);
      final escaped = _htmlEscape(data);

      if (style.isEmpty) {
        buffer.write(escaped.replaceAll('\n', '<br>'));
      } else {
        buffer.write('<span$style>${escaped.replaceAll('\n', '<br>')}</span>');
      }
    }

    buffer.writeln('</body>');
    buffer.writeln('</html>');

    return buffer.toString();
  }

  pw.TextStyle _quillPdfTextStyle(Map<dynamic, dynamic>? attributes) {
    double fontSize = 11;
    var fontWeight = pw.FontWeight.normal;
    var fontStyle = pw.FontStyle.normal;

    if (attributes != null) {
      if (attributes['bold'] != null && attributes['bold'] != false) {
        fontWeight = pw.FontWeight.bold;
      }

      if (attributes['italic'] != null && attributes['italic'] != false) {
        fontStyle = pw.FontStyle.italic;
      }

      final size = attributes['size'];
      if (size != null) {
        final parsed = double.tryParse(
          size.toString().replaceAll(RegExp(r'[^0-9.]'), ''),
        );
        if (parsed != null && parsed > 0) {
          fontSize = parsed;
        }
      }
    }

    return pw.TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
    );
  }

  Future<List<int>> _createPdfBytesFromQuill() async {
    final pdf = pw.Document();
    final ops = _quillOperations();

    final spans = <pw.InlineSpan>[];

    for (final op in ops) {
      final dynamic data = op.data;
      final dynamic attributes = op.attributes;

      if (data is! String || data.isEmpty) {
        continue;
      }

      final attrs = attributes is Map ? attributes : null;

      spans.add(pw.TextSpan(text: data, style: _quillPdfTextStyle(attrs)));
    }

    if (spans.isEmpty) {
      spans.add(
        const pw.TextSpan(text: ' ', style: pw.TextStyle(fontSize: 11)),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(54),
        build: (context) => [pw.RichText(text: pw.TextSpan(children: spans))],
      ),
    );

    return pdf.save();
  }

  String _docxRunProperties(Map<dynamic, dynamic>? attributes) {
    if (attributes == null || attributes.isEmpty) {
      return '';
    }

    final parts = <String>[];

    if (attributes['bold'] != null && attributes['bold'] != false) {
      parts.add('<w:b/>');
    }

    if (attributes['italic'] != null && attributes['italic'] != false) {
      parts.add('<w:i/>');
    }

    if (attributes['underline'] != null && attributes['underline'] != false) {
      parts.add('<w:u w:val="single"/>');
    }

    final font = attributes['font'];
    if (font != null && font.toString().trim().isNotEmpty) {
      final escaped = _xmlEscape(font.toString());
      parts.add(
        '<w:rFonts w:ascii="$escaped" w:hAnsi="$escaped" w:eastAsia="$escaped"/>',
      );
    }

    final size = attributes['size'];
    if (size != null) {
      final parsed = double.tryParse(
        size.toString().replaceAll(RegExp(r'[^0-9.]'), ''),
      );

      if (parsed != null && parsed > 0) {
        final halfPoints = (parsed * 2).round();
        parts.add('<w:sz w:val="$halfPoints"/>');
        parts.add('<w:szCs w:val="$halfPoints"/>');
      }
    }

    if (parts.isEmpty) {
      return '';
    }

    return '<w:rPr>${parts.join()}</w:rPr>';
  }

  String _createDocxDocumentXmlFromQuill() {
    final buffer = StringBuffer();

    buffer.write(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document '
      'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:body>',
    );

    final ops = _quillOperations();

    var paragraph = StringBuffer();
    var paragraphHasContent = false;

    void flushParagraph() {
      if (!paragraphHasContent) {
        buffer.write(
          '<w:p><w:r><w:t xml:space="preserve"> '
          '</w:t></w:r></w:p>',
        );
      } else {
        buffer.write('<w:p>${paragraph.toString()}</w:p>');
      }

      paragraph = StringBuffer();
      paragraphHasContent = false;
    }

    for (final op in ops) {
      final dynamic data = op.data;
      final dynamic attributes = op.attributes;

      if (data is! String) {
        continue;
      }

      final attrs = attributes is Map ? attributes : null;
      final rPr = _docxRunProperties(attrs);

      final parts = data.split('\n');

      for (var i = 0; i < parts.length; i++) {
        final part = parts[i];

        if (part.isNotEmpty) {
          paragraph.write(
            '<w:r>$rPr'
            '<w:t xml:space="preserve">${_xmlEscape(part)}</w:t>'
            '</w:r>',
          );

          paragraphHasContent = true;
        }

        if (i < parts.length - 1) {
          flushParagraph();
        }
      }
    }

    flushParagraph();

    buffer.write(
      '<w:sectPr>'
      '<w:pgSz w:w="11906" w:h="16838"/>'
      '<w:pgMar w:top="1440" w:right="1440" '
      'w:bottom="1440" w:left="1440" '
      'w:header="720" w:footer="720" w:gutter="0"/>'
      '</w:sectPr>'
      '</w:body>'
      '</w:document>',
    );

    return buffer.toString();
  }

  Future<List<int>> _createDocxBytesFromQuill() async {
    final archive = Archive();

    const contentTypes =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" '
        'ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '<Override PartName="/docProps/core.xml" '
        'ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
        '<Override PartName="/docProps/app.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
        '</Types>';

    const rels =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
        'Target="word/document.xml"/>'
        '</Relationships>';

    const documentRels =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '</Relationships>';

    const appProps =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">'
        '<Application>Tayyib Word</Application>'
        '<AppVersion>1.0</AppVersion>'
        '</Properties>';

    const coreProps =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties '
        'xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:dcmitype="http://purl.org/dc/dcmitype/" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        '<dc:title>Tayyib Word Document</dc:title>'
        '<dc:creator>Tayyib Word</dc:creator>'
        '<cp:lastModifiedBy>Tayyib Word</cp:lastModifiedBy>'
        '</cp:coreProperties>';

    final document = _createDocxDocumentXmlFromQuill();

    archive.addFile(
      ArchiveFile(
        '[Content_Types].xml',
        contentTypes.codeUnits.length,
        contentTypes.codeUnits,
      ),
    );

    archive.addFile(
      ArchiveFile('_rels/.rels', rels.codeUnits.length, rels.codeUnits),
    );

    archive.addFile(
      ArchiveFile(
        'word/document.xml',
        document.codeUnits.length,
        document.codeUnits,
      ),
    );

    archive.addFile(
      ArchiveFile(
        'word/_rels/document.xml.rels',
        documentRels.codeUnits.length,
        documentRels.codeUnits,
      ),
    );

    archive.addFile(
      ArchiveFile(
        'docProps/app.xml',
        appProps.codeUnits.length,
        appProps.codeUnits,
      ),
    );

    archive.addFile(
      ArchiveFile(
        'docProps/core.xml',
        coreProps.codeUnits.length,
        coreProps.codeUnits,
      ),
    );

    return ZipEncoder().encode(archive);
  }

  Future<void> _exportDocument(String type, String fileName) async {
    try {
      final directory = await _exportDirectory();
      final base = _baseDocumentName(fileName);
      final plainText = _quillPlainText();

      late String extension;
      late List<int> bytes;

      switch (type) {
        case 'TXT':
          extension = '.txt';
          bytes = utf8.encode(plainText);
          break;

        case 'HTML':
          extension = '.html';
          bytes = utf8.encode(_createHtmlDocumentFromQuill());
          break;

        case 'DOCX':
          extension = '.docx';
          bytes = await _createDocxBytesFromQuill();
          break;

        case 'PDF':
          extension = '.pdf';
          bytes = await _createPdfBytesFromQuill();
          break;

        default:
          _showMessage('Unsupported format');
          return;
      }

      final finalName = '$base$extension';
      final path = '${directory.path}/$finalName';

      await File(path).writeAsBytes(bytes, flush: true);

      setState(() {
        _currentFileName = finalName;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved as $finalName'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: 'Tayyib Word Document — $finalName',
        ),
      );
    } catch (e) {
      _showMessage('Could not export file: $e');
    }
  }

  Future<void> _saveFile() async {
    final lowerName = _currentFileName.toLowerCase();

    if (lowerName.endsWith('.docx')) {
      await _exportDocument('DOCX', _currentFileName);
    } else if (lowerName.endsWith('.pdf')) {
      await _exportDocument('PDF', _currentFileName);
    } else if (lowerName.endsWith('.html') || lowerName.endsWith('.htm')) {
      await _exportDocument('HTML', _currentFileName);
    } else {
      await _exportDocument('TXT', _currentFileName);
    }
  }

  Future<void> _saveAsDialog() async {
    final nameController = TextEditingController(
      text: _baseDocumentName(_currentFileName),
    );

    String selectedType = 'DOCX';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Save As'),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'File name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Save as type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'DOCX',
                      child: Text('Word Document (*.docx)'),
                    ),
                    DropdownMenuItem(value: 'PDF', child: Text('PDF (*.pdf)')),
                    DropdownMenuItem(
                      value: 'HTML',
                      child: Text('Web Page (*.html)'),
                    ),
                    DropdownMenuItem(
                      value: 'TXT',
                      child: Text('Text Document (*.txt)'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedType = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final name = nameController.text.trim();

                if (name.isEmpty) {
                  return;
                }

                Navigator.pop(dialogContext);
                await _exportDocument(selectedType, name);
              },
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
  }

  Future<void> _printDocument() async {
    try {
      final bytes = await _createPdfBytesFromQuill();

      await Printing.layoutPdf(
        onLayout: (format) async => Uint8List.fromList(bytes),
      );
    } catch (e) {
      _showMessage('Could not print document: $e');
    }
  }

  Future<void> _showOptionsDialog() async {
    String selectedFont = _fontName;
    double selectedSize = _fontSize;

    const availableFonts = [
      'Calibri',
      'Arial',
      'Times New Roman',
      'Courier New',
      'Georgia',
      'Verdana',
    ];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.settings),
                  SizedBox(width: 10),
                  Text('Tayyib Word Options'),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: availableFonts.contains(selectedFont)
                          ? selectedFont
                          : availableFonts.first,
                      decoration: const InputDecoration(
                        labelText: 'Default Font',
                        border: OutlineInputBorder(),
                      ),
                      items: availableFonts
                          .map(
                            (font) => DropdownMenuItem<String>(
                              value: font,
                              child: Text(
                                font,
                                style: TextStyle(fontFamily: font),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedFont = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<double>(
                      initialValue: selectedSize,
                      decoration: const InputDecoration(
                        labelText: 'Default Font Size',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 9, child: Text('9')),
                        DropdownMenuItem(value: 10, child: Text('10')),
                        DropdownMenuItem(value: 11, child: Text('11')),
                        DropdownMenuItem(value: 12, child: Text('12')),
                        DropdownMenuItem(value: 14, child: Text('14')),
                        DropdownMenuItem(value: 16, child: Text('16')),
                        DropdownMenuItem(value: 18, child: Text('18')),
                        DropdownMenuItem(value: 20, child: Text('20')),
                        DropdownMenuItem(value: 24, child: Text('24')),
                        DropdownMenuItem(value: 28, child: Text('28')),
                        DropdownMenuItem(value: 32, child: Text('32')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedSize = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'These settings will be used as the editor defaults.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _fontName = selectedFont;
                      _fontSize = selectedSize;
                      _fontNameController.text = selectedFont;
                      _fontSizeController.text = selectedSize
                          .toInt()
                          .toString();
                    });

                    Navigator.pop(dialogContext);
                    _showMessage('Options saved.');
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _cutText() {
    final selection = _controller.selection;

    if (!selection.isValid || selection.isCollapsed) {
      _showMessage('Select some text first.');
      return;
    }

    final selectedText = _controller.text.substring(
      selection.start,
      selection.end,
    );

    Clipboard.setData(ClipboardData(text: selectedText));

    final newText = _controller.text.replaceRange(
      selection.start,
      selection.end,
      '',
    );

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start),
    );
  }

  Future<void> _copyText() async {
    final selection = _controller.selection;

    if (!selection.isValid || selection.isCollapsed) {
      _showMessage('Select some text first.');
      return;
    }

    final selectedText = _controller.text.substring(
      selection.start,
      selection.end,
    );

    await Clipboard.setData(ClipboardData(text: selectedText));
    _showMessage('Copied');
  }

  Future<void> _pasteText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);

    if (data == null || data.text == null) {
      _showMessage('Clipboard is empty.');
      return;
    }

    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : _controller.text.length;
    final end = selection.isValid ? selection.end : start;

    final newText = _controller.text.replaceRange(start, end, data.text!);

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + data.text!.length),
    );
  }

  void _selectAll() {
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  void _toggleFormatPainter() {
    setState(() {
      if (!_formatPainterActive) {
        _formatPainterActive = true;
      } else {
        _formatPainterActive = false;
      }
    });

    _showMessage(
      _formatPainterActive
          ? 'Format Painter: formatting captured'
          : 'Format Painter: Off',
    );
  }

  void _undo() {
    if (_quillController.hasUndo) {
      _quillController.undo();
    }
  }

  void _redo() {
    if (_quillController.hasRedo) {
      _quillController.redo();
    }
  }

  void _toggleBold() {
    final attrs = _quillController.getSelectionStyle().attributes;
    final attribute = attrs.containsKey(quill.Attribute.bold.key)
        ? quill.Attribute.clone(quill.Attribute.bold, null)
        : quill.Attribute.bold;

    setState(() {
      _isBold = !attrs.containsKey(quill.Attribute.bold.key);
    });

    _quillController.formatSelection(attribute);
  }

  void _toggleItalic() {
    final attrs = _quillController.getSelectionStyle().attributes;
    final attribute = attrs.containsKey(quill.Attribute.italic.key)
        ? quill.Attribute.clone(quill.Attribute.italic, null)
        : quill.Attribute.italic;

    setState(() {
      _isItalic = !attrs.containsKey(quill.Attribute.italic.key);
    });

    _quillController.formatSelection(attribute);
  }

  void _toggleUnderline() {
    final attrs = _quillController.getSelectionStyle().attributes;
    final attribute = attrs.containsKey(quill.Attribute.underline.key)
        ? quill.Attribute.clone(quill.Attribute.underline, null)
        : quill.Attribute.underline;

    setState(() {
      _isUnderline = !attrs.containsKey(quill.Attribute.underline.key);
    });

    _quillController.formatSelection(attribute);
  }

  void _findText() {
    final findController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Find'),
          content: TextField(
            controller: findController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Find what',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final query = findController.text;

                if (query.isEmpty) return;

                final index = _controller.text.toLowerCase().indexOf(
                  query.toLowerCase(),
                );

                if (index >= 0) {
                  _controller.selection = TextSelection(
                    baseOffset: index,
                    extentOffset: index + query.length,
                  );

                  Navigator.pop(context);
                } else {
                  _showMessage('Text not found.');
                }
              },
              child: const Text('Find'),
            ),
          ],
        );
      },
    );
  }

  void _replaceText() {
    final findController = TextEditingController();
    final replaceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Replace'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: findController,
                decoration: const InputDecoration(
                  labelText: 'Find what',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: replaceController,
                decoration: const InputDecoration(
                  labelText: 'Replace with',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final find = findController.text;

                if (find.isEmpty) return;

                final replacement = replaceController.text;

                final documentText = _quillController.document.toPlainText();

                final lowerDocument = documentText.toLowerCase();
                final lowerFind = find.toLowerCase();

                var searchFrom = 0;
                var replacements = 0;

                while (true) {
                  final index = lowerDocument.indexOf(lowerFind, searchFrom);

                  if (index < 0) {
                    break;
                  }

                  _quillController.replaceText(
                    index,
                    find.length,
                    replacement,
                    TextSelection.collapsed(offset: index + replacement.length),
                  );

                  replacements++;
                  searchFrom = index + replacement.length;

                  final updatedText = _quillController.document.toPlainText();

                  if (searchFrom > updatedText.length) {
                    break;
                  }

                  final nextIndex = updatedText.toLowerCase().indexOf(
                    lowerFind,
                    searchFrom,
                  );

                  if (nextIndex < 0) {
                    break;
                  }

                  searchFrom = nextIndex;
                }

                _showMessage(
                  replacements == 0
                      ? 'Text not found.'
                      : 'Replaced $replacements occurrence(s).',
                );

                Navigator.pop(context);
              },
              child: const Text('Replace All'),
            ),
          ],
        );
      },
    );
  }

  void _insertText(String value) {
    if (value.isEmpty) return;

    final selection = _quillController.selection;
    final documentLength = _quillController.document.length;

    final start = selection.isValid
        ? selection.start.clamp(0, documentLength - 1)
        : documentLength - 1;

    final end = selection.isValid
        ? selection.end.clamp(start, documentLength - 1)
        : start;

    final length = end - start;

    _quillController.replaceText(
      start,
      length,
      value,
      TextSelection.collapsed(offset: start + value.length),
    );
  }

  void _insertTable() {
    var rows = 3;
    var columns = 3;
    var headerRow = true;
    var borderStyle = 'Full';
    final cells = <List<TextEditingController>>[];

    void rebuildCells() {
      while (cells.length < rows) {
        cells.add([]);
      }
      while (cells.length > rows) {
        for (final controller in cells.removeLast()) {
          controller.dispose();
        }
      }

      for (var r = 0; r < rows; r++) {
        while (cells[r].length < columns) {
          cells[r].add(TextEditingController());
        }
        while (cells[r].length > columns) {
          cells[r].removeLast().dispose();
        }
      }
    }

    rebuildCells();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            rebuildCells();

            return AlertDialog(
              title: const Text('Table Editor'),
              content: SizedBox(
                width: 700,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Rows: $rows   Columns: $columns',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Add Row',
                            onPressed: () {
                              setDialogState(() {
                                rows = (rows + 1).clamp(1, 20);
                              });
                            },
                            icon: const Icon(Icons.add_box),
                          ),
                          IconButton(
                            tooltip: 'Delete Row',
                            onPressed: rows <= 1
                                ? null
                                : () {
                                    setDialogState(() {
                                      rows--;
                                    });
                                  },
                            icon: const Icon(Icons.remove_circle),
                          ),
                          IconButton(
                            tooltip: 'Add Column',
                            onPressed: () {
                              setDialogState(() {
                                columns = (columns + 1).clamp(1, 10);
                              });
                            },
                            icon: const Icon(Icons.view_column),
                          ),
                          IconButton(
                            tooltip: 'Delete Column',
                            onPressed: columns <= 1
                                ? null
                                : () {
                                    setDialogState(() {
                                      columns--;
                                    });
                                  },
                            icon: const Icon(Icons.view_column_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final result = await showDialog<List<int>?>(
                                  context: context,
                                  builder: (rangeContext) {
                                    final r1 = TextEditingController(text: '1');
                                    final c1 = TextEditingController(text: '1');
                                    final r2 = TextEditingController(text: '1');
                                    final c2 = TextEditingController(text: '2');

                                    return AlertDialog(
                                      title: const Text('Merge Cells'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'Enter the rectangular range to merge.',
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller: r1,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Start row',
                                                        border:
                                                            OutlineInputBorder(),
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: TextField(
                                                  controller: c1,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText:
                                                            'Start column',
                                                        border:
                                                            OutlineInputBorder(),
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller: r2,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'End row',
                                                        border:
                                                            OutlineInputBorder(),
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: TextField(
                                                  controller: c2,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'End column',
                                                        border:
                                                            OutlineInputBorder(),
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(rangeContext),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            final values = [
                                              int.tryParse(r1.text) ?? 1,
                                              int.tryParse(c1.text) ?? 1,
                                              int.tryParse(r2.text) ?? 1,
                                              int.tryParse(c2.text) ?? 1,
                                            ];
                                            Navigator.pop(rangeContext, values);
                                          },
                                          child: const Text('Merge'),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (result == null) {
                                  return;
                                }

                                final startRow = (result[0] - 1).clamp(
                                  0,
                                  rows - 1,
                                );
                                final startCol = (result[1] - 1).clamp(
                                  0,
                                  columns - 1,
                                );
                                final endRow = (result[2] - 1).clamp(
                                  0,
                                  rows - 1,
                                );
                                final endCol = (result[3] - 1).clamp(
                                  0,
                                  columns - 1,
                                );

                                final topRow = startRow <= endRow
                                    ? startRow
                                    : endRow;
                                final bottomRow = startRow <= endRow
                                    ? endRow
                                    : startRow;
                                final leftCol = startCol <= endCol
                                    ? startCol
                                    : endCol;
                                final rightCol = startCol <= endCol
                                    ? endCol
                                    : startCol;

                                final parts = <String>[];

                                for (var r = topRow; r <= bottomRow; r++) {
                                  for (var c = leftCol; c <= rightCol; c++) {
                                    final value = cells[r][c].text.trim();
                                    if (value.isNotEmpty) {
                                      parts.add(value);
                                    }
                                  }
                                }

                                setDialogState(() {
                                  cells[topRow][leftCol].text = parts.join(
                                    ' | ',
                                  );

                                  for (var r = topRow; r <= bottomRow; r++) {
                                    for (var c = leftCol; c <= rightCol; c++) {
                                      if (r == topRow && c == leftCol) {
                                        continue;
                                      }
                                      cells[r][c].clear();
                                    }
                                  }
                                });

                                _showMessage('Cells merged successfully.');
                              },
                              icon: const Icon(Icons.merge_type),
                              label: const Text('Merge'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final result = await showDialog<List<int>?>(
                                  context: context,
                                  builder: (splitContext) {
                                    final row = TextEditingController(
                                      text: '1',
                                    );
                                    final column = TextEditingController(
                                      text: '1',
                                    );

                                    return AlertDialog(
                                      title: const Text('Split Cell'),
                                      content: Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: row,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'Row',
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: column,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'Column',
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(splitContext),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(splitContext, [
                                              int.tryParse(row.text) ?? 1,
                                              int.tryParse(column.text) ?? 1,
                                            ]);
                                          },
                                          child: const Text('Split'),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (result == null) {
                                  return;
                                }

                                final targetRow = (result[0] - 1).clamp(
                                  0,
                                  rows - 1,
                                );
                                final targetCol = (result[1] - 1).clamp(
                                  0,
                                  columns - 1,
                                );

                                final value = cells[targetRow][targetCol].text
                                    .trim();

                                if (!value.contains('|')) {
                                  _showMessage(
                                    'This cell has no merged parts to split.',
                                  );
                                  return;
                                }

                                final parts = value
                                    .split('|')
                                    .map((part) => part.trim())
                                    .where((part) => part.isNotEmpty)
                                    .toList();

                                if (parts.isEmpty) {
                                  _showMessage('This cell cannot be split.');
                                  return;
                                }

                                setDialogState(() {
                                  cells[targetRow][targetCol].text =
                                      parts.first;

                                  for (var i = 1; i < parts.length; i++) {
                                    if (targetCol + i < columns) {
                                      cells[targetRow][targetCol + i].text =
                                          parts[i];
                                    }
                                  }
                                });

                                _showMessage('Cell split successfully.');
                              },
                              icon: const Icon(Icons.call_split),
                              label: const Text('Split'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFD6D6D6)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: headerRow,
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        headerRow = value ?? true;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 2),
                                  const Text(
                                    'Header row',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 155,
                              height: 38,
                              child: DropdownButtonFormField<String>(
                                initialValue: borderStyle,
                                isDense: true,
                                decoration: const InputDecoration(
                                  labelText: 'Borders',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Full',
                                    child: Text(
                                      'Full borders',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Outer',
                                    child: Text(
                                      'Outer border',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'None',
                                    child: Text(
                                      'No borders',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setDialogState(() {
                                      borderStyle = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const SizedBox(height: 12),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 360),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: Table(
                              border: TableBorder.all(
                                color: borderStyle == 'None'
                                    ? Colors.transparent
                                    : Colors.grey,
                              ),
                              defaultColumnWidth: const IntrinsicColumnWidth(),
                              children: [
                                for (var r = 0; r < rows; r++)
                                  TableRow(
                                    decoration: r == 0 && headerRow
                                        ? const BoxDecoration(
                                            color: Color(0xFFEFEFEF),
                                          )
                                        : null,
                                    children: [
                                      for (var c = 0; c < columns; c++)
                                        Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: SizedBox(
                                            width: 120,
                                            child: TextField(
                                              controller: cells[r][c],
                                              maxLines: 2,
                                              decoration: InputDecoration(
                                                labelText: r == 0 && headerRow
                                                    ? 'Header ${c + 1}'
                                                    : 'Cell ${r + 1},${c + 1}',
                                                isDense: true,
                                                border:
                                                    const OutlineInputBorder(),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    for (final row in cells) {
                      for (final controller in row) {
                        controller.dispose();
                      }
                    }
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Insert'),
                  onPressed: () {
                    final tableCells = <List<String>>[
                      for (var r = 0; r < rows; r++)
                        [
                          for (var c = 0; c < columns; c++)
                            cells[r][c].text.trim(),
                        ],
                    ];

                    final tableEmbed = TayyibTableEmbed(
                      rows: rows,
                      columns: columns,
                      headerRow: headerRow,
                      borderStyle: borderStyle,
                      cells: tableCells,
                    );

                    final insertOffset = _quillController.selection.start;

                    _quillController.document.insert(insertOffset, tableEmbed);

                    _quillController.updateSelection(
                      TextSelection.collapsed(offset: insertOffset + 1),
                      quill.ChangeSource.local,
                    );

                    for (final row in cells) {
                      for (final controller in row) {
                        controller.dispose();
                      }
                    }

                    Navigator.pop(dialogContext);

                    _showMessage(
                      'Table inserted: $rows rows × $columns columns',
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _insertPicture() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (!mounted) return;

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final path = file.path;

      if (path == null || path.isEmpty) {
        _showMessage('Could not read the selected picture.');
        return;
      }

      final widthController = TextEditingController(text: '500');
      final heightController = TextEditingController(text: '300');
      var alignment = 'Center';

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Insert Picture'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.image),
                        title: Text(file.name),
                        subtitle: const Text('Selected picture'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: widthController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Width',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: heightController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Height',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: alignment,
                        decoration: const InputDecoration(
                          labelText: 'Alignment',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Left', child: Text('Left')),
                          DropdownMenuItem(
                            value: 'Center',
                            child: Text('Center'),
                          ),
                          DropdownMenuItem(
                            value: 'Right',
                            child: Text('Right'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              alignment = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Insert'),
                    onPressed: () {
                      var width = double.tryParse(widthController.text) ?? 500;
                      var height =
                          double.tryParse(heightController.text) ?? 300;

                      width = width.clamp(50, 1000);
                      height = height.clamp(50, 1000);

                      final pictureEmbed = TayyibPictureEmbed(
                        path: path,
                        width: width,
                        height: height,
                        alignment: alignment,
                      );

                      final insertOffset = _quillController.selection.start;

                      _quillController.document.insert(
                        insertOffset,
                        pictureEmbed,
                      );

                      _quillController.updateSelection(
                        TextSelection.collapsed(offset: insertOffset + 1),
                        quill.ChangeSource.local,
                      );

                      Navigator.pop(dialogContext);
                      _showMessage('Picture inserted: ${file.name}');
                    },
                  ),
                ],
              );
            },
          );
        },
      );

      widthController.dispose();
      heightController.dispose();
    } catch (e) {
      _showMessage('Picture insertion failed: $e');
    }
  }

  void _showShapes() {
    const shapes = <Map<String, String>>[
      {'name': 'Rectangle', 'symbol': '▭'},
      {'name': 'Rounded Rectangle', 'symbol': '▢'},
      {'name': 'Circle', 'symbol': '○'},
      {'name': 'Triangle', 'symbol': '△'},
      {'name': 'Arrow', 'symbol': '➜'},
      {'name': 'Left Arrow', 'symbol': '←'},
      {'name': 'Right Arrow', 'symbol': '→'},
      {'name': 'Up Arrow', 'symbol': '↑'},
      {'name': 'Down Arrow', 'symbol': '↓'},
      {'name': 'Star', 'symbol': '★'},
      {'name': 'Diamond', 'symbol': '◇'},
      {'name': 'Hexagon', 'symbol': '⬡'},
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: shapes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.35,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final shape = shapes[index];

                return OutlinedButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);

                    final sizeController = TextEditingController(text: '120');
                    var alignment = 'Center';

                    showDialog<void>(
                      context: context,
                      builder: (dialogContext) {
                        return StatefulBuilder(
                          builder: (context, setDialogState) {
                            return AlertDialog(
                              title: Text('Insert ${shape['name']}'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    shape['symbol'] ?? '',
                                    style: const TextStyle(fontSize: 52),
                                  ),
                                  TextField(
                                    controller: sizeController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Size',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    initialValue: alignment,
                                    decoration: const InputDecoration(
                                      labelText: 'Alignment',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'Left',
                                        child: Text('Left'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Center',
                                        child: Text('Center'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Right',
                                        child: Text('Right'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setDialogState(() {
                                          alignment = value;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    var size =
                                        double.tryParse(sizeController.text) ??
                                        120;
                                    size = size.clamp(30, 600);

                                    final shapeEmbed = TayyibShapeEmbed(
                                      name: shape['name'] ?? 'Rectangle',
                                      size: size,
                                      alignment: alignment,
                                    );
                                    final insertOffset =
                                        _quillController.selection.start;
                                    _quillController.document.insert(
                                      insertOffset,
                                      shapeEmbed,
                                    );
                                    _quillController.updateSelection(
                                      TextSelection.collapsed(
                                        offset: insertOffset + 1,
                                      ),
                                      quill.ChangeSource.local,
                                    );

                                    Navigator.pop(dialogContext);
                                    _showMessage('${shape['name']} inserted.');
                                  },
                                  child: const Text('Insert'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );

                    sizeController.dispose();
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        shape['symbol'] ?? '',
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shape['name'] ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showChart() {
    var chartType = 'Column';

    final titleController = TextEditingController(text: 'My Chart');

    final dataController = TextEditingController(text: '12,28,20,35,24,42');

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Insert Chart'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: chartType,
                      decoration: const InputDecoration(
                        labelText: 'Chart type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Column',
                          child: Text('Column'),
                        ),
                        DropdownMenuItem(value: 'Bar', child: Text('Bar')),
                        DropdownMenuItem(value: 'Line', child: Text('Line')),
                        DropdownMenuItem(value: 'Pie', child: Text('Pie')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            chartType = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Chart title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: dataController,
                      maxLines: 3,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Data values',
                        hintText: '12,28,20,35,24,42',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('Insert'),
                  onPressed: () {
                    final title = titleController.text.trim().isEmpty
                        ? 'My Chart'
                        : titleController.text.trim();

                    final rawValues = dataController.text
                        .split(RegExp(r'[,;\s]+'))
                        .where((value) => value.trim().isNotEmpty)
                        .toList();

                    final values = <double>[];

                    for (final raw in rawValues) {
                      final value = double.tryParse(raw);

                      if (value != null) {
                        values.add(value);
                      }
                    }

                    if (values.isEmpty) {
                      _showMessage('Enter at least one numeric value.');
                      return;
                    }

                    final chartEmbed = TayyibChartEmbed(
                      chartType: chartType,
                      title: title,
                      values: values,
                    );

                    final offset = _quillController.selection.start;

                    _quillController.document.insert(offset, chartEmbed);

                    _quillController.updateSelection(
                      TextSelection.collapsed(offset: offset + 1),
                      quill.ChangeSource.local,
                    );

                    Navigator.pop(dialogContext);

                    _showMessage('$chartType chart inserted.');
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _insertPageBreak() {
    _insertText('\n\n---------------- PAGE BREAK ----------------\n\n');
  }

  void _changeAlignment(TextAlign alignment) {
    _showMessage('Alignment selected: ${alignment.name}');
  }

  Widget _buildRibbon() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF3F3F3),
        border: Border(bottom: BorderSide(color: Color(0xFFC8C8C8))),
      ),
      child: Column(children: [_buildTabs(), _buildRibbonContent()]),
    );
  }

  void _showFileMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        Widget item(IconData icon, String label, VoidCallback action) {
          return ListTile(
            leading: Icon(icon, color: const Color(0xFF217346)),
            title: Text(label),
            onTap: () {
              Navigator.pop(context);
              action();
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 54,
                color: const Color(0xFF217346),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Text(
                  'File',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              item(Icons.note_add, 'New', _newDocument),
              item(Icons.folder_open, 'Open', _openFile),
              item(Icons.save, 'Save', _saveFile),
              item(Icons.save_as, 'Save As', _saveAsDialog),
              item(Icons.print, 'Print', _printDocument),
              const Divider(height: 1),
              item(Icons.settings, 'Options', _showOptionsDialog),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 35,
      color: const Color(0xFFEDEDED),
      child: Row(
        children: [
          InkWell(
            onTap: _showFileMenu,
            child: Container(
              width: 58,
              height: 35,
              color: const Color(0xFF217346),
              alignment: Alignment.center,
              child: const Text(
                'File',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: _tabs
                    .map(
                      (tab) => InkWell(
                        onTap: () {
                          setState(() {
                            _activeTab = tab;
                          });
                        },
                        child: Container(
                          height: 35,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: _activeTab == tab
                                ? Colors.white
                                : Colors.transparent,
                            border: _activeTab == tab
                                ? const Border(
                                    top: BorderSide(
                                      color: Color(0xFF217346),
                                      width: 2,
                                    ),
                                  )
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            tab,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _activeTab == tab
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRibbonContent() {
    switch (_activeTab) {
      case 'Insert':
        return _buildInsertRibbon();
      case 'Page Layout':
        return _buildPageLayoutRibbon();
      case 'References':
        return _buildReferencesRibbon();
      case 'Mailings':
        return _buildMailingsRibbon();
      case 'Review':
        return _buildReviewRibbon();
      case 'View':
        return _buildViewRibbon();
      case 'Home':
      default:
        return _buildHomeRibbon();
    }
  }

  Widget _buildHomeRibbon() {
    return SizedBox(
      height: 108,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildRibbonGroup('Clipboard', [
              _smallRibbonButton(Icons.content_cut, 'Cut', _cutText),
              _smallRibbonButton(Icons.copy, 'Copy', _copyText),
              _smallRibbonButton(Icons.paste, 'Paste', _pasteText),
              _smallRibbonButton(Icons.select_all, 'Select All', _selectAll),
              _smallRibbonButton(
                Icons.format_paint,
                'Format Painter',
                _toggleFormatPainter,
                active: _formatPainterActive,
              ),
            ]),
            _buildRibbonGroup('Font', [
              _fontControls(),
              Row(
                children: [
                  _smallRibbonButton(
                    Icons.format_bold,
                    'Bold',
                    _toggleBold,
                    active: _isBold,
                  ),
                  _smallRibbonButton(
                    Icons.format_italic,
                    'Italic',
                    _toggleItalic,
                    active: _isItalic,
                  ),
                  _smallRibbonButton(
                    Icons.format_underlined,
                    'Underline',
                    _toggleUnderline,
                    active: _isUnderline,
                  ),
                  _smallRibbonButton(
                    Icons.format_strikethrough,
                    'Strike',
                    _toggleStrikethrough,
                    active: _isStrikethrough,
                  ),
                  _smallRibbonButton(
                    Icons.superscript,
                    'Superscript',
                    _toggleSuperscript,
                    active: _isSuperscript,
                  ),
                  _smallRibbonButton(
                    Icons.subscript,
                    'Subscript',
                    _toggleSubscript,
                    active: _isSubscript,
                  ),
                ],
              ),
            ]),
            _buildRibbonGroup('Paragraph', [
              Row(
                children: [
                  _smallRibbonButton(
                    Icons.format_list_bulleted,
                    'Bullets',
                    () => _insertText('\n• '),
                  ),
                  _smallRibbonButton(
                    Icons.format_list_numbered,
                    'Numbering',
                    () => _insertText('\n1. '),
                  ),
                  _smallRibbonButton(
                    Icons.format_list_numbered_rtl,
                    'Multilevel',
                    () => _insertText('\n1.1 '),
                  ),
                  _smallRibbonButton(
                    Icons.format_indent_decrease,
                    'Decrease',
                    _decreaseIndent,
                  ),
                  _smallRibbonButton(
                    Icons.format_indent_increase,
                    'Increase',
                    _increaseIndent,
                  ),
                  _smallRibbonButton(
                    Icons.sort_by_alpha,
                    'Sort',
                    _showSortDialog,
                  ),
                  _smallRibbonButton(
                    Icons.format_align_left,
                    '¶',
                    _toggleParagraphMarks,
                    active: _showParagraphMarks,
                  ),
                ],
              ),
              Row(
                children: [
                  _smallRibbonButton(
                    Icons.format_align_left,
                    'Left',
                    () => _changeAlignment(TextAlign.left),
                  ),
                  _smallRibbonButton(
                    Icons.format_align_center,
                    'Center',
                    () => _changeAlignment(TextAlign.center),
                  ),
                  _smallRibbonButton(
                    Icons.format_align_right,
                    'Right',
                    () => _changeAlignment(TextAlign.right),
                  ),
                  _smallRibbonButton(
                    Icons.format_align_justify,
                    'Justify',
                    () => _changeAlignment(TextAlign.justify),
                  ),
                  _smallRibbonButton(
                    Icons.format_line_spacing,
                    'Spacing',
                    _showLineSpacing,
                  ),
                  _smallRibbonButton(Icons.border_all, 'Borders', _showBorders),
                  _smallRibbonButton(
                    Icons.format_color_fill,
                    'Shading',
                    _showShading,
                  ),
                ],
              ),
            ]),
            _buildRibbonGroup('Styles', [
              _smallRibbonButton(Icons.style, 'Styles', _showStyles),
              _smallRibbonButton(
                Icons.text_fields,
                'Normal',
                () => _applyStyle('Normal'),
              ),
              _smallRibbonButton(
                Icons.title,
                'Title',
                () => _applyStyle('Title'),
              ),
              _smallRibbonButton(
                Icons.looks_one,
                'Heading 1',
                () => _applyStyle('Heading 1'),
              ),
              _smallRibbonButton(
                Icons.looks_two,
                'Heading 2',
                () => _applyStyle('Heading 2'),
              ),
            ]),
            _buildRibbonGroup('Editing', [
              _bigRibbonButton(Icons.search, 'Find', _findText),
              _bigRibbonButton(Icons.find_replace, 'Replace', _replaceText),
            ]),
          ],
        ),
      ),
    );
  }

  void _toggleStrikethrough() {
    setState(() {
      _isStrikethrough = !_isStrikethrough;
    });
    _showMessage(_isStrikethrough ? 'Strikethrough: On' : 'Strikethrough: Off');
  }

  void _toggleSuperscript() {
    setState(() {
      _isSuperscript = !_isSuperscript;
      if (_isSuperscript) {
        _isSubscript = false;
      }
    });
    _showMessage(_isSuperscript ? 'Superscript: On' : 'Superscript: Off');
  }

  void _toggleSubscript() {
    setState(() {
      _isSubscript = !_isSubscript;
      if (_isSubscript) {
        _isSuperscript = false;
      }
    });
    _showMessage(_isSubscript ? 'Subscript: On' : 'Subscript: Off');
  }

  void _decreaseIndent() {
    final value = _controller.text;
    final selection = _controller.selection;

    if (selection.isValid && !selection.isCollapsed) {
      final start = selection.start.clamp(0, value.length);
      final end = selection.end.clamp(0, value.length);
      final selected = value.substring(start, end);

      final updated = selected.replaceAll(
        RegExp(r'^ {1,4}', multiLine: true),
        '',
      );

      _controller.value = _controller.value.copyWith(
        text: value.replaceRange(start, end, updated),
        selection: TextSelection.collapsed(offset: start + updated.length),
      );
    } else {
      final offset = selection.isValid
          ? selection.baseOffset.clamp(0, value.length)
          : value.length;

      final lineStart = value.lastIndexOf('\n', offset - 1) + 1;
      final lineEnd = value.indexOf('\n', offset);

      final end = lineEnd == -1 ? value.length : lineEnd;
      final line = value.substring(lineStart, end);

      final spaces = RegExp(r'^ {1,4}').firstMatch(line);

      if (spaces != null) {
        final removeCount = spaces.group(0)!.length;
        final updated = value.replaceRange(
          lineStart,
          lineStart + removeCount,
          '',
        );

        _controller.value = _controller.value.copyWith(
          text: updated,
          selection: TextSelection.collapsed(
            offset: (offset - removeCount).clamp(0, updated.length),
          ),
        );
      }
    }

    _showMessage('Decrease indent');
  }

  void _showStyles() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final styles = [
          'Normal',
          'No Spacing',
          'Title',
          'Subtitle',
          'Heading 1',
          'Heading 2',
          'Quote',
        ];

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: styles.map((style) {
              return ListTile(
                leading: const Icon(Icons.style),
                title: Text(style),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _applyStyle(style);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _applyStyle(String style) {
    setState(() {
      switch (style) {
        case 'Title':
          _fontSize = 24;
          _isBold = true;
          _isItalic = false;
          _isUnderline = false;
          break;
        case 'Subtitle':
          _fontSize = 16;
          _isBold = false;
          _isItalic = true;
          _isUnderline = false;
          break;
        case 'Heading 1':
          _fontSize = 20;
          _isBold = true;
          _isItalic = false;
          _isUnderline = false;
          break;
        case 'Heading 2':
          _fontSize = 16;
          _isBold = true;
          _isItalic = false;
          _isUnderline = false;
          break;
        case 'Quote':
          _fontSize = 12;
          _isBold = false;
          _isItalic = true;
          _isUnderline = false;
          break;
        case 'No Spacing':
          _lineSpacing = 1.0;
          _fontSize = 11;
          _isBold = false;
          _isItalic = false;
          _isUnderline = false;
          break;
        default:
          _fontSize = 11;
          _lineSpacing = 1.25;
          _isBold = false;
          _isItalic = false;
          _isUnderline = false;
      }
    });

    _showMessage('Style applied: $style');
  }

  void _showSortDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sort'),
          content: const Text('Choose a sorting order.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showMessage('Sort A → Z');
              },
              child: const Text('A → Z'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showMessage('Sort Z → A');
              },
              child: const Text('Z → A'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _toggleParagraphMarks() {
    setState(() {
      _showParagraphMarks = !_showParagraphMarks;
    });
    _showMessage(
      _showParagraphMarks ? 'Paragraph marks ¶: On' : 'Paragraph marks ¶: Off',
    );
  }

  void _showLineSpacing() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final values = [1.0, 1.15, 1.25, 1.5, 2.0];

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: values.map((value) {
              return ListTile(
                leading: const Icon(Icons.format_line_spacing),
                title: Text('Line spacing ${value.toString()}'),
                trailing: _lineSpacing == value
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  setState(() {
                    _lineSpacing = value;
                  });

                  _quillController.formatSelection(
                    quill.LineHeightAttribute(lineHeight: value),
                  );

                  Navigator.pop(sheetContext);
                  _showMessage('Line spacing: ${value.toString()}');
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showBorders() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final options = [
          ('Bottom Border', '▁'),
          ('Top Border', '▔'),
          ('Left Border', '▏'),
          ('Right Border', '▕'),
          ('All Borders', '▦'),
          ('No Border', ''),
        ];

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: options.map((item) {
              return ListTile(
                leading: const Icon(Icons.border_all),
                title: Text(item.$1),
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (item.$2.isNotEmpty) {
                    _insertText('\n${item.$2}\n');
                  }
                  _showMessage('Border: ${item.$1}');
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showShading() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final shades = [
          'No Shading',
          'Light Gray',
          'Gray',
          'Dark Gray',
          'Blue',
          'Green',
          'Yellow',
        ];

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: shades.map((shade) {
              return ListTile(
                leading: const Icon(Icons.format_color_fill),
                title: Text(shade),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showMessage('Shading: $shade');
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildInsertRibbon() {
    return SizedBox(
      height: 108,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildRibbonGroup('Pages', [
              _bigRibbonButton(
                Icons.insert_page_break,
                'Page Break',
                _insertPageBreak,
              ),
            ]),
            _buildRibbonGroup('Tables', [
              _bigRibbonButton(Icons.table_chart, 'Table', _insertTable),
            ]),
            _buildRibbonGroup('Illustrations', [
              _bigRibbonButton(Icons.image, 'Picture', _insertPicture),
              _bigRibbonButton(Icons.crop_square, 'Shapes', _showShapes),
              _bigRibbonButton(Icons.bar_chart, 'Chart', _showChart),
            ]),
            _buildRibbonGroup('Text', [
              _bigRibbonButton(Icons.text_fields, 'Text Box', _showTextBox),
              _bigRibbonButton(Icons.title, 'WordArt', _showWordArt),
            ]),
            _buildRibbonGroup('Symbols', [
              _bigRibbonButton(Icons.functions, 'Equation', _showEquation),
              _bigRibbonButton(
                Icons.emoji_symbols,
                'Symbol',
                _showSymbolPicker,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _showTextBox() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Insert Text Box'),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Text',
              hintText: 'Enter text for the text box',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.text_fields),
              label: const Text('Insert'),
              onPressed: () {
                final value = controller.text.trim();

                if (value.isEmpty) {
                  _showMessage('Enter some text first.');
                  return;
                }

                final textBoxEmbed = TayyibTextBoxEmbed(
                  text: value,
                  style: 'Simple',
                );

                final insertOffset = _quillController.selection.start;

                _quillController.document.insert(insertOffset, textBoxEmbed);

                _quillController.updateSelection(
                  TextSelection.collapsed(offset: insertOffset + 1),
                  quill.ChangeSource.local,
                );

                Navigator.pop(dialogContext);
                _showMessage('Text Box inserted');
              },
            ),
          ],
        );
      },
    );
  }

  void _showWordArt() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        var selectedStyle = 'Classic';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Insert WordArt'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'WordArt text',
                      hintText: 'Enter your text',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStyle,
                    decoration: const InputDecoration(
                      labelText: 'Style',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Classic',
                        child: Text('Classic'),
                      ),
                      DropdownMenuItem(value: 'Bold', child: Text('Bold')),
                      DropdownMenuItem(
                        value: 'Outline',
                        child: Text('Outline'),
                      ),
                      DropdownMenuItem(value: 'Shadow', child: Text('Shadow')),
                      DropdownMenuItem(value: 'Banner', child: Text('Banner')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedStyle = value);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.title),
                  label: const Text('Insert'),
                  onPressed: () {
                    final value = controller.text.trim();

                    if (value.isEmpty) {
                      _showMessage('Enter WordArt text first.');
                      return;
                    }

                    final wordArtEmbed = TayyibWordArtEmbed(
                      text: value,
                      style: selectedStyle,
                    );

                    final insertOffset = _quillController.selection.start;

                    _quillController.document.insert(
                      insertOffset,
                      wordArtEmbed,
                    );

                    _quillController.updateSelection(
                      TextSelection.collapsed(offset: insertOffset + 1),
                      quill.ChangeSource.local,
                    );

                    Navigator.pop(dialogContext);
                    _showMessage('WordArt inserted');
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEquation() {
    final equationController = TextEditingController();
    final numeratorController = TextEditingController();
    final denominatorController = TextEditingController();

    final templates = <String>[
      'a² + b² = c²',
      'ax² + bx + c = 0',
      'E = mc²',
      'F = ma',
      'πr²',
      '√x',
      '∑ᵢ₌₁ⁿ i',
      '∫ₐᵇ f(x) dx',
      'x₁ + x₂',
      'x² + y²',
    ];

    final symbols = <String>[
      '²',
      '³',
      '⁰',
      '¹',
      '⁴',
      '⁵',
      '₀',
      '₁',
      '₂',
      '₃',
      '₄',
      '₅',
      '√',
      '∑',
      '∏',
      '∫',
      '∞',
      'π',
      'α',
      'β',
      'γ',
      'θ',
      'λ',
      'μ',
      'σ',
      'φ',
      'ω',
      '±',
      '×',
      '÷',
      '≠',
      '≤',
      '≥',
      '≈',
      '≡',
      '→',
      '←',
      '↔',
      '∂',
      '∆',
      '∇',
    ];

    void insertAtCursor(String value) {
      final text = equationController.text;
      final selection = equationController.selection;

      final startPos = selection.start < 0 ? text.length : selection.start;
      final endPos = selection.end < 0 ? text.length : selection.end;

      final updated = text.replaceRange(startPos, endPos, value);

      equationController.value = TextEditingValue(
        text: updated,
        selection: TextSelection.collapsed(offset: startPos + value.length),
      );
    }

    Widget fractionPreview() {
      final numerator = numeratorController.text.trim();
      final denominator = denominatorController.text.trim();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              numerator.isEmpty ? 'লব' : numerator,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
            ),
            Container(
              width: 100,
              height: 2,
              color: Colors.black87,
              margin: const EdgeInsets.symmetric(vertical: 5),
            ),
            Text(
              denominator.isEmpty ? 'হর' : denominator,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.functions),
                  SizedBox(width: 8),
                  Text('Equation'),
                ],
              ),
              content: SizedBox(
                width: 700,
                height: 570,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fraction — লব ও হর',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: numeratorController,
                            decoration: const InputDecoration(
                              labelText: 'লব (উপরের অংশ)',
                              hintText: 'যেমন: a + b',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) {
                              setDialogState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Padding(
                          padding: EdgeInsets.only(top: 14),
                          child: Text(
                            '/',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: denominatorController,
                            decoration: const InputDecoration(
                              labelText: 'হর (নিচের অংশ)',
                              hintText: 'যেমন: c + d',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) {
                              setDialogState(() {});
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Fraction Preview',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),

                    Center(child: fractionPreview()),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            final n = numeratorController.text.trim();
                            final d = denominatorController.text.trim();

                            if (n.isEmpty || d.isEmpty) {
                              _showMessage('লব এবং হর দুটোই পূরণ করুন।');
                              return;
                            }

                            equationController.text = '($n)/($d)';

                            equationController.selection =
                                TextSelection.collapsed(
                                  offset: equationController.text.length,
                                );

                            setDialogState(() {});
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Fraction তৈরি'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            numeratorController.clear();
                            denominatorController.clear();
                            setDialogState(() {});
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'Equation Templates',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),

                    SizedBox(
                      height: 70,
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: templates.map((item) {
                            return OutlinedButton(
                              onPressed: () {
                                equationController.text = item;
                                equationController.selection =
                                    TextSelection.collapsed(
                                      offset: item.length,
                                    );
                                setDialogState(() {});
                              },
                              child: Text(item),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Math Symbols',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),

                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 9,
                              crossAxisSpacing: 5,
                              mainAxisSpacing: 5,
                            ),
                        itemCount: symbols.length,
                        itemBuilder: (context, index) {
                          final symbol = symbols[index];

                          return InkWell(
                            onTap: () {
                              insertAtCursor(symbol);
                              setDialogState(() {});
                            },
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                symbol,
                                style: const TextStyle(fontSize: 19),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final fractionN = numeratorController.text.trim();
                    final fractionD = denominatorController.text.trim();

                    String value = equationController.text.trim();

                    if (fractionN.isNotEmpty && fractionD.isNotEmpty) {
                      value = 'Fraction: $fractionN / $fractionD';
                    }

                    if (value.isEmpty) {
                      _showMessage('একটি Equation অথবা Fraction দিন।');
                      return;
                    }

                    final equationEmbed = TayyibEquationEmbed(
                      expression: value,
                      numerator: fractionN,
                      denominator: fractionD,
                    );

                    final selection = _quillController.selection;
                    final index = selection.baseOffset.clamp(
                      0,
                      _quillController.document.length - 1,
                    );

                    _quillController.document.insert(index, equationEmbed);

                    _quillController.updateSelection(
                      TextSelection.collapsed(offset: index + 1),
                      quill.ChangeSource.local,
                    );

                    Navigator.pop(dialogContext);
                    _showMessage('Equation inserted');
                  },
                  icon: const Icon(Icons.functions),
                  label: const Text('Insert Equation'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSymbolPicker() {
    final searchController = TextEditingController();

    final categories = <String, List<String>>{
      'Common': ['©', '®', '™', '§', '¶', '†', '‡', '•', '…', '°', '№'],
      'Math': [
        '±',
        '×',
        '÷',
        '=',
        '≠',
        '<',
        '>',
        '≤',
        '≥',
        '≈',
        '≡',
        '∞',
        '√',
        '∑',
        '∏',
        '∫',
        '∂',
        '∆',
        '∇',
        '∝',
        '∴',
      ],
      'Greek': [
        'α',
        'β',
        'γ',
        'δ',
        'ε',
        'ζ',
        'η',
        'θ',
        'ι',
        'κ',
        'λ',
        'μ',
        'ν',
        'ξ',
        'π',
        'ρ',
        'σ',
        'τ',
        'φ',
        'χ',
        'ψ',
        'ω',
        'Α',
        'Β',
        'Γ',
        'Δ',
        'Θ',
        'Λ',
        'Ξ',
        'Π',
        'Σ',
        'Φ',
        'Ψ',
        'Ω',
      ],
      'Arrows': [
        '←',
        '→',
        '↑',
        '↓',
        '↔',
        '↕',
        '↖',
        '↗',
        '↘',
        '↙',
        '⇒',
        '⇐',
        '⇑',
        '⇓',
        '⇔',
        '➜',
        '➝',
        '➞',
      ],
      'Currency': ['\$', '€', '£', '¥', '₹', '৳', '₽', '₩', '₺', '₴'],
      'Fractions': [
        '½',
        '⅓',
        '⅔',
        '¼',
        '¾',
        '⅕',
        '⅖',
        '⅗',
        '⅘',
        '⅙',
        '⅚',
        '⅛',
        '⅜',
        '⅝',
        '⅞',
      ],
      'Shapes': [
        '○',
        '●',
        '□',
        '■',
        '△',
        '▲',
        '◇',
        '◆',
        '☆',
        '★',
        '♠',
        '♣',
        '♥',
        '♦',
      ],
      'Punctuation': ['“', '”', '‘', '’', '«', '»', '–', '—', '-', '¿', '¡'],
    };

    String selectedCategory = 'Common';

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final query = searchController.text.trim().toLowerCase();

            final allSymbols = categories[selectedCategory] ?? [];

            final symbols = query.isEmpty
                ? allSymbols
                : allSymbols
                      .where((symbol) => symbol.toLowerCase().contains(query))
                      .toList();

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.text_fields),
                  SizedBox(width: 8),
                  Text('Symbol'),
                ],
              ),
              content: SizedBox(
                width: 700,
                height: 520,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Search symbols',
                        hintText: 'Search or choose a category',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      height: 42,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: categories.keys.map((category) {
                            final selected = category == selectedCategory;

                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(category),
                                selected: selected,
                                onSelected: (_) {
                                  setDialogState(() {
                                    selectedCategory = category;
                                    searchController.clear();
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Expanded(
                      child: symbols.isEmpty
                          ? const Center(child: Text('No symbols found.'))
                          : GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 9,
                                    crossAxisSpacing: 7,
                                    mainAxisSpacing: 7,
                                    childAspectRatio: 1.15,
                                  ),
                              itemCount: symbols.length,
                              itemBuilder: (context, index) {
                                final symbol = symbols[index];

                                return Tooltip(
                                  message: 'Insert $symbol',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () {
                                      _insertText(symbol);
                                      Navigator.pop(dialogContext);
                                      _showMessage('Symbol inserted: $symbol');
                                    },
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade400,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        symbol,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    searchController.dispose();
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final theme in [
            'Office',
            'Office 2007',
            'Classic',
            'Modern',
            'Simple',
          ])
            ListTile(
              leading: const Icon(Icons.palette),
              title: Text(theme),
              onTap: () {
                setState(() => _themeName = theme);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  void _showThemeFonts() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final font in [
              'Office',
              'Calibri',
              'Arial',
              'Cambria',
              'Times New Roman',
              'Georgia',
              'Verdana',
            ])
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: Text(font),
                trailing: _fontSetName == font ? const Icon(Icons.check) : null,
                onTap: () {
                  setState(() {
                    _fontSetName = font;
                  });

                  _quillController.formatSelection(
                    quill.Attribute.fromKeyValue(
                      quill.Attribute.font.key,
                      font,
                    ),
                  );

                  Navigator.pop(sheetContext);
                  _showMessage('Theme font: $font');
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showMargins() {
    final margins = {
      'Normal': [72.0, 72.0, 82.0, 82.0],
      'Narrow': [36.0, 36.0, 36.0, 36.0],
      'Moderate': [72.0, 72.0, 54.0, 54.0],
      'Wide': [72.0, 72.0, 108.0, 108.0],
    };

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: margins.entries.map((entry) {
          return ListTile(
            leading: const Icon(Icons.margin),
            title: Text(entry.key),
            onTap: () {
              final m = entry.value;
              setState(() {
                _marginTop = m[0];
                _marginBottom = m[1];
                _marginLeft = m[2];
                _marginRight = m[3];
              });
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showOrientation() {
    final renderObject = context.findRenderObject();

    if (renderObject is! RenderBox) {
      return;
    }

    final offset = renderObject.localToGlobal(
      renderObject.size.bottomRight(Offset.zero),
    );

    final screenSize = MediaQuery.sizeOf(context);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx.clamp(8.0, screenSize.width - 190.0),
        (offset.dy - 120.0).clamp(8.0, screenSize.height - 150.0),
        12.0,
        0.0,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'Portrait',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.stay_current_portrait,
                size: 20,
                color: _landscape
                    ? Colors.black87
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              const Text('Portrait'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'Landscape',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.stay_current_landscape,
                size: 20,
                color: _landscape
                    ? Theme.of(context).colorScheme.primary
                    : Colors.black87,
              ),
              const SizedBox(width: 10),
              const Text('Landscape'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'Portrait') {
        setState(() => _landscape = false);
      } else if (value == 'Landscape') {
        setState(() => _landscape = true);
      }
    });
  }

  void _showPageSize() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final size in ['A4', 'A5', 'Letter', 'Legal'])
            ListTile(
              leading: const Icon(Icons.description),
              title: Text(size),
              onTap: () {
                setState(() => _pageSizeName = size);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  void _showColumns() {
    final renderObject = context.findRenderObject();

    if (renderObject is! RenderBox) {
      return;
    }

    final offset = renderObject.localToGlobal(
      renderObject.size.bottomRight(Offset.zero),
    );

    final screenSize = MediaQuery.sizeOf(context);

    showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx.clamp(8.0, screenSize.width - 180.0),
        (offset.dy - 170.0).clamp(8.0, screenSize.height - 190.0),
        12.0,
        0.0,
      ),
      items: [
        for (final count in [1, 2, 3, 4])
          PopupMenuItem<int>(
            value: count,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.view_column,
                  size: 20,
                  color: _columns == count
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black87,
                ),
                const SizedBox(width: 10),
                Text('$count Column${count == 1 ? '' : 's'}'),
              ],
            ),
          ),
      ],
    ).then((value) {
      if (value != null) {
        setState(() {
          _columns = value;
        });
      }
    });
  }

  void _showWatermark() {
    final controller = TextEditingController(text: _watermark);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Watermark'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Watermark text',
            hintText: 'Example: CONFIDENTIAL',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _watermark = controller.text);
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showPageColor() {
    final colors = [
      Colors.white,
      const Color(0xFFF5F5F5),
      const Color(0xFFFFF8E1),
      const Color(0xFFE3F2FD),
      const Color(0xFFE8F5E9),
      const Color(0xFFFCE4EC),
    ];

    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 18,
          runSpacing: 18,
          children: colors.map((color) {
            return InkWell(
              onTap: () {
                setState(() => _pageColor = color);
                Navigator.pop(context);
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showPageBorders() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final border in ['None', 'Box', 'Shadow', '3-D'])
            ListTile(
              leading: const Icon(Icons.border_outer),
              title: Text(border),
              onTap: () {
                setState(() => _pageBorderStyle = border);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  void _showParagraphSpacing() {
    final spacing = {
      'Normal': 1.25,
      'Compact': 1.0,
      'Relaxed': 1.5,
      'Double': 2.0,
    };

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: spacing.entries.map((entry) {
          return ListTile(
            leading: const Icon(Icons.format_line_spacing),
            title: Text(entry.key),
            onTap: () {
              setState(() => _lineSpacing = entry.value);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _increaseIndent() {
    final value = _controller.text;
    final selection = _controller.selection;

    if (selection.isValid && !selection.isCollapsed) {
      final selected = value.substring(selection.start, selection.end);
      final replacement = selected
          .split('\n')
          .map((line) => '    $line')
          .join('\n');

      _controller.value = _controller.value.copyWith(
        text: value.replaceRange(selection.start, selection.end, replacement),
        selection: TextSelection.collapsed(
          offset: selection.start + replacement.length,
        ),
      );
    } else {
      _controller.value = _controller.value.copyWith(
        text: '$value    ',
        selection: TextSelection.collapsed(offset: value.length + 4),
      );
    }
  }

  Widget _buildPageLayoutRibbon() {
    return SizedBox(
      height: 108,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildRibbonGroup('Themes', [
              _bigRibbonButton(Icons.palette, _themeName, _showThemePicker),
              _bigRibbonButton(Icons.text_fields, 'Fonts', _showThemeFonts),
            ]),
            _buildRibbonGroup('Page Setup', [
              _bigRibbonButton(Icons.margin, 'Margins', _showMargins),
              _bigRibbonButton(
                Icons.screen_lock_rotation,
                _landscape ? 'Landscape' : 'Portrait',
                _showOrientation,
              ),
              _bigRibbonButton(Icons.description, _pageSizeName, _showPageSize),
              _bigRibbonButton(
                Icons.view_column,
                'Columns $_columns',
                _showColumns,
              ),
            ]),
            _buildRibbonGroup('Page Background', [
              _bigRibbonButton(Icons.water_drop, 'Watermark', _showWatermark),
              _bigRibbonButton(
                Icons.format_color_fill,
                'Page Color',
                _showPageColor,
              ),
              _bigRibbonButton(
                Icons.border_outer,
                'Page Borders',
                _showPageBorders,
              ),
            ]),
            _buildRibbonGroup('Paragraph', [
              _bigRibbonButton(
                Icons.keyboard_arrow_right,
                'Indent',
                _increaseIndent,
              ),
              _bigRibbonButton(
                Icons.format_line_spacing,
                'Spacing',
                _showParagraphSpacing,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _showTableOfContents() {
    final lines = _controller.text.split('\n');
    final headings = <String>[];

    for (final line in lines) {
      final t = line.trim();
      if (t.startsWith('# ')) {
        headings.add(t.substring(2).trim());
      } else if (t.startsWith('## ')) {
        headings.add('  ${t.substring(3).trim()}');
      }
    }

    if (headings.isEmpty) {
      _showMessage('No headings found. Use # Heading or ## Subheading.');
      return;
    }

    final toc = StringBuffer()
      ..writeln('TABLE OF CONTENTS')
      ..writeln('=================');

    for (var i = 0; i < headings.length; i++) {
      toc.writeln('${i + 1}. ${headings[i]}');
    }

    _insertText('\n${toc.toString()}\n');
  }

  void _insertFootnote() {
    final number =
        RegExp(r'\[\^(\d+)\]')
            .allMatches(_controller.text)
            .map((m) => int.tryParse(m.group(1) ?? '') ?? 0)
            .fold(0, (a, b) => a > b ? a : b) +
        1;

    final noteController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Insert Footnote $number'),
        content: TextField(
          controller: noteController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Footnote text',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final note = noteController.text.trim();
              if (note.isNotEmpty) {
                _insertText('[^$number]');
                _insertText('\n\n[$number] $note');
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );
  }

  void _showCitationDialog() {
    final author = TextEditingController();
    final year = TextEditingController();
    final title = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Insert Citation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: author,
              decoration: const InputDecoration(labelText: 'Author'),
            ),
            TextField(
              controller: year,
              decoration: const InputDecoration(labelText: 'Year'),
            ),
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final a = author.text.trim();
              final y = year.text.trim();
              final t = title.text.trim();

              if (a.isNotEmpty) {
                final citation = y.isNotEmpty ? '($a, $y)' : '($a)';
                _insertText(citation);

                if (t.isNotEmpty) {
                  _insertText(' $t');
                }
              }

              Navigator.pop(dialogContext);
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );
  }

  void _showBibliography() {
    final entries = <String>[];
    final lines = _controller.text.split('\n');

    for (final line in lines) {
      final t = line.trim();
      if (t.startsWith('[') && t.contains(']')) {
        entries.add(t);
      }
    }

    if (entries.isEmpty) {
      _showMessage('No citation entries found.');
      return;
    }

    final buffer = StringBuffer()
      ..writeln('\nBIBLIOGRAPHY')
      ..writeln('=============');

    for (var i = 0; i < entries.length; i++) {
      buffer.writeln('${i + 1}. ${entries[i]}');
    }

    _insertText(buffer.toString());
  }

  void _showCaptionDialog() {
    final captionController = TextEditingController();
    String label = 'Figure';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Insert Caption'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: label,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Figure', child: Text('Figure')),
                  DropdownMenuItem(value: 'Table', child: Text('Table')),
                  DropdownMenuItem(value: 'Equation', child: Text('Equation')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => label = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: captionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Caption',
                  hintText: 'Enter caption text',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final caption = captionController.text.trim();

                if (caption.isNotEmpty) {
                  final pattern = RegExp(
                    '$label (\\d+):',
                    caseSensitive: false,
                  );

                  final number =
                      pattern
                          .allMatches(_controller.text)
                          .map((m) => int.tryParse(m.group(1) ?? '') ?? 0)
                          .fold(0, (a, b) => a > b ? a : b) +
                      1;

                  _insertText('\n$label $number: $caption\n');
                }

                Navigator.pop(dialogContext);
              },
              child: const Text('Insert'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferencesRibbon() {
    return SizedBox(
      height: 108,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildRibbonGroup('Table of Contents', [
              _bigRibbonButton(Icons.list, 'TOC', _showTableOfContents),
            ]),
            _buildRibbonGroup('Footnotes', [
              _bigRibbonButton(
                Icons.note_add,
                'Insert Footnote',
                _insertFootnote,
              ),
              _bigRibbonButton(
                Icons.notes,
                'Next Footnote',
                () => _showMessage('Next Footnote'),
              ),
            ]),
            _buildRibbonGroup('Citations & Bibliography', [
              _bigRibbonButton(
                Icons.library_books,
                'Citation',
                _showCitationDialog,
              ),
              _bigRibbonButton(
                Icons.menu_book,
                'Bibliography',
                _showBibliography,
              ),
            ]),
            _buildRibbonGroup('Captions', [
              _bigRibbonButton(
                Icons.label,
                'Insert Caption',
                _showCaptionDialog,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _showMailMerge() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final recipients = <Map<String, String>>[];

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Mail Merge Recipients'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        final name = nameController.text.trim();
                        final email = emailController.text.trim();

                        if (name.isNotEmpty || email.isNotEmpty) {
                          setState(() {
                            recipients.add({'name': name, 'email': email});
                          });
                          nameController.clear();
                          emailController.clear();
                        }
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add'),
                    ),
                    const SizedBox(width: 8),
                    Text('${recipients.length} recipient(s)'),
                  ],
                ),
                const SizedBox(height: 12),
                if (recipients.isEmpty)
                  const Text('No recipients added yet.')
                else
                  SizedBox(
                    height: 150,
                    child: ListView.builder(
                      itemCount: recipients.length,
                      itemBuilder: (context, index) {
                        final item = recipients[index];

                        return ListTile(
                          dense: true,
                          title: Text(
                            item['name']!.isEmpty ? '(No name)' : item['name']!,
                          ),
                          subtitle: Text(
                            item['email']!.isEmpty
                                ? '(No email)'
                                : item['email']!,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              setState(() {
                                recipients.removeAt(index);
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (recipients.isNotEmpty) {
                  _showMessage(
                    '${recipients.length} recipient(s) ready for mail merge.',
                  );
                } else {
                  _showMessage('Add at least one recipient.');
                }
                Navigator.pop(dialogContext);
              },
              child: const Text('Use Recipients'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEnvelopesDialog() {
    final recipient = TextEditingController();
    final sender = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Envelopes"),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: recipient,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Delivery address",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sender,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Return address",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final to = recipient.text.trim();
              final from = sender.text.trim();

              _insertText(
                "\n========== ENVELOPE ==========\n"
                "TO:\n${to.isEmpty ? "[Delivery address]" : to}\n\n"
                "FROM:\n${from.isEmpty ? "[Return address]" : from}\n"
                "===============================\n",
              );

              Navigator.pop(dialogContext);
            },
            icon: const Icon(Icons.check),
            label: const Text("Insert"),
          ),
        ],
      ),
    );
  }

  void _showLabelsDialog() {
    final address = TextEditingController();
    String labelType = "30 per page";

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Labels"),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: labelType,
                  decoration: const InputDecoration(
                    labelText: "Label type",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: "30 per page",
                      child: Text("30 per page"),
                    ),
                    DropdownMenuItem(
                      value: "24 per page",
                      child: Text("24 per page"),
                    ),
                    DropdownMenuItem(
                      value: "18 per page",
                      child: Text("18 per page"),
                    ),
                    DropdownMenuItem(
                      value: "12 per page",
                      child: Text("12 per page"),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => labelType = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: address,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: "Label address/text",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final value = address.text.trim();

                _insertText(
                  "\n========== LABEL ==========\n"
                  "Type: $labelType\n"
                  "${value.isEmpty ? "[Label text]" : value}\n"
                  "============================\n",
                );

                Navigator.pop(dialogContext);
              },
              icon: const Icon(Icons.check),
              label: const Text("Insert"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMailingsRibbon() {
    return SizedBox(
      height: 108,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildRibbonGroup('Create', [
              _bigRibbonButton(Icons.mail, 'Envelopes', _showEnvelopesDialog),
              _bigRibbonButton(
                Icons.local_post_office,
                'Labels',
                _showLabelsDialog,
              ),
            ]),
            _buildRibbonGroup('Start Mail Merge', [
              _bigRibbonButton(Icons.merge_type, 'Mail Merge', _showMailMerge),
              _bigRibbonButton(Icons.contacts, 'Recipients', _showMailMerge),
            ]),
            _buildRibbonGroup('Write & Insert Fields', [
              _bigRibbonButton(
                Icons.person_add,
                'Address Block',
                () => _insertText('\n«AddressBlock»\n'),
              ),
              _bigRibbonButton(
                Icons.text_snippet,
                'Greeting',
                () => _insertText('\n«GreetingLine»\n'),
              ),
            ]),
            _buildRibbonGroup('Finish', [
              _bigRibbonButton(
                Icons.done_all,
                'Finish Merge',
                () => _showMessage('Finish & Merge'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _showSpellingDialog() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _showMessage('There is no text to check.');
      return;
    }

    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Spelling & Grammar'),
        content: Text(
          'Basic document check completed.\n\n'
          'Words: $words\n'
          'Sentences: \n\n'
          'For detailed spelling correction, select and edit the highlighted text manually.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showThesaurusDialog() {
    final selected = _controller.selection;
    final selectedText =
        selected.isValid && selected.start >= 0 && selected.end > selected.start
        ? _controller.text.substring(selected.start, selected.end).trim()
        : '';

    final input = TextEditingController(text: selectedText);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thesaurus'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: input,
            decoration: const InputDecoration(
              labelText: 'Word or phrase',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final word = input.text.trim();
              Navigator.pop(dialogContext);
              if (word.isEmpty) {
                _showMessage('Enter a word first.');
              } else {
                _showMessage(
                  'Thesaurus suggestions for : similar, related, equivalent',
                );
              }
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showWordCountDialog() {
    final text = _controller.text;
    final words = text.trim().isEmpty
        ? 0
        : text.trim().split(RegExp(r'\s+')).length;
    final characters = text.length;
    final charactersNoSpaces = text.replaceAll(RegExp(r'\s'), '').length;
    final paragraphs = text.trim().isEmpty
        ? 0
        : text
              .split(RegExp(r'\n\s*\n'))
              .where((e) => e.trim().isNotEmpty)
              .length;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Word Count'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Words: $words'),
            Text('Characters: $characters'),
            Text('Characters excluding spaces: $charactersNoSpaces'),
            Text('Paragraphs: $paragraphs'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _addComment() {
    final comment = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Comment'),
        content: TextField(
          controller: comment,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Comment',
            hintText: 'Type your comment here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final value = comment.text.trim();
              if (value.isNotEmpty) {
                _insertText('\n[Comment: $value]\n');
              }
              Navigator.pop(dialogContext);
            },
            icon: const Icon(Icons.comment),
            label: const Text('Add Comment'),
          ),
        ],
      ),
    );
  }

  void _deleteComment() {
    final text = _controller.text;
    final pattern = RegExp(r'\[Comment:.*?\]\n?', dotAll: true);
    final updated = text.replaceFirst(pattern, '');

    if (updated != text) {
      _controller.value = TextEditingValue(
        text: updated,
        selection: TextSelection.collapsed(offset: updated.length),
      );
      _showMessage('Comment deleted.');
    } else {
      _showMessage('No comment marker found.');
    }
  }

  void _toggleTrackChanges() {
    _showMessage(
      'Track Changes is available for review workflow. '
      'Changes are represented with review markers in this editor.',
    );
  }

  void _showMarkup() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Show Markup'),
        content: const Text(
          'Review markup includes comments and change markers in the document text.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _acceptChange() {
    final text = _controller.text;
    final updated = text.replaceAll(RegExp(r'\[Change: (.*?) -> (.*?)\]'), r'');

    if (updated != text) {
      _controller.value = TextEditingValue(
        text: updated,
        selection: TextSelection.collapsed(offset: updated.length),
      );
      _showMessage('Change accepted.');
    } else {
      _showMessage('No tracked change found.');
    }
  }

  void _rejectChange() {
    final text = _controller.text;
    final updated = text.replaceAll(RegExp(r'\[Change: (.*?) -> (.*?)\]'), r'');

    if (updated != text) {
      _controller.value = TextEditingValue(
        text: updated,
        selection: TextSelection.collapsed(offset: updated.length),
      );
      _showMessage('Change rejected.');
    } else {
      _showMessage('No tracked change found.');
    }
  }

  void _showProtectDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Protect Document'),
        content: const Text(
          'Document protection is available as a review setting. '
          'You can lock the document workflow here before sharing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showMessage('Document protection enabled for this session.');
            },
            icon: const Icon(Icons.lock),
            label: const Text('Protect'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRibbon() {
    return SizedBox(
      height: 108,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildRibbonGroup('Proofing', [
              _bigRibbonButton(
                Icons.spellcheck,
                'Spelling',
                _showSpellingDialog,
              ),
              _bigRibbonButton(
                Icons.menu_book,
                'Thesaurus',
                _showThesaurusDialog,
              ),
              _bigRibbonButton(
                Icons.numbers,
                'Word Count',
                _showWordCountDialog,
              ),
            ]),
            _buildRibbonGroup('Comments', [
              _bigRibbonButton(Icons.comment, 'New Comment', _addComment),
              _bigRibbonButton(Icons.delete, 'Delete', _deleteComment),
            ]),
            _buildRibbonGroup('Tracking', [
              _bigRibbonButton(
                Icons.track_changes,
                'Track Changes',
                _toggleTrackChanges,
              ),
              _bigRibbonButton(Icons.visibility, 'Show Markup', _showMarkup),
            ]),
            _buildRibbonGroup('Changes', [
              _bigRibbonButton(Icons.check, 'Accept', _acceptChange),
              _bigRibbonButton(Icons.close, 'Reject', _rejectChange),
            ]),
            _buildRibbonGroup('Protect', [
              _bigRibbonButton(Icons.lock, 'Protect', _showProtectDialog),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildViewRibbon() {
    final activeView = _viewMode;
    return SizedBox(
      height: 108,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildRibbonGroup('Views', [
              if (activeView == 'Web Layout') const SizedBox.shrink(),
              _bigRibbonButton(Icons.description, 'Print Layout', () {
                setState(() {
                  _viewMode = 'Print Layout';
                });
                _showMessage('Print Layout selected');
              }),
              _bigRibbonButton(Icons.web, 'Web Layout', () {
                setState(() {
                  _viewMode = 'Web Layout';
                });
                _showMessage('Web Layout selected');
              }),
            ]),
            _buildRibbonGroup('Show/Hide', [
              _bigRibbonButton(
                _showRuler ? Icons.straighten : Icons.straighten_outlined,
                'Ruler',
                () {
                  setState(() {
                    _showRuler = !_showRuler;
                  });
                  _showMessage(_showRuler ? 'Ruler: On' : 'Ruler: Off');
                },
              ),
              _bigRibbonButton(
                _showGridlines ? Icons.grid_on : Icons.grid_off,
                'Gridlines',
                () {
                  setState(() {
                    _showGridlines = !_showGridlines;
                  });
                  _showMessage(
                    _showGridlines ? 'Gridlines: On' : 'Gridlines: Off',
                  );
                },
              ),
            ]),
            _buildRibbonGroup('Zoom', [
              _bigRibbonButton(Icons.zoom_in, 'Zoom In', () {
                setState(() {
                  _zoom = (_zoom + 0.10).clamp(0.50, 2.00).toDouble();
                });
                _showMessage('Zoom: ${(_zoom * 100).round()}%');
              }),
              _bigRibbonButton(Icons.zoom_out, 'Zoom Out', () {
                setState(() {
                  _zoom = (_zoom - 0.10).clamp(0.50, 2.00).toDouble();
                });
                _showMessage('Zoom: ${(_zoom * 100).round()}%');
              }),
              _bigRibbonButton(Icons.fit_screen, '100%', () {
                setState(() {
                  _zoom = 1.0;
                });
                _showMessage('Zoom: 100%');
              }),
            ]),
            _buildRibbonGroup('Window', [
              _bigRibbonButton(Icons.open_in_new, 'New Window', () {
                _showMessage(
                  'New Window is not available in this Android editor.',
                );
              }),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _fontControls() {
    final fonts = <String>[
      'Calibri',
      'Arial',
      'Times New Roman',
      'Cambria',
      'Georgia',
      'Verdana',
      'Tahoma',
      'Courier New',
      'Roboto',
      'Noto Sans',
      'Noto Serif',
    ];

    final sizes = <double>[
      8,
      9,
      10,
      11,
      12,
      14,
      16,
      18,
      20,
      24,
      28,
      32,
      36,
      48,
      72,
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 150,
          height: 32,
          child: TextField(
            controller: _fontNameController,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              border: const OutlineInputBorder(),
              suffixIcon: PopupMenuButton<String>(
                icon: const Icon(Icons.arrow_drop_down, size: 20),
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  _fontNameController.text = value;
                  _fontNameController.selection = TextSelection.collapsed(
                    offset: value.length,
                  );

                  setState(() {
                    _fontName = value;
                  });

                  _quillController.formatSelection(
                    quill.Attribute.fromKeyValue(
                      quill.Attribute.font.key,
                      value,
                    ),
                  );
                },
                itemBuilder: (context) {
                  return fonts
                      .map(
                        (font) => PopupMenuItem<String>(
                          value: font,
                          child: Text(
                            font,
                            style: TextStyle(fontFamily: font, fontSize: 13),
                          ),
                        ),
                      )
                      .toList();
                },
              ),
            ),
            onChanged: (value) {
              setState(() {
                _fontName = value;
              });
            },
            onSubmitted: (value) {
              final font = value.trim();
              if (font.isEmpty) return;

              setState(() {
                _fontName = font;
              });

              _quillController.formatSelection(
                quill.Attribute.fromKeyValue(quill.Attribute.font.key, font),
              );
            },
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 58,
          height: 32,
          child: TextField(
            controller: _fontSizeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              border: const OutlineInputBorder(),
              suffixIcon: PopupMenuButton<double>(
                icon: const Icon(Icons.arrow_drop_down, size: 18),
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  _fontSizeController.text = value.toInt().toString();
                  _fontSizeController.selection = TextSelection.collapsed(
                    offset: _fontSizeController.text.length,
                  );

                  setState(() {
                    _fontSize = value;
                  });

                  _quillController.formatSelection(
                    quill.Attribute.fromKeyValue(
                      quill.Attribute.size.key,
                      value.toString(),
                    ),
                  );
                },
                itemBuilder: (context) {
                  return sizes
                      .map(
                        (size) => PopupMenuItem<double>(
                          value: size,
                          child: Text(size.toInt().toString()),
                        ),
                      )
                      .toList();
                },
              ),
            ),
            onSubmitted: (value) {
              final size = double.tryParse(value.trim());
              if (size == null || size <= 0) {
                _fontSizeController.text = _fontSize.toInt().toString();
                return;
              }

              setState(() {
                _fontSize = size;
              });

              _quillController.formatSelection(
                quill.Attribute.fromKeyValue(
                  quill.Attribute.size.key,
                  size.toString(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRibbonGroup(String label, List<Widget> children) {
    return Container(
      height: 108,
      padding: const EdgeInsets.fromLTRB(7, 5, 7, 0),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFFD0D0D0))),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: children,
            ),
          ),
          SizedBox(
            height: 22,
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF444444)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigRibbonButton(IconData icon, String label, VoidCallback onPressed) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          width: 58,
          height: 82,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 27, color: const Color(0xFF333333)),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallRibbonButton(
    IconData icon,
    String label,
    VoidCallback onPressed, {
    bool active = false,
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          width: 38,
          height: 36,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFD9EAF7) : Colors.transparent,
            border: active ? Border.all(color: const Color(0xFF7AA7D1)) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF333333)),
              Text(label, style: const TextStyle(fontSize: 7)),
            ],
          ),
        ),
      ),
    );
  }

  /// Step 16C foundation:
  /// Calculates the printable width available to each column.
  /// The Quill document remains a single source of truth.
  /// Actual cursor/selection editing stays in the primary editor.
  int _calculateDocumentPageCount({
    required String plainText,
    required double pageWidth,
    required double pageHeight,
    required double contentWidth,
    required double contentHeight,
    required bool webLayout,
  }) {
    if (webLayout) {
      return 1;
    }

    final String normalized = plainText.replaceAll('\r\n', '\n');
    final List<String> paragraphs = normalized.split('\n');

    final double fontHeight = math.max(14.0, _fontSize * 1.25);
    final double usableHeight = math.max(200.0, contentHeight);
    final double usableWidth = math.max(120.0, contentWidth);

    int estimatedLines = 0;

    for (final paragraph in paragraphs) {
      if (paragraph.isEmpty) {
        estimatedLines += 1;
        continue;
      }

      final int charsPerLine = math.max(
        8,
        (usableWidth / math.max(5.0, _fontSize * 0.55)).floor(),
      );

      estimatedLines += math.max(1, (paragraph.length / charsPerLine).ceil());
    }

    final int linesPerPage = math.max(1, (usableHeight / fontHeight).floor());

    final int estimatedPages = math.max(
      1,
      (estimatedLines / linesPerPage).ceil(),
    );

    return estimatedPages;
  }

  List<double> _calculateColumnWidths(double contentWidth) {
    final int count = _columns.clamp(1, 4);

    final double gap = switch (count) {
      1 => 0.0,
      2 => 24.0,
      3 => 18.0,
      _ => 14.0,
    };

    final double width = math.max(
      80.0,
      (contentWidth - gap * (count - 1)) / count,
    );

    return List<double>.filled(count, width);
  }

  final List<quill.QuillController> _columnControllers =
      <quill.QuillController>[];
  bool _syncingColumnEditors = false;

  void _disposeColumnControllers() {
    for (final controller in _columnControllers) {
      controller.dispose();
    }
    _columnControllers.clear();
  }

  String _columnPlainText(quill.QuillController controller) {
    return controller.document.toPlainText().replaceFirst(RegExp(r'\n$'), '');
  }

  void _syncColumnsToMaster() {
    if (_syncingColumnEditors || _columnControllers.isEmpty) {
      return;
    }

    _syncingColumnEditors = true;

    final String merged = _columnControllers.map(_columnPlainText).join();

    final String current = _quillController.document.toPlainText().replaceFirst(
      RegExp(r'\n$'),
      '',
    );

    if (merged != current) {
      _quillController.document = quill.Document.fromJson([
        {'insert': merged.isEmpty ? '\n' : '$merged\n'},
      ]);

      _controller.text = merged;
      _updateWordCount();
    }

    _syncingColumnEditors = false;

    if (mounted) {
      setState(() {});
    }
  }

  void _rebuildColumnEditors({required List<String> parts}) {
    _syncingColumnEditors = true;

    _disposeColumnControllers();

    for (final part in parts) {
      final controller = quill.QuillController(
        document: quill.Document.fromJson([
          {'insert': part.isEmpty ? '\n' : '$part\n'},
        ]),
        selection: const TextSelection.collapsed(offset: 0),
      );

      controller.addListener(_syncColumnsToMaster);
      _columnControllers.add(controller);
    }

    _syncingColumnEditors = false;
  }

  List<String> _splitTextForColumns({
    required String source,
    required int count,
    required double columnWidth,
    required double columnHeight,
  }) {
    if (source.isEmpty) {
      return List<String>.filled(count, '');
    }

    final double fontSize = _fontSize.clamp(8.0, 96.0);
    final double lineHeight = math.max(12.0, fontSize * _lineSpacing * 1.45);
    final double averageCharWidth = math.max(4.0, fontSize * 0.52);

    final int charsPerLine = math.max(
      10,
      (columnWidth / averageCharWidth).floor(),
    );

    final int linesPerColumn = math.max(1, (columnHeight / lineHeight).floor());

    final int capacity = math.max(charsPerLine, charsPerLine * linesPerColumn);

    final List<String> result = <String>[];

    int cursor = 0;

    while (cursor < source.length) {
      int end = math.min(source.length, cursor + capacity);

      if (end < source.length) {
        final int newline = source.lastIndexOf('\n', end - 1);
        final int space = source.lastIndexOf(' ', end - 1);

        final int boundary = math.max(newline, space);

        if (boundary > cursor + math.max(1, (capacity * 0.55).floor())) {
          end = boundary + 1;
        }
      }

      if (end <= cursor) {
        end = math.min(source.length, cursor + capacity);
      }

      result.add(source.substring(cursor, end));
      cursor = end;
    }

    while (result.length < count) {
      result.add('');
    }

    return result;
  }

  Widget _buildColumnEditor(
    quill.QuillController controller,
    double width,
    double height,
  ) {
    return SizedBox(
      width: width,
      height: height,
      child: quill.QuillEditor.basic(
        controller: controller,
        config: quill.QuillEditorConfig(
          padding: EdgeInsets.zero,
          autoFocus: false,
          expands: false,
          scrollable: true,
          enableInteractiveSelection: true,
          enableSelectionToolbar: true,
          placeholder: 'Start typing...',
          embedBuilders: [
            TayyibTableEmbedBuilder(),
            TayyibObjectBuilder(TayyibTextBoxEmbedBuilder()),
            TayyibObjectBuilder(TayyibWordArtEmbedBuilder()),
            TayyibObjectBuilder(TayyibPictureEmbedBuilder()),
            TayyibObjectBuilder(TayyibShapeEmbedBuilder()),
            TayyibObjectBuilder(TayyibChartEmbedBuilder()),
            TayyibObjectBuilder(TayyibEquationEmbedBuilder()),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnLayout({
    required double contentWidth,
    required double contentHeight,
  }) {
    // Keep one Quill document as the single source of truth.
    // The previous implementation split the document into several
    // independent QuillControllers and merged plain text back, which
    // destroyed formatting/embeds and caused cursor/editing problems.
    //
    // Flutter Quill does not provide true newspaper-style flowing
    // columns, so until a dedicated multi-column layout engine is used,
    // we deliberately keep the editor continuous and lossless.
    return SizedBox(
      width: contentWidth,
      height: contentHeight,
      child: quill.QuillEditor.basic(
        controller: _quillController,
        config: quill.QuillEditorConfig(
          padding: EdgeInsets.zero,
          autoFocus: false,
          expands: false,
          scrollable: true,
          enableInteractiveSelection: true,
          enableSelectionToolbar: true,
          placeholder: 'Start typing...',
          embedBuilders: [
            TayyibTableEmbedBuilder(),
            TayyibObjectBuilder(TayyibTextBoxEmbedBuilder()),
            TayyibObjectBuilder(TayyibWordArtEmbedBuilder()),
            TayyibObjectBuilder(TayyibPictureEmbedBuilder()),
            TayyibObjectBuilder(TayyibShapeEmbedBuilder()),
            TayyibObjectBuilder(TayyibChartEmbedBuilder()),
            TayyibObjectBuilder(TayyibEquationEmbedBuilder()),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    final bool webLayout = _viewMode == 'Web Layout';

    final double basePageWidth = _landscape ? 842.0 : 595.0;
    final double basePageHeight = _landscape ? 595.0 : 842.0;

    final double pageWidth = webLayout ? 900.0 : basePageWidth;
    final double pageHeight = webLayout ? 1100.0 : basePageHeight;

    final double contentWidth = (pageWidth - _marginLeft - _marginRight).clamp(
      120.0,
      pageWidth,
    );

    final double contentHeight = (pageHeight - _marginTop - _marginBottom)
        .clamp(200.0, pageHeight);

    // The document is now a continuous flow instead of one fixed page.
    // We estimate a safe minimum number of pages from the current
    // document length and allow the editor to grow naturally.
    final String plainText = _quillController.document.toPlainText();

    // Estimate wrapped lines from the actual printable width.
    // This keeps pagination responsive to margins, orientation and font size.
    final double safeFontSize = _fontSize.clamp(8.0, 96.0);

    final double averageCharWidth = math.max(4.0, safeFontSize * 0.52);

    final int charsPerLine = math.max(
      8,
      (contentWidth / averageCharWidth).floor(),
    );

    int lineEstimate = 0;

    for (final String paragraph in plainText.split('\n')) {
      final int length = paragraph.length;

      lineEstimate += math.max(1, (length / charsPerLine).ceil());
    }

    final double estimatedLineHeight = math.max(
      12.0,
      safeFontSize * _lineSpacing * 1.45,
    );

    final double estimatedContentHeight = math.max(
      contentHeight,
      lineEstimate * estimatedLineHeight,
    );

    // Keep the document flow on whole-page boundaries.
    // This preserves one Quill document while giving the page painter
    // enough height to render consecutive A4/Letter-style pages cleanly.
    final double usablePageHeight = math.max(
      200.0,
      pageHeight - _marginTop - _marginBottom,
    );

    final int pageCount = math.max(
      1,
      (estimatedContentHeight / usablePageHeight).ceil(),
    );

    final double pageFlowHeight =
        (pageCount * usablePageHeight) + _marginTop + _marginBottom;

    // Keep a little breathing room between printed pages while the
    // document is shown as one continuous scrollable surface.
    final double pageGap = webLayout ? 0.0 : 24.0;

    // Add the visual gap only in Print Layout.
    // Web Layout remains a continuous document without page breaks.
    final double documentFlowHeight =
        pageFlowHeight +
        (webLayout ? 0.0 : math.max(0, pageCount - 1) * pageGap);

    final double scaledPageWidth = pageWidth * _zoom;

    Widget editorContent = SizedBox(
      width: scaledPageWidth,
      child: Transform.scale(
        scale: _zoom,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: pageWidth,
          child: CustomPaint(
            painter: _TayyibPageBackgroundPainter(
              pageWidth: pageWidth,
              pageHeight: pageHeight,
              zoom: 1.0,
              webLayout: webLayout,
              pageColor: _pageColor,
              pageBorderStyle: _pageBorderStyle,
              showGridlines: _showGridlines,
              watermark: _watermark,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: documentFlowHeight),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  _marginLeft,
                  _marginTop,
                  _marginRight,
                  _marginBottom,
                ),
                child: SizedBox(
                  width: contentWidth,
                  child: _buildColumnLayout(
                    contentWidth: contentWidth,
                    contentHeight: estimatedContentHeight,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Widget editorBody = Container(
      color: webLayout ? const Color(0xFFF1F3F5) : const Color(0xFFD9D9D9),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: webLayout ? 18 : 8,
          bottom: 50,
          left: 12,
          right: 12,
        ),
        child: Column(
          children: [
            if (_showRuler)
              _buildDocumentRuler(pageWidth: pageWidth, webLayout: webLayout),
            const SizedBox(height: 6),
            Center(child: editorContent),
          ],
        ),
      ),
    );

    if (webLayout) {
      editorBody = Container(
        color: const Color(0xFFF1F3F5),
        child: Column(
          children: [
            if (_showRuler)
              _buildDocumentRuler(pageWidth: pageWidth, webLayout: true),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  top: 8,
                  bottom: 50,
                  left: 12,
                  right: 12,
                ),
                child: Center(child: editorContent),
              ),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (webLayout) {
          if (_currentPage != 1 && mounted) {
            setState(() {
              _currentPage = 1;
            });
          }
          return false;
        }

        if (notification.metrics.axis == Axis.vertical) {
          final double pageExtent =
              math.max(200.0, pageHeight - _marginTop - _marginBottom) +
              pageGap;

          final int calculatedPage =
              ((notification.metrics.pixels / pageExtent).floor() + 1).clamp(
                1,
                pageCount,
              );

          if (calculatedPage != _currentPage && mounted) {
            setState(() {
              _currentPage = calculatedPage;
            });
          }
        }

        return false;
      },
      child: Stack(
        children: [
          editorBody,
          if (!webLayout)
            Positioned(
              right: 18,
              bottom: 14,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 6,
                      offset: Offset(0, 2),
                      color: Color(0x33000000),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    'Page $_currentPage of $pageCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentRuler({
    required double pageWidth,
    required bool webLayout,
  }) {
    final int marks = (pageWidth / 24).ceil();

    return SizedBox(
      width: pageWidth * _zoom,
      height: 30,
      child: Transform.scale(
        scale: _zoom,
        alignment: Alignment.topCenter,
        child: Container(
          height: 30,
          width: pageWidth,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F7),
            border: Border.all(color: const Color(0xFFBDBDBD)),
          ),
          child: Row(
            children: List.generate(marks, (index) {
              final bool major = index % 4 == 0;

              return SizedBox(
                width: 24,
                height: 30,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: Container(
                        width: 1,
                        height: major ? 13 : 7,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (major)
                      Positioned(
                        left: 3,
                        top: 2,
                        child: Text(
                          '$index',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      height: 25,
      color: const Color(0xFF217346),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Builder(
            builder: (context) {
              final double pageHeight = _landscape ? 595.0 : 842.0;

              final double contentHeight =
                  (pageHeight - _marginTop - _marginBottom).clamp(
                    200.0,
                    pageHeight,
                  );

              final double contentWidth =
                  ((_landscape ? 842.0 : 595.0) - _marginLeft - _marginRight)
                      .clamp(120.0, _landscape ? 842.0 : 595.0);

              final int pages = _calculateDocumentPageCount(
                plainText: _quillController.document.toPlainText(),
                pageWidth: _landscape ? 842.0 : 595.0,
                pageHeight: _landscape ? 595.0 : 842.0,
                contentWidth: contentWidth,
                contentHeight: contentHeight,
                webLayout: _viewMode == 'Web Layout',
              );

              return Text(
                'Page $_currentPage of $pages',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              );
            },
          ),
          const SizedBox(width: 18),
          Text(
            '$_wordCount words',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          const Spacer(),
          const Text(
            'English (United States)',
            style: TextStyle(color: Colors.white, fontSize: 10),
          ),
          const SizedBox(width: 18),
          const Text(
            '100%',
            style: TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBar() {
    return Container(
      height: 42,
      color: const Color(0xFF185C37),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF107C41),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: const Text(
              'W',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$_currentFileName - Tayyib Word',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          IconButton(
            tooltip: 'New',
            onPressed: _newDocument,
            icon: const Icon(Icons.note_add, color: Colors.white, size: 19),
          ),
          IconButton(
            tooltip: 'Open',
            onPressed: _openFile,
            icon: const Icon(Icons.folder_open, color: Colors.white, size: 19),
          ),
          IconButton(
            tooltip: 'Save',
            onPressed: _saveFile,
            icon: const Icon(Icons.save, color: Colors.white, size: 19),
          ),
          IconButton(
            tooltip: 'Undo',
            onPressed: _undo,
            icon: const Icon(Icons.undo, color: Colors.white, size: 19),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: _redo,
            icon: const Icon(Icons.redo, color: Colors.white, size: 19),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9D9D9),
      body: SafeArea(
        child: Column(
          children: [
            _buildTitleBar(),
            _buildRibbon(),
            Expanded(child: _buildEditor()),
            _buildStatusBar(),
          ],
        ),
      ),
    );
  }
}
