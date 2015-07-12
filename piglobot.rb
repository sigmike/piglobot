# encoding: utf-8

=begin
    Copyright (c) 2007-2012 by Piglop
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

require "rubygems"
require "bundler/setup"

require 'media_wiki'

class Piglobot < MediaWiki::Gateway
  def initialize
    super("https://fr.wikipedia.org/w/api.php", ignorewarnings: true)
    password = File.read(File.expand_path('../password', __FILE__)).strip
    login("Piglobot", password)
  end
  
  MONTHS = %w(janvier février mars avril mai juin
              juillet août septembre octobre novembre décembre)

  def format_date(time)
    day = time.day
    month = MONTHS[time.month - 1]
    year = time.year
    "{{date|#{day}|#{month}|#{year}}}"
  end
end
