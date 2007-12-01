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

require 'suivi_portail_informatique'

describe SuiviPortailInformatique do
  before do
    @bot = mock("bot")
    @wiki = mock("wiki")
    @bot.should_receive(:wiki).and_return(@wiki)
    
    @job = SuiviPortailInformatique.new(@bot)
  end
  
  it "should be a job" do
    @job.should be_kind_of(Piglobot::Job)
  end
  
  it "should have a better name" do
    @job.name.should == "[[Projet:Informatique/Suivi]]"
  end
  
  it "should retreive links and post them" do
    @wiki.should_receive(:links).with("Modèle:Portail informatique").and_return(["foo", "bar"])
    time = mock("time")
    Time.should_receive(:now).with().and_return(time)
    Piglobot::Tools.should_receive(:write_date).with(time).and_return("<date>")
    text = ""
    text << "<noinclude><small>''"
    text << "Liste des articles référencés par le projet « Informatique ». "
    text << "Mise à jour le <date> par {{u|Piglobot}}."
    text << "''</small></noinclude>\n"
    text << "* [[:foo]]\n"
    text << "* [[:bar]]\n"
    @wiki.should_receive(:post) do |page, content, comment|
      page.should == "Projet:Informatique/Suivi"
      content.should == text
      comment.should == "Mise à jour automatique"
    end
    @job.process
    @job.done?.should == true
  end
end
