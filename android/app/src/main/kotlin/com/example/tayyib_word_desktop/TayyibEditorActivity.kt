package com.example.tayyib_word_desktop

import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.GridLayout
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.TextView
import org.libreoffice.androidlib.LOActivity

class TayyibEditorActivity : LOActivity() {
    private val blue=Color.rgb(31,78,121)
    private val ribbon=Color.rgb(242,246,250)
    private val line=Color.rgb(190,204,220)
    private val dark=Color.rgb(45,45,45)
    private var tabs:LinearLayout?=null
    private var body:LinearLayout?=null

    private data class Item(val name:String,val cmd:String?=null)
    private data class Group(val name:String,val width:Int,val items:List<Item>,val cols:Int=2)

    override fun onCreate(b:Bundle?){super.onCreate(b);ui()}

    private fun dp(n:Int)= (n*resources.displayMetrics.density).toInt()

    private fun ui(){
        val root=findViewById<ViewGroup>(android.R.id.content)?:return
        val panel=LinearLayout(this).apply{
            orientation=LinearLayout.VERTICAL
            setBackgroundColor(ribbon)
            elevation=dp(5).toFloat()
        }
        panel.addView(title(),LinearLayout.LayoutParams(-1,dp(44)))
        tabs=LinearLayout(this).apply{
            orientation=LinearLayout.HORIZONTAL
            gravity=Gravity.CENTER_VERTICAL
            setBackgroundColor(Color.rgb(224,234,244))
        }
        val ts=HorizontalScrollView(this).apply{
            isHorizontalScrollBarEnabled=false
            addView(tabs,ViewGroup.LayoutParams(-2,dp(36)))
        }
        panel.addView(ts,LinearLayout.LayoutParams(-1,dp(36)))
        body=LinearLayout(this).apply{
            orientation=LinearLayout.HORIZONTAL
            gravity=Gravity.TOP
            setPadding(dp(4),dp(4),dp(4),dp(2))
            setBackgroundColor(ribbon)
        }
        val rs=HorizontalScrollView(this).apply{
            isHorizontalScrollBarEnabled=false
            addView(body,ViewGroup.LayoutParams(-2,dp(158)))
        }
        panel.addView(rs,LinearLayout.LayoutParams(-1,dp(166)))
        root.addView(panel,FrameLayout.LayoutParams(-1,dp(246),Gravity.TOP))
        show("Home")
    }

    private fun title():View{
        val b=LinearLayout(this).apply{
            orientation=LinearLayout.HORIZONTAL
            gravity=Gravity.CENTER_VERTICAL
            setBackgroundColor(blue)
        }
        b.addView(top("O",24){},LinearLayout.LayoutParams(dp(42),-1))
        b.addView(top("↶",23){uno(".uno:Undo")},LinearLayout.LayoutParams(dp(38),-1))
        b.addView(top("↷",23){uno(".uno:Redo")},LinearLayout.LayoutParams(dp(38),-1))
        b.addView(TextView(this).apply{
            text="Document1 - Microsoft Word"
            textSize=14f
            gravity=Gravity.CENTER
            setTextColor(Color.WHITE)
        },LinearLayout.LayoutParams(0,-1,1f))
        b.addView(top("?",20){},LinearLayout.LayoutParams(dp(34),-1))
        b.addView(top("—",18){},LinearLayout.LayoutParams(dp(34),-1))
        b.addView(top("□",18){},LinearLayout.LayoutParams(dp(34),-1))
        b.addView(top("×",22){finish()},LinearLayout.LayoutParams(dp(34),-1))
        return b
    }

    private fun top(t:String,z:Int,c:()->Unit)=TextView(this).apply{
        text=t;textSize=z.toFloat();gravity=Gravity.CENTER
        setTextColor(Color.WHITE);setOnClickListener{c()}
    }

    private fun show(tab:String){
        body?.removeAllViews()
        tabs?.removeAllViews()
        val names=listOf("File","Home","Insert","Page Layout","References","Mailings","Review","View")
        names.forEach{n->
            tabs?.addView(TextView(this).apply{
                text=n;textSize=14f;gravity=Gravity.CENTER
                setPadding(dp(14),0,dp(14),0)
                setTextColor(if(n==tab)blue else dark)
                typeface=if(n==tab)Typeface.DEFAULT_BOLD else Typeface.DEFAULT
                setBackgroundColor(if(n==tab)Color.WHITE else Color.TRANSPARENT)
                setOnClickListener{if(n!="File")show(n)}
            },LinearLayout.LayoutParams(-2,dp(36)))
        }
        groups(tab).forEach{group(it)}
    }

