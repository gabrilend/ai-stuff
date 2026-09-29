# 10-042e: Shape Gifs Gallery Source

## Parent Issue

10-042: Integrate Standalone Images Into Site

## Current Behavior

The site's gallery is built from a list of image sources in `config.lua`.
Each source has a name, a folder under `input/images/`, and an outside
folder under `/home/ritz/pictures/` that is copied in. The sources are
my-art, things-I-almost-posted, poem-pictures, dnd-pictures and
fediverse-stars. `src/generate-gallery-pages.lua` (10-042a) gives each
source its own page under `output/gallery/`, plus an index page listing
them all.

A new collection now exists and has no page: animated gifs of 3D shapes
interacting. They are drawn by the monorepo's gallery renderer,
`delta-version/scripts/readme-gallery/` (delta-version issue 060), and kept
at `/home/ritz/pictures/shape-gifs/`, with PNG stills in a `stills/`
subfolder. The owner wants them all showcased:

> I want all of them. But idk which ones I want to be in the readme yet.
> Let's keep them all at /home/ritz/pictures/shape-gifs/ and ideally, make
> an issue file in [neocities-modernization] to add a new gallery page that
> showcases them.

## Intended Behavior

A **shape-gifs** gallery page, `output/gallery/shape-gifs.html`, listed on
the gallery index beside the other sources, showing every gif in
`/home/ritz/pictures/shape-gifs/`, animated.

- **A source like the others.** A new entry in `config.lua`'s image
  sources:
  - name `shape-gifs`;
  - path `input/images/shape-gifs`;
  - `external.source = "/home/ritz/pictures/shape-gifs"`;
  - a description such as "3D shapes interacting, drawn by a program".

  The existing copy step (10-026) brings the files in. No new pipeline.
- **Gifs only.** The `stills/` subfolder holds the PNG stills. They are not
  shown on this page: the gif is the work, and the still is a preview for
  places that cannot animate.
- **Animated on the page.** The gallery shows each original file scaled by
  the browser (`width=` on the `<img>`), not a converted thumbnail, so the
  gifs keep animating. This must stay true: any step added later that makes
  real thumbnails must pass gifs through untouched, or the page shows frozen
  first frames.
- **Captions.** Each gif's caption is its filename in words
  ("jellyfish-flythrough" becomes "jellyfish flythrough"), as the gallery
  already does. A scene's one-line description, from its scene file or the
  renderer's `.info.md`, could be used as alt text; see open questions.
- **Weight.** The collection is about two dozen gifs of 0.3–1.6 MB each,
  tens of megabytes in all. That is within Neocities' limits, but a page
  that starts every gif at once is heavy. The page should use the existing
  lazy loading, so gifs below the fold load as they scroll into view.
- **In the rest of the site, gallery-only for now.** Unlike the other
  sources, these are not poems' pictures. Whether they join the
  chronological interleave (10-042b) or the similar/different navigation
  (10-042c) is an open question. Until it is answered, they appear only on
  their gallery page.

## Suggested Implementation Steps

1. **Add the source** to `config.lua` beside my-art, with the external
   folder and `include_by_default = true`.
2. **Keep the stills out.** Either exclude the `stills/` subfolder in the
   source's settings, or have the copy step skip it. Check which mechanism
   the image manager already offers (`excluded_images`, subfolder handling)
   before adding one.
3. **Run the image stage** and confirm the catalog (`assets/image-catalog.json`)
   gains one entry per gif, with extension `gif`.
4. **Generate the gallery** and confirm that `output/gallery/shape-gifs.html`
   exists, the index links it, and every gif on it animates in a browser.
5. **Test.** Add a check to the gallery tests that a gif source's page links
   the original `.gif` files, not generated thumbnails, so animation cannot
   be lost unnoticed.
6. **Upload** with the site's normal deploy.

## Related

- delta-version issue 060 (the renderer that makes these gifs, and its scene
  files)
- 10-042a (gallery pages), 10-042b (chronological interleaving), 10-042c
  (filename embeddings), 10-042d (gallery chronological list)
- 11-009 (pure black backgrounds): the gifs are drawn on black to match

## Open questions

- Should the shape gifs also appear in the chronological page, the
  similar/different navigation, or both? Or only on their own gallery page?
- Alt text: the filename in words, or each scene's one-line description?
  The description is better for screen readers, but it lives in the
  renderer's scene files in another project.
