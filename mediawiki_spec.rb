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

require 'libs'
require 'piglobot'

=begin
describe REXML do
  before do
    html = File.read("edit_sandbox.html")
    rexml = REXML::Document.new( html )
    @doc = rexml.root
  end
  
  it "should find edit form" do
    form = @doc.elements["//form']"]
    form.should_not == nil
    form.attributes["name"].should == "editform"
  end
  
  it "should find edit form with name in xpath" do
    pending "not working on buggy REXML on Gutsy" do
      @doc.elements['//form[@name="editform"]'].should_not == nil
    end
  end
end
=end

describe MediaWiki, " logging in" do
  before do
    @http = mock("http")
    Net::HTTP.should_receive(:new).with("localhost", 80).and_return(@http)
    @url = "http://localhost/wiki"
    @wiki = MediaWiki::Wiki.new(@url)
  end
  
  it "should not set read_only on valid reply" do
    @http.should_receive(:start).and_yield(@http)
    response = mock("response")
    Net::HTTPSuccess.should_receive(:===).with(response).and_return(true)
    response.stub!(:body).and_return(File.read("edit_sandbox.html"))
    @http.should_receive(:request).and_return(response)
    
    article = @wiki.article("article name")
    article.read_only.should_not == true
  end
end

describe MediaWiki, " with fake MiniBrowser" do
  before do
    @browser = mock("browser")
    url = "http://localhost/wiki"
    @uri = mock("uri")
    @uri.stub!(:path).and_return("/wiki/")
    URI.should_receive(:parse).with(url + "/").and_return(@uri)
    MediaWiki::MiniBrowser.should_receive(:new).with(@uri).and_return(@browser)
    @wiki = MediaWiki::Wiki.new(url)
  end
  
  it "should retreive history" do
    # to update:
    # wget "http://fr.wikipedia.org/w/index.php?title=Wikip%C3%A9dia&dir=prev&offset=20071023064530&limit=4&action=history" -O sample_history.html
    result = File.read("sample_history.html")
    @browser.should_receive(:get_content).with(@uri.path + "index.php?title=#{CGI.escape('Wikipédia')}&limit=1000&action=history").and_return(result)
    @wiki.history("Wikipédia", 1000).should == [
      { :oldid => "22180997", :author => "Jauclair", :date => "25 octobre 2007 à 17:17" },
      { :oldid => "22094257", :author => "DocteurCosmos", :date => "23 octobre 2007 à 16:00" },
      { :oldid => "22094221", :author => "DocteurCosmos", :date => "23 octobre 2007 à 15:59" },
      { :oldid => "22080062", :author => "DocteurCosmos", :date => "23 octobre 2007 à 07:47" },
    ]
  end
  
  it "should use offset in history" do
    result = File.read("sample_history.html")
    @browser.should_receive(:get_content).with(@uri.path + "index.php?title=#{CGI.escape('Wikipédia')}&limit=1000&offset=offset&action=history").and_return(result)
    @wiki.history("Wikipédia", 1000, "offset")
  end
  
  it "should return empty array when history is empty" do
    result = File.read("sample_empty_history.html")
    @browser.should_receive(:get_content).with(@uri.path + "index.php?title=#{CGI.escape('Wikipédia')}&limit=1&action=history").and_return(result)
    @wiki.history("Wikipédia", 1).should == []
  end
  
  it "should retreive old text" do
    # to update:
    # wget "http://fr.wikipedia.org/w/index.php?title=Utilisateur:Piglobot/Bac_%C3%A0_sable&action=edit&oldid=22274949" -O sample_edit_old.html
    result = File.read("sample_edit_old.html")
    @browser.should_receive(:get_content).with(@uri.path + "index.php?title=#{CGI.escape 'Utilisateur:Piglobot/Bac_à_sable'}&action=edit&oldid=22274949").and_return(result)
    @wiki.old_text("Utilisateur:Piglobot/Bac à sable", "22274949").should == "[[Chine]]\n"
  end
  
  it "should retreive category articles" do
    result = File.read("sample_category.html")
    @browser.should_receive(:get_content).with(@uri.path + "index.php?title=#{CGI.escape 'Category:Category_name'}").and_return(result)
    items, next_id = @wiki.category_slice("Category name")
    items.size.should == 200
    items.first.should == "Discussion Wikipédia:Liste des articles non neutres/André-Georges Manry"
    items.should include("Modèle:Initialiser LANN")
    items.should include("Wikipédia:Liste des articles non neutres/Alexis Carrel")
    items.should include("Wikipédia:Liste des articles non neutres/Alfa Romeo 166")
    items.should include("Wikipédia:Liste des articles non neutres/Auriculothérapie")
    items.should include("Wikipédia:Liste des articles non neutres/Bengaliidae")
    items.last.should == "Wikipédia:Liste des articles non neutres/Canadien français"
    next_id.should == "Wikip%C3%A9dia%3AListe+des+articles+non+neutres%2FCannelle+%28ourse%29"
  end

  it "should retreive category article with amp" do
    result = File.read("sample_category_with_amp.html")
    @browser.should_receive(:get_content).with(@uri.path + "index.php?title=#{CGI.escape 'Category:Category_name'}").and_return(result)
    items, next_id = @wiki.category_slice("Category name")
    items.size.should == 200
    items.delete_if { |item| item !~ /Associ/ }
    items.should_not include("Wikipédia:Liste des articles non neutres/Frémeaux &amp; Associés")
    items.should include("Wikipédia:Liste des articles non neutres/Frémeaux & Associés")
  end

  it "should retreive next category articles" do
    result = File.read("sample_category.html")
    @browser.should_receive(:get_content).with(@uri.path + "index.php?title=#{CGI.escape 'Category:Category_name'}&from=néxt_id").and_return(result)
    @wiki.category_slice("Category name", "néxt_id")
  end
  
  it "should retreive no next category in category_buggy.html" do
    result = File.read("sample_category_buggy.html")
    @browser.should_receive(:get_content).and_return(result)
    items, next_id = @wiki.category_slice("name", "next")
    next_id.should == nil
  end
  
  it "should retreive full category" do
    name = mock("name")
    @wiki.should_receive(:puts).ordered.with("Getting pages in category #{name}")
    @wiki.should_receive(:category_slice).ordered.with(name, nil).and_return([["foo"], "bar"])
    @wiki.should_receive(:puts).ordered.with("Getting pages in category #{name} starting at \"bar\"")
    @wiki.should_receive(:category_slice).ordered.with(name, "bar").and_return([["bar"], "baz"])
    @wiki.should_receive(:puts).ordered.with("Getting pages in category #{name} starting at \"baz\"")
    @wiki.should_receive(:category_slice).ordered.with(name, "baz").and_return([["baz"], nil])
    @wiki.full_category(name).should == ["foo", "bar", "baz"]
  end
  
  it "should work on programming category" do
    name = "Langage de programmation"
    
    url = @uri.path + "index.php?title=Category%3ALangage_de_programmation"
    content = File.read("sample_category_programming.html")
    @browser.should_receive(:get_content).with(url).and_return(content)
    
    url = @uri.path + 
      "index.php?title=Category%3ALangage_de_programmation&from=Visual+Basic+for+Applications"
    content = File.read("sample_category_programming_2.html")
    @browser.should_receive(:get_content).with(url).and_return(content)
    
    @wiki.should_receive(:puts).twice
    
    result = @wiki.full_category(name)
    result.should include("Ruby")
    result.should include("YaBasic")
  end
  
  it "should retreive links" do
    result = File.read("sample_links.html")
    url = @uri.path + "index.php?title=#{CGI.escape 'Special:Whatlinkshere/Foo:Bàr'}"
    url << "&limit=500&from=0"
    @browser.should_receive(:get_content).with(url).and_return(result)
    items, next_id = @wiki.links("Foo:Bàr")
    items.size.should == 20
    items.first.should == "Algorithmique"
    items.should include("Amstrad CPC 6128")
    items.should include("Apple I")
    items.last.should == "Carte mère"
    next_id.should == "635"
  end

  it "should retreive links with offset" do
    result = File.read("sample_links.html")
    url = @uri.path + "index.php?title=#{CGI.escape 'Special:Whatlinkshere/Foo:Bàr'}"
    url << "&limit=500&from=offset"
    @browser.should_receive(:get_content).with(url).and_return(result)
    items, next_id = @wiki.links("Foo:Bàr", "offset")
  end
  
  it "should retreive links with offset and namespace" do
    result = File.read("sample_links.html")
    url = @uri.path + "index.php?title=#{CGI.escape 'Special:Whatlinkshere/Foo:Bàr'}"
    url << "&limit=500&from=offset"
    url << "&namespace=0"
    @browser.should_receive(:get_content).with(url).and_return(result)
    items, next_id = @wiki.links("Foo:Bàr", "offset", 0)
  end
  
  it "should detect last page" do
    result = File.read("sample_links_end.html")
    url = @uri.path + "index.php?title=#{CGI.escape 'Special:Whatlinkshere/Foo:Bàr'}"
    url << "&limit=500&from=offset"
    @browser.should_receive(:get_content).with(url).and_return(result)
    items, next_id = @wiki.links("Foo:Bàr", "offset")
    next_id.should == nil
  end
  
  it "should retreive all links pages" do
    @wiki.should_receive(:links).with("foo", "0").and_return([["bar", "baz"], "123"])
    @wiki.should_receive(:links).with("foo", "123").and_return([["bob", "baz"], "456"])
    @wiki.should_receive(:links).with("foo", "456").and_return([["mock"], nil])
    @wiki.full_links("foo").should == ["bar", "baz", "bob", "baz", "mock"]
  end

  it "should retreive all links pages with namespace" do
    @wiki.should_receive(:links).with("foo", "0", 4).and_return([["bar", "baz"], "123"])
    @wiki.should_receive(:links).with("foo", "123", 4).and_return([["bob", "baz"], "456"])
    @wiki.should_receive(:links).with("foo", "456", 4).and_return([["mock"], nil])
    @wiki.full_links("foo", 4).should == ["bar", "baz", "bob", "baz", "mock"]
  end
  
  it "should retreive all pages" do
    result = File.read("sample_all_pages_1.html")
    url = @uri.path + "index.php?title=#{CGI.escape 'Special:Allpages'}"
    url << "&from=(from)&namespace=(namespace)"
    @browser.should_receive(:get_content).with(url).and_return(result)
    items, next_id = @wiki.all_pages("(from)", "(namespace)")
    items.size.should == 960
    items[0].should == "Catégorie:-1"
    items[1].should == "Catégorie:-10"
    items[2].should == "Catégorie:-100"
    items[3].should == "Catégorie:-1000"
    items.should include("Catégorie:.NET Framework")
    items.should include("Catégorie:10e arrondissement de Paris")
    items.should include("Catégorie:106")
    items.last.should == "Catégorie:1109"
    next_id.should == "111"
  end

  it "should retreive all pages on second page" do
    result = File.read("sample_all_pages_2.html")
    url = @uri.path + "index.php?title=#{CGI.escape 'Special:Allpages'}"
    url << "&from=(from)&namespace=(namespace)"
    @browser.should_receive(:get_content).with(url).and_return(result)
    items, next_id = @wiki.all_pages("(from)", "(namespace)")
    items.size.should == 960
    items[0].should == "Catégorie:111"
    items.should include("Catégorie:1201")
    items.should include("Catégorie:1535 en Tunisie")
    items.last.should == "Catégorie:1867 au Canada"
    next_id.should == "1867_en_musique"
  end

  it "should retreive all pages on last page" do
    result = File.read("sample_all_pages_last.html")
    url = @uri.path + "index.php?title=#{CGI.escape 'Special:Allpages'}"
    url << "&from=(from)&namespace=(namespace)"
    @browser.should_receive(:get_content).with(url).and_return(result)
    items, next_id = @wiki.all_pages("(from)", "(namespace)")
    items[0].should == "Catégorie:Đà Nẵng"
    items.should_not include("Catégorie:Œuvre médiévale galloise") # redirect
    items.should include("Catégorie:Œuvre de Gluck")
    items.should include("Catégorie:Œuvre épique médiévale")
    items.should include("Catégorie:Œuvre médiévale hongroise")
    items.should include("Catégorie:Œuvre médiévale française")
    items.should include("Catégorie:Œuvre de Martinů")
    items.last.should == "Catégorie:Œuvres de Flavius Josèphe"
    items.size.should == 274 - 1 # 1 redirect
    next_id.should == nil
  end

  it "should retreive full all pages" do
    @wiki.should_receive(:puts).with("All pages starting at \"\"")
    @wiki.should_receive(:all_pages).with("", "14").and_return([["bar", "baz"], "123"])
    @wiki.should_receive(:puts).with("All pages starting at \"123\"")
    @wiki.should_receive(:all_pages).with("123", "14").and_return([["bob", "baz"], "456"])
    @wiki.should_receive(:puts).with("All pages starting at \"456\"")
    @wiki.should_receive(:all_pages).with("456", "14").and_return([["mock"], nil])
    @wiki.should_receive(:puts).with("All pages done")
    @wiki.full_all_pages("14").should == ["bar", "baz", "bob", "baz", "mock"]
  end
end

=begin
# Avoid tests on real wikipedia
describe MediaWiki::Wiki, " on real wikipedia" do
  it "should post to sandbox" do
    @wiki = MediaWiki::Wiki.new("http://fr.wikipedia.org/w", "Piglobot", File.read("password"))
    article = @wiki.article("Utilisateur:Piglobot/Bac à sable")
    old_text = article.text
    new_text = "testing mediawiki #{Time.now.to_f}"
    article.text = new_text
    article.submit("Test de ruby-mediawiki")
    article = @wiki.article("Utilisateur:Piglobot/Bac à sable")
    article.text.strip.should == new_text.strip
    article.text = old_text
    article.submit("Rétablissement de l'ancien contenu")
  end

  it "should post konvertor to sandbox" do
    @wiki = MediaWiki::Wiki.new("http://fr.wikipedia.org/w", "Piglobot", File.read("password"))
    article = @wiki.article("Utilisateur:Piglobot/Bac à sable")
    new_text = File.read("konvertor.txt")
    article.text = new_text
    article.submit("Test de ruby-mediawiki")
    article = @wiki.article("Utilisateur:Piglobot/Bac à sable")
    article.text.strip.should == new_text.strip
  end
end
=end
