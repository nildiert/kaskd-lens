# frozen_string_literal: true

require_relative "lens/version"
require_relative "lens/html_report"

module Kaskd
  module Lens
    class << self
      # Generate a standalone HTML file with the interactive service graph.
      #
      # @param root     [String, nil] project root (defaults to Dir.pwd)
      # @param output   [String, nil] output file path (defaults to "kaskd-report.html")
      # @return [String] the path to the generated HTML file
      def generate_html(root: nil, output: nil)
        root   ||= Dir.pwd
        output ||= File.join(root, "kaskd-report.html")

        result = Kaskd.analyze(root: root)
        html   = HtmlReport.new(result).render

        File.write(output, html)
        output
      end

      # Generate and immediately open the HTML report in the default browser.
      #
      # @param root   [String, nil] project root
      # @param output [String, nil] output file path
      # @return [String] the path to the generated HTML file
      def open_viewer(root: nil, output: nil)
        path = generate_html(root: root, output: output)
        open_in_browser("file://#{File.expand_path(path)}")
        path
      end

      # Start a lightweight HTTP server and open the report in the browser.
      #
      # @param root [String, nil] project root
      # @param port [Integer]     port to bind (default: 4567)
      def serve(root: nil, port: 4567)
        require "webrick"

        root ||= Dir.pwd
        result = Kaskd.analyze(root: root)
        html   = HtmlReport.new(result).render

        server = WEBrick::HTTPServer.new(Port: port, Logger: WEBrick::Log.new("/dev/null"), AccessLog: [])
        server.mount_proc "/" do |_req, res|
          res["Content-Type"] = "text/html; charset=utf-8"
          res.body = html
        end

        url = "http://localhost:#{port}"
        puts "Kaskd Lens serving at #{url}"
        open_in_browser(url)

        trap("INT") { server.shutdown }
        server.start
      end

      private

      def open_in_browser(url)
        cmd = case RUBY_PLATFORM
              when /darwin/i  then "open"
              when /linux/i   then "xdg-open"
              when /mingw|mswin/i then "start"
              else return
              end
        system(cmd, url)
      end
    end
  end
end
