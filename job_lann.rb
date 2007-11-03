
class LANN < Piglobot::Job
  attr_accessor :pages

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
  end
  
  def remove_bad_names
    @pages.delete_if { |name| name !~ /\AWikipédia:Liste des articles non neutres\// }
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
  end
  
  def remove_already_done
    links = @wiki.links("Modèle:Archive LANN")
    @pages -= links
  end
  
  def remove_active
    now = Time.now
    limit = now - 7 * 24 * 3600
    @pages.delete_if do |page|
      history = @wiki.history(page, 1)
      if history.empty?
        true
      else
        date = history.first[:date]
        date < limit
      end
    end
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
        date < limit
      end
    end
  end
  
  def process_remaining
    @pages.each do |page|
      process_page page
    end
  end
  
  def process_page(page)
    puts "process #{page.inspect}"
  end
end
