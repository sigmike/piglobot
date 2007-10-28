#!/usr/bin/env ruby

ARGV.replace ["piglobot_spec.rb", "mediawiki_spec.rb"] if ARGV.empty?
ARGV << "--diff"

$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/rspec/rspec/lib"))
require 'spec'

exit ::Spec::Runner::CommandLine.run(rspec_options)
