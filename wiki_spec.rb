require 'piglobot'
require 'helper'

describe Piglobot::Wiki do
  before do
    @mediawiki = mock("mediawiki")
    MediaWiki::Wiki.should_receive(:new).once.with(
      "http://fr.wikipedia.org/w",
      "Piglobot",
      File.read("password").strip
    ).and_return(@mediawiki)
    @article = mock("article")
    @wiki = Piglobot::Wiki.new
  end
  
  it "should post text" do
    @mediawiki.should_receive(:article).with("Article name").once.and_return(@article)
    @article.should_receive(:text=).with("article content")
    @article.should_receive(:submit).with("comment")
    Piglobot::Tools.should_receive(:log).with("Post [[Article name]] (comment)")
    @wiki.internal_post "Article name", "article content", "comment"
  end
  
  it "should get text" do
    @mediawiki.should_receive(:article).with("Article name").once.and_return(@article)
    @article.should_receive(:text).with().and_return("content")
    Piglobot::Tools.should_receive(:log).with("Get [[Article name]]")
    @wiki.internal_get("Article name").should == "content"
  end
  
  it "should append text" do
    @mediawiki.should_receive(:article).with("Article name").once.and_return(@article)
    @article.should_receive(:text).with().and_return("content")
    @article.should_receive(:text=).with("contentnew text")
    @article.should_receive(:submit).with("append comment")
    Piglobot::Tools.should_receive(:log).with("Append [[Article name]] (append comment)")
    @wiki.internal_append("Article name", "new text", "append comment")
  end
  
  it "should use fast_what_links_here on links" do
    name = "Article name"
    links = ["Foo", "Bar", "Foo:Bar", "Hello:Bob", "Baz"]
    expected_links = links
    Piglobot::Tools.should_receive(:log).with("What links to [[Article name]]")
    @mediawiki.should_receive(:article).with(name).once.and_return(@article)
    @article.should_receive(:fast_what_links_here).with(5000).and_return(links)
    @wiki.internal_links(name).should == expected_links
  end
  
  it "should wait 10 minutes and retry on error" do
    step = 0
    steps = rand(30) + 2
    
    Piglobot::Tools.should_receive(:log).with("Retry in 10 minutes (Mock 'Piglobot::Wiki' received :foo but passed block failed with: erreur)").exactly(steps-1).times
    Kernel.should_receive(:sleep).with(10*60).exactly(steps-1).times
    
    @wiki.should_receive(:foo).with("bar", :baz).exactly(steps).times do
      step += 1
      if step < steps
        raise "erreur"
      else
        "result"
      end
    end
    @wiki.retry(:foo, "bar", :baz).should == "result"
  end
  
  %w( get post append links ).each do |method|
    it "should call retry with internal on #{method}" do
      @wiki.should_receive(:retry).with("internal_#{method}".intern, "foo", :bar).and_return("baz")
      @wiki.send(method, "foo", :bar).should == "baz"
    end
  end
end

