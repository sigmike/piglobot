class Piglobot
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
