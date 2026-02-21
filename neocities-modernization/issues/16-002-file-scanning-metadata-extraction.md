# Issue 16-002: File Scanning and Metadata Extraction

## Priority
High (Core Functionality)

## Phase
16 (Network Media)

## Current Behavior

No Android file scanning exists. Desktop-side code reads local files directly. There is no metadata extraction pipeline for photos/videos beyond what's needed for poems and text.

## Intended Behavior

Implement comprehensive file scanning and metadata extraction for Android media files:
1. Recursive directory scanning for photos and videos
2. EXIF/metadata extraction for timestamps and details
3. Thumbnail generation for preview images
4. File indexing with stable IDs
5. Incremental scanning for efficiency

### Supported File Types

| Type | Extensions | Metadata |
|------|------------|----------|
| Photo | .jpg, .jpeg, .png, .gif, .webp, .heic | EXIF, dimensions, size |
| Video | .mp4, .mov, .webm, .mkv, .avi | Duration, dimensions, size |
| Raw | .dng, .raw, .arw, .cr2 | EXIF, dimensions |

### Directory Scan Targets

Default Android media locations:
```
/sdcard/DCIM/Camera/          # Main camera photos/videos
/sdcard/DCIM/Screenshots/     # Screenshots
/sdcard/Pictures/             # Saved images
/sdcard/Movies/               # Videos
/sdcard/Download/             # Downloaded media
```

### File Index Structure

```lua
-- In-memory index
local file_index = {
    files = {
        ["a1b2c3d4e5f6g7h8"] = {
            id = "a1b2c3d4e5f6g7h8",
            path = "/sdcard/DCIM/Camera/IMG_20260215_143022.jpg",
            filename = "IMG_20260215_143022.jpg",
            extension = "jpg",
            size = 4523678,
            mime_type = "image/jpeg",

            -- Timestamps
            timestamp = "2026-02-15T14:30:22",
            timestamp_unix = 1739628622,
            mtime = 1739628622,

            -- Dimensions
            width = 4032,
            height = 3024,

            -- EXIF (photos)
            exif = {
                make = "Google",
                model = "Pixel 8",
                orientation = 1,
                gps_lat = 37.7749,
                gps_lon = -122.4194
            },

            -- Video metadata (videos)
            video = {
                duration = 15.5,  -- seconds
                fps = 30,
                codec = "h264"
            },

            -- Thumbnail
            thumbnail_path = "/tmp/android-server/thumbs/a1b2c3d4.jpg",
            thumbnail_generated = true
        },
        -- ... more files
    },

    -- Statistics
    stats = {
        total_files = 1247,
        total_size = 12847234567,
        images = 1102,
        videos = 145,
        last_scan = "2026-02-20T10:30:00"
    },

    -- Scan state
    directories = {
        "/sdcard/DCIM/Camera",
        "/sdcard/Pictures"
    },
    last_full_scan = "2026-02-20T10:30:00"
}
```

### Scanning Implementation (Lua)

```lua
-- {{{ local function scan_directory_recursive
local function scan_directory_recursive(base_path, file_list)
    local media_extensions = {
        jpg = "image/jpeg",
        jpeg = "image/jpeg",
        png = "image/png",
        gif = "image/gif",
        webp = "image/webp",
        heic = "image/heic",
        mp4 = "video/mp4",
        mov = "video/quicktime",
        webm = "video/webm",
        mkv = "video/x-matroska"
    }

    -- Use find command for efficiency
    local cmd = string.format(
        'find "%s" -type f \\( %s \\) 2>/dev/null',
        base_path,
        build_extension_pattern(media_extensions)
    )

    local handle = io.popen(cmd)
    for file_path in handle:lines() do
        local ext = file_path:match("%.(%w+)$"):lower()
        local mime = media_extensions[ext]

        if mime then
            local file_info = extract_file_info(file_path, mime)
            file_list[file_info.id] = file_info
        end
    end
    handle:close()

    return file_list
end
-- }}}

-- {{{ local function build_extension_pattern
local function build_extension_pattern(extensions)
    local patterns = {}
    for ext, _ in pairs(extensions) do
        table.insert(patterns, string.format('-iname "*.%s"', ext))
    end
    return table.concat(patterns, " -o ")
end
-- }}}
```

