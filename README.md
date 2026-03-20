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
- **Focused mode** — pre-select a specific service and view its blast radius + affected test files in a dedicated Tests tab

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

### Focused mode — inspect a specific service

Opens a report pre-selected on one service, with its full blast radius highlighted and a **Tests** tab listing every test file that exercises it or any service it affects.

```ruby
# Generate focused report and open in browser
Kaskd::Lens.open_focus(class_name: "Payments::ProcessRefund")

# Custom root / output path / BFS depth
Kaskd::Lens.open_focus(
  class_name: "Payments::ProcessRefund",
  root:       "/path/to/project",
  output:     "/tmp/focus-process-refund.html",
  max_depth:  4
)

# Just generate the file without opening it
path = Kaskd::Lens.focus(class_name: "Payments::ProcessRefund")
# => "/path/to/project/kaskd-focus-payments-processrefund.html"
```

The focused report adds:

- Header shows `Focus: Payments::ProcessRefund`
- Green **tests** badge with the count of affected test files
- **Tests** tab in the detail overlay, grouped by pack

Inside a Rails app:

```bash
bundle exec rails runner \
  "require 'kaskd-lens'; Kaskd::Lens.open_focus(class_name: 'Payments::ProcessRefund', root: Rails.root.to_s)"
```

### Programmatic usage

```ruby
require 'kaskd-lens'

result = Kaskd.analyze(root: "/path/to/project")

# Standard report
html = Kaskd::Lens::HtmlReport.new(result).render
File.write("my-report.html", html)

# Focused report (requires kaskd BlastRadius + TestFinder)
blast = Kaskd::BlastRadius.new(result[:services]).compute("Payments::ProcessRefund", max_depth: 6)
tests = Kaskd::TestFinder.new(root: "/path/to/project").find_for(
  blast[:affected].map { |a| a[:class_name] } + ["Payments::ProcessRefund"],
  result[:services]
)
focused = { class_name: "Payments::ProcessRefund", blast_radius: blast, tests: tests[:test_files] }
html = Kaskd::Lens::HtmlReport.new(result, focused: focused).render
File.write("focused.html", html)
```

## License

MIT
