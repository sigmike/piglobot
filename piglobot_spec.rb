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
    @wiki = mock("wiki")
    @article = mock("article")
    @bot = Piglobot.new(@wiki)
  end
  
  it "should publish spec" do
    @wiki.should_receive(:article).with("Utilisateur:Piglobot/Spec").once.and_return(@article)
    text = "<source lang=\"ruby\">\n" + File.read("piglobot_spec.rb") + "<" + "/source>"
    @article.should_receive(:text=).with(text)
    @article.should_receive(:submit).with("comment")
    @bot.publish_spec("comment")
  end

  it "should publish code" do
    @wiki.should_receive(:article).with("Utilisateur:Piglobot/Code").once.and_return(@article)
    text = "<source lang=\"ruby\">\n" + File.read("piglobot.rb") + "<" + "/source>"
    @article.should_receive(:text=).with(text)
    @article.should_receive(:submit).with("comment")
    @bot.publish_code("comment")
  end
end
