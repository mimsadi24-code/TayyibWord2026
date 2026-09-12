import 'package:flutter/material.dart';

void main() => runApp(const TayyibWord2007());

class TayyibWord2007 extends StatelessWidget {
  const TayyibWord2007({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TayyibWord',
      theme: ThemeData(
        useMaterial3: false,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F4E79),
        ),
      ),
      home: const WordWindow(),
    );
  }
}

class RibbonTab {
  final String name;
  final List<RibbonGroup> groups;

  const RibbonTab(this.name, this.groups);
}

class RibbonGroup {
  final String name;
  final List<RibbonItem> items;

  const RibbonGroup(this.name, this.items);
}

class RibbonItem {
  final IconData icon;
  final String label;
  final bool large;

  const RibbonItem(this.icon, this.label, {this.large = false});
}

const tabs = <RibbonTab>[
  RibbonTab('Home', [
    RibbonGroup('Clipboard', [
      RibbonItem(Icons.content_paste, 'Paste', large: true),
      RibbonItem(Icons.content_copy, 'Copy'),
      RibbonItem(Icons.content_cut, 'Cut'),
      RibbonItem(Icons.format_paint, 'Format Painter'),
    ]),
    RibbonGroup('Font', [
      RibbonItem(Icons.font_download, 'Font'),
      RibbonItem(Icons.format_size, 'Font Size'),
      RibbonItem(Icons.format_bold, 'Bold'),
      RibbonItem(Icons.format_italic, 'Italic'),
      RibbonItem(Icons.format_underlined, 'Underline'),
      RibbonItem(Icons.strikethrough_s, 'Strikethrough'),
      RibbonItem(Icons.format_color_text, 'Font Color'),
      RibbonItem(Icons.format_color_fill, 'Text Highlight'),
    ]),
    RibbonGroup('Paragraph', [
      RibbonItem(Icons.format_align_left, 'Align Left'),
      RibbonItem(Icons.format_align_center, 'Center'),
      RibbonItem(Icons.format_align_right, 'Align Right'),
      RibbonItem(Icons.format_align_justify, 'Justify'),
      RibbonItem(Icons.format_list_bulleted, 'Bullets'),
      RibbonItem(Icons.format_list_numbered, 'Numbering'),
      RibbonItem(Icons.format_indent_increase, 'Increase Indent'),
      RibbonItem(Icons.format_indent_decrease, 'Decrease Indent'),
    ]),
    RibbonGroup('Styles', [
      RibbonItem(Icons.title, 'Styles', large: true),
      RibbonItem(Icons.style, 'Change Styles'),
    ]),
    RibbonGroup('Editing', [
      RibbonItem(Icons.search, 'Find'),
      RibbonItem(Icons.find_replace, 'Replace'),
      RibbonItem(Icons.select_all, 'Select'),
    ]),
  ]),
  RibbonTab('Insert', [
    RibbonGroup('Pages', [
      RibbonItem(Icons.insert_drive_file, 'Cover Page', large: true),
      RibbonItem(Icons.note_add, 'Blank Page'),
      RibbonItem(Icons.horizontal_rule, 'Page Break'),
    ]),
    RibbonGroup('Tables', [
      RibbonItem(Icons.table_chart, 'Table', large: true),
    ]),
    RibbonGroup('Illustrations', [
      RibbonItem(Icons.image, 'Picture', large: true),
      RibbonItem(Icons.photo_library, 'Clip Art'),
      RibbonItem(Icons.shape_line, 'Shapes'),
      RibbonItem(Icons.insert_chart, 'Chart'),
    ]),
    RibbonGroup('Links', [
      RibbonItem(Icons.link, 'Hyperlink', large: true),
      RibbonItem(Icons.bookmark, 'Bookmark'),
      RibbonItem(Icons.linked_camera, 'Cross-reference'),
    ]),
    RibbonGroup('Header & Footer', [
      RibbonItem(Icons.vertical_align_top, 'Header', large: true),
      RibbonItem(Icons.vertical_align_bottom, 'Footer', large: true),
      RibbonItem(Icons.numbers, 'Page Number'),
    ]),
    RibbonGroup('Text', [
      RibbonItem(Icons.text_fields, 'Text Box', large: true),
      RibbonItem(Icons.art_track, 'WordArt'),
      RibbonItem(Icons.add_box, 'Drop Cap'),
      RibbonItem(Icons.date_range, 'Date & Time'),
      RibbonItem(Icons.code, 'Object'),
    ]),
    RibbonGroup('Symbols', [
      RibbonItem(Icons.functions, 'Equation', large: true),
      RibbonItem(Icons.science, 'Symbol'),
    ]),
  ]),
  RibbonTab('Page Layout', [
    RibbonGroup('Themes', [
      RibbonItem(Icons.palette, 'Themes', large: true),
      RibbonItem(Icons.color_lens, 'Colors'),
      RibbonItem(Icons.font_download, 'Fonts'),
      RibbonItem(Icons.auto_awesome, 'Effects'),
    ]),
    RibbonGroup('Page Setup', [
      RibbonItem(Icons.description, 'Margins', large: true),
      RibbonItem(Icons.stay_current_landscape, 'Orientation'),
      RibbonItem(Icons.article, 'Size'),
      RibbonItem(Icons.view_week, 'Columns'),
      RibbonItem(Icons.breaking_news, 'Breaks'),
      RibbonItem(Icons.line_style, 'Line Numbers'),
      RibbonItem(Icons.text_rotation_none, 'Hyphenation'),
    ]),
    RibbonGroup('Page Background', [
      RibbonItem(Icons.water_drop, 'Watermark', large: true),
      RibbonItem(Icons.format_color_fill, 'Page Color'),
      RibbonItem(Icons.border_style, 'Page Borders'),
    ]),
    RibbonGroup('Paragraph', [
      RibbonItem(Icons.format_indent_decrease, 'Indent Left'),
      RibbonItem(Icons.format_indent_increase, 'Indent Right'),
      RibbonItem(Icons.arrow_upward, 'Spacing Before'),
      RibbonItem(Icons.arrow_downward, 'Spacing After'),
    ]),
    RibbonGroup('Arrange', [
      RibbonItem(Icons.position_top_right, 'Position', large: true),
      RibbonItem(Icons.wrap_text, 'Wrap Text'),
      RibbonItem(Icons.bring_to_front, 'Bring Forward'),
      RibbonItem(Icons.send_to_back, 'Send Backward'),
      RibbonItem(Icons.align_horizontal_left, 'Align'),
      RibbonItem(Icons.grid_3x3, 'Group'),
      RibbonItem(Icons.rotate_right, 'Rotate'),
    ]),
  ]),
  RibbonTab('References', [
    RibbonGroup('Table of Contents', [
      RibbonItem(Icons.list_alt, 'Table of Contents', large: true),
      RibbonItem(Icons.add, 'Add Text'),
      RibbonItem(Icons.refresh, 'Update Table'),
    ]),
    RibbonGroup('Footnotes', [
      RibbonItem(Icons.vertical_align_bottom, 'Insert Footnote', large: true),
      RibbonItem(Icons.vertical_align_top, 'Insert Endnote'),
      RibbonItem(Icons.navigate_before, 'Previous Footnote'),
      RibbonItem(Icons.navigate_next, 'Next Footnote'),
    ]),
    RibbonGroup('Citations & Bibliography', [
      RibbonItem(Icons.menu_book, 'Insert Citation', large: true),
      RibbonItem(Icons.library_books, 'Manage Sources'),
      RibbonItem(Icons.book, 'Style'),
      RibbonItem(Icons.format_quote, 'Bibliography'),
    ]),
    RibbonGroup('Captions', [
      RibbonItem(Icons.label, 'Insert Caption', large: true),
      RibbonItem(Icons.list, 'Table of Figures'),
      RibbonItem(Icons.update, 'Update Table'),
      RibbonItem(Icons.crossword, 'Cross-reference'),
    ]),
    RibbonGroup('Index', [
      RibbonItem(Icons.bookmarks, 'Mark Entry', large: true),
      RibbonItem(Icons.list_alt, 'Insert Index'),
      RibbonItem(Icons.refresh, 'Update Index'),
    ]),
    RibbonGroup('Table of Authorities', [
      RibbonItem(Icons.gavel, 'Mark Citation', large: true),
      RibbonItem(Icons.table_view, 'Insert Table'),
      RibbonItem(Icons.update, 'Update Table'),
    ]),
  ]),
  RibbonTab('Mailings', [
    RibbonGroup('Create', [
      RibbonItem(Icons.mail, 'Envelopes', large: true),
      RibbonItem(Icons.local_post_office, 'Labels', large: true),
    ]),
    RibbonGroup('Start Mail Merge', [
      RibbonItem(Icons.mark_email_read, 'Start Mail Merge', large: true),
      RibbonItem(Icons.contacts, 'Select Recipients'),
      RibbonItem(Icons.edit_document, 'Edit Recipient List'),
    ]),
    RibbonGroup('Write & Insert Fields', [
      RibbonItem(Icons.input, 'Highlight Merge Fields'),
      RibbonItem(Icons.person_add, 'Address Block', large: true),
      RibbonItem(Icons.text_fields, 'Greeting Line'),
      RibbonItem(Icons.add_circle_outline, 'Insert Merge Field'),
      RibbonItem(Icons.rules, 'Rules'),
      RibbonItem(Icons.match_case, 'Match Fields'),
      RibbonItem(Icons.refresh, 'Update Labels'),
    ]),
    RibbonGroup('Preview Results', [
      RibbonItem(Icons.preview, 'Preview Results', large: true),
      RibbonItem(Icons.navigate_before, 'Previous'),
      RibbonItem(Icons.navigate_next, 'Next'),
      RibbonItem(Icons.find_in_page, 'Find Recipient'),
      RibbonItem(Icons.error_outline, 'Check for Errors'),
    ]),
    RibbonGroup('Finish', [
      RibbonItem(Icons.done_all, 'Finish & Merge', large: true),
    ]),
  ]),
  RibbonTab('Review', [
    RibbonGroup('Proofing', [
      RibbonItem(Icons.spellcheck, 'Spelling & Grammar', large: true),
      RibbonItem(Icons.menu_book, 'Research'),
      RibbonItem(Icons.translate, 'Translate'),
      RibbonItem(Icons.language, 'Language'),
      RibbonItem(Icons.word, 'Word Count'),
    ]),
    RibbonGroup('Comments', [
      RibbonItem(Icons.comment, 'New Comment', large: true),
      RibbonItem(Icons.delete, 'Delete'),
      RibbonItem(Icons.navigate_before, 'Previous'),
      RibbonItem(Icons.navigate_next, 'Next'),
    ]),
    RibbonGroup('Tracking', [
      RibbonItem(Icons.track_changes, 'Track Changes', large: true),
      RibbonItem(Icons.change_history, 'Balloons'),
      RibbonItem(Icons.rate_review, 'Display for Review'),
      RibbonItem(Icons.settings, 'Show Markup'),
      RibbonItem(Icons.list_alt, 'Reviewing Pane'),
    ]),
    RibbonGroup('Changes', [
      RibbonItem(Icons.check, 'Accept', large: true),
      RibbonItem(Icons.close, 'Reject', large: true),
      RibbonItem(Icons.navigate_before, 'Previous'),
      RibbonItem(Icons.navigate_next, 'Next'),
    ]),
    RibbonGroup('Compare', [
      RibbonItem(Icons.compare_arrows, 'Compare', large: true),
      RibbonItem(Icons.merge_type, 'Combine'),
    ]),
    RibbonGroup('Protect', [
      RibbonItem(Icons.lock, 'Protect Document', large: true),
    ]),
  ]),
  RibbonTab('View', [
    RibbonGroup('Document Views', [
      RibbonItem(Icons.print, 'Print Layout', large: true),
      RibbonItem(Icons.menu_book, 'Full Screen Reading', large: true),
      RibbonItem(Icons.web, 'Web Layout', large: true),
      RibbonItem(Icons.view_agenda, 'Outline', large: true),
      RibbonItem(Icons.description, 'Draft', large: true),
    ]),
    RibbonGroup('Show/Hide', [
      RibbonItem(Icons.ruler, 'Ruler', large: true),
      RibbonItem(Icons.grid_on, 'Gridlines'),
      RibbonItem(Icons.navigation, 'Navigation Pane'),
      RibbonItem(Icons.mark_unread_chat_alt, 'Message Bar'),
      RibbonItem(Icons.map, 'Document Map'),
    ]),
    RibbonGroup('Zoom', [
      RibbonItem(Icons.zoom_in, 'Zoom', large: true),
      RibbonItem(Icons.looks_one, '100%'),
      RibbonItem(Icons.view_column, 'One Page'),
      RibbonItem(Icons.view_week, 'Two Pages'),
      RibbonItem(Icons.fit_screen, 'Page Width'),
    ]),
    RibbonGroup('Window', [
      RibbonItem(Icons.add_box, 'New Window'),
      RibbonItem(Icons.view_column, 'Arrange All'),
      RibbonItem(Icons.splitscreen, 'Split'),
      RibbonItem(Icons.compare, 'View Side by Side'),
      RibbonItem(Icons.sync_alt, 'Synchronous Scrolling'),
      RibbonItem(Icons.switch_left, 'Switch Windows'),
    ]),
    RibbonGroup('Macros', [
      RibbonItem(Icons.code, 'Macros', large: true),
      RibbonItem(Icons.fiber_manual_record, 'Record Macro'),
      RibbonItem(Icons.pause_circle, 'Pause Recording'),
    ]),
  ]),
];

