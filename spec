#!/usr/bin/env ruby

ARGV.replace %w(
  piglobot_spec.rb
  dump_spec.rb
  editor_spec.rb
  tools_spec.rb
  wiki_spec.rb
  job_spec.rb
) if ARGV.empty?
ARGV << "--diff"

$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/rspec/rspec/lib"))
require 'spec'

exit ::Spec::Runner::CommandLine.run(rspec_options)
