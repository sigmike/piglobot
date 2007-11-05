
class LANN < Piglobot::Job
  attr_accessor :pages

  def log(text)
    Piglobot::Tools.log(text)
  end
  
  def done?
    @done
  end

  def process
    if @data.nil? or @data[:pages].empty?
      get_pages
      remove_bad_names
      remove_cited
      remove_already_done
      @bot.notice("[[WP:LANN]] : #{@pages.size} pages à traiter")
    else
      @pages = @data[:pages]
      page = @pages.shift
      process_page page
    end
    @done = (@pages.empty?)
    @data = { :pages => @pages }
  end
  
  def get_pages
    @pages = @wiki.category("Wikipédia:Archives Articles non neutres")
    log "#{@pages.size} articles dans la catégorie"
    @bot.notice("[[WP:LANN]] : #{@pages.size} pages dans la [[:Catégorie:Wikipédia:Archives Articles non neutres]]")
  end
  
  def remove_bad_names
    @pages.delete_if { |name| name !~ /\AWikipédia:Liste des articles non neutres\// }
    log "#{pages.size} articles avec un nom valide"
    @bot.notice("[[WP:LANN]] : #{@pages.size} pages avec un nom valide")
  end
  
  def remove_cited
    lann = @wiki.get("Wikipédia:Liste des articles non neutres")
    parser = Piglobot::Parser.new
    links = parser.internal_links(lann)
    links.map! do |link|
      if link =~ %r{\A/}
        "Wikipédia:Liste des articles non neutres" + link
      else
        nil
      end
    end
    old_pages = @pages
    @pages -= links
    if @pages.size == old_pages.size
      raise Piglobot::ErrorPrevention, "Aucune page de la catégorie n'est cité dans [[WP:LANN]]"
    end
    log "#{pages.size} articles non cités"
    @bot.notice("[[WP:LANN]] : #{@pages.size} pages non mentionnées dans [[WP:LANN]]")
  end
  
  def remove_already_done
    links = @wiki.links("Modèle:Archive LANN")
    @pages -= links
    log "#{pages.size} articles non traités"
    @bot.notice("[[WP:LANN]] : #{@pages.size} pages ne contenant pas le [[Modèle:Archive LANN]]")
  end
  
  def active?(page)
    now = Time.now
    limit = now - 7 * 24 * 3600
    history = @wiki.history(page, 1)
    raise "La page n'existe pas" if history.empty?
    
    date = history.first[:date]
    if date > limit
      return true
    else
      talk_history = @wiki.history("Discussion " + page, 1)
      return false if talk_history.empty?
      
      talk_date = talk_history.first[:date]
      if talk_date > limit
        return true
      else
        return false
      end
    end
  end
  
  def process_page(page)
    begin
      if active? page
        log("[[#{page}]] ignorée car active")
        @bot.notice("[[WP:LANN]] : [[#{page}]] non blanchie car active")
      else
        empty_page(page)
        empty_talk_page(page)
      end
    rescue => e
      @bot.notice("[[WP:LANN]] : [[#{page}]] non blanchie car une erreur s'est produite : #{e.message}")
      log("Erreur pour [[#{page}]] : #{e.message}\n#{e.backtrace.join("\n")}")
    end
    @changed = true
  end
  
  def empty_page(page)
    log("Blanchiment de [[#{page}]]")
    history = @wiki.history(page, 1)
    oldid = history.first[:oldid]
    article = page.sub(%r{\A.+?/}, "")
    content = "{{subst:Blanchiment LANN | article = [[:#{article}]] | oldid = #{oldid} }}"
    comment = "[[Utilisateur:Piglobot/Travail#Blanchiment LANN|Blanchiment automatique de courtoisie]]"
    @wiki.post(page, content, comment)
  end

  def empty_talk_page(page)
    talk_page = "Discussion " + page
    history = @wiki.history(talk_page, 1)
    if history.empty?
      log("Blanchiment inutile de [[#{talk_page}]]")
    else
      log("Blanchiment de [[#{talk_page}]]")
      oldid = history.first[:oldid]
      content = "{{Blanchiment de courtoisie}}"
      comment = "[[Utilisateur:Piglobot/Travail#Blanchiment LANN|Blanchiment automatique de courtoisie]]"
      @wiki.post(talk_page, content, comment)
    end
  end
end
