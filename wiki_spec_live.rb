require 'piglobot'

describe Piglobot::Wiki, " live" do
  before :all do
    @wiki = Piglobot::Wiki.new
  end
  
  it "should find Ruby in 'Langage de programmation'" do
    @wiki.category("Langage de programmation").should include("Ruby")
  end
  
  it "should retreive history on Accueil" do
    @wiki.history("Accueil", 2, "20070625202235").should == [
      { :oldid => "18253715", :author => "IAlex", :date => Time.local(2007, 6, 25, 20, 7, 0) },
      { :oldid => "18253294", :author => "Tavernier", :date => Time.local(2007, 6, 25, 19, 52, 0) },
    ]
  end
  
  it "should find Ruby in links to Infobox Langage de programmation" do
    @wiki.links("Modèle:Infobox Langage de programmation").should include("Ruby")
  end
end
