
require 'libs'

require 'mediawiki/dotfile'

ENV["MEDIAWIKI_RC"]="mediawikirc"
wiki = MediaWiki.dotfile

$VERBOSE = true

#p wiki.article("Modèle:Infobox Logiciel").fast_what_links_here(10000)
fast = wiki.article("Modèle:Infobox Logiciel").fast_what_links_here(1000)
p fast
if false
  base = wiki.article("Modèle:Infobox Logiciel").what_links_here(1000)
  p base
  p(base - fast)
  p(fast - base)
end
