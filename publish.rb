require 'libs'
require 'piglobot'
require 'mediawiki/dotfile'

comment = ARGV[0] || ""

ENV["MEDIAWIKI_RC"]="mediawikirc"
wiki = MediaWiki.dotfile
bot = Piglobot.new(wiki)

system("svn", "ci", "-m", comment) || exit(1)
puts "publish spec"
bot.publish_spec comment
puts "publish code"
bot.publish_code comment
