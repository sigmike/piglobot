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
    @mediawiki.should_receive(:fast_post).with("Article name", "article content", "comment").once
    Piglobot::Tools.should_receive(:log).with("Post [[Article name]] (comment)")
    @wiki.internal_post "Article name", "article content", "comment"
  end
  
  it "should get text" do
    @mediawiki.should_receive(:fast_get).with("Article name").once.and_return("content")
    Piglobot::Tools.should_receive(:log).with("Get [[Article name]]")
    @wiki.internal_get("Article name").should == "content"
  end
  
  it "should append text" do
    @mediawiki.should_receive(:fast_append).with("Article name", "new text", "append comment").once
    Piglobot::Tools.should_receive(:log).with("Append [[Article name]] (append comment)")
    @wiki.internal_append("Article name", "new text", "append comment")
  end
  
  it "should use full_links on links" do
    name = "Article name"
    links = ["Foo", "Bar", "Foo:Bar", "Hello:Bob", "Baz"]
    expected_links = links
    Piglobot::Tools.should_receive(:log).with("What links to [[Article name]]")
    @mediawiki.should_receive(:full_links).with(name).once.and_return(links)
    @wiki.internal_links(name).should == expected_links
  end
  
  it "should accept namespace on links" do
    name = "Article"
    links = ["Foo", "Bar"]
    expected_links = links
    Piglobot::Tools.should_receive(:log).with("What links to [[Article]] in namespace 1")
    @mediawiki.should_receive(:full_links).with(name, 1).once.and_return(links)
    @wiki.internal_links(name, 1).should == expected_links
  end
  
  it "should use full_category on category" do
    category = "A category"
    result = ["Foo", "Bar", "Foo:Bar", "Hello:Bob", "Baz"]
    expected = result.dup
    Piglobot::Tools.should_receive(:log).with("[[Category:A category]]")
    @mediawiki.should_receive(:full_category).with(category).once.and_return(result)
    @wiki.internal_category(category).should == expected
  end
  
  it "should use full_all_pages on all_pages" do
    namespace = "15"
    pages = ["Foo", "Bar", "Foo:Bar", "Hello:Bob", "Baz"]
    expected_pages = pages
    Piglobot::Tools.should_receive(:log).with("AllPages in namespace 15")
    @mediawiki.should_receive(:full_all_pages).with(namespace).once.and_return(pages)
    @wiki.internal_all_pages(namespace).should == expected_pages
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
  
  it "should retreive history" do
    Piglobot::Tools.should_receive(:parse_time).with("time").and_return("parsed time")
    Piglobot::Tools.should_receive(:parse_time).with("time 2").and_return("parsed time 2")
    @mediawiki.should_receive(:history).with("foo", 12, nil).and_return([
      { :oldid => "oldid", :author => "author", :date => "time" },
      { :oldid => "oldid2", :author => "author2", :date => "time 2" },
    ])
    Piglobot::Tools.should_receive(:log).with("History [[foo]] (12, nil)")
    @wiki.internal_history("foo", 12).should == [
      { :oldid => "oldid", :author => "author", :date => "parsed time" },
      { :oldid => "oldid2", :author => "author2", :date => "parsed time 2" },
    ]
  end
  
  it "should retreive history with offset" do
    Piglobot::Tools.should_receive(:parse_time).with("time").and_return("parsed time")
    @mediawiki.should_receive(:history).with("foo", 5, "123456").and_return([
      { :oldid => "oldid", :author => "author", :date => "time" },
    ])
    Piglobot::Tools.should_receive(:log).with("History [[foo]] (5, \"123456\")")
    @wiki.internal_history("foo", 5, "123456")
  end
  
  it "should get user list" do
    Piglobot::Tools.should_receive(:log).with("User list in group foo")
    @mediawiki.should_receive(:list_all_users).with("foo").once.and_return("result")
    @wiki.internal_users("foo").should == "result"
  end
  
  it "should get contributions" do
    Piglobot::Tools.should_receive(:parse_time).with("time").and_return("parsed time")
    Piglobot::Tools.should_receive(:parse_time).with("time 2").and_return("parsed time 2")
    @mediawiki.should_receive(:contributions).with("username", 12).and_return([
      { :oldid => "oldid", :page => "page", :date => "time" },
      { :oldid => "oldid2", :page => "page2", :date => "time 2" },
    ])
    Piglobot::Tools.should_receive(:log).with("Contributions of username (12)")
    @wiki.internal_contributions("username", 12).should == [
      { :oldid => "oldid", :page => "page", :date => "parsed time" },
      { :oldid => "oldid2", :page => "page2", :date => "parsed time 2" },
    ]
  end
  
  %w( get post append links category history all_pages users contributions ).each do |method|
    it "should call retry with internal on #{method}" do
      @wiki.should_receive(:retry).with("internal_#{method}".intern, "foo", :bar).and_return("baz")
      @wiki.send(method, "foo", :bar).should == "baz"
    end
  end
  
  it "should allow access to mediawiki object" do
    @wiki.mediawiki.should == @mediawiki
  end
end
