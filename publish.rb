#!/usr/bin/env ruby

require 'piglobot'

system "./spec" or raise "Spec failed"

comment = ARGV[0] || ""

wiki = Piglobot::Wiki.new
dump = Piglobot::Dump.new(wiki)

dump.publish_code comment
system("svn", "ci", "-m", comment) || exit(1)
