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

require 'libs'
require 'yaml'
require 'mediawiki'

class Piglobot
  class Wiki
    def initialize
      @wiki = MediaWiki::Wiki.new("http://fr.wikipedia.org/w", "Piglobot", File.read("password"))
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
    
    def links(name)
      article = @wiki.article(name)
      article.fast_what_links_here(1000)
    end
  end
  
  class Dump
    def initialize(wiki)
      @wiki = wiki
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
      result = text.scan(/<source lang="text">(.*)<\/source>/m)
      if result.first and result.first.first
        @data = YAML.load(result.first.first)
      else
        @data = nil
      end
    end
  
    def save_data data
      publish("Data", data.to_yaml, "Sauvegarde", "text")
    end
  end
  
  class Editor
    def initialize(wiki)
      @wiki = wiki
    end
    
    def parse_infobox(text)
      before, content, after = text.scan(/(.*)\{\{Infobox Logiciel(.*)\}\}(.*)/m).first
      parameters = []
      if content
        content.split(/\s*\|\s*/m).each do |arg|
          name, value = arg.scan(/(.+)\s*=\s*(.+)\s*/m).first
          if name
            parameters << [name.strip, value.strip]
          end
        end
      end
      return nil unless before
      {
        :before => before,
        :after => after,
        :parameters => parameters,
      }
    end
    
    def write_infobox(box)
      "{{Infobox Logiciel}}"
    end
  end
  
  def initialize
    @wiki = Wiki.new
    @dump = Dump.new(@wiki)
    @editor = Editor.new(@wiki)
  end
  
  def run
    data = @dump.load_data
    if data.nil?
      data = {}
    else
      articles = data["Infobox Logiciel"]
      if articles and !articles.empty?
        article = articles.shift
        text = @wiki.get(article)
        box = @editor.parse_infobox(text)
        if box
          result = @editor.write_infobox(box)
          @wiki.post("Utilisateur:Piglobot/Bac à sable",
            text,
            "Texte initial de l'article [[#{article}]]")
          @wiki.post("Utilisateur:Piglobot/Bac à sable",
            result,
            "Correction de la syntaxe de l'infobox")
        end
      else
        data["Infobox Logiciel"] = @wiki.links("Modèle:Infobox Logiciel")
      end
    end
    @dump.save_data(data)
  end
end

if __FILE__ == $0
  bot = Piglobot.new
  bot.run
end
