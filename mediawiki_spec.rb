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
  
  # disabled : fails on gutsy
  # it "should find edit form with name in xpath" do
  #   @doc.elements['//form[@name="editform"]'].should_not == nil
  # end
end

describe MediaWiki, "logging in" do
  before do
    @http = mock("http")
    Net::HTTP.should_receive(:new).with("localhost", 80).and_return(@http)
    @url = "http://localhost/wiki"
    @wiki = MediaWiki::Wiki.new(@url)
  end
  
  it "should allow post" do
    @http.should_receive(:start).and_yield(@http)
    response = mock("response")
    Net::HTTPSuccess.should_receive(:===).with(response).and_return(true)
    response.stub!(:body).and_return(File.read("edit_sandbox.html"))
    @http.should_receive(:request).and_return(response)
    
    article = @wiki.article("article name")
    article.text = "article content"
    article.submit("comment")
  end
end
