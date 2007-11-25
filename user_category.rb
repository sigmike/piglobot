require 'job'

class UserCategory < Piglobot::Job
  def initialize(*args)
    super
    @name = "[[Utilisateur:Piglobot/Utilisateurs catégorisés dans main|Utilisateurs catégorisés dans main]]"
  end
  
  def process
    20.times do
      step_and_sleep
    end
  end
  
  def step_and_sleep
    step
    sleep 2
  end
  
  def step
    @done = false
    @data ||= {}
    categories = @data[:categories]
    if categories.nil?
      @data[:categories] = @wiki.all_pages("14").select { |page|
        valid_category?(page)
      }
      @data[:empty] = []
      @data[:one] = []
      
      @changed = true
    else
      category = nil
      loop do
        category = categories.shift
        break if category.nil? or category !~ /^Utilisateur/
      end
      @changed = false
      process_category(category)
      if categories.empty?
        [
          [@data[:empty], "Catégories vides"],
          [@data[:one], "Catégories avec une seule page"],
        ].each do |pages, title|
          @wiki.post("Utilisateur:Piglobot/#{title}", pages.map { |page| "* [[:#{page}]]\n" }.join, "Mise à jour")
        end
        @done = true
        @data = nil
      elsif categories.size % 1000 == 0
        notice("#{categories.size} catégories à traiter (dernière : [[:#{category}]])")
      end
    end
  end
  
  def valid_category?(name)
    name !~ /^Catégorie:Utilisateur/
  end
  
  def process_category(name)
    if valid_category?(name)
      process_valid_category(name)
    else
      log("Catégorie ignorée : #{name}")
    end
  end
  
  def process_valid_category(name)
    pages = @wiki.category(name.split(":", 2).last)
    log("#{pages.size} pages dans #{name}")
    if pages.size == 0
      @data[:empty] << name
    elsif pages.size == 1
      @data[:one] << name
    end
    pages.delete_if { |page| page !~ /^Utilisateur:/ and page !~ /^Discussion Utilisateur:/ }
    if pages.empty?
      log "Aucune page utilisateur dans #{name}"
    else
      post_user_category(name, pages)
    end
  end
  
  def post_user_category(name, pages)
    list_page = "Utilisateur:Piglobot/Utilisateurs catégorisés dans main"
    text = "== [[:#{name}]] ==\n" + pages.map { |page| "* [[:#{page}]]\n" }.join + "\n"
    comment = "#{pages.size} pages dans [[:#{name}]]"
    @wiki.append(list_page, text, comment)
    @changed = true
  end
end
