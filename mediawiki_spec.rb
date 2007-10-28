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
      ["22180997", "Jauclair"],
      ["22094257", "DocteurCosmos"],
      ["22094221", "DocteurCosmos"],
      ["22080062", "DocteurCosmos"],
    ]
  end
  
  it "should retreive old text" do
    # to update:
    # wget "http://fr.wikipedia.org/w/index.php?title=Utilisateur:Piglobot/Bac_%C3%A0_sable&action=edit&oldid=22274949" -O sample_edit_old.html
    result = File.read("sample_edit_old.html")
    @browser.should_receive(:get_content).with(@uri.path + "index.php?title=#{CGI.escape 'Utilisateur:Piglobot/Bac_à_sable'}&action=edit&oldid=22274949").and_return(result)
    @wiki.old_text("Utilisateur:Piglobot/Bac à sable", "22274949").should == "[[Chine]]\n"
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
