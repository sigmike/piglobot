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

describe Piglobot do
  before do
    @mediawiki = mock("mediawiki")
    @wiki = mock("wiki")
    Piglobot::Wiki.should_receive(:new).once.and_return(@wiki)
    @bot = Piglobot.new(@mediawiki)
  end
  
  it "should publish spec" do
    text = "<source lang=\"ruby\">\n" + File.read("piglobot_spec.rb") + "<" + "/source>"
    @wiki.should_receive(:post).with("Utilisateur:Piglobot/Spec", text, "comment")
    @bot.publish_spec("comment")
  end

  it "should publish code" do
    text = "<source lang=\"ruby\">\n" + File.read("piglobot.rb") + "<" + "/source>"
    @wiki.should_receive(:post).with("Utilisateur:Piglobot/Code", text, "comment")
    @bot.publish_code("comment")
  end
  
  it "should load data" do
    data = "foo"
    text = "<source lang=\"text\">\n" + data.to_yaml + "</source" + ">"
    @wiki.should_receive(:get).with("Utilisateur:Piglobot/Data").once.and_return(text)
    @bot.load_data
    @bot.data.should == data
  end

  it "should save data" do
    data = "bar"
    text = "<source lang=\"text\">\n" + data.to_yaml + "</source" + ">"
    @wiki.should_receive(:post).with("Utilisateur:Piglobot/Data", text, "Sauvegarde").once
    @bot.data = data
    @bot.save_data
  end
end

describe Piglobot::Wiki do
  before do
    @mediawiki = mock("mediawiki")
    @article = mock("article")
    @wiki = Piglobot::Wiki.new(@mediawiki)
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
