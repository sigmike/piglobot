=begin
    Copyright (c) 2007 by Piglop
    This file is part of Piglobot.

    Piglobot is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Piglobot is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Piglobot.  If not, see <http://www.gnu.org/licenses/>.
=end

require 'libs'

require 'mediawiki/dotfile'

ENV["MEDIAWIKI_RC"]="mediawikirc"
wiki = MediaWiki.dotfile

$VERBOSE = true

wiki.language = "fr"
#p wiki.article("Modèle:Infobox Logiciel").fast_what_links_here(10000)
fast = wiki.article("Modèle:Infobox Logiciel").fast_what_links_here(100)
p fast
if true
  base = wiki.article("Modèle:Infobox Logiciel").what_links_here(100)
  p base
  p(base - fast)
  p(fast - base)
end
