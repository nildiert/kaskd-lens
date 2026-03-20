# frozen_string_literal: true

require "json"

module Kaskd
  module Lens
    # Generates a standalone HTML file with the interactive service graph viewer.
    #
    # The output is a single HTML file with:
    # - vis-network.min.js inlined (no CDN dependency)
    # - The analysis data embedded as window.__KASKD_DATA__
    # - Full interactive UI: search, pack filter, blast radius, depth slider,
    #   detail overlay with tabs, path tracing, dark/light themes, copy diagram,
    #   export JSON, navigation history
    class HtmlReport
      # @param result [Hash] output from Kaskd.analyze
      #   { services: Hash, generated_at: String, total: Integer }
      def initialize(result)
        @result = result
      end

      # @return [String] the complete HTML document
      def render
        vis_js = load_vis_network_js
        data_json = JSON.generate(@result)

        build_html(vis_js, data_json)
      end

      private

      def load_vis_network_js
        path = File.expand_path("../../../vendor/assets/vis-network.min.js", __dir__)
        File.read(path)
      end

      def build_html(vis_js, data_json)
        <<~HTML
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Service Graph — Kaskd Lens</title>
            <script>#{vis_js}</script>
            <style>#{css}</style>
          </head>
          <body>

          <div id="overlay">
            <div class="spin"></div>
            <p id="overlay-msg">Loading graph…</p>
          </div>

          <header>
            <h1>&#11041; Service Graph</h1>
            <span class="badge" id="badge-total">—</span>
            <span class="badge" id="badge-cache">—</span>
            <span class="spacer"></span>
            <div class="theme-toggle" id="theme-toggle" title="Toggle light/dark theme">
              <span class="icon" id="icon-moon">&#9790;</span>
              <div class="toggle-track">
                <div class="toggle-knob"></div>
              </div>
              <span class="icon dim" id="icon-sun">&#9788;</span>
            </div>
          </header>

          <div class="main">
            <!-- Sidebar -->
            <div class="sidebar">
              <div class="pack-filter">
                <select id="pack-select">
                  <option value="">All packs</option>
                </select>
              </div>
              <div class="search-wrap">
                <div class="si">
                  <input type="text" id="search" placeholder="Search service…" autocomplete="off">
                </div>
              </div>
              <div id="service-list"></div>
            </div>

            <!-- Detail overlay panel -->
            <div id="detail-overlay">
              <div class="overlay-header">
                <span class="overlay-title" id="detail-overlay-title">Details</span>
                <button id="btn-close-detail" title="Close panel">&#10005;</button>
              </div>
              <div class="tabs">
                <div class="tab active" data-tab="affected">
                  &#8593; Affected <span class="tab-count" id="tc-affected">0</span>
                </div>
                <div class="tab" data-tab="deps">
                  &#8595; Dependencies <span class="tab-count" id="tc-deps">0</span>
                </div>
                <div class="tab" data-tab="info">
                  &#8505; Info
                </div>
              </div>
              <div class="tab-body active" id="tb-affected"></div>
              <div class="tab-body" id="tb-deps"></div>
              <div class="tab-body" id="tb-info"></div>
            </div>
            <button id="btn-toggle-detail" title="Toggle detail panel"><span class="arrow">&#9654;</span></button>

            <!-- Right -->
            <div class="right-panel">
              <!-- Info bar -->
              <div id="info-bar">
                <div class="nav-group">
                  <button class="nav-btn" id="btn-back" title="Go back" disabled>&#9664;</button>
                  <button class="nav-btn" id="btn-forward" title="Go forward" disabled>&#9654;</button>
                </div>
                <div>
                  <div id="info-name"></div>
                  <div id="info-file"></div>
                </div>
                <span class="spacer"></span>
                <button class="btn-export" id="btn-export" title="Download dependency report as JSON">&#8615; Export JSON</button>
                <div class="blast-badge" title="Services that would be affected if this one changes">
                  <div>
                    <div class="num" id="blast-num">0</div>
                    <div class="lbl">affected</div>
                  </div>
                </div>
              </div>

              <!-- Graph -->
              <div class="graph-area">
                <div id="vis-graph"></div>

                <div id="graph-empty">
                  <svg width="60" height="60" viewBox="0 0 60 60" fill="none" stroke="#4a6080" stroke-width="1.5">
                    <circle cx="30" cy="10" r="7"/>
                    <circle cx="10" cy="46" r="7"/>
                    <circle cx="50" cy="46" r="7"/>
                    <line x1="30" y1="17" x2="19" y2="39"/>
                    <line x1="30" y1="17" x2="41" y2="39"/>
                  </svg>
                  <p>Select a service to see its transitive blast radius</p>
                </div>

                <button id="btn-copy-diagram" title="Copy diagram to clipboard">
                  <span class="copy-icon">&#128203;</span> Copy diagram
                </button>

                <div id="depth-ctrl">
                  Depth
                  <input type="range" id="depth-slider" min="1" max="6" value="3">
                  <span id="depth-val">3</span>
                </div>

                <div id="legend">
                  <div class="leg"><div class="leg-dot" style="background:#f0f6fc;border:1px solid #8b949e"></div> Selected</div>
                  <div class="leg"><div class="leg-dot" style="background:#bd561d"></div> Affected level 1 (above)</div>
                  <div class="leg"><div class="leg-dot" style="background:#5e2208"></div> Affected level 2+ (above)</div>
                  <div class="leg"><div class="leg-dot" style="background:#1f6feb"></div> Dependency level 1 (below)</div>
                  <div class="leg"><div class="leg-dot" style="background:#09357e"></div> Dependency level 2+ (below)</div>
                </div>
              </div>
            </div>
          </div>

          <div class="toast" id="toast"></div>

          <script>
          window.__KASKD_DATA__ = #{data_json};
          #{javascript}
          </script>
          </body>
          </html>
        HTML
      end

      # rubocop:disable Metrics/MethodLength
      def css
        <<~CSS
          *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

          /* ── Dark theme (default) ─────────────────────────────────── */
          :root, [data-theme="dark"] {
            --bg-deep:    #0d1117;
            --bg-dark:    #161b22;
            --bg-card:    #21262d;
            --bg-hover:   #1c2128;
            --border:     #30363d;
            --border-hi:  #6e7681;
            --text-base:  #e6edf3;
            --text-muted: #8b949e;
            --text-dim:   #484f58;
            --accent:     #2f81f7;
            --accent-hi:  #58a6ff;
            --orange:     #f0883e;
            --overlay-bg: rgba(13, 17, 23, .9);
            --svc-name:   #cdd9e5;
            --selected-bg:    #f0f6fc;
            --selected-border:#cdd9e5;
            --selected-font:  #0d1117;
            --node-shadow: rgba(0,0,0,0.4);
            --legend-bg:  rgba(22, 27, 34, .96);
            --chip-blue-bg:  #1f3d6e;
            --chip-blue-fg:  #79c0ff;
            --chip-blue-bdr: #1f6feb;
            --chip-green-bg: #5c2200;
            --chip-green-fg: #ffa657;
            --chip-green-bdr:#bd561d;
            --scrollbar-thumb: var(--border);
          }

          /* ── Light theme ──────────────────────────────────────────── */
          [data-theme="light"] {
            --bg-deep:    #f6f8fa;
            --bg-dark:    #ffffff;
            --bg-card:    #f0f3f6;
            --bg-hover:   #eaeef2;
            --border:     #d0d7de;
            --border-hi:  #8c959f;
            --text-base:  #1f2328;
            --text-muted: #656d76;
            --text-dim:   #8c959f;
            --accent:     #0969da;
            --accent-hi:  #0550ae;
            --orange:     #bc4c00;
            --overlay-bg: rgba(246, 248, 250, .92);
            --svc-name:   #1f2328;
            --selected-bg:    #0969da;
            --selected-border:#0550ae;
            --selected-font:  #ffffff;
            --node-shadow: rgba(0,0,0,0.12);
            --legend-bg:  rgba(255, 255, 255, .96);
            --chip-blue-bg:  #ddf4ff;
            --chip-blue-fg:  #0550ae;
            --chip-blue-bdr: #54aeff;
            --chip-green-bg: #fff1e5;
            --chip-green-fg: #bc4c00;
            --chip-green-bdr:#d4a72c;
            --scrollbar-thumb: #c1c8cf;
          }

          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            font-size: 13px;
            background: var(--bg-deep);
            color: var(--text-base);
            height: 100vh;
            display: flex;
            flex-direction: column;
            overflow: hidden;
          }

          /* ── Header ──────────────────────────────────────────────── */
          header {
            background: var(--bg-dark);
            border-bottom: 1px solid var(--border);
            padding: 10px 18px;
            display: flex;
            align-items: center;
            gap: 12px;
            flex-shrink: 0;
          }
          header h1 { font-size: 15px; font-weight: 700; color: var(--text-base); letter-spacing: -0.3px; }
          .badge {
            background: var(--bg-card);
            border: 1px solid var(--border);
            color: var(--text-muted);
            font-size: 11px;
            padding: 2px 8px;
            border-radius: 20px;
          }
          header .spacer { flex: 1; }

          /* ── Layout ──────────────────────────────────────────────── */
          .main { display: flex; flex: 1; overflow: hidden; position: relative; }

          /* ── Sidebar ─────────────────────────────────────────────── */
          .sidebar {
            width: 320px;
            flex-shrink: 0;
            background: var(--bg-dark);
            border-right: 1px solid var(--border);
            display: flex;
            flex-direction: column;
            overflow: hidden;
          }
          .search-wrap {
            padding: 12px;
            border-bottom: 1px solid var(--border);
            flex-shrink: 0;
          }
          .search-wrap input {
            width: 100%;
            background: var(--bg-deep);
            border: 1px solid var(--border);
            border-radius: 8px;
            color: var(--text-base);
            padding: 7px 10px 7px 30px;
            font-size: 12px;
            outline: none;
            transition: border-color .15s;
          }
          .search-wrap input:focus { border-color: var(--accent); }
          .search-wrap .si { position: relative; }
          .search-wrap .si::before {
            content: "\\2315";
            position: absolute;
            left: 9px;
            top: 50%;
            transform: translateY(-50%);
            color: var(--text-dim);
            font-size: 16px;
            line-height: 1;
          }

          #service-list { flex: 1; overflow-y: auto; padding: 4px 0; }
          #service-list::-webkit-scrollbar { width: 3px; }
          #service-list::-webkit-scrollbar-thumb { background: var(--scrollbar-thumb); border-radius: 2px; }

          .svc-item {
            padding: 8px 12px;
            cursor: pointer;
            border-left: 2px solid transparent;
            transition: background .1s, border-color .1s;
          }
          .svc-item:hover { background: var(--bg-hover); border-left-color: var(--border-hi); }
          .svc-item.active { background: var(--bg-hover); border-left-color: var(--accent-hi); }
          .svc-item .name {
            font-size: 12px;
            color: var(--svc-name);
            font-family: "SF Mono", "Fira Code", monospace;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
          }
          .svc-item .desc {
            font-size: 11px;
            color: var(--text-muted);
            margin-top: 2px;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
          }
          .svc-item .chips {
            display: flex;
            gap: 4px;
            margin-top: 3px;
            flex-wrap: wrap;
          }
          .chip {
            font-size: 9px;
            font-weight: 600;
            padding: 1px 5px;
            border-radius: 3px;
            letter-spacing: .03em;
            text-transform: uppercase;
          }
          .chip-blue  { background: var(--chip-blue-bg); color: var(--chip-blue-fg); border: 1px solid var(--chip-blue-bdr); }
          .chip-green { background: var(--chip-green-bg); color: var(--chip-green-fg); border: 1px solid var(--chip-green-bdr); }

          .empty-msg { padding: 24px 16px; text-align: center; color: var(--text-dim); font-size: 12px; }

          /* ── Right panel ─────────────────────────────────────────── */
          .right-panel { flex: 1; display: flex; flex-direction: column; overflow: hidden; }

          /* ── Info bar ────────────────────────────────────────────── */
          #info-bar {
            background: var(--bg-card);
            border-bottom: 1px solid var(--border);
            padding: 10px 16px;
            display: none;
            align-items: center;
            gap: 12px;
            flex-shrink: 0;
          }
          #info-bar.visible { display: flex; }
          #info-name {
            font-family: "SF Mono", "Fira Code", monospace;
            font-size: 13px;
            font-weight: 700;
            color: var(--text-base);
            max-width: 340px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
          }
          #info-file {
            font-size: 10px;
            color: var(--text-muted);
            font-family: monospace;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            flex: 1;
          }
          .blast-badge {
            display: flex;
            align-items: center;
            gap: 6px;
            background: #3d1f00;
            border: 1px solid #bd561d;
            border-radius: 6px;
            padding: 4px 12px;
            flex-shrink: 0;
          }
          .blast-badge .num {
            font-size: 20px;
            font-weight: 800;
            color: #ffa657;
            line-height: 1;
          }
          .blast-badge .lbl { font-size: 10px; color: #c46212; text-transform: uppercase; letter-spacing: .05em; }

          /* ── Nav buttons ─────────────────────────────────────────── */
          .nav-group {
            display: flex;
            gap: 2px;
            flex-shrink: 0;
          }
          .nav-btn {
            background: var(--bg-deep);
            border: 1px solid var(--border);
            color: var(--text-muted);
            width: 28px;
            height: 28px;
            border-radius: 6px;
            cursor: pointer;
            font-size: 14px;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: color .15s, border-color .15s, opacity .15s;
          }
          .nav-btn:hover:not(:disabled) { color: var(--accent-hi); border-color: var(--accent-hi); }
          .nav-btn:disabled { opacity: .3; cursor: default; }

          /* ── Export button ────────────────────────────────────────── */
          .btn-export {
            background: var(--bg-deep);
            border: 1px solid var(--border);
            color: var(--text-muted);
            padding: 4px 10px;
            border-radius: 6px;
            cursor: pointer;
            font-size: 11px;
            display: flex;
            align-items: center;
            gap: 5px;
            transition: color .15s, border-color .15s;
            flex-shrink: 0;
          }
          .btn-export:hover { color: var(--accent-hi); border-color: var(--accent-hi); }

          /* ── Graph ───────────────────────────────────────────────── */
          .graph-area { flex: 1; position: relative; min-height: 0; }
          #vis-graph { width: 100%; height: 100%; }
          #graph-empty {
            position: absolute;
            inset: 0;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            gap: 14px;
            color: var(--text-dim);
            pointer-events: none;
          }
          #graph-empty svg { opacity: .25; }
          #graph-empty p { font-size: 12px; }

          /* legend */
          #legend {
            position: absolute;
            bottom: 14px;
            right: 14px;
            background: var(--legend-bg);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 10px 12px;
            font-size: 11px;
            display: none;
            gap: 8px;
            flex-direction: column;
          }
          #legend.visible { display: flex; }
          .leg { display: flex; align-items: center; gap: 8px; color: var(--text-muted); }
          .leg-dot { width: 9px; height: 9px; border-radius: 50%; flex-shrink: 0; }

          /* depth control */
          #depth-ctrl {
            position: absolute;
            top: 12px;
            right: 12px;
            background: var(--legend-bg);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 8px 12px;
            display: none;
            align-items: center;
            gap: 8px;
            font-size: 11px;
            color: var(--text-muted);
          }
          #depth-ctrl.visible { display: flex; }
          #depth-slider { width: 80px; accent-color: var(--accent); }
          #depth-val { color: var(--accent-hi); font-weight: 700; min-width: 14px; }

          /* ── Detail tabs (inside overlay) ───────────────────────── */
          #detail-overlay .tabs {
            display: flex;
            border-bottom: 1px solid var(--border);
            flex-shrink: 0;
          }
          .tab {
            padding: 8px 16px;
            cursor: pointer;
            font-size: 11px;
            font-weight: 600;
            color: var(--text-muted);
            border-bottom: 2px solid transparent;
            transition: color .1s, border-color .1s;
            text-transform: uppercase;
            letter-spacing: .05em;
            display: flex;
            align-items: center;
            gap: 6px;
          }
          .tab:hover { color: var(--text-base); }
          .tab.active { color: var(--text-base); border-bottom-color: var(--accent-hi); }
          .tab-count {
            background: var(--bg-card);
            border: 1px solid var(--border);
            border-radius: 20px;
            padding: 0 5px;
            font-size: 10px;
            color: var(--text-muted);
          }
          .tab-body { flex: 1; overflow-y: auto; padding: 8px 12px; display: none; }
          .tab-body::-webkit-scrollbar { width: 3px; }
          .tab-body::-webkit-scrollbar-thumb { background: var(--scrollbar-thumb); }
          .tab-body.active { display: block; }

          /* depth group */
          .depth-group { margin-bottom: 12px; }
          .depth-label {
            font-size: 10px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: .07em;
            padding: 3px 6px;
            border-radius: 4px;
            margin-bottom: 5px;
            display: inline-flex;
            align-items: center;
            gap: 5px;
          }
          .depth-label.blue-1 { background: #1f6feb; color: #fff; }
          .depth-label.blue-2 { background: #1158cb; color: #cae8ff; }
          .depth-label.blue-3 { background: #0d45a5; color: #79c0ff; }
          .depth-label.blue-n { background: #09357e; color: #58a6ff; }
          .depth-label.green-1 { background: #bd561d; color: #fff; }
          .depth-label.green-2 { background: #9b4215; color: #ffd8b1; }
          .depth-label.green-3 { background: #7c310e; color: #ffa657; }
          .depth-label.green-n { background: #5e2208; color: #f0883e; }

          .dep-item {
            display: flex;
            align-items: center;
            gap: 7px;
            padding: 3px 4px;
            border-radius: 4px;
            cursor: pointer;
            transition: background .1s;
          }
          .dep-item:hover { background: var(--bg-hover); }
          .dep-item .dot { width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0; }
          .dep-item .nm {
            font-family: "SF Mono", "Fira Code", monospace;
            font-size: 11px;
            color: var(--svc-name);
          }
          .dep-item:hover .nm { color: var(--text-base); }

          .desc-info { padding: 8px 4px; font-size: 12px; color: var(--text-muted); line-height: 1.55; }
          .dep-desc {
            font-size: 11px;
            color: var(--text-muted);
            margin-top: 2px;
            line-height: 1.4;
            white-space: normal;
          }

          /* ── Path trace ──────────────────────────────────────────── */
          .path-trace {
            font-size: 10px;
            color: var(--text-dim);
            margin-top: 2px;
            font-family: "SF Mono", "Fira Code", monospace;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
          }
          .path-trace .arrow { color: var(--text-dim); margin: 0 2px; }
          .path-trace .hop   { color: var(--text-muted); }
          .path-trace .direct { color: var(--text-dim); font-style: italic; }

          /* ── Pack filter ─────────────────────────────────────────── */
          .pack-filter {
            padding: 8px 12px;
            border-bottom: 1px solid var(--border);
            flex-shrink: 0;
          }
          .pack-filter select {
            width: 100%;
            background: var(--bg-deep);
            border: 1px solid var(--border);
            border-radius: 6px;
            color: var(--text-base);
            padding: 5px 8px;
            font-size: 11px;
            outline: none;
            cursor: pointer;
          }
          .pack-filter select:focus { border-color: var(--accent); }
          .pack-filter select option { background: var(--bg-dark); }

          /* ── Theme toggle ────────────────────────────────────────── */
          .theme-toggle {
            display: flex;
            align-items: center;
            gap: 6px;
            cursor: pointer;
            user-select: none;
          }
          .theme-toggle .icon { font-size: 14px; line-height: 1; transition: opacity .2s; }
          .theme-toggle .icon.dim { opacity: .35; }
          .toggle-track {
            width: 36px;
            height: 20px;
            background: var(--bg-card);
            border: 1px solid var(--border);
            border-radius: 20px;
            position: relative;
            transition: background .2s, border-color .2s;
          }
          .toggle-track .toggle-knob {
            width: 16px;
            height: 16px;
            border-radius: 50%;
            background: var(--accent-hi);
            position: absolute;
            top: 1px;
            left: 1px;
            transition: transform .25s cubic-bezier(.4,.0,.2,1), background .2s;
          }
          [data-theme="light"] .toggle-track .toggle-knob { transform: translateX(16px); }
          [data-theme="light"] .toggle-track { background: var(--accent); border-color: var(--accent); }
          [data-theme="light"] .toggle-track .toggle-knob { background: #ffffff; }

          /* ── Sidebar detail overlay ──────────────────────────────── */
          #detail-overlay {
            position: absolute;
            top: 0;
            left: 320px;
            width: 380px;
            height: 100%;
            background: var(--bg-dark);
            border-left: 1px solid var(--border);
            box-shadow: 4px 0 24px rgba(0,0,0,.3);
            z-index: 50;
            display: none;
            flex-direction: column;
            overflow: hidden;
            transition: transform .25s cubic-bezier(.4,.0,.2,1), opacity .2s;
          }
          [data-theme="light"] #detail-overlay { box-shadow: 4px 0 24px rgba(0,0,0,.08); }
          #detail-overlay.visible { display: flex; }

          #detail-overlay .overlay-header {
            display: flex;
            align-items: center;
            padding: 10px 12px;
            border-bottom: 1px solid var(--border);
            gap: 8px;
            flex-shrink: 0;
          }
          #detail-overlay .overlay-header .overlay-title {
            font-size: 12px;
            font-weight: 700;
            color: var(--text-base);
            flex: 1;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
            font-family: "SF Mono", "Fira Code", monospace;
          }
          #btn-close-detail {
            background: none;
            border: 1px solid var(--border);
            color: var(--text-muted);
            width: 24px;
            height: 24px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 14px;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: color .15s, border-color .15s;
            flex-shrink: 0;
          }
          #btn-close-detail:hover { color: var(--text-base); border-color: var(--border-hi); }

          #btn-toggle-detail {
            position: absolute;
            top: 50%;
            left: 320px;
            transform: translateY(-50%);
            width: 28px;
            height: 56px;
            background: var(--bg-dark);
            border: 1px solid var(--border);
            border-left: none;
            border-radius: 0 8px 8px 0;
            cursor: pointer;
            display: none;
            align-items: center;
            justify-content: center;
            color: var(--text-muted);
            font-size: 13px;
            z-index: 51;
            transition: color .15s, background .15s, left .25s;
          }
          #btn-toggle-detail:hover { color: var(--accent-hi); background: var(--bg-card); }
          #btn-toggle-detail.visible { display: flex; }
          #btn-toggle-detail.shifted { left: 700px; }
          #btn-toggle-detail .arrow { transition: transform .2s; }
          #btn-toggle-detail.shifted .arrow { transform: rotate(180deg); }

          /* ── Copy diagram button ─────────────────────────────────── */
          #btn-copy-diagram {
            position: absolute;
            top: 12px;
            left: 12px;
            background: var(--legend-bg);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 6px 12px;
            cursor: pointer;
            font-size: 11px;
            color: var(--text-muted);
            display: none;
            align-items: center;
            gap: 6px;
            transition: color .15s, border-color .15s;
            z-index: 10;
          }
          #btn-copy-diagram:hover { color: var(--accent-hi); border-color: var(--accent-hi); }
          #btn-copy-diagram.visible { display: flex; }
          #btn-copy-diagram .copy-icon { font-size: 13px; }
          #btn-copy-diagram.copied { color: #3fb950; border-color: #3fb950; }
          #btn-copy-diagram.copied::after { content: none; }

          /* ── Toast notification ──────────────────────────────────── */
          .toast {
            position: fixed;
            bottom: 20px;
            left: 50%;
            transform: translateX(-50%) translateY(80px);
            background: var(--bg-card);
            border: 1px solid var(--border);
            color: var(--text-base);
            padding: 8px 20px;
            border-radius: 8px;
            font-size: 12px;
            z-index: 200;
            opacity: 0;
            transition: transform .3s cubic-bezier(.4,.0,.2,1), opacity .3s;
            pointer-events: none;
          }
          .toast.show {
            transform: translateX(-50%) translateY(0);
            opacity: 1;
          }
          #overlay {
            position: fixed;
            inset: 0;
            background: var(--overlay-bg);
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            gap: 16px;
            z-index: 100;
          }
          #overlay.hidden { display: none; }
          .spin {
            width: 34px; height: 34px;
            border: 3px solid var(--border);
            border-top-color: var(--accent);
            border-radius: 50%;
            animation: spin .7s linear infinite;
          }
          @keyframes spin { to { transform: rotate(360deg); } }
          #overlay p { color: var(--text-muted); font-size: 12px; }
        CSS
      end
      # rubocop:enable Metrics/MethodLength

      # rubocop:disable Metrics/MethodLength
      def javascript
        <<~'JS'
          (function () {
            'use strict';

            // ── Load data from embedded JSON ──────────────────────────────────────────
            var DATA = window.__KASKD_DATA__;

            // ── State ──────────────────────────────────────────────────────────────────
            let services  = {};
            let revIndex  = {};
            let network   = null;
            let selected  = null;
            let maxDepth  = 3;
            let activePack = '';

            // Navigation history
            let navHistory = [];
            let navIndex   = -1;
            let navLock    = false;

            // ── Colors by depth ────────────────────────────────────────────────────────
            const USER_COLORS = [
              { bg: '#bd561d', border: '#ffa657', font: '#ffffff', dot: '#ffa657' },
              { bg: '#9b4215', border: '#f0883e', font: '#ffd8b1', dot: '#f0883e' },
              { bg: '#7c310e', border: '#d4641a', font: '#ffc680', dot: '#d4641a' },
              { bg: '#5e2208', border: '#bd561d', font: '#ffa657', dot: '#bd561d' },
            ];
            const DEP_COLORS = [
              { bg: '#1f6feb', border: '#79c0ff', font: '#ffffff', dot: '#79c0ff' },
              { bg: '#1158cb', border: '#58a6ff', font: '#cae8ff', dot: '#58a6ff' },
              { bg: '#0d45a5', border: '#2f81f7', font: '#a5d3ff', dot: '#2f81f7' },
              { bg: '#09357e', border: '#1f6feb', font: '#79c0ff', dot: '#1f6feb' },
            ];
            const DEPTH_LABEL_CLASS = {
              users: ['green-1','green-2','green-3','green-n'],
              deps:  ['blue-1','blue-2','blue-3','blue-n'],
            };

            function userColor(d) { return USER_COLORS[Math.min(d - 1, USER_COLORS.length - 1)]; }
            function depColor(d)  { return DEP_COLORS[Math.min(d - 1, DEP_COLORS.length - 1)]; }

            // ── BFS with path tracking ─────────────────────────────────────────────────
            function bfs(startName, neighborsFn, maxD, filter) {
              const dist = {};
              const prev = {};
              const queue = [startName];
              dist[startName] = 0;
              while (queue.length) {
                const cur = queue.shift();
                if (dist[cur] >= maxD) continue;
                (neighborsFn(cur) || []).forEach(nb => {
                  if (dist[nb] === undefined && (!filter || filter(nb))) {
                    dist[nb] = dist[cur] + 1;
                    prev[nb] = cur;
                    queue.push(nb);
                  }
                });
              }
              delete dist[startName];
              delete prev[startName];
              return { dist, prev };
            }

            function getPath(name, prev) {
              const path = [name];
              let cur = name;
              let guard = 0;
              while (prev[cur] && guard++ < 20) {
                cur = prev[cur];
                path.unshift(cur);
              }
              return path;
            }

            function packFilter() {
              if (!activePack) return null;
              return nb => !services[nb] || services[nb].pack === activePack;
            }

            function getAffected(name, maxD) {
              return bfs(name, n => revIndex[n] || [], maxD, packFilter());
            }

            function getDeps(name, maxD) {
              return bfs(name, n => (services[n]?.dependencies || []), maxD, packFilter());
            }

            // ── Build reverse index ────────────────────────────────────────────────────
            function buildRevIndex() {
              revIndex = {};
              Object.values(services).forEach(s => {
                (s.dependencies || []).forEach(dep => {
                  if (!revIndex[dep]) revIndex[dep] = [];
                  revIndex[dep].push(s.class_name);
                });
              });
            }

            // ── Pack selector ──────────────────────────────────────────────────────────
            function populatePacks() {
              const packs = [...new Set(Object.values(services).map(s => s.pack).filter(Boolean))].sort();
              const sel = document.getElementById('pack-select');
              const current = sel.value;
              sel.innerHTML = '<option value="">All packs</option>' +
                packs.map(p => `<option value="${esc(p)}"${p === current ? ' selected' : ''}>${esc(p)}</option>`).join('');
            }

            // ── Initialize from embedded data ──────────────────────────────────────────
            function loadData() {
              services = DATA.services || {};
              buildRevIndex();
              populatePacks();
              updateBadges(DATA);
              renderList('');
              hideOverlay();
            }

            function hideOverlay() {
              document.getElementById('overlay').classList.add('hidden');
            }

            // ── Badges ─────────────────────────────────────────────────────────────────
            function updateBadges(data) {
              document.getElementById('badge-total').textContent = `${data.total} services`;
              var d = new Date(data.generated_at);
              document.getElementById('badge-cache').textContent =
                `Generated ${d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
            }

            // ── List ───────────────────────────────────────────────────────────────────
            function renderList(q) {
              const el  = document.getElementById('service-list');
              const lq  = q.toLowerCase();
              const all = Object.values(services)
                .filter(s => (!lq || s.class_name.toLowerCase().includes(lq)) &&
                             (!activePack || s.pack === activePack))
                .sort((a, b) => a.class_name.localeCompare(b.class_name))
                .slice(0, 250);

              if (!all.length) {
                el.innerHTML = `<div class="empty-msg">No results for "<b>${esc(q)}</b>"</div>`;
                return;
              }

              el.innerHTML = all.map(s => {
                const deps  = (s.dependencies || []).length;
                const users = (revIndex[s.class_name] || []).length;
                return `
                  <div class="svc-item${s.class_name === selected ? ' active' : ''}" data-n="${esc(s.class_name)}">
                    <div class="name" title="${esc(s.class_name)}">${esc(s.class_name)}</div>
                    ${s.description ? `<div class="desc">${esc(s.description)}</div>` : ''}
                    <div class="chips">
                      ${deps  ? `<span class="chip chip-blue">&#8595; ${deps}</span>`  : ''}
                      ${users ? `<span class="chip chip-green">&#8593; ${users}</span>` : ''}
                    </div>
                  </div>`;
              }).join('');

              el.querySelectorAll('.svc-item').forEach(item =>
                item.addEventListener('click', () => selectService(item.dataset.n))
              );
            }

            // ── Select service ─────────────────────────────────────────────────────────
            function selectService(name) {
              selected = name;
              const svc = services[name];
              if (!svc) return;

              if (!navLock) {
                navHistory = navHistory.slice(0, navIndex + 1);
                navHistory.push(name);
                navIndex = navHistory.length - 1;
              }
              updateNavButtons();

              document.querySelectorAll('.svc-item').forEach(el =>
                el.classList.toggle('active', el.dataset.n === name)
              );
              document.querySelector('.svc-item.active')?.scrollIntoView({ block: 'nearest' });

              const { dist: affectedDist, prev: affectedPrev } = getAffected(name, maxDepth);
              const { dist: depsDist,     prev: depsPrev }     = getDeps(name, maxDepth);

              showInfoBar(svc, Object.keys(affectedDist).length);
              renderGraph(name, affectedDist, depsDist, affectedPrev, depsPrev);
              renderAffectedTab(affectedDist, affectedPrev, name);
              renderDepsTab(depsDist, depsPrev, name);
              renderInfoTab(svc);
              showDetailOverlay(svc.class_name);
            }

            // ── Navigation ─────────────────────────────────────────────────────────────
            function navigateBack() {
              if (navIndex <= 0) return;
              navIndex--;
              navLock = true;
              selectService(navHistory[navIndex]);
              navLock = false;
            }

            function navigateForward() {
              if (navIndex >= navHistory.length - 1) return;
              navIndex++;
              navLock = true;
              selectService(navHistory[navIndex]);
              navLock = false;
            }

            function updateNavButtons() {
              document.getElementById('btn-back').disabled    = navIndex <= 0;
              document.getElementById('btn-forward').disabled = navIndex >= navHistory.length - 1;
            }

            // ── Info bar ───────────────────────────────────────────────────────────────
            function showInfoBar(svc, blastCount) {
              document.getElementById('info-name').textContent = svc.class_name;
              document.getElementById('info-file').textContent = svc.file || '';
              document.getElementById('blast-num').textContent = blastCount;
              document.getElementById('info-bar').classList.add('visible');
            }

            // ── Graph ──────────────────────────────────────────────────────────────────
            function renderGraph(name, affected, deps, affectedPrev, depsPrev) {
              document.getElementById('graph-empty').style.display = 'none';
              document.getElementById('legend').classList.add('visible');
              document.getElementById('depth-ctrl').classList.add('visible');
              document.getElementById('btn-copy-diagram').classList.add('visible');

              const isLight = document.documentElement.getAttribute('data-theme') === 'light';
              const selBg    = isLight ? '#0969da' : '#f0f6fc';
              const selBdr   = isLight ? '#0550ae' : '#cdd9e5';
              const selFont  = isLight ? '#ffffff' : '#0d1117';
              const selHiBg  = isLight ? '#0550ae' : '#ffffff';
              const selHiBdr = isLight ? '#0969da' : '#e6edf3';
              const shadowColor = isLight ? 'rgba(0,0,0,0.12)' : 'rgba(0,0,0,0.4)';

              const nodes = new vis.DataSet();
              const edges = new vis.DataSet();

              // Selected node at level 0
              nodes.add({
                id: name,
                label: nodeLabel(name, 0),
                title: name,
                shape: 'ellipse',
                size: 32,
                level: 0,
                color: { background: selBg, border: selBdr,
                         highlight: { background: selHiBg, border: selHiBdr } },
                font:  { color: selFont, size: 13, bold: true, face: 'SF Mono, Fira Code, monospace' },
                borderWidth: 2,
              });

              // Affected nodes go ABOVE (negative levels)
              Object.entries(affected).forEach(([n, d]) => {
                const c    = userColor(d);
                const size = d === 1 ? 20 : 14;
                const path = getPath(n, affectedPrev);
                const pathStr = path.length > 1
                  ? path.map(shortLabel).join(' \u2192 ')
                  : `directly uses ${shortLabel(name)}`;
                nodes.add({
                  id: n, label: nodeLabel(n, d),
                  title: `${n}\nAffected (level ${d})\n${pathStr}${services[n]?.description ? '\n\n' + services[n].description : ''}`,
                  shape: 'box', size,
                  level: -d,
                  color: { background: c.bg, border: c.border,
                           highlight: { background: c.border, border: '#fff' } },
                  font:  { color: c.font, size: 12, face: 'SF Mono, Fira Code, monospace' },
                  borderWidth: d === 1 ? 2 : 1,
                });
                const parent = affectedPrev[n] || name;
                edges.add({
                  from: n, to: parent, arrows: 'to',
                  color: { color: c.border, opacity: Math.max(0.3, 1 - (d - 1) * 0.2) },
                  width: Math.max(0.5, 2 - d * 0.3),
                  dashes: d > 1,
                  title: `${n} \u2192 ${parent} (level ${d})`,
                });
              });

              // Dependency nodes go BELOW (positive levels)
              Object.entries(deps).forEach(([n, d]) => {
                if (nodes.get(n)) return;
                const c    = depColor(d);
                const size = d === 1 ? 20 : 14;
                const path = getPath(n, depsPrev);
                const pathStr = path.length > 1
                  ? path.map(shortLabel).join(' \u2192 ')
                  : `${shortLabel(name)} directly uses ${shortLabel(n)}`;
                nodes.add({
                  id: n, label: nodeLabel(n, d),
                  title: `${n}\nDependency (level ${d})\n${pathStr}${services[n]?.description ? '\n\n' + services[n].description : ''}`,
                  shape: 'box', size,
                  level: d,
                  color: { background: c.bg, border: c.border,
                           highlight: { background: c.border, border: '#fff' } },
                  font:  { color: c.font, size: 12, face: 'SF Mono, Fira Code, monospace' },
                  borderWidth: d === 1 ? 2 : 1,
                });
                const parent = depsPrev[n] || name;
                edges.add({
                  from: parent, to: n, arrows: 'to',
                  color: { color: c.border, opacity: Math.max(0.3, 1 - (d - 1) * 0.2) },
                  width: Math.max(0.5, 2 - d * 0.3),
                  dashes: d > 1,
                  title: `${parent} \u2192 ${n} (level ${d})`,
                });
              });

              const container = document.getElementById('vis-graph');
              if (network) { network.destroy(); network = null; }

              const totalNodes = nodes.length;
              const levelSep = totalNodes > 40 ? 120 : totalNodes > 20 ? 150 : 180;
              const nodeSep  = totalNodes > 40 ? 100 : totalNodes > 20 ? 130 : 160;

              network = new vis.Network(container, { nodes, edges }, {
                layout: {
                  hierarchical: {
                    enabled: true,
                    direction: 'DU',
                    sortMethod: 'directed',
                    levelSeparation: levelSep,
                    nodeSpacing: nodeSep,
                    treeSpacing: 200,
                    blockShifting: true,
                    edgeMinimization: true,
                    parentCentralization: true,
                  },
                },
                physics: {
                  enabled: true,
                  hierarchicalRepulsion: {
                    centralGravity: 0.0,
                    springLength: 120,
                    springConstant: 0.01,
                    nodeDistance: nodeSep + 20,
                    damping: 0.09,
                    avoidOverlap: 0.8,
                  },
                  stabilization: { iterations: 150, fit: true },
                },
                interaction: { hover: true, tooltipDelay: 150, zoomView: true },
                edges: {
                  smooth: { type: 'cubicBezier', forceDirection: 'vertical', roundness: 0.4 },
                  selectionWidth: 2,
                },
                nodes: { shadow: { enabled: true, size: 6, color: shadowColor } },
              });

              network.on('click', p => {
                if (p.nodes.length && p.nodes[0] !== selected) selectService(p.nodes[0]);
              });

              network.once('stabilizationIterationsDone', () => {
                network.fit({ animation: { duration: 300, easingFunction: 'easeInOutQuad' } });
              });
            }

            // ── Tabs ───────────────────────────────────────────────────────────────────
            function renderAffectedTab(affectedDist, affectedPrev, rootName) {
              const grouped = groupByDepth(affectedDist);
              const total   = Object.keys(affectedDist).length;
              document.getElementById('tc-affected').textContent = total;
              const el = document.getElementById('tb-affected');
              if (!total) {
                el.innerHTML = '<div class="desc-info">No service depends on this one.</div>';
                return;
              }
              el.innerHTML = Object.entries(grouped).map(([d, names]) => {
                const cls = DEPTH_LABEL_CLASS.users[Math.min(+d - 1, 3)];
                const dot = USER_COLORS[Math.min(+d - 1, 3)].dot;
                return `
                  <div class="depth-group">
                    <div class="depth-label ${cls}">Level ${d} <span style="opacity:.6">(${names.length})</span></div>
                    ${names.map(n => depItemHtml(n, dot, getPath(n, affectedPrev), rootName, 'affected')).join('')}
                  </div>`;
              }).join('');
              el.querySelectorAll('.dep-item').forEach(i =>
                i.addEventListener('click', () => selectService(i.dataset.n))
              );
            }

            function renderDepsTab(depsDist, depsPrev, rootName) {
              const grouped = groupByDepth(depsDist);
              const total   = Object.keys(depsDist).length;
              document.getElementById('tc-deps').textContent = total;
              const el = document.getElementById('tb-deps');
              if (!total) {
                el.innerHTML = '<div class="desc-info">This service has no direct dependencies.</div>';
                return;
              }
              el.innerHTML = Object.entries(grouped).map(([d, names]) => {
                const cls = DEPTH_LABEL_CLASS.deps[Math.min(+d - 1, 3)];
                const dot = DEP_COLORS[Math.min(+d - 1, 3)].dot;
                return `
                  <div class="depth-group">
                    <div class="depth-label ${cls}">Level ${d} <span style="opacity:.6">(${names.length})</span></div>
                    ${names.map(n => depItemHtml(n, dot, getPath(n, depsPrev), rootName, 'deps')).join('')}
                  </div>`;
              }).join('');
              el.querySelectorAll('.dep-item').forEach(i =>
                i.addEventListener('click', () => selectService(i.dataset.n))
              );
            }

            function renderInfoTab(svc) {
              const desc = svc.description || (svc.parent ? `Inherits from ${svc.parent}` : '');
              document.getElementById('tb-info').innerHTML = `
                <div class="desc-info">
                  ${desc ? esc(desc) : '<span style="color:var(--text-dim)">No description documented.</span>'}
                  ${svc.parent ? `<br><br><span style="color:var(--text-muted)">Inherits from: <code style="color:#93c5fd">${esc(svc.parent)}</code></span>` : ''}
                </div>`;
            }

            // ── Helpers ────────────────────────────────────────────────────────────────
            function groupByDepth(distMap) {
              const g = {};
              Object.entries(distMap)
                .sort((a, b) => a[1] - b[1] || a[0].localeCompare(b[0]))
                .forEach(([n, d]) => { (g[d] = g[d] || []).push(n); });
              return g;
            }

            function depItemHtml(name, dotColor, path, rootName, type) {
              let pathHtml = '';
              if (path.length <= 2) {
                const label = type === 'affected'
                  ? `directly uses <b>${shortLabel(rootName)}</b>`
                  : `directly used by <b>${shortLabel(rootName)}</b>`;
                pathHtml = `<div class="path-trace direct">${label}</div>`;
              } else {
                const hops = path.slice(1, -1).map(n => `<span class="hop">${esc(shortLabel(n))}</span>`);
                pathHtml = `<div class="path-trace">via <span class="arrow">\u2192</span> ${hops.join(' <span class="arrow">\u2192</span> ')}</div>`;
              }
              const desc = services[name]?.description;
              return `
                <div class="dep-item" data-n="${esc(name)}" title="${esc(name)}">
                  <div class="dot" style="background:${dotColor};margin-top:3px;align-self:flex-start"></div>
                  <div style="overflow:hidden;min-width:0">
                    <span class="nm">${esc(name)}</span>
                    ${pathHtml}
                    ${desc ? `<div class="dep-desc">${esc(desc)}</div>` : ''}
                  </div>
                </div>`;
            }

            function shortLabel(name) {
              const parts = name.split('::');
              if (parts.length <= 2) return name;
              return parts.slice(-2).join('::');
            }

            function nodeLabel(name) {
              const parts = name.split('::');
              if (parts.length === 1) return name;
              const ns    = parts.slice(0, -1).join('::');
              const klass = parts[parts.length - 1];
              return ns + '\n' + klass;
            }

            function esc(s) {
              return String(s)
                .replace(/&/g,'&amp;').replace(/</g,'&lt;')
                .replace(/>/g,'&gt;').replace(/"/g,'&quot;');
            }

            // ── Detail overlay ─────────────────────────────────────────────────────────
            let detailVisible = false;

            function showDetailOverlay(name) {
              const overlay = document.getElementById('detail-overlay');
              const toggleBtn = document.getElementById('btn-toggle-detail');
              document.getElementById('detail-overlay-title').textContent = shortLabel(name);
              overlay.classList.add('visible');
              toggleBtn.classList.add('visible');
              toggleBtn.classList.add('shifted');
              detailVisible = true;
            }

            function hideDetailOverlay() {
              document.getElementById('detail-overlay').classList.remove('visible');
              document.getElementById('btn-toggle-detail').classList.remove('shifted');
              detailVisible = false;
            }

            function toggleDetailOverlay() {
              if (detailVisible) {
                hideDetailOverlay();
              } else if (selected) {
                showDetailOverlay(shortLabel(selected));
              }
            }

            // ── Theme ──────────────────────────────────────────────────────────────────
            function getStoredTheme() {
              try { return localStorage.getItem('kaskd-lens-theme'); } catch(e) { return null; }
            }

            function setTheme(theme) {
              document.documentElement.setAttribute('data-theme', theme);
              try { localStorage.setItem('kaskd-lens-theme', theme); } catch(e) {}
              const moonIcon = document.getElementById('icon-moon');
              const sunIcon  = document.getElementById('icon-sun');
              if (theme === 'light') {
                moonIcon.classList.add('dim');
                sunIcon.classList.remove('dim');
              } else {
                moonIcon.classList.remove('dim');
                sunIcon.classList.add('dim');
              }
              if (selected && services[selected]) {
                const { dist: affectedDist, prev: affectedPrev } = getAffected(selected, maxDepth);
                const { dist: depsDist,     prev: depsPrev }     = getDeps(selected, maxDepth);
                renderGraph(selected, affectedDist, depsDist, affectedPrev, depsPrev);
              }
            }

            function toggleTheme() {
              const current = document.documentElement.getAttribute('data-theme') || 'dark';
              setTheme(current === 'dark' ? 'light' : 'dark');
            }

            // Initialize theme
            (function initTheme() {
              var stored = getStoredTheme();
              setTheme(stored || 'dark');
            })();

            // ── Copy diagram ───────────────────────────────────────────────────────────
            function showToast(msg, duration) {
              const toast = document.getElementById('toast');
              toast.textContent = msg;
              toast.classList.add('show');
              setTimeout(() => toast.classList.remove('show'), duration || 2500);
            }

            function copyDiagram() {
              if (!network) return;
              const btn = document.getElementById('btn-copy-diagram');

              const srcCanvas = document.querySelector('#vis-graph canvas');
              if (!srcCanvas) {
                showToast('No diagram to copy');
                return;
              }

              const isLight = document.documentElement.getAttribute('data-theme') === 'light';
              const bgColor = isLight ? '#f6f8fa' : '#0d1117';

              const outCanvas = document.createElement('canvas');
              outCanvas.width  = srcCanvas.width;
              outCanvas.height = srcCanvas.height;
              const ctx = outCanvas.getContext('2d');

              ctx.fillStyle = bgColor;
              ctx.fillRect(0, 0, outCanvas.width, outCanvas.height);
              ctx.drawImage(srcCanvas, 0, 0);

              outCanvas.toBlob(function(blob) {
                if (!blob) {
                  showToast('Failed to capture diagram');
                  return;
                }

                if (navigator.clipboard && typeof ClipboardItem !== 'undefined') {
                  navigator.clipboard.write([
                    new ClipboardItem({ 'image/png': blob })
                  ]).then(function() {
                    btn.classList.add('copied');
                    btn.innerHTML = '<span class="copy-icon">&#10003;</span> Copied!';
                    showToast('Diagram copied to clipboard');
                    setTimeout(function() {
                      btn.classList.remove('copied');
                      btn.innerHTML = '<span class="copy-icon">&#128203;</span> Copy diagram';
                    }, 2000);
                  }).catch(function() {
                    fallbackDownload(blob);
                  });
                } else {
                  fallbackDownload(blob);
                }
              }, 'image/png');
            }

            function fallbackDownload(blob) {
              const url = URL.createObjectURL(blob);
              const a = document.createElement('a');
              a.href = url;
              a.download = 'service-graph-' + (selected || 'diagram') + '.png';
              document.body.appendChild(a);
              a.click();
              document.body.removeChild(a);
              URL.revokeObjectURL(url);
              showToast('Diagram downloaded as PNG (clipboard unavailable)');
            }

            // ── Export JSON report ──────────────────────────────────────────────────────
            function exportJSON() {
              if (!selected || !services[selected]) return;

              const svc = services[selected];
              const { dist: affectedDist, prev: affectedPrev } = getAffected(selected, maxDepth);
              const { dist: depsDist,     prev: depsPrev }     = getDeps(selected, maxDepth);

              const report = {
                generated_at: new Date().toISOString(),
                service: {
                  class_name: svc.class_name,
                  file: svc.file || null,
                  pack: svc.pack || null,
                  description: svc.description || null,
                  parent: svc.parent || null,
                  direct_dependencies: svc.dependencies || [],
                },
                analysis: {
                  max_depth: maxDepth,
                  pack_filter: activePack || null,
                },
                affected: Object.entries(affectedDist)
                  .sort((a, b) => a[1] - b[1] || a[0].localeCompare(b[0]))
                  .map(([name, depth]) => ({
                    class_name: name,
                    depth: depth,
                    path: getPath(name, affectedPrev),
                    file: services[name]?.file || null,
                    pack: services[name]?.pack || null,
                  })),
                dependencies: Object.entries(depsDist)
                  .sort((a, b) => a[1] - b[1] || a[0].localeCompare(b[0]))
                  .map(([name, depth]) => ({
                    class_name: name,
                    depth: depth,
                    path: getPath(name, depsPrev),
                    file: services[name]?.file || null,
                    pack: services[name]?.pack || null,
                  })),
                summary: {
                  total_affected: Object.keys(affectedDist).length,
                  total_dependencies: Object.keys(depsDist).length,
                },
              };

              const json = JSON.stringify(report, null, 2);
              const blob = new Blob([json], { type: 'application/json' });
              const url = URL.createObjectURL(blob);
              const a = document.createElement('a');
              a.href = url;
              a.download = selected.replace(/::/g, '-').toLowerCase() + '-report.json';
              document.body.appendChild(a);
              a.click();
              document.body.removeChild(a);
              URL.revokeObjectURL(url);
              showToast('Report downloaded');
            }

            // ── Events ─────────────────────────────────────────────────────────────────
            document.getElementById('pack-select').addEventListener('change', e => {
              activePack = e.target.value;
              renderList(document.getElementById('search').value);
              if (selected) selectService(selected);
            });

            document.getElementById('search').addEventListener('input', e => renderList(e.target.value));

            document.querySelectorAll('.tab').forEach(tab => {
              tab.addEventListener('click', () => {
                document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
                document.querySelectorAll('.tab-body').forEach(b => b.classList.remove('active'));
                tab.classList.add('active');
                document.getElementById('tb-' + tab.dataset.tab).classList.add('active');
              });
            });

            document.getElementById('depth-slider').addEventListener('input', e => {
              maxDepth = +e.target.value;
              document.getElementById('depth-val').textContent = maxDepth;
              if (selected) selectService(selected);
            });

            // Theme toggle
            document.getElementById('theme-toggle').addEventListener('click', toggleTheme);

            // Detail overlay
            document.getElementById('btn-close-detail').addEventListener('click', hideDetailOverlay);
            document.getElementById('btn-toggle-detail').addEventListener('click', toggleDetailOverlay);

            // Copy diagram
            document.getElementById('btn-copy-diagram').addEventListener('click', copyDiagram);

            // Navigation
            document.getElementById('btn-back').addEventListener('click', navigateBack);
            document.getElementById('btn-forward').addEventListener('click', navigateForward);

            // Export
            document.getElementById('btn-export').addEventListener('click', exportJSON);

            // ── Init ───────────────────────────────────────────────────────────────────
            loadData();
          })();
        JS
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
