# Issue 16-002: Native Android Background Service

## Priority
High (Implementation)

## Current Behavior

No native Android app exists for serving files. Users who want a GUI interface rather than CLI would need to use third-party apps that may not integrate with the neocities pipeline.

## Intended Behavior

Create a native Android application that provides:
- GUI for starting/stopping the file server
- Background service for continuous operation
- Settings screen for configuration
- Status notification showing server state

### App Features

| Feature | Description |
|---------|-------------|
| Start/Stop Toggle | Main switch to enable/disable server |
| Port Configuration | Editable port number (default 8443) |
| Directory Selection | Choose which folders to serve |
| Status Display | Current IP, port, file count |
| Persistent Notification | Shows when server is running |
| Auto-start Option | Start server on device boot |

### UI Layout (Main Screen)

```
+----------------------------------------+
|  Android File Server             [...]  |
+----------------------------------------+
|                                        |
|  Server Status: [ RUNNING ]            |
|                                        |
|  IP Address: 192.168.0.42              |
|  Port: 8443                            |
|  Files: 1,247 (1,102 images, 145 video)|
|                                        |
|  +----------------------------------+  |
|  |                                  |  |
|  |     [ START / STOP SERVER ]      |  |
|  |                                  |  |
|  +----------------------------------+  |
|                                        |
|  Serving directories:                  |
|  - /sdcard/DCIM/Camera                 |
|  - /sdcard/Pictures                    |
|  [ + Add Directory ]                   |
|                                        |
+----------------------------------------+
|  [ Settings ]              [ About ]   |
+----------------------------------------+
```

### Settings Screen

```
+----------------------------------------+
|  Settings                        [<-]  |
+----------------------------------------+
|                                        |
|  Network                               |
|  +----------------------------------+  |
|  | Port number        [  8443  ]    |  |
|  | Bind interface     [ All    v ]  |  |
|  +----------------------------------+  |
|                                        |
|  Security                              |
|  +----------------------------------+  |
|  | HTTPS enabled      [x]           |  |
|  | Regenerate cert    [ Regenerate ]|  |
|  +----------------------------------+  |
|                                        |
|  Behavior                              |
|  +----------------------------------+  |
|  | Start on boot      [ ]           |  |
|  | Rescan interval    [ 5 min v ]   |  |
|  | Thumbnail size     [ 256px v ]   |  |
|  +----------------------------------+  |
|                                        |
+----------------------------------------+
```

### Core Architecture (Kotlin)

```kotlin
// FileServerService.kt - Background service
class FileServerService : Service() {

    private lateinit var server: NanoHTTPD
    private lateinit var fileIndex: FileIndex

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, createNotification())

        val config = loadConfig()
        fileIndex = FileIndex(config.directories)
        fileIndex.scan()

        server = FileServer(config.port, fileIndex)
        server.start()

        return START_STICKY
    }

    override fun onDestroy() {
        server.stop()
        super.onDestroy()
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("File Server Running")
            .setContentText("Serving ${fileIndex.count} files on port ${config.port}")
            .setSmallIcon(R.drawable.ic_server)
            .setOngoing(true)
            .build()
    }
}
```

```kotlin
// FileServer.kt - NanoHTTPD-based server
class FileServer(port: Int, private val fileIndex: FileIndex) : NanoHTTPD(port) {

    init {
        makeSecure(SSLUtils.createSSLContext(), null)
    }

    override fun serve(session: IHTTPSession): Response {
        val uri = session.uri

        return when {
            uri == "/api/list" -> serveFileList()
            uri == "/api/count" -> serveFileCount()
            uri.startsWith("/api/file/") -> serveFile(uri.removePrefix("/api/file/"))
            uri.startsWith("/api/thumbnail/") -> serveThumbnail(uri.removePrefix("/api/thumbnail/"))
            uri.startsWith("/api/metadata/") -> serveMetadata(uri.removePrefix("/api/metadata/"))
            else -> newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Not found")
        }
    }

    private fun serveFileList(): Response {
        val json = Gson().toJson(mapOf(
            "files" to fileIndex.files.values.map { it.toJson() },
            "count" to fileIndex.count,
            "scanned_at" to fileIndex.lastScan.toString()
        ))
        return newFixedLengthResponse(Response.Status.OK, "application/json", json)
    }

    // ... additional serve methods
}
```

