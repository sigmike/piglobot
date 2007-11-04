
class LANN < Piglobot::Job
  attr_accessor :pages

  def log(text)
    Piglobot::Tools.log(text)
  end

  def process
    get_pages
    remove_bad_names
    remove_cited
    remove_already_done
    remove_active
    remove_active_talk
    process_remaining
  end
  
  def get_pages
    @pages = @wiki.category("Wikipédia:Archives Articles non neutres")
    log "#{pages.size} articles dans la catégorie"
  end
  
  def remove_bad_names
    @pages.delete_if { |name| name !~ /\AWikipédia:Liste des articles non neutres\// }
    log "#{pages.size} articles avec un nom valide"
  end
  
  def remove_cited
    lann = @wiki.get("WP:LANN")
    parser = Piglobot::Parser.new
    links = parser.internal_links(lann)
    links.map! do |link|
      if link =~ %r{\A/}
        "Wikipédia:Liste des articles non neutres" + link
      else
        nil
      end
    end
    @pages -= links
    log "#{pages.size} articles non cités"
  end
  
  def remove_already_done
    links = @wiki.links("Modèle:Archive LANN")
    @pages -= links
    log "#{pages.size} articles non traités"
  end
  
  def remove_active
    now = Time.now
    limit = now - 7 * 24 * 3600
    @pages.delete_if do |page|
      history = @wiki.history(page, 1)
      if history.empty?
        log "[[#{page}]] ignoré car sans historique"
        true
      else
        date = history.first[:date]
        if date < limit
          log "[[#{page}]] ignoré car actif"
          true
        else
          false
        end
      end
    end
    log "#{pages.size} articles inactifs"
  end
  
  def remove_active_talk
    now = Time.now
    limit = now - 7 * 24 * 3600
    @pages.delete_if do |page|
      history = @wiki.history("Discussion " + page, 1)
      if history.empty?
        false
      else
        date = history.first[:date]
        if date < limit
          log "[[#{page}]] ignoré car discussion active"
          true
        else
          false
        end
      end
    end
    log "#{pages.size} articles avec discussion inactive"
  end
  
  def process_remaining
    log "Traitement de #{@pages.size} pages"
    @pages.each do |page|
      process_page page
    end
  end
  
  def process_page(page)
    puts "process #{page.inspect}"
  end
end
