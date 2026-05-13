package com.example.true_hadith

import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.true_hadith/audio_trim"
    private val WA_CHANNEL = "com.example.true_hadith/whatsapp"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // WhatsApp voice notes channel — queries MediaStore so scoped storage is not an issue
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WA_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getVoiceNotes") {
                result.success(queryWhatsAppVoiceNotes())
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "trimAudio" -> {
                    val audioPath = call.argument<String>("audioPath")
                    val startSeconds = call.argument<Double>("startSeconds")
                    val endSeconds = call.argument<Double>("endSeconds")
                    val outputPath = call.argument<String>("outputPath")
                    
                    if (audioPath == null || startSeconds == null || endSeconds == null || outputPath == null) {
                        result.error("INVALID_ARGUMENT", "Missing required arguments", null)
                        return@setMethodCallHandler
                    }
                    
                    try {
                        val trimmedPath = trimAudioFile(audioPath, startSeconds, endSeconds, outputPath)
                        result.success(trimmedPath)
                    } catch (e: Exception) {
                        result.error("TRIM_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun trimAudioFile(inputPath: String, startSeconds: Double, endSeconds: Double, outputPath: String): String {
        val inputFile = File(inputPath)
        if (!inputFile.exists()) {
            throw Exception("Input audio file not found: $inputPath")
        }

        val extractor = MediaExtractor()
        extractor.setDataSource(inputPath)

        val trackCount = extractor.trackCount
        var audioTrackIndex = -1
        var audioFormat: MediaFormat? = null

        // Find audio track
        for (i in 0 until trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME)
            if (mime?.startsWith("audio/") == true) {
                audioTrackIndex = i
                audioFormat = format
                break
            }
        }

        if (audioTrackIndex == -1 || audioFormat == null) {
            extractor.release()
            throw Exception("No audio track found in file")
        }

        // MediaMuxer MPEG_4 only supports AAC. For other codecs, skip trimming.
        val mime = audioFormat.getString(MediaFormat.KEY_MIME) ?: ""
        if (!mime.equals("audio/mp4a-latm", ignoreCase = true) &&
            !mime.equals("audio/aac", ignoreCase = true)) {
            extractor.release()
            throw Exception("Unsupported codec for trimming: $mime. Full audio will be used.")
        }

        extractor.selectTrack(audioTrackIndex)

        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val outputTrackIndex = muxer.addTrack(audioFormat)

        muxer.start()

        val startTimeUs = (startSeconds * 1000000).toLong()
        val endTimeUs = (endSeconds * 1000000).toLong()
        val durationUs = endTimeUs - startTimeUs

        extractor.seekTo(startTimeUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)

        val buffer = ByteBuffer.allocate(64 * 1024) // 64KB buffer
        val bufferInfo = android.media.MediaCodec.BufferInfo()

        var isEOS = false
        var presentationTimeUs: Long = 0

        while (!isEOS) {
            buffer.clear()
            val sampleSize = extractor.readSampleData(buffer, 0)
            if (sampleSize < 0) {
                isEOS = true
                break
            }

            presentationTimeUs = extractor.sampleTime

            if (presentationTimeUs >= endTimeUs) {
                isEOS = true
                break
            }

            if (presentationTimeUs >= startTimeUs) {
                bufferInfo.offset = 0
                bufferInfo.size = sampleSize
                bufferInfo.flags = extractor.sampleFlags
                bufferInfo.presentationTimeUs = presentationTimeUs - startTimeUs

                buffer.position(0)
                buffer.limit(sampleSize)
                muxer.writeSampleData(outputTrackIndex, buffer, bufferInfo)
            }

            extractor.advance()
        }

        muxer.stop()
        muxer.release()
        extractor.release()

        return outputPath
    }

    private fun queryWhatsAppVoiceNotes(): List<Map<String, Any>> {
        val results = mutableListOf<Map<String, Any>>()
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }
        val projection = arrayOf(
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DATE_MODIFIED
        )
        val selection = "${MediaStore.Audio.Media.DATA} LIKE ?"
        val selectionArgs = arrayOf("%WhatsApp Voice Notes%")
        val sortOrder = "${MediaStore.Audio.Media.DATE_MODIFIED} DESC"
        try {
            contentResolver.query(collection, projection, selection, selectionArgs, sortOrder)?.use { cursor ->
                val pathCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
                val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
                val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
                val dateCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_MODIFIED)
                while (cursor.moveToNext()) {
                    val path = cursor.getString(pathCol) ?: continue
                    results.add(mapOf(
                        "path" to path,
                        "name" to (cursor.getString(nameCol) ?: path.substringAfterLast("/")),
                        "size" to cursor.getLong(sizeCol),
                        "modified" to cursor.getLong(dateCol) * 1000L
                    ))
                }
            }
        } catch (_: Exception) {}
        return results
    }
}
