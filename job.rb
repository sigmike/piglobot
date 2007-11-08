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

class Piglobot
  class Job
    attr_accessor :data, :name
    
    def initialize(bot)
      @bot = bot
      @wiki = bot.wiki
      @changed = false
      @data = nil
      @name = self.class.name
    end
    
    def data_id
      self.class.name
    end
    
    def changed?
      @changed
    end
    
    def process
      raise "No process defined in this job"
    end
    
    def done?
      true
    end
    
    def notice(text)
      @bot.notice("#@name : #{text}")
    end
  end
  
  class HomonymPrevention < Job
    def data_id
      "Homonymes"
    end
  
    def done?
      false
    end
    
    def process
      changes = false
      data = @data
      data ||= {}
      china = data["Chine"] || {}
      china = {} if china.is_a?(Array)
      last = china["Last"] || {}
      new = china["New"] || []
      
      if last.empty?
        last = @wiki.links("Chine")
        Piglobot::Tools.log("#{last.size} liens vers la page d'homonymie [[Chine]]")
      else
        current = @wiki.links("Chine")
        
        new.delete_if do |old_new|
          if current.include? old_new
            false
          else
            Piglobot::Tools.log("Le lien vers [[Chine]] dans [[#{old_new}]] a été supprimé avant d'être traité")
            true
          end
        end
        
        current_new = current - last
        last = current
        current_new.each do |new_name|
          Piglobot::Tools.log("Un lien vers [[Chine]] a été ajouté dans [[#{new_name}]]")
        end
        new += current_new
      end
      china["Last"] = last
      china["New"] = new if new
      data["Chine"] = china
      @changed = changes
      @data = data
    end
  end
  
  class InfoboxRewriter < Job
    attr_accessor :links, :infobox
  
    def done?
      false
    end
    
    def data_id
      @infobox
    end
  
    def initialize(bot, infobox, links)
      super(bot)
      @infobox = infobox
      @links = links
      @editor = Piglobot::Editor.new(bot)
    end
    
    def process
      @editor.setup(@infobox)
      data = @data
      changes = false
      infobox = @infobox
      links = @links
      
      articles = data
  
      if articles and !articles.empty?
        article = articles.shift
        if article =~ /:/
          comment = "Article ignoré car il n'est pas dans le bon espace de nom"
          text = "[[#{article}]] : #{comment}"
          Piglobot::Tools.log(text)
        else
          text = @wiki.get(article)
          begin
            @editor.current_article = article
            box = @editor.parse_infobox(text)
            if box
              result = @editor.write_infobox(box)
              if result != text
                comment = "[[Utilisateur:Piglobot/Travail##{infobox}|Correction automatique]] de l'[[Modèle:#{infobox}|#{infobox}]]"
                @wiki.post(article,
                  result,
                  comment)
                changes = true
              else
                text = "[[#{article}]] : Aucun changement nécessaire dans l'#{infobox}"
                Piglobot::Tools.log(text)
              end
            else
              @bot.notice("#{infobox} non trouvée dans l'article", article)
              changes = true
            end
          rescue => e
            @bot.notice(e.message, article)
            changes = true
          end
        end
      else
        articles = []
        links.each do |link|
          articles += @wiki.links(link)
        end
        articles.uniq!
        articles.delete_if { |name| name =~ /:/ and name !~ /::/ }
        data = articles
        @bot.notice("#{articles.size} articles à traiter pour #{infobox}")
        changes = true
      end
      @changed = changes
      @data = data
    end
  end
  
  class InfoboxSoftware < InfoboxRewriter
    def initialize(bot)
      super(bot, "Infobox Logiciel", ["Modèle:Infobox Logiciel"])
    end
  end
  
  class InfoboxProtectedArea < InfoboxRewriter
    def initialize(bot)
      super(bot,
        "Infobox Aire protégée",
        ["Modèle:Infobox Aire protégée", "Modèle:Infobox aire protégée"]
      )
    end
  end
end
