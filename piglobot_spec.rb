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
    along with Foobar.  If not, see <http://www.gnu.org/licenses/>.
=end

require 'piglobot'

describe Piglobot::Dump do
  before do
    @wiki = mock("wiki")
    @dump = Piglobot::Dump.new(@wiki)
  end
  
  it "should publish spec" do
    text = "<source lang=\"ruby\">\n" + File.read("piglobot_spec.rb") + "<" + "/source>"
    @wiki.should_receive(:post).with("Utilisateur:Piglobot/Spec", text, "comment")
    @dump.publish_spec("comment")
  end

  it "should publish code" do
    text = "<source lang=\"ruby\">\n" + File.read("piglobot.rb") + "<" + "/source>"
    @wiki.should_receive(:post).with("Utilisateur:Piglobot/Code", text, "comment")
    @dump.publish_code("comment")
  end
  
  it "should load data" do
    data = "foo"
    text = "<source lang=\"text\">\n" + data.to_yaml + "</source" + ">"
    @wiki.should_receive(:get).with("Utilisateur:Piglobot/Data").once.and_return(text)
    @dump.load_data.should == data
  end

  it "should save data" do
    data = "bar"
    text = "<source lang=\"text\">\n" + data.to_yaml + "</source" + ">"
    @wiki.should_receive(:post).with("Utilisateur:Piglobot/Data", text, "Sauvegarde").once
    @dump.save_data(data)
  end
  
  it "should load nil when no data" do
    text = "\n"
    @wiki.should_receive(:get).with("Utilisateur:Piglobot/Data").once.and_return(text)
    @dump.load_data.should == nil
  end
end

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
    @wiki.post "Article name", "article content", "comment"
  end
  
  it "should get text" do
    @mediawiki.should_receive(:article).with("Article name").once.and_return(@article)
    @article.should_receive(:text).with().and_return("content")
    @wiki.get("Article name").should == "content"
  end
end

describe Piglobot do
  before do
    @wiki = mock("wiki")
    @dump = mock("dump")
    Piglobot::Wiki.should_receive(:new).and_return(@wiki)
    Piglobot::Dump.should_receive(:new).once.with(@wiki).and_return(@dump)
    @bot = Piglobot.new
  end
  
  it "should initialize data on first run" do
    @dump.should_receive(:load_data).and_return(nil)
    @dump.should_receive(:save_data).with({})
    @bot.run
  end
end
