require 'libs'
require 'piglobot'
require 'mediawiki/dotfile'

comment = ARGV[0] || ""

ENV["MEDIAWIKI_RC"]="mediawikirc"
wiki = MediaWiki.dotfile
bot = Piglobot.new(wiki)

bot.publish_spec comment
bot.publish_code comment
