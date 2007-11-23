require 'job'

class UserCategory < Piglobot::Job
  def initialize(*args)
    super
    @name = "Catégories utilisateur"
  end
  
  def process
    @done = false
    @data ||= {}
    categories = @data[:categories]
    if categories.nil?
      @data[:categories] = @wiki.all_pages("14")
      @changed = true
    else
      process_category(categories.shift)
      @changed = true
      if categories.empty?
        @done = true
        @data = nil
      end
    end
  end
end
