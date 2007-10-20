#!/usr/bin/env ruby

ARGV.replace ["piglobot_spec.rb", "--diff"] if ARGV.empty?

$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/rspec/rspec/lib"))
require 'spec'

exit ::Spec::Runner::CommandLine.run(rspec_options)
