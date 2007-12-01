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

require 'job'
require 'ruby-mediawiki/lib/mediawiki/minibrowser'

class Change < Piglobot::Job
  attr_accessor :raw_data, :currencies

  def initialize(*args)
    super
    @name = "{{m|Change}}"
  end

  def process
    get_raw_data
    parse_raw_data
    publish_data
  end
  
  def get_raw_data
    uri = URI.parse("http://xurrency.com/")
    browser = MediaWiki::MiniBrowser.new(uri)
    @raw_data = browser.get_content("/usd/feed")
  end
  
  def parse_raw_data
    regexp = %r{<title xml:lang="en"><!\[CDATA\[1 USD = ([\d\.]+) ([A-Z]+)\]\]></title>}
    @currencies = {}
    @raw_data.scan(regexp).each do |value, name|
      @currencies[name] = value
    end
  end
  
  def publish_data
    missing = false
    names = %w( EUR GBP JPY CAD CHF )
    hash = {}
    names.each do |name|
      value = @currencies[name]
      if value
        hash[name] = value
      else
        notice("[[Modèle:Change/#{name}]] : Aucune donnée")
        missing = true
      end
    end
    if missing
      notice("Mise à jour annulée car il manque des données")
    else
      comment = "[[Utilisateur:Piglobot/Travail#Change|Mise à jour automatique]]"
      hash.each do |name, value|
        @wiki.post("Modèle:Change/#{name}", value, comment)
      end
      now = Time.now
      monthes = %w( janvier février mars avril mai juin juillet août septembre octobre novembre décembre )
      now = "#{now.day} #{monthes[now.month - 1]} #{now.year}"
      @wiki.post("Modèle:Change/Màj", now, comment)
    end

  end
end
