class Piglobot
  class Job
    attr_accessor :data
    
    def initialize(bot)
      @bot = bot
      @wiki = bot.wiki
      @changed = false
      @data = nil
    end
    
    def data_id
      self.class.name
    end
    
    def changed?
      @changed
    end
  end
  
  class HomonymPrevention < Job
    def data_id
      "Homonymes"
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
