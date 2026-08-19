# Tessera Studio

A local interface over [Tessera](../tessera): browse a directory of models,
analyse one, read the findings its own metadata discloses, and download a
CycloneDX 1.6 or SPDX 3.0.1 bill of materials.

```bash
make build
./bin/tessera-studio /path/to/models
#   http://127.0.0.1:7777
```

## What it is, and what it deliberately isn't

Studio is a **separate program** from the Tessera library and CLI. It depends on
Tessera exactly the way any other consumer would — by importing it:

```go
import tessera "github.com/DAVANO-INNOVATION-LAB/tessera"
```

Studio depends on the published module, with a checksummed `go.sum` like any
other consumer — there is no sibling-directory arrangement to reproduce. To work
on both at once, point Go at a local checkout without editing `go.mod`:

```bash
go work init . ../tessera
```

`go.work` is gitignored, so that stays a local convenience and never becomes a
condition of building this repository.

Nothing in the analyser knows Studio exists. That direction of dependency is the
point: the analyser stays a small, embeddable, zero-dependency library, and the
interface is one of several things built on top of it. Studio's own module graph
is itself plus Tessera, and nothing else.

It is **not** a service. There is no database, no queue, no job history, no
accounts. A request runs an analysis and returns it. Restarting the process
loses nothing because there was nothing to lose.

## Security posture

Studio is a viewer for artifacts you do not trust yet, so it is built to be
uninteresting as a target:

- **Loopback by default.** It binds `127.0.0.1:7777`. Pass `--addr` to change
  that, and understand what you are doing if you bind a routable interface.
- **Confined to one directory.** Every path is resolved inside the directory
  named on the command line. Absolute paths are refused; `..` is neutralised.
  The UI must not become a way to read arbitrary files off the host.
- **Content-Security-Policy that allows nothing external.** The page is
  self-contained: no fonts, no scripts, no images from anywhere else.
- **It inherits Tessera's guarantees.** Analysis reads headers and metadata
  only — no framework loads, no ONNX operator resolution, no external-data
  fetch, and no network access at all.

## Endpoints

| Route | Purpose |
|---|---|
| `GET /` | the interface |
| `GET /api/browse?path=` | list a directory, marking recognised models |
| `GET /api/analyze?path=` | full analysis as JSON |
| `GET /api/bom?path=&format=cyclonedx\|spdx` | bill of materials as a download |

Downloads are reproducible: the BOM is stamped from the model file's own
modification time rather than the wall clock, so fetching twice gives you the
same bytes.

## Layout

```
cmd/tessera-studio    the server binary
internal/web          routes, path confinement, and the embedded UI
```

The interface is a single embedded `ui.html` — no build step, no bundler, no
node_modules. `go build` produces one binary with the UI inside it.

## Licence

Apache-2.0.