### Metadata Extraction

#### EXIF for Photos

```lua
-- {{{ local function extract_exif
local function extract_exif(file_path)
    local exif = {}

    -- Use exiftool for comprehensive extraction
    local cmd = string.format(
        'exiftool -json -DateTimeOriginal -Make -Model -ImageWidth -ImageHeight -Orientation -GPSLatitude -GPSLongitude "%s" 2>/dev/null',
        file_path
    )

    local handle = io.popen(cmd)
    local json_str = handle:read("*a")
    handle:close()

    if json_str and json_str ~= "" then
        local data = json.decode(json_str)
        if data and data[1] then
            local d = data[1]
            exif.datetime = d.DateTimeOriginal
            exif.make = d.Make
            exif.model = d.Model
            exif.width = d.ImageWidth
            exif.height = d.ImageHeight
            exif.orientation = d.Orientation
            exif.gps_lat = parse_gps(d.GPSLatitude)
            exif.gps_lon = parse_gps(d.GPSLongitude)
        end
    end

    return exif
end
-- }}}
```

#### Video Metadata

```lua
-- {{{ local function extract_video_metadata
local function extract_video_metadata(file_path)
    local video = {}

    -- Use ffprobe for video info
    local cmd = string.format(
        'ffprobe -v quiet -print_format json -show_format -show_streams "%s" 2>/dev/null',
        file_path
    )

    local handle = io.popen(cmd)
    local json_str = handle:read("*a")
    handle:close()

    if json_str and json_str ~= "" then
        local data = json.decode(json_str)
        if data then
            -- Format info
            if data.format then
                video.duration = tonumber(data.format.duration)
                video.size = tonumber(data.format.size)
            end

            -- Video stream info
            for _, stream in ipairs(data.streams or {}) do
                if stream.codec_type == "video" then
                    video.width = stream.width
                    video.height = stream.height
                    video.codec = stream.codec_name
                    video.fps = parse_frame_rate(stream.r_frame_rate)
                    break
                end
            end
        end
    end

    return video
end
-- }}}
```

### Thumbnail Generation

```lua
-- {{{ local function generate_thumbnail
local function generate_thumbnail(file_path, file_id, config)
    local thumb_dir = config.thumbnail_dir or "/tmp/android-server/thumbs"
    local thumb_size = config.thumbnail_size or 256
    local thumb_path = string.format("%s/%s.jpg", thumb_dir, file_id)

    -- Create directory
    os.execute("mkdir -p " .. thumb_dir)

    -- Check if already exists
    if file_exists(thumb_path) then
        return thumb_path, true
    end

    local mime = get_mime_type(file_path)

    if mime:match("^image/") then
        -- Image thumbnail using convert (ImageMagick)
        local cmd = string.format(
            'convert "%s" -thumbnail %dx%d^ -gravity center -extent %dx%d "%s" 2>/dev/null',
            file_path, thumb_size, thumb_size, thumb_size, thumb_size, thumb_path
        )
        os.execute(cmd)

    elseif mime:match("^video/") then
        -- Video thumbnail using ffmpeg (grab frame at 1 second)
        local cmd = string.format(
            'ffmpeg -y -i "%s" -ss 00:00:01 -vframes 1 -vf scale=%d:-1 "%s" 2>/dev/null',
            file_path, thumb_size, thumb_path
        )
        os.execute(cmd)
    end

    return thumb_path, file_exists(thumb_path)
end
-- }}}
```

### File ID Generation

Stable IDs based on file content/path:

```lua
-- {{{ local function generate_file_id
local function generate_file_id(file_path)
    -- Combine path, size, and mtime for stable ID
    local stat = get_file_stat(file_path)

    local input = string.format("%s:%d:%d",
        file_path,
        stat.size or 0,
        stat.mtime or 0
    )

    -- SHA256 hash, truncated to 16 chars
    local handle = io.popen(string.format(
        'echo -n "%s" | sha256sum | cut -c1-16',
        input:gsub('"', '\\"')
    ))
    local hash = handle:read("*l")
    handle:close()

    return hash or generate_random_id()
end
-- }}}
```

