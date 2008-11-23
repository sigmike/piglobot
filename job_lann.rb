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

class LANN < Piglobot::Job
  attr_accessor :pages, :category, :title, :cite_pages, :done_model, :empty_comment

  def initialize(*args)
    super
    @name = "[[WP:LANN]]"
    @category = "Wikipédia:Archives Articles non neutres"
    @title = "Wikipédia:Liste des articles non neutres/"
    @done_model = "Modèle:Archive LANN"
    @empty_comment = "[[Utilisateur:Piglobot/Travail#Blanchiment LANN|Blanchiment automatique de courtoisie]]"
    @test_page = "Utilisateur:Piglobot/Test LANN"
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
      #notice("#{@pages.size} pages à traiter")
    else
      @pages = @data[:pages]
      page = @pages.shift
      process_page page
    end
    if @pages.empty?
      @done = true
      if @data and @data[:done] and !@data[:done].empty?
        pages = @data[:done].map { |page| "[[#{page}]]" }.join(", ")
        notice("Pages blanchies : " + pages)
        @data[:done] = []
      else
        notice("Aucune page blanchie")
      end
    else
      @done = false
    end
    done_pages = []
    done_pages = (@data[:done] || []) if @data
    @data = { :pages => @pages, :done => done_pages }
  end
  
  def get_pages
    @pages = @wiki.category(@category)
    log "#{@pages.size} articles dans la catégorie"
    #notice("#{@pages.size} pages dans la [[:Catégorie:#@category]]")
  end
  
  def remove_bad_names
    @pages.delete_if { |name| name !~ /\A#{Regexp.escape @title}./ }
    log "#{pages.size} articles avec un nom valide"
    #notice("#{@pages.size} pages avec un nom valide")
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
    log "#{pages.size} article(s) non cité(s)"
    
    #notice("#{@pages.size} pages non mentionnées dans [[WP:LANN]]")
  end
  
  def remove_already_done
    links = @wiki.links(@done_model)
    if links.include? @test_page
      @pages -= links
    else
      notice("Erreur : Page de test [[:#{@test_page}]] non présente dans les liens vers [[:#{@done_model}]]. Considère toutes les pages comme traitées.")
      @pages = []
    end
    log "#{pages.size} articles non traités"
    #notice("#{@pages.size} pages ne contenant pas le [[#{@done_model}]]")
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
        @changed = false
      else
        done = []
        done = @data[:done] if @data and @data[:done]
        if empty_page(page)
          done << page
        end
        if empty_talk_page(page)
          done << "Discussion #{page}"
        end
        @data ||= {}
        @data[:done] = done
        @changed = true
      end
    rescue => e
      log("Erreur pour [[#{page}]] : #{e.message}\n#{e.backtrace.join("\n")}")
      notice("[[#{page}]] non blanchie car une erreur s'est produite : #{e.message}")
      @changed = true
    end
  end
  
  def empty_page(page)
    log("Blanchiment de [[#{page}]]")
    history = @wiki.history(page, 1)
    oldid = history.first[:oldid]
    article = page.sub(%r{\A.+?/}, "")
    content = "{{subst:Blanchiment LANN | article = [[:#{article}]] | oldid = #{oldid} }}"
    comment = "[[Utilisateur:Piglobot/Travail#Blanchiment LANN|Blanchiment automatique de courtoisie]]"
    @wiki.post(page, content, comment)
    true
  end

  def empty_talk_page(page)
    talk_page = "Discussion " + page
    history = @wiki.history(talk_page, 1)
    if history.empty?
      log("Blanchiment inutile de [[#{talk_page}]]")
      false
    else
      log("Blanchiment de [[#{talk_page}]]")
      oldid = history.first[:oldid]
      content = "{{Blanchiment de courtoisie}}"
      comment = @empty_comment
      @wiki.post(talk_page, content, comment)
      true
    end
  end
end

class AaC < LANN
  def initialize(*args)
    super
    @name = "[[WP:AàC]]"
    @category = "Archives Appel à commentaires"
    @title = "Wikipédia:Appel à commentaires/"
    @done_model = "Modèle:Blanchiment de courtoisie"
    @empty_comment = "[[Utilisateur:Piglobot/Travail#Blanchiment AàC|Blanchiment automatique de courtoisie]]"
    @test_page = "Utilisateur:Piglobot/Test AàC"
  end

  def remove_cited
    parser = Piglobot::Parser.new
    
    content = @wiki.get("Wikipédia:Appel à commentaires/Article")
    links = parser.internal_links(content)
    
    content = @wiki.get("Wikipédia:Appel à commentaires/Utilisateur")
    links += parser.internal_links(content)
    
    old_pages = @pages
    @pages -= links
    log "#{pages.size} articles non cités"
    #notice("#{@pages.size} pages non mentionnées dans les pages de maintenance")
  end
  
  def empty_page(page)
    log("Blanchiment de [[#{page}]]")
    content = "{{subst:Blanchiment Appel à Commentaire}}"
    comment = "[[Utilisateur:Piglobot/Travail#Blanchiment AàC|Blanchiment automatique de courtoisie]]"
    @wiki.post(page, content, comment)
    true
  end

end
