# frozen_string_literal: true

require_relative "lib/kaskd/lens/version"

Gem::Specification.new do |spec|
  spec.name    = "kaskd-lens"
  spec.version = Kaskd::Lens::VERSION
  spec.authors = ["nildiert"]
  spec.email   = []

  spec.summary     = "Interactive HTML viewer for kaskd service dependency graphs."
  spec.description = <<~DESC
    kaskd-lens generates a self-contained, interactive HTML page that visualizes
    the service dependency graph produced by the kaskd gem. Includes blast radius
    exploration, depth control, search, pack filtering, and dark/light themes.
    No Rails required — works standalone or via a built-in WEBrick server.
  DESC

  spec.homepage = "https://github.com/nildiert/kaskd-lens"
  spec.license  = "MIT"

  spec.metadata = {
    "homepage_uri"    => spec.homepage,
    "source_code_uri" => "https://github.com/nildiert/kaskd-lens",
    "changelog_uri"   => "https://github.com/nildiert/kaskd-lens/releases",
  }

  spec.required_ruby_version = ">= 2.7"

  spec.files = Dir["lib/**/*.rb", "vendor/**/*", "LICENSE", "README.md"]

  spec.require_paths = ["lib"]

  spec.add_dependency "kaskd", "~> 0.1"
end
