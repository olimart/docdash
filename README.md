# DocDash

A lightweight, dependency-free macOS API documentation browser in the spirit of
[Dash](https://kapeli.com/dash): a sidebar with instant fuzzy search over installed
docsets on the left, rendered documentation on the right. Internal use only.

- **Multiple docsets, multiple versions** — e.g. Ruby 3.4 *and* Ruby 4.0 installed
  side by side, each independently activatable via its checkbox in the sidebar.
- **No dependencies** — pure Swift + AppKit/WebKit, built with SwiftPM. No Xcode
  project, no third-party packages.
- **Scalable pipelines** — every docset type has its own tailored parser pipeline
  that emits one common JSON format the app consumes.

## Using the app

1. Download `DocDash.zip` from the latest [release](../../releases), unzip, and run
   (right-click ▸ Open on first launch — internal builds are ad-hoc signed).
2. **Docsets ▸ Manage Docsets…** lists the catalog published on the `docsets`
   release; click Install.
3. Type in the search field (`⌘F` / `⌘L` to focus). Results rank exact method
   matches first (`map` → `Array#map`). Arrow keys navigate, the page renders
   on the right. Checkboxes in the sidebar activate/deactivate versions.

## Architecture

```
┌────────────────────────┐      ┌──────────────────────────────┐
│  pipelines/<type>/     │      │  DocDash.app (Swift/AppKit)  │
│  tailored per source   │ ───▶ │  DocsetLibrary → SearchEngine│
│  ruby/ rails/ fixture/ │      │  Sidebar ─ WKWebView         │
└────────────────────────┘      └──────────────────────────────┘
        common format: docset.json + index.json + content/
```

### Common docset format

Every pipeline produces a folder that the app consumes as-is:

```
ruby-3.4.10/
├── docset.json    # manifest: type, name, version, identifier, entryCount…
├── index.json     # {"entries": [["Array#map", "m", "Array.html#method-i-map"], …]}
└── content/       # self-contained HTML tree
```

Kind codes: `c` class · `o` module · `m` method · `M` class method · `n` constant
· `a` attribute · `f` guide/page.

Installed docsets live in `~/Library/Application Support/DocDash/Docsets/`
(override with `DOCDASH_DOCSETS_DIR`). Anything you drop there in the format
above appears after **Docsets ▸ Reload Library** — that's the whole contract.

### Pipelines

| Pipeline | Source | Notes |
|---|---|---|
| `pipelines/ruby/build.sh <version> <out>` | cache.ruby-lang.org release tarball | core + stdlib, mirrors ruby-doc.org |
| `pipelines/rails/build.sh <version> <out>` | rails/rails at tag `v<version>` | all framework gems, mirrors api.rubyonrails.org |
| `pipelines/fixture/build.sh <out>` | bundled sample.rb | tiny docset for CI smoke tests |

Both real pipelines share `pipelines/lib/rdoc_docset.rb`, which runs RDoc's
darkfish generator and walks the parsed store to emit the search index. **Adding
a new docset type** = new folder under `pipelines/` with a `build.sh` that emits
the common format (RDoc-based sources can reuse the engine; anything else — e.g.
Python's Sphinx inventory — just needs to write the same three artifacts), then
add it to `.github/workflows/docsets.yml`.

## Building

```sh
./scripts/make_app.sh dist              # native arch → dist/DocDash.app
./scripts/make_app.sh dist --universal  # arm64 + x86_64
```

Headless smoke test (used by CI):

```sh
./pipelines/fixture/build.sh /tmp/fixture-docsets
DOCDASH_DOCSETS_DIR=/tmp/fixture-docsets \
  dist/DocDash.app/Contents/MacOS/DocDash --selftest --query greet --expect-results
```

## CI

- **Build App** (`.github/workflows/build.yml`) — on every push to `main`: builds
  the universal bundle and runs the smoke test, uploading `DocDash.zip` as an
  artifact. On tags `v*`: also creates a GitHub release with the zip attached.
- **Build Docsets** (`.github/workflows/docsets.yml`) — manual dispatch with
  version lists as inputs; regenerates docset tarballs and `catalog.json` and
  publishes them to the fixed `docsets` release, which the in-app installer reads.
