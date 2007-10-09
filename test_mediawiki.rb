
$: << 'ruby-mediawiki/lib'

require 'mediawiki/dotfile'

ENV["MEDIAWIKI_RC"]="mediawikirc"
wiki = MediaWiki.dotfile

$VERBOSE = true

#p wiki.article("Modèle:Infobox Logiciel").fast_what_links_here(10000)
fast = wiki.article("Modèle:Infobox Logiciel").fast_what_links_here
base = wiki.article("Modèle:Infobox Logiciel").what_links_here
p base
p fast
p(base - fast)