### Incremental Scanning

Track file changes without full rescan:

```lua
-- {{{ local function incremental_scan
local function incremental_scan(directories, existing_index)
    local changes = {
        added = {},
        removed = {},
        modified = {}
    }

    -- Build set of current files
    local current_files = {}
    for _, dir in ipairs(directories) do
        scan_directory_quick(dir, current_files)
    end

    -- Find added and modified
    for path, info in pairs(current_files) do
        local existing = find_by_path(existing_index, path)
        if not existing then
            table.insert(changes.added, path)
        elseif existing.mtime ~= info.mtime or existing.size ~= info.size then
            table.insert(changes.modified, path)
        end
    end

    -- Find removed
    for id, file in pairs(existing_index.files) do
        if not current_files[file.path] then
            table.insert(changes.removed, id)
        end
    end

    return changes
end
-- }}}

-- {{{ local function apply_incremental_changes
local function apply_incremental_changes(index, changes, config)
    -- Remove deleted files
    for _, id in ipairs(changes.removed) do
        index.files[id] = nil
    end

    -- Add/update files
    for _, path in ipairs(changes.added) do
        local info = extract_file_info(path, get_mime_type(path))
        generate_thumbnail(path, info.id, config)
        index.files[info.id] = info
    end

    for _, path in ipairs(changes.modified) do
        local info = extract_file_info(path, get_mime_type(path))
        generate_thumbnail(path, info.id, config)
        index.files[info.id] = info
    end

    -- Update stats
    recalculate_stats(index)

    return index
end
-- }}}
```

### API Response Format

```json
// GET /api/list
{
    "files": [
        {
            "id": "a1b2c3d4e5f6g7h8",
            "filename": "IMG_20260215_143022.jpg",
            "path": "/DCIM/Camera/IMG_20260215_143022.jpg",
            "timestamp": "2026-02-15T14:30:22",
            "size": 4523678,
            "mime_type": "image/jpeg",
            "width": 4032,
            "height": 3024,
            "thumbnail_url": "/api/thumbnail/a1b2c3d4e5f6g7h8",
            "file_url": "/api/file/a1b2c3d4e5f6g7h8"
        }
    ],
    "stats": {
        "total_files": 1247,
        "images": 1102,
        "videos": 145,
        "total_size": 12847234567
    },
    "scanned_at": "2026-02-20T10:30:00Z"
}
```

## Suggested Implementation Steps

1. **Implement directory scanner**
   - Recursive file discovery
   - Extension filtering
   - Basic file info (path, size, mtime)

2. **Add EXIF extraction**
   - Install exiftool in Termux
   - Parse datetime, make, model
   - Handle missing EXIF gracefully

3. **Add video metadata extraction**
   - Use ffprobe
   - Extract duration, dimensions, codec

4. **Implement thumbnail generator**
   - ImageMagick for photos
   - FFmpeg for video frames
   - Cache thumbnails to disk

5. **Add file ID generation**
   - Stable hashing
   - Handle path changes

6. **Implement incremental scanning**
   - Track file changes
   - Update index efficiently
   - Background rescan timer

7. **Build API responses**
   - JSON formatting
   - Include all metadata
   - Pagination for large collections

## Termux Dependencies

```bash
pkg install exiftool imagemagick ffmpeg
```

## Testing Checklist

- [ ] Scans DCIM directories correctly
- [ ] Finds all photo/video extensions
- [ ] EXIF datetime extracted
- [ ] Video duration extracted
- [ ] Thumbnails generated
- [ ] Incremental scan detects new files
- [ ] Incremental scan detects deleted files
- [ ] File IDs stable across rescans

## Related Documents

- 16-001: Android File Server — Vision
- 16-001a: Termux + Lua server implementation
- 16-001c: Network file type integration

## Metadata

- **Status**: Open
- **Created**: 2026-02-20
- **Phase**: 16 (Network Media)
- **Estimated Complexity**: Medium-High
- **Dependencies**: exiftool, ffprobe, ImageMagick
