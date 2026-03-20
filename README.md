# kaskd-lens

Interactive HTML viewer for [kaskd](https://github.com/nildiert/kaskd) service dependency graphs.

Generates a self-contained HTML page that visualizes the service dependency graph produced by the `kaskd` gem. Features include:

- **vis.js interactive graph** with hierarchical layout
- **Blast radius** badge showing affected service count
- **Depth slider** to control BFS traversal depth (1-6)
- **Sidebar** with search and pack filtering
- **Detail overlay** with Affected/Dependencies/Info tabs
- **Path tracing** showing how services are connected
- **Dark/light themes** with localStorage persistence
- **Copy diagram** to clipboard as PNG
- **Export JSON** dependency report
- **Navigation history** (back/forward)
- **No external dependencies** — vis-network.js is vendored and inlined

## Installation

```ruby
gem 'kaskd-lens'
```

## Usage

### Generate a standalone HTML file

```ruby
require 'kaskd-lens'

# Analyze current directory and write report
path = Kaskd::Lens.generate_html
# => "kaskd-report.html"

# Specify project root and output path
path = Kaskd::Lens.generate_html(root: "/path/to/project", output: "/tmp/graph.html")
```

### Generate and open in browser

```ruby
Kaskd::Lens.open_viewer
Kaskd::Lens.open_viewer(root: "/path/to/project")
```

### Start a local HTTP server

```ruby
Kaskd::Lens.serve
Kaskd::Lens.serve(root: "/path/to/project", port: 8080)
```

### Programmatic usage

```ruby
require 'kaskd-lens'

result = Kaskd.analyze(root: "/path/to/project")
html   = Kaskd::Lens::HtmlReport.new(result).render
File.write("my-report.html", html)
```

## License

MIT
