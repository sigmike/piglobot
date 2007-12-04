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
    sleep 5
  end
  
  def step
    @done = false
    @data ||= {}
    
    if @data[:done]
      @done = true
      log("Toutes les catégories ont été traitées")
      write_data
      return
    end
    
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
        @done = true
        @data[:done] = true
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
      log "#{pages.size} pages utilisateur dans #{name}"
      add_user_category(name, pages)
    end
  end
  
  def post_user_categories(categories)
    list_page = "Utilisateur:Piglobot/Utilisateurs catégorisés dans main"
    text = ""
    categories.sort_by { |name, pages| name.downcase }.each do |name, pages|
      if pages.size > 10
        pages = pages[0..9] + ["#{name}|..."]
      end
      text << "== [[:#{name}]] ==\n" + pages.map { |page| "* [[:#{page}]]\n" }.join + "\n"
    end
    @wiki.append(list_page, text, "Mise à jour")
    @changed = true
  end
  
  def add_user_category(name, pages)
    @data[:users] ||= {}
    @data[:users][name] = pages
  end
  
  def write_data
    post_user_categories(@data[:users]) if @data[:users]
    @data[:users] = {}
  end
end
