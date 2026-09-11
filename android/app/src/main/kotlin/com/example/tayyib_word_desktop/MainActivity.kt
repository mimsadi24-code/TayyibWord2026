package com.example.tayyib_word_desktop

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "tayyibword/file"
    private val createDocumentRequestCode = 1001
    private var pendingSaveText: String? = null
    private var pendingSaveBytes: ByteArray? = null
    private var pendingSaveFormat: String = "txt"
    private var pendingSaveResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveFile" -> {
                    val text = call.argument<String>("text") ?: ""
                    val fileName = call.argument<String>("fileName") ?: "Document1.txt"
                    val format = call.argument<String>("format") ?: "txt"
                    val bytes = call.argument<ByteArray>("bytes")
                    val uriString = call.argument<String>("uri")

                    if (!uriString.isNullOrEmpty()) {
                        try {
                            val uri = Uri.parse(uriString)
                            contentResolver.openOutputStream(uri)?.use { output ->
                                if (bytes != null) {
                                    output.write(bytes)
                                } else {
                                    output.write(text.toByteArray(Charsets.UTF_8))
                                }
                            }
                            var savedName = fileName
                            val cursor = contentResolver.query(
                                uri,
                                arrayOf(android.provider.OpenableColumns.DISPLAY_NAME),
                                null,
                                null,
                                null
                            )

                            cursor?.use {
                                if (it.moveToFirst()) {
                                    val index = it.getColumnIndex(
                                        android.provider.OpenableColumns.DISPLAY_NAME
                                    )
                                    if (index >= 0) {
                                        savedName = it.getString(index)
                                    }
                                }
                            }

                            result.success(
                                mapOf(
                                    "uri" to uriString,
                                    "name" to savedName
                                )
                            )
                        } catch (e: Exception) {
                            result.error("SAVE_ERROR", e.message, null)
                        }
                    } else {
                        pendingSaveText = text
                        pendingSaveBytes = bytes
                        pendingSaveFormat = format
                        pendingSaveResult = result

                        val mimeType = when (format.lowercase()) {
                            "pdf" -> "application/pdf"
                            "docx" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                            else -> "text/plain"
                        }

                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = mimeType
                            putExtra(Intent.EXTRA_TITLE, fileName)
                        }

                        startActivityForResult(intent, createDocumentRequestCode)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == createDocumentRequestCode) {
            if (resultCode == RESULT_OK && data?.data != null) {
                val uri: Uri = data.data!!
                val text = pendingSaveText ?: ""
                val bytes = pendingSaveBytes

                try {
                    contentResolver.openOutputStream(uri)?.use { output ->
                        if (bytes != null) {
                            output.write(bytes)
                        } else {
                            output.write(text.toByteArray(Charsets.UTF_8))
                        }
                    }
                    val cursor = contentResolver.query(
                        uri,
                        arrayOf(android.provider.OpenableColumns.DISPLAY_NAME),
                        null,
                        null,
                        null
                    )

                    var savedName = "Document1.txt"
                    cursor?.use {
                        if (it.moveToFirst()) {
                            val index = it.getColumnIndex(
                                android.provider.OpenableColumns.DISPLAY_NAME
                            )
                            if (index >= 0) {
                                savedName = it.getString(index)
                            }
                        }
                    }

                    pendingSaveResult?.success(
                        mapOf(
                            "uri" to uri.toString(),
                            "name" to savedName
                        )
                    )
                } catch (e: Exception) {
                    pendingSaveResult?.error("SAVE_ERROR", e.message, null)
                }
            } else {
                pendingSaveResult?.success(null)
            }

            pendingSaveText = null
            pendingSaveBytes = null
            pendingSaveFormat = "txt"
            pendingSaveResult = null
        }
    }
}
