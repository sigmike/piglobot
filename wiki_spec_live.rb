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

require 'piglobot'

describe Piglobot::Wiki, " live" do
  before :all do
    @wiki = Piglobot::Wiki.new
  end
  
  it "should find Ruby in 'Langage de programmation'" do
    @wiki.category("Langage de programmation").sort.should include("Ruby")
  end
  
  it "should retreive history on Accueil" do
    result = @wiki.history("Bot informatique", 2, "47594710")
    result.should == [
      { :oldid => "47594710", :author => "Freewol", :date => Time.at(1260435071) },
      { :oldid => "47587549", :author => "3eX", :date => Time.at(1260398472) },
    ]
  end
  
  it "should find Ruby in links to Infobox Langage de programmation" do
    @wiki.links("Modèle:Infobox Langage de programmation").sort.should include("Ruby")
  end
  
  it "should find Linux in Modèle:Portail informatique" do
    @wiki.links("Modèle:Portail informatique").sort.should include("Noyau de système d'exploitation")
  end
  
  it "should get test page" do
    @wiki.get("Utilisateur:Piglobot/Page de test").should == "page de test\n\nbla bla"
  end
  
  it "should post" do
    @wiki.post("Utilisateur:Piglobot/Bac à sable", "foo bar\n", "test 1")
    @wiki.get("Utilisateur:Piglobot/Bac à sable").should == "foo bar"
    @wiki.post("Utilisateur:Piglobot/Bac à sable", "", "test 2")
    @wiki.get("Utilisateur:Piglobot/Bac à sable").should == ""
  end
  
  it "should have at least 2 pages in admin list" do
    list, next_id = @wiki.mediawiki.list_users("sysop")
    next_id.should_not be_nil
  end

  it "should have at least 2 pages in LANN category" do
    list, next_id = @wiki.mediawiki.category_slice("Wikipédia:Archives Articles non neutres")
    next_id.should_not be_nil
  end
  
  it "should get some contributions for Piglobot" do
    list = @wiki.contributions("Piglobot", 10)
    list.size.should == 10
  end
end
