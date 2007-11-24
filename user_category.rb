require 'job'

class UserCategory < Piglobot::Job
  def initialize(*args)
    super
    @name = "[[Utilisateur:Piglobot/Utilisateurs catégorisés dans main|Utilisateurs catégorisés dans main]]"
  end
  
  def process
    10.times do
      step
    end
  end
  
  def step
    @done = false
    @data ||= {}
    categories = @data[:categories]
    if categories.nil?
      @data[:categories] = @wiki.all_pages("14")
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
        @done = true
        @data = nil
      elsif categories.size % 100 == 0
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
    pages = @wiki.category(name)
    pages.delete_if { |page| page !~ /^Utilisateur:/ and page !~ /^Discussion Utilisateur:/ }
    if pages.empty?
      log "Aucune page utilisateur dans #{name}"
    else
      post_user_category(name, pages)
    end
  end
  
  def post_user_category(name, pages)
    @wiki.append("Utilisateur:Piglobot/Utilisateurs catégorisés dans main",
      "== [[:#{name}]] ==\n" + pages.map { |page| "* [[:#{page}]]\n" }.join + "\n")
    @changed = true
  end
end
