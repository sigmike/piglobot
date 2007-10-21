require 'piglobot'

system "./spec" or raise "Spec failed"

comment = ARGV[0] || ""

wiki = Piglobot::Wiki.new
bot = Piglobot::Dump.new(wiki)

puts "publish spec"
bot.publish_spec comment
puts "publish code"
bot.publish_code comment
system("svn", "ci", "-m", comment) || exit(1)
