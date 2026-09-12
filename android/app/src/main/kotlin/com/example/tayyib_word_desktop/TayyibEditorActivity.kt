package com.example.tayyib_word_desktop

import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.TextView
import org.libreoffice.androidlib.LOActivity

class TayyibEditorActivity : LOActivity() {

    private val blue = Color.rgb(24, 90, 189)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        addWord2007Ribbon()
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private fun addWord2007Ribbon() {
        val root = findViewById<ViewGroup>(android.R.id.content) ?: return

        val ribbon = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(Color.rgb(245, 246, 248))
            elevation = dp(4).toFloat()
            setPadding(dp(6), 0, dp(6), 0)
        }

        val scroll = HorizontalScrollView(this).apply {
            isHorizontalScrollBarEnabled = false
            addView(
                ribbon,
                ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    dp(66)
                )
            )
        }

        root.addView(
            scroll,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(66)
            )
        )

        addGroup(ribbon, "Clipboard") {
            addButton(ribbon, "Paste", "paste")
        }

        addGroup(ribbon, "Font") {
            addButton(ribbon, "B", ".uno:Bold", true)
            addButton(ribbon, "I", ".uno:Italic", true)
            addButton(ribbon, "U", ".uno:Underline", true)
            addButton(ribbon, "S", ".uno:Strikeout", true)
        }

        addGroup(ribbon, "Paragraph") {
            addButton(ribbon, "Left", ".uno:LeftPara")
            addButton(ribbon, "Center", ".uno:CenterPara")
            addButton(ribbon, "Right", ".uno:RightPara")
            addButton(ribbon, "Justify", ".uno:JustifyPara")
        }

        addGroup(ribbon, "Edit") {
            addButton(ribbon, "Undo", ".uno:Undo")
            addButton(ribbon, "Redo", ".uno:Redo")
            addButton(ribbon, "Find", ".uno:SearchDialog")
        }

        addGroup(ribbon, "Insert") {
            addButton(ribbon, "Table", ".uno:InsertTable")
            addButton(ribbon, "Image", ".uno:InsertGraphic")
            addButton(ribbon, "Link", ".uno:HyperlinkDialog")
        }

        addGroup(ribbon, "File") {
            addButton(ribbon, "Save", ".uno:Save")
            addButton(ribbon, "Save As", ".uno:SaveAs")
            addButton(ribbon, "Print", ".uno:Print")
        }

        addGroup(ribbon, "View") {
            addButton(ribbon, "Zoom+", ".uno:ZoomPlus")
            addButton(ribbon, "Zoom-", ".uno:ZoomMinus")
        }
    }

    private fun addGroup(
        ribbon: LinearLayout,
        title: String,
        block: () -> Unit
    ) {
        val group = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(5), 0, dp(5), 0)
        }

        ribbon.addView(
            group,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )

        block()

        val label = TextView(this).apply {
            text = title
            textSize = 9f
            gravity = Gravity.CENTER
            setTextColor(Color.DKGRAY)
        }

        group.addView(
            label,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(16)
            )
        )
    }

    private fun addButton(
        ribbon: LinearLayout,
        text: String,
        command: String,
        italic: Boolean = false
    ) {
        val parent = ribbon.getChildAt(ribbon.childCount - 1) as LinearLayout

        val button = TextView(this).apply {
            this.text = text
            textSize = 12f
            gravity = Gravity.CENTER
            setTextColor(Color.DKGRAY)
            setPadding(dp(8), 0, dp(8), 0)
            if (italic) {
                typeface = Typeface.create(
                    Typeface.DEFAULT,
                    if (text == "B") Typeface.BOLD
                    else if (text == "I") Typeface.ITALIC
                    else Typeface.NORMAL
                )
            }
            setOnClickListener {
                try {
                    if (command == "paste") {
                        postMobileMessage("paste")
                    } else {
                        postUnoCommand(command, "", false)
                    }
                } catch (_: Exception) {
                }
            }
        }

        parent.addView(
            button,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                dp(48)
            )
        )
    }
}
