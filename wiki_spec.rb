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
    @bot = mock("bot")
    RWikiBot.should_receive(:new).once.with(
      "Piglobot",
      File.read("password").strip,
      "http://fr.wikipedia.org/w/api.php"
      ).and_return(@bot)
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
  
  it "should wait 10 minutes and retry 10 times on error" do
    step = 0
    
    Piglobot::Tools.should_receive(:log).with(/Retry in 10 minutes \(.+\)/).exactly(9).times
    Kernel.should_receive(:sleep).with(10*60).exactly(9).times
    
    e = RuntimeError.new("error")
    @wiki.should_receive(:foo).with("bar", :baz).exactly(10).times.and_raise(e)
    timeout 2 do
      lambda {
        @wiki.retry(:foo, "bar", :baz)
      }.should raise_error(RuntimeError, "error")
    end
  end
  
  it "should get user list" do
    Piglobot::Tools.should_receive(:log).with("User list in group foo")
    @mediawiki.should_receive(:list_all_users).with("foo").once.and_return("result")
    @wiki.internal_users("foo").should == "result"
  end
  
  it "should use rwikibot to get contributions" do
    bot_result = [
      {"comment"=>
        "Les tests de compatibilit\303\251 avec la version actuelle de mediawiki ont \303\251chou\303\251. Tous les travaux en cours sont suspendus.",
        "size"=>"327051",
        "revid"=>"45649272",
        "pageid"=>"2081159",
        "timestamp"=>"2009-10-11T05:30:48Z",
        "title"=>"Utilisateur:Piglobot/Journal",
        "ns"=>"2",
        "user"=>"Piglobot",
        "top"=>""},
      {"comment"=>"test 2",
        "size"=>"0",
        "revid"=>"45649269",
        "pageid"=>"2074026",
        "timestamp"=>"2009-10-11T05:30:35Z",
        "title"=>"Utilisateur:Piglobot/Bac \303\240 sable",
        "ns"=>"2",
        "user"=>"Piglobot",
        "top"=>""}]

    Piglobot::Tools.should_receive(:parse_time).with("2009-10-11T05:30:48Z").and_return("parsed time")
    Piglobot::Tools.should_receive(:parse_time).with("2009-10-11T05:30:35Z").and_return("parsed time 2")
    @bot.should_receive(:contributions).with(:user => "username", :limit => 12).and_return(bot_result)
    Piglobot::Tools.should_receive(:log).with("Contributions of username (12)")
    @wiki.internal_contributions("username", 12).should == [
      { :oldid => "45649272", :page => "Utilisateur:Piglobot/Journal", :date => "parsed time" },
      { :oldid => "45649269", :page => "Utilisateur:Piglobot/Bac \303\240 sable", :date => "parsed time 2" },
    ]
  end
  
  it "should use rwikibot to get history" do
    bot_result = {
      "pages"=> {
        "page"=> {
          "pageid"=>"826510",
          "title"=>"Bot informatique",
          "ns"=>"0",
          "revisions"=> {
            "rev"=> [
              {
                "comment"=>
                "Annulation des modifications 47587549 de [[Sp\303\251cial:Contributions/3eX|3eX]] ([[User talk:3eX|d]]) pub",
                "revid"=>"47594710",
                "timestamp"=>"2009-12-10T08:51:11Z",
                "parentid"=>"47587549",
                "user"=>"Freewol"
              },
              {
                "comment"=>"/* Articles connexes */",
                "revid"=>"47587549",
                "timestamp"=>"2009-12-09T22:41:12Z",
                "parentid"=>"45437160",
                "user"=>"3eX"
              }
            ]
          }
        }
      }
    }

    Piglobot::Tools.should_receive(:parse_time).with("2009-12-10T08:51:11Z").and_return("parsed time")
    Piglobot::Tools.should_receive(:parse_time).with("2009-12-09T22:41:12Z").and_return("parsed time 2")
    @bot.should_receive(:revisions).with(:titles => "Bot informatique", :limit => 2, :startid => "start").and_return(bot_result)
    Piglobot::Tools.should_receive(:log).with("History [[Bot informatique]] (2)")
    @wiki.internal_history("Bot informatique", 2, "start").should == [
      { :oldid => "47594710", :author => "Freewol", :date => "parsed time" },
      { :oldid => "47587549", :author => "3eX", :date => "parsed time 2" },
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
