
class LANN < Piglobot::Job
  attr_accessor :pages

  def process
    get_pages
    remove_bad_names
    remove_cited
    remove_already_done
    remove_active
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
    links = parse_internal_links(lann)
    links.map! do |link|
      if link =~ %r{\A/}
        "Wikipédia:Liste des articles non neutres" + link
      else
        nil
      end
    end
    @pages -= links
  end
  
  def process_remaining
    @pages.each do |page|
      process_page page
    end
  end
end
