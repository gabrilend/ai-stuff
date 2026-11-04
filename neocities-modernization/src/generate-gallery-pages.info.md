# generate-gallery-pages.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in src/generate-gallery-pages.lua: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
Issue 10-042a: Generate HTML gallery pages for standalone images
Creates gallery index and per-source gallery pages from image-catalog.json

Usage:
  luajit src/generate-gallery-pages.lua [--dir PATH]

Output:
  output/gallery/index.html - Gallery index listing all sources
  output/gallery/my-art.html - Gallery for my-art images
  output/gallery/poem-pictures.html - Gallery for poem-pictures images
  output/gallery/things-i-almost-posted.html - Gallery for things-i-almost-posted
  output/gallery/dnd-pictures.html - Gallery for dnd-pictures
  output/gallery/fediverse-stars.html - Gallery for fediverse-stars

Note: fediverse-media is excluded as those images are inline with poems

--help: print the header above and exit, when run as a program (libs/script-help.lua)
```

## External functions (what other programs can call)

### `M.generate(output_dir)`

```
output_dir: where the pages go (default the site's gallery/; another
folder for a trial)
```

## Inside (local to the file)

### `load_image_catalog()`
(No comment above it in the source.)

### `filter_standalone_images(catalog)`

```
Filter to only standalone images (exclude fediverse-media)
```

### `group_by_source(images)`

```
Group images by their source_name
```

### `url_encode_path(path)`

```
Percent-encode a relative URL path so filenames containing spaces, ?, #, %,
parentheses, etc. don't break the href/src. Path separators (/) and the safe
set [A-Za-z0-9-._~] are preserved, so the "../../gallery/..." structure still
resolves; only the unsafe bytes inside each segment are escaped. Without this
a space silently truncated the src and the browser drew a broken-image icon.
```

### `get_relative_image_path(absolute_path)`

```
Convert absolute path to a URL-safe relative path from output/gallery/.
```

### `caption_with_breaks(filename)`

```
Render a filename as a thumbnail caption that WRAPS on dashes/underscores
instead of being chopped to 20 chars + "...". We HTML-escape the name, then
insert <wbr> (a zero-width break opportunity) after each - or _ so a long
name like "dnd-pictures-from-the-internet-04" folds onto several lines inside
the thumbnail column rather than truncating or overflowing. The caller wraps
this in a width-constrained span so the breaks actually engage.
```

### `extract_display_name(filename)`

```
Extract a display name from filename (used as alt text)
```

### `generate_html_header(title)`
(No comment above it in the source.)

### `generate_html_footer()`
(No comment above it in the source.)

### `generate_gallery_grid(images)`

```
Generate a MASONRY layout for images. The old fixed <table> grid forced every
row to the height of its tallest image, so portrait/landscape mixes left big
ragged vertical gaps. CSS multi-column layout packs each column independently
(an item flows under the previous one in its column), giving uniform ~18px
gaps and no wasted space -- and needs no JavaScript, so it still works as a
plain neocities page. break-inside:avoid keeps an image and its caption
together rather than splitting them across a column boundary.
```

### `generate_source_gallery(source_name, images)`

```
Generate a gallery page for a specific source
```

### `generate_gallery_index(grouped_images)`

```
Generate the main gallery index page
```

### `image_qualified_title(img)`

```
"source: sub: name.png" for a catalog image: strip the (absolute)
source_directory prefix off relative_path, then delegate to the shared title
helper that poem-page image entries also use (Issue 9-013 / 10-042d).
```

### `image_anchor(img, fallback_index)`

```
Stable per-image anchor so poem pages can deep-link to one image here.
```

### `generate_gallery_chronological(images)`

```
Issue 10-042d: all standalone images, every source, in time order, as a
vertical scroll. Between each pair of images is a caption block naming the
image ABOVE and the image BELOW, so every title shows twice (once on each
side of its picture). Each image is anchored for deep-linking from poems.
```
