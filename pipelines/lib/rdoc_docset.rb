#!/usr/bin/env ruby
# frozen_string_literal: true

# Shared docset engine for RDoc-based documentation (Ruby, Rails, any gem).
#
# Runs RDoc's darkfish HTML generator over a source tree, then walks the
# parsed store to emit DocDash's common docset format:
#
#   <out>/docset.json   manifest
#   <out>/index.json    {"entries": [["Array#map", "m", "Array.html#method-i-map"], ...]}
#   <out>/content/      darkfish HTML tree
#
# Kind codes: c class, o module, m instance method, M class method,
#             n constant, a attribute, f page/guide.
#
# Usage (run from the documentation source root):
#   ruby rdoc_docset.rb --type TYPE --name NAME --version V --id ID \
#        --out DIR [--source-url URL] [--main PAGE] [--title T] -- [rdoc files/args...]

require "rdoc"
require "rdoc/rdoc"
require "json"
require "fileutils"
require "optparse"
require "time"

options = {
  type: nil, name: nil, version: nil, id: nil, out: nil,
  source_url: nil, main: nil, title: nil
}

parser = OptionParser.new do |opts|
  opts.on("--type TYPE") { |v| options[:type] = v }
  opts.on("--name NAME") { |v| options[:name] = v }
  opts.on("--version VERSION") { |v| options[:version] = v }
  opts.on("--id ID") { |v| options[:id] = v }
  opts.on("--out DIR") { |v| options[:out] = v }
  opts.on("--source-url URL") { |v| options[:source_url] = v }
  opts.on("--main PAGE") { |v| options[:main] = v }
  opts.on("--title TITLE") { |v| options[:title] = v }
end
rdoc_args = parser.parse(ARGV)

%i[type name version id out].each do |key|
  abort "rdoc_docset.rb: missing --#{key}" unless options[key]
end

out_dir = File.expand_path(options[:out])
content_dir = File.join(out_dir, "content")
FileUtils.rm_rf(out_dir)
FileUtils.mkdir_p(out_dir)

title = options[:title] || "#{options[:name]} #{options[:version]}"

argv = ["--format=darkfish", "--op=#{content_dir}", "--title=#{title}", "--quiet"]
argv << "--main=#{options[:main]}" if options[:main]
argv.concat(rdoc_args)

puts "[rdoc_docset] generating HTML: rdoc #{argv.join(' ')}"
rdoc = RDoc::RDoc.new
rdoc.document(argv)

store = rdoc.store
entries = []

# Pages (READMEs, guides).
store.all_files.each do |file|
  next unless file.text?
  entries << [file.page_name, "f", file.path]
end

store.all_classes_and_modules.each do |cm|
  next unless cm.display?
  entries << [cm.full_name, cm.module? ? "o" : "c", cm.path]

  cm.method_list.each do |m|
    next unless m.display?
    display = m.singleton ? "#{cm.full_name}::#{m.name}" : "#{cm.full_name}##{m.name}"
    entries << [display, m.singleton ? "M" : "m", m.path]
  end

  cm.constants.each do |const|
    path = const.respond_to?(:path) ? const.path : "#{cm.path}##{const.name}"
    entries << ["#{cm.full_name}::#{const.name}", "n", path]
  end

  cm.attributes.each do |attr|
    path = attr.respond_to?(:path) ? attr.path : cm.path
    entries << ["#{cm.full_name}##{attr.name}", "a", path]
  end
end

entries.uniq! { |name, kind, _| [name, kind] }
entries.sort_by! { |name, _, _| name.downcase }

File.write(File.join(out_dir, "index.json"), JSON.generate({ entries: entries }))

manifest = {
  format: 1,
  type: options[:type],
  name: options[:name],
  version: options[:version],
  identifier: options[:id],
  indexPath: "index.json",
  contentRoot: "content",
  landingPage: "index.html",
  entryCount: entries.size,
  generatedAt: Time.now.utc.iso8601,
  source: options[:source_url]
}
File.write(File.join(out_dir, "docset.json"), JSON.pretty_generate(manifest))

puts "[rdoc_docset] wrote #{entries.size} entries to #{out_dir}"
