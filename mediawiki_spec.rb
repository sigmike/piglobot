require 'libs'
require 'piglobot'

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

