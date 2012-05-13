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
    super("http://fr.wikipedia.org/w/api.php")
    login("Piglobot", File.read(File.expand_path('../password', __FILE__)))
  end
end