    private fun group(g:Group){
        val box=LinearLayout(this).apply{
            orientation=LinearLayout.VERTICAL
            setPadding(dp(4),dp(3),dp(4),0)
            background=GradientDrawable().apply{
                setColor(Color.TRANSPARENT)
                setStroke(dp(1),line)
                cornerRadius=dp(2).toFloat()
            }
        }
        val grid=GridLayout(this).apply{
            columnCount=g.cols
            rowCount=GridLayout.UNDEFINED
            useDefaultMargins=false
        }
        g.items.forEach{item->
            grid.addView(button(item),GridLayout.LayoutParams().apply{
                width=0
                height=dp(34)
                columnSpec=GridLayout.spec(GridLayout.UNDEFINED,1,1f)
                rowSpec=GridLayout.spec(GridLayout.UNDEFINED)
                setMargins(dp(2),dp(2),dp(2),dp(2))
            })
        }
        box.addView(grid,LinearLayout.LayoutParams(-1,0,1f))
        box.addView(TextView(this).apply{
            text=g.name;textSize=10f;gravity=Gravity.CENTER;setTextColor(Color.DKGRAY)
        },LinearLayout.LayoutParams(-1,dp(18)))
        body?.addView(box,LinearLayout.LayoutParams(dp(g.width),dp(154)).apply{
            setMargins(dp(2),0,dp(2),0)
        })
    }

    private fun button(i:Item)=TextView(this).apply{
        text=i.name
        textSize=10f
        gravity=Gravity.CENTER
        setTextColor(dark)
        setPadding(dp(2),dp(2),dp(2),dp(2))
        background=GradientDrawable().apply{
            setColor(Color.WHITE)
            setStroke(dp(1),Color.rgb(215,221,228))
            cornerRadius=dp(2).toFloat()
        }
        setOnClickListener{if(i.cmd!=null)uno(i.cmd) else action(i.name)}
    }

    private fun I(n:String,c:String?=null)=Item(n,c)

