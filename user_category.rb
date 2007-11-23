require 'job'

class UserCategory < Piglobot::Job
  def initialize(*args)
    super
    @name = "Catégories utilisateur"
  end
  
  def process
    @data ||= {}
    if @data[:categories].nil?
      @data[:categories] = @wiki.all_pages("14")
    end
  end
end
