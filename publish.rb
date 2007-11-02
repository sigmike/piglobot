#!/usr/bin/env ruby

require 'piglobot'

system "./spec" or raise "Spec failed"

comment = ARGV[0] || ""

bot = Piglobot.new

bot.publish_code comment
system("svn", "ci", "-m", comment) || exit(1)