    private fun groups(t:String):List<Group>{
        return when(t){
            "Home"->listOf(
                Group("Clipboard",130,listOf(I("📋\nPaste"),I("Cut",".uno:Cut"),I("Copy",".uno:Copy"),I("Format Painter")),1),
                Group("Font",300,listOf(I("Calibri (Body)"),I("11"),I("B\nBold",".uno:Bold"),I("I\nItalic",".uno:Italic"),I("U\nUnderline",".uno:Underline"),I("S\nStrike",".uno:Strikeout"),I("x₂\nSubscript",".uno:Subscript"),I("x²\nSuperscript",".uno:Superscript"),I("A↕\nChange Case"),I("Tx\nClear"),I("🖍\nHighlight"),I("A̲\nFont Color"),I("A+\nGrow"),I("A−\nShrink")),4),
                Group("Paragraph",275,listOf(I("•\nBullets"),I("1.\nNumbering"),I("≡\nMultilevel List"),I("←\nDecrease Indent"),I("→\nIncrease Indent"),I("A↕\nSort"),I("¶\nShow/Hide"),I("Left",".uno:LeftPara"),I("Center",".uno:CenterPara"),I("Right",".uno:RightPara"),I("Justify",".uno:JustifyPara"),I("↕\nLine Spacing"),I("▣\nShading"),I("▤\nBorders")),4),
                Group("Styles",235,listOf(I("Normal"),I("No Spacing"),I("Heading 1"),I("Heading 2"),I("Title"),I("Subtitle"),I("Subtle Emphasis"),I("Quote"),I("Change Styles")),3),
                Group("Editing",125,listOf(I("🔎 Find",".uno:SearchDialog"),I("↔ Replace"),I("☑ Select")),1)
            )
            "Insert"->listOf(
                Group("Pages",130,listOf(I("▣ Cover Page"),I("□ Blank Page"),I("↵ Page Break")),1),
                Group("Tables",115,listOf(I("▦\nTable",".uno:InsertTable")),1),
                Group("Illustrations",255,listOf(I("▧\nPicture",".uno:InsertGraphic"),I("▱\nClip Art"),I("◇\nShapes"),I("✦\nSmartArt"),I("▥\nChart"),I("▣\nScreenshot")),3),
                Group("Links",145,listOf(I("🔗 Hyperlink",".uno:HyperlinkDialog"),I("🔖 Bookmark"),I("↗ Cross-reference")),1),
                Group("Header & Footer",150,listOf(I("Header"),I("Footer"),I("# Page Number")),1),
                Group("Text",210,listOf(I("▣ Text Box"),I("❖ Quick Parts"),I("A WordArt"),I("D Drop Cap"),I("✍ Signature Line"),I("📅 Date & Time"),I("▦ Object")),2),
                Group("Symbols",125,listOf(I("∑ Equation",".uno:InsertFormula"),I("Ω Symbol")),1)
            )
            "Page Layout"->listOf(
                Group("Themes",145,listOf(I("Aa\nThemes"),I("◼\nColors"),I("A\nFonts"),I("◉\nEffects")),2),
                Group("Page Setup",220,listOf(I("▤ Margins"),I("↔ Orientation"),I("A4 Size"),I("▥ Columns"),I("↵ Breaks"),I("123 Line Numbers"),I("abc Hyphenation")),2),
                Group("Page Background",150,listOf(I("Watermark"),I("Page Color"),I("Page Borders")),1),
                Group("Paragraph",150,listOf(I("← Indent"),I("→ Indent"),I("↑ Before"),I("↓ After")),2),
                Group("Arrange",205,listOf(I("Position"),I("Bring to Front"),I("Send to Back"),I("Text Wrapping"),I("Align"),I("Group"),I("Rotate")),2)
            )
            "References"->listOf(
                Group("Table of Contents",180,listOf(I("▤ Table of Contents"),I("↻ Update Table")),1),
                Group("Footnotes",145,listOf(I("AB¹ Insert Footnote"),I("ABᵃ Insert Endnote")),1),
                Group("Citations & Bibliography",205,listOf(I("Insert Citation"),I("Manage Sources"),I("Bibliography")),1),
                Group("Captions",145,listOf(I("Insert Caption"),I("Cross-reference")),1),
                Group("Index",125,listOf(I("Mark Entry"),I("Insert Index")),1),
                Group("Table of Authorities",175,listOf(I("Mark Citation"),I("Table of Authorities")),1)
            )
            "Mailings"->listOf(
                Group("Create",130,listOf(I("Envelopes"),I("Labels")),1),
                Group("Start Mail Merge",180,listOf(I("Start Mail Merge"),I("Select Recipients"),I("Edit Recipient List")),1),
                Group("Write & Insert Fields",210,listOf(I("Address Block"),I("Greeting Line"),I("Insert Merge Field"),I("Rules"),I("Match Fields"),I("Update Labels")),2),
                Group("Preview Results",155,listOf(I("Preview Results"),I("First"),I("Previous"),I("Next"),I("Last"),I("Find Recipient")),2),
                Group("Finish",135,listOf(I("Finish & Merge")),1)
            )
            "Review"->listOf(
                Group("Proofing",145,listOf(I("ABC Spelling"),I("Thesaurus"),I("Word Count")),1),
                Group("Comments",145,listOf(I("New Comment"),I("Delete"),I("Previous"),I("Next")),1),
                Group("Tracking",155,listOf(I("Track Changes"),I("Show Markup"),I("Reviewing Pane")),1),
                Group("Changes",130,listOf(I("Accept"),I("Reject"),I("Previous"),I("Next")),1),
                Group("Compare",120,listOf(I("Compare"),I("Combine")),1),
                Group("Protect",150,listOf(I("Protect Document"),I("Restrict Editing")),1)
            )
            "View"->listOf(
                Group("Document Views",185,listOf(I("▣ Print Layout"),I("▤ Full Screen"),I("▥ Web Layout"),I("Outline"),I("Draft")),2),
                Group("Show/Hide",155,listOf(I("☑ Ruler"),I("☑ Gridlines"),I("☑ Navigation Pane")),2),
                Group("Zoom",175,listOf(I("Zoom +",".uno:ZoomPlus"),I("Zoom −",".uno:ZoomMinus"),I("100%"),I("One Page"),I("Two Pages"),I("Page Width")),2),
                Group("Window",180,listOf(I("New Window"),I("Arrange All"),I("Split"),I("View Side by Side"),I("Switch Windows")),2),
                Group("Macros",110,listOf(I("Macros")),1)
            )
            else->emptyList()
        }
    }

