#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/rspec/rspec/lib"))
require 'spec'
exit ::Spec::Runner::CommandLine.run(rspec_options)
