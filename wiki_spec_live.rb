require 'piglobot'

describe Piglobot::Wiki, " live" do
  before :all do
    @wiki = Piglobot::Wiki.new
  end
  
  it "should find Ruby in 'Langage de programmation'" do
    @wiki.category("Langage de programmation").should include("Ruby")
  end
end