```kotlin
// FileIndex.kt - Media file indexing
class FileIndex(private val directories: List<String>) {

    val files = mutableMapOf<String, MediaFile>()
    var lastScan: Instant = Instant.MIN
    val count: Int get() = files.size

    fun scan() {
        files.clear()
        directories.forEach { dir ->
            File(dir).walkTopDown()
                .filter { it.isFile && it.isMediaFile() }
                .forEach { file ->
                    val mediaFile = MediaFile.fromFile(file)
                    files[mediaFile.id] = mediaFile
                }
        }
        lastScan = Instant.now()
    }

    private fun File.isMediaFile(): Boolean {
        val ext = extension.lowercase()
        return ext in listOf("jpg", "jpeg", "png", "gif", "webp", "mp4", "mov", "webm", "mkv")
    }
}
```

### Required Android Permissions

```xml
<!-- AndroidManifest.xml -->
<manifest>
    <!-- Storage access -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />

    <!-- Network -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

    <!-- Background operation -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

    <application>
        <service
            android:name=".FileServerService"
            android:foregroundServiceType="dataSync" />

        <receiver android:name=".BootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
            </intent-filter>
        </receiver>
    </application>
</manifest>
```

### Dependencies (build.gradle)

```gradle
dependencies {
    // NanoHTTPD for lightweight HTTP server
    implementation 'org.nanohttpd:nanohttpd:2.3.1'
    implementation 'org.nanohttpd:nanohttpd-nanolets:2.3.1'

    // JSON serialization
    implementation 'com.google.code.gson:gson:2.10.1'

    // Image loading/thumbnails
    implementation 'io.coil-kt:coil:2.5.0'

    // EXIF reading
    implementation 'androidx.exifinterface:exifinterface:1.3.6'

    // Standard Android
    implementation 'androidx.core:core-ktx:1.12.0'
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'com.google.android.material:material:1.11.0'
}
```

## Suggested Implementation Steps

1. **Create Android project**
   - New project with minimum SDK 26 (Android 8.0)
   - Setup Kotlin and required dependencies
   - Create basic MainActivity

2. **Implement FileIndex**
   - Media file scanning
   - Metadata extraction (EXIF)
   - File ID generation

3. **Implement FileServer**
   - NanoHTTPD subclass
   - API route handlers
   - SSL/TLS configuration

4. **Implement FileServerService**
   - Foreground service
   - Notification channel
   - Start/stop lifecycle

5. **Create UI**
   - Main activity layout
   - Settings activity
   - Service binding for status updates

6. **Add boot receiver**
   - Optional auto-start
   - Respect user preference

7. **Testing**
   - Permission handling
   - Background execution
   - Battery optimization whitelisting

## Comparison: Termux vs Native

| Aspect | Termux (16-001) | Native (16-002) |
|--------|------------------|------------------|
| Setup complexity | Lower | Higher |
| User interface | CLI only | Full GUI |
| Background reliability | May be killed | Foreground service |
| Development language | Lua | Kotlin |
| Distribution | Manual script copy | APK install |
| Maintenance | Edit script | App update |

## Related Documents

- 16-001: Android File Server — Vision
- 16-001: Termux + Lua server implementation
- 16-004: HTTPS with self-signed certificates

## Metadata

- **Status**: Open
- **Created**: 2026-02-20
- **Phase**: 16 (Network Media)
- **Estimated Complexity**: High
- **Dependencies**: NanoHTTPD, Android SDK 26+
