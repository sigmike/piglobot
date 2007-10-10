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
    along with Foobar.  If not, see <http://www.gnu.org/licenses/>.
=end

class Piglobot
  class Wiki
    def initialize(wiki)
      @wiki = wiki
    end
    
    def post(article, text, comment)
      article = @wiki.article(article)
      article.text = text
      article.submit(comment)
    end
  
    def get(article)
      article = @wiki.article(article)
      article.text
    end
  end
  
  def initialize(wiki)
    @wiki = Wiki.new(wiki)
  end
  
  def publish(name, text, comment, lang = "ruby")
    text = "<source lang=\"#{lang}\">\n#{text}</source" + ">"
    article = @wiki.post("Utilisateur:Piglobot/#{name}", text, comment)
  end
  
  def publish_spec(comment)
    publish("Spec", File.read("piglobot_spec.rb"), comment)
  end

  def publish_code(comment)
    publish("Code", File.read("piglobot.rb"), comment)
  end
  
  attr_accessor :data
  def load_data
    text = @wiki.get("Utilisateur:Piglobot/Data")
    @data = YAML.load(text.scan(/<source lang="text">(.*)<\/source>/m).first.first)
  end

  def save_data
    publish("Data", @data.to_yaml, "Sauvegarde", "text")
  end
end

if __FILE__ == $0
  require 'libs'
  require 'mediawiki/dotfile'

  ENV["MEDIAWIKI_RC"]="mediawikirc"
  wiki = MediaWiki.dotfile
  bot = Piglobot.new(wiki)
  bot.data = { "test" => "plop" }
  bot.save_data
end
