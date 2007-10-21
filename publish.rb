#!/usr/bin/env ruby

require 'piglobot'

system "./spec" or raise "Spec failed"

comment = ARGV[0] || ""

wiki = Piglobot::Wiki.new
bot = Piglobot::Dump.new(wiki)

bot.publish_spec comment
bot.publish_code comment
system("svn", "ci", "-m", comment) || exit(1)