class WordWindow extends StatefulWidget {
  const WordWindow({super.key});

  @override
  State<WordWindow> createState() => _WordWindowState();
}

class _WordWindowState extends State<WordWindow> {
  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final tab = tabs[selectedTab];

    return Scaffold(
      backgroundColor: const Color(0xFFD9D9D9),
      body: SafeArea(
        child: Column(
          children: [
            // WORD 2007 TITLE BAR
            Container(
              height: 42,
              color: const Color(0xFF174A7C),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  _officeButton(),
                  const SizedBox(width: 5),
                  _quickButton(Icons.save, 'Save'),
                  _quickButton(Icons.undo, 'Undo'),
                  _quickButton(Icons.redo, 'Redo'),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Document1 - Microsoft Word',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const Icon(Icons.help_outline,
                      color: Colors.white70, size: 20),
                  const SizedBox(width: 10),
                ],
              ),
            ),

            // WORD 2007 TAB BAR
            Container(
              height: 39,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFEEF3F8),
                    Color(0xFFD6E0EA),
                  ],
                ),
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _tab('Home', 0),
                  _tab('Insert', 1),
                  _tab('Page Layout', 2),
                  _tab('References', 3),
                  _tab('Mailings', 4),
                  _tab('Review', 5),
                  _tab('View', 6),
                ],
              ),
            ),

            // WORD 2007 RIBBON
            Container(
              height: 156,
              color: const Color(0xFFEAF0F6),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 4,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: tab.groups.length,
                separatorBuilder: (_, __) => const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFFB9C7D5),
                ),
                itemBuilder: (_, index) =>
                    _group(tab.groups[index]),
              ),
            ),

            // DOCUMENT WINDOW — NO BLANK/OPEN LANDING SCREEN
            Expanded(
              child: Container(
                color: const Color(0xFFC8C8C8),
                child: Center(
                  child: Container(
                    width: 620,
                    height: 760,
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 12,
                          spreadRadius: 1,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(65, 65, 65, 65),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: 1,
                          height: 20,
                          child: ColoredBox(
                            color: Color(0xFF222222),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // WORD 2007 STATUS BAR
            Container(
              height: 27,
              color: const Color(0xFF315B80),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: const Row(
                children: [
                  Text(
                    'Page 1 of 1',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  SizedBox(width: 18),
                  Text(
                    'Words: 0',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  Spacer(),
                  Text(
                    '100%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.zoom_in,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _officeButton() {
    return Container(
      width: 44,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [
            Color(0xFF4F9ACB),
            Color(0xFF18527E),
            Color(0xFF0B3152),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF7DB7D8),
          width: 1,
        ),
      ),
      child: const Center(
        child: Text(
          'O',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
    );
  }

  Widget _quickButton(IconData icon, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 30,
        height: 36,
        child: Icon(
          icon,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  Widget _tab(String name, int index) {
    final active = selectedTab == index;

    return InkWell(
      onTap: () => setState(() => selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEAF0F6) : Colors.transparent,
          border: active
              ? const Border(
                  top: BorderSide(
                    color: Color(0xFF3B78A8),
                    width: 3,
                  ),
                  left: BorderSide(
                    color: Color(0xFFB5C6D7),
                  ),
                  right: BorderSide(
                    color: Color(0xFFB5C6D7),
                  ),
                )
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          name,
          style: TextStyle(
            fontSize: 13,
            color: active
                ? const Color(0xFF173A5A)
                : const Color(0xFF2B2B2B),
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _group(RibbonGroup group) {
    return SizedBox(
      width: group.items.length <= 2 ? 100 : 150,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Wrap(
                direction: Axis.vertical,
                spacing: 1,
                runSpacing: 1,
                children: group.items.map(_item).toList(),
              ),
            ),
          ),
          Container(
            height: 20,
            alignment: Alignment.center,
            child: Text(
              group.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF304B62),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(RibbonItem item) {
    return SizedBox(
      width: item.large ? 68 : 62,
      height: item.large ? 62 : 38,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(2),
          onTap: () {},
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: item.large ? 27 : 19,
                color: const Color(0xFF254B6A),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF263746),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