    private fun action(raw:String){
        val n=raw.replace("\n"," ").trim().lowercase()
        try{
            when{
                n=="paste" || n.startsWith("📋 paste") -> postMobileMessage("paste")
                n=="cut" || n.startsWith("cut") -> uno(".uno:Cut")
                n=="copy" || n.startsWith("copy") -> uno(".uno:Copy")
                n.contains("save as") -> uno(".uno:SaveAs")
                n=="save" || n.startsWith("save ") -> uno(".uno:Save")
                n.contains("print") -> uno(".uno:Print")
                n.contains("bold") -> uno(".uno:Bold")
                n.contains("italic") -> uno(".uno:Italic")
                n.contains("underline") -> uno(".uno:Underline")
                n.contains("strike") -> uno(".uno:Strikeout")
                n.contains("subscript") -> uno(".uno:Subscript")
                n.contains("superscript") -> uno(".uno:Superscript")
                n=="left" || n.startsWith("left ") -> uno(".uno:LeftPara")
                n=="center" || n.startsWith("center ") -> uno(".uno:CenterPara")
                n=="right" || n.startsWith("right ") -> uno(".uno:RightPara")
                n=="justify" || n.startsWith("justify ") -> uno(".uno:JustifyPara")
                n.contains("find") -> uno(".uno:SearchDialog")
                n.contains("table") && !n.contains("contents") -> uno(".uno:InsertTable")
                n.contains("picture") -> uno(".uno:InsertGraphic")
                n.contains("hyperlink") -> uno(".uno:HyperlinkDialog")
                n.contains("equation") -> uno(".uno:InsertFormula")
                n.contains("zoom +") -> uno(".uno:ZoomPlus")
                n.contains("zoom −") || n.contains("zoom -") -> uno(".uno:ZoomMinus")
                n.contains("undo") -> uno(".uno:Undo")
                n.contains("redo") -> uno(".uno:Redo")
                n.contains("page break") -> uno(".uno:InsertPageBreak")
                n.contains("new comment") -> uno(".uno:InsertAnnotation")
                n.contains("word count") -> uno(".uno:WordCountDialog")
                n.contains("spelling") -> uno(".uno:SpellDialog")
                n.contains("thesaurus") -> uno(".uno:ThesaurusDialog")
                n.contains("insert caption") -> uno(".uno:InsertCaptionDialog")
                n.contains("bookmark") -> uno(".uno:InsertBookmark")
                n.contains("footnote") -> uno(".uno:InsertFootnote")
                n.contains("endnote") -> uno(".uno:InsertEndnote")
                n.contains("page number") -> uno(".uno:InsertPageNumber")
                n.contains("header") -> uno(".uno:InsertPageHeader")
                n.contains("footer") -> uno(".uno:InsertPageFooter")
                n.contains("select") -> uno(".uno:SelectAll")
                n.contains("show/hide") -> uno(".uno:ControlCodes")
                n.contains("ruler") -> uno(".uno:ViewRuler")
                n.contains("gridlines") -> uno(".uno:Grid")
                n.contains("navigation pane") -> uno(".uno:Sidebar")
                n.contains("print layout") -> uno(".uno:PrintLayout")
                n.contains("full screen") -> uno(".uno:FullScreen")
                n.contains("web layout") -> uno(".uno:BrowseView")
                n.contains("outline") -> uno(".uno:OutlineView")
                n.contains("draft") -> uno(".uno:NormalView")
                n.contains("columns") -> uno(".uno:FormatColumns")
                n.contains("page color") -> uno(".uno:BackgroundColor")
                n.contains("page borders") -> uno(".uno:BorderDialog")
                n.contains("protect document") -> uno(".uno:Protect")
                n.contains("track changes") -> uno(".uno:TrackChanges")
                n.contains("accept") -> uno(".uno:AcceptTrackedChange")
                n.contains("reject") -> uno(".uno:RejectTrackedChange")
                n.contains("previous") -> uno(".uno:PreviousTrackedChange")
                n.contains("next") -> uno(".uno:NextTrackedChange")
                n.contains("macros") -> uno(".uno:MacroDialog")
                n.contains("new window") -> uno(".uno:NewWindow")
                n.contains("split") -> uno(".uno:SplitWindow")
                n.contains("switch windows") -> uno(".uno:WindowList")
                else -> {}
            }
        }catch(_:Exception){}
    }

    private fun uno(c:String){try{postUnoCommand(c,"",false)}catch(_:Exception){}}

}
