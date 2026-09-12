package com.example.tayyib_word_desktop

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileOutputStream
import java.util.zip.CRC32
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class MainActivity : FlutterActivity() {

    private val channel = "tayyibword/engine"
    private val openRequest = 4701

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "newDocument" -> {
                    try {
                        val file = createBlankOdt()
                        val uri = FileProvider.getUriForFile(
                            this,
                            "${packageName}.fileprovider",
                            file
                        )

                        val intent = Intent(
                            this,
                            TayyibEditorActivity::class.java
                        ).apply {
                            setData(uri)
                            addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                            )
                        }

                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error(
                            "NEW_DOCUMENT_FAILED",
                            e.message,
                            null
                        )
                    }
                }

                "openDocument" -> {
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        putExtra(
                            Intent.EXTRA_MIME_TYPES,
                            arrayOf(
                                "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                                "application/msword",
                                "application/vnd.oasis.opendocument.text",
                                "application/rtf",
                                "text/plain"
                            )
                        )
                    }

                    startActivityForResult(intent, openRequest)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        if (
            requestCode == openRequest &&
            resultCode == RESULT_OK &&
            data?.data != null
        ) {
            val uri: Uri = data.data!!

            try {
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
            } catch (_: Exception) {
            }

            val editorIntent = Intent(
                this,
                TayyibEditorActivity::class.java
            ).apply {
                setData(uri)
                addFlags(
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
            }

            startActivity(editorIntent)
        }
    }

    private fun createBlankOdt(): File {
        val directory = File(
            cacheDir,
            "new-documents"
        ).apply {
            mkdirs()
        }

        val file = File.createTempFile(
            "TayyibWord-",
            ".odt",
            directory
        )

        ZipOutputStream(
            BufferedOutputStream(
                FileOutputStream(file)
            )
        ).use { zip ->
            addStoredEntry(
                zip,
                "mimetype",
                "application/vnd.oasis.opendocument.text"
            )

            addEntry(
                zip,
                "content.xml",
                """
                <?xml version="1.0" encoding="UTF-8"?>
                <office:document-content
                    xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
                    xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
                    xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0"
                    xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"
                    office:version="1.3">
                    <office:automatic-styles>
                        <style:style
                            style:name="P1"
                            style:family="paragraph">
                            <style:text-properties
                                fo:font-size="12pt"/>
                        </style:style>
                    </office:automatic-styles>
                    <office:body>
                        <office:text>
                            <text:p text:style-name="P1"></text:p>
                        </office:text>
                    </office:body>
                </office:document-content>
                """.trimIndent()
            )

            addEntry(
                zip,
                "styles.xml",
                """
                <?xml version="1.0" encoding="UTF-8"?>
                <office:document-styles
                    xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
                    xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0"
                    xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
                    xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"
                    office:version="1.3">
                    <office:styles>
                        <style:default-style style:family="paragraph">
                            <style:text-properties
                                fo:font-size="12pt"
                                fo:font-family="Liberation Serif"/>
                        </style:default-style>
                    </office:styles>
                </office:document-styles>
                """.trimIndent()
            )

            addEntry(
                zip,
                "meta.xml",
                """
                <?xml version="1.0" encoding="UTF-8"?>
                <office:document-meta
                    xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
                    office:version="1.3">
                    <office:meta/>
                </office:document-meta>
                """.trimIndent()
            )

            addEntry(
                zip,
                "settings.xml",
                """
                <?xml version="1.0" encoding="UTF-8"?>
                <office:document-settings
                    xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
                    office:version="1.3">
                    <office:settings/>
                </office:document-settings>
                """.trimIndent()
            )

            addEntry(
                zip,
                "META-INF/manifest.xml",
                """
                <?xml version="1.0" encoding="UTF-8"?>
                <manifest:manifest
                    xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0"
                    manifest:version="1.3">
                    <manifest:file-entry
                        manifest:media-type="application/vnd.oasis.opendocument.text"
                        manifest:full-path="/"/>
                    <manifest:file-entry
                        manifest:media-type="text/xml"
                        manifest:full-path="content.xml"/>
                    <manifest:file-entry
                        manifest:media-type="text/xml"
                        manifest:full-path="styles.xml"/>
                    <manifest:file-entry
                        manifest:media-type="text/xml"
                        manifest:full-path="meta.xml"/>
                    <manifest:file-entry
                        manifest:media-type="text/xml"
                        manifest:full-path="settings.xml"/>
                </manifest:manifest>
                """.trimIndent()
            )
        }

        return file
    }

    private fun addStoredEntry(
        zip: ZipOutputStream,
        name: String,
        value: String
    ) {
        val bytes = value.toByteArray(Charsets.US_ASCII)
        val entry = ZipEntry(name)
        val crc = CRC32()

        crc.update(bytes)

        entry.method = ZipEntry.STORED
        entry.size = bytes.size.toLong()
        entry.compressedSize = bytes.size.toLong()
        entry.crc = crc.value

        zip.putNextEntry(entry)
        zip.write(bytes)
        zip.closeEntry()
    }

    private fun addEntry(
        zip: ZipOutputStream,
        name: String,
        value: String
    ) {
        val entry = ZipEntry(name)

        zip.putNextEntry(entry)
        zip.write(value.toByteArray(Charsets.UTF_8))
        zip.closeEntry()
    }
}
