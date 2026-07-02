#!/usr/bin/env ruby
# frozen_string_literal: true

# Builds catalog.json from a directory of packaged docsets. Each tarball is
# inspected for its docset.json manifest; download URLs point at the fixed
# "docsets" GitHub release.
#
# Usage: ruby pipelines/make_catalog.rb <dist-dir> <owner/repo> <release-tag>

require "json"
require "open3"

dist_dir, repo, tag = ARGV
abort "usage: make_catalog.rb <dist-dir> <owner/repo> <release-tag>" unless dist_dir && repo && tag

docsets = Dir.glob(File.join(dist_dir, "*.tar.gz")).sort.map do |tarball|
  listing, = Open3.capture2("tar", "-tzf", tarball)
  manifest_path = listing.lines.map(&:strip).find { |l| l.end_with?("/docset.json") }
  abort "no docset.json in #{tarball}" unless manifest_path
  manifest_json, = Open3.capture2("tar", "-xzOf", tarball, manifest_path)
  manifest = JSON.parse(manifest_json)
  {
    type: manifest.fetch("type"),
    name: manifest.fetch("name"),
    version: manifest.fetch("version"),
    identifier: manifest.fetch("identifier"),
    url: "https://github.com/#{repo}/releases/download/#{tag}/#{File.basename(tarball)}",
    sizeBytes: File.size(tarball)
  }
end

catalog = { format: 1, docsets: docsets }
path = File.join(dist_dir, "catalog.json")
File.write(path, JSON.pretty_generate(catalog))
puts "wrote #{path} with #{docsets.size} docsets"
