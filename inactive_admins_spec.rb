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

require 'inactive_admins'

describe InactiveAdmins do
  before do
    @bot = mock("bot")
    @wiki = mock("wiki")
    @bot.should_receive(:wiki).with().and_return(@wiki)
    @job = InactiveAdmins.new(@bot)
  end
  
  it "should process" do
    @job.should_receive(:get_admin_list)
    @job.should_receive(:remove_excluded)
    @job.should_receive(:get_last_contribution)
    @job.should_receive(:remove_active)
    @job.should_receive(:publish_list)
    @job.process
  end
  
  it "should get admin list" do
    @wiki.should_receive(:users).with("sysop").and_return(["foo", "bar"])
    @job.get_admin_list
    @job.data.should == ["foo", "bar"]
  end
  
  it "should remove excluded admins" do
    @job.data = initial_admins = ["foo", "bob", "Bob", "Mock", "baz"]
    @wiki.should_receive(:get).with("Wikipédia:Liste des administrateurs inactifs/Exclusions").and_return("foo\n* {{u|Bob}}\n*{{u|mock}}\n\nbar\n{{u|baz}}")
    @job.remove_excluded
    @job.data.should == initial_admins - ["Bob", "baz"]
  end
  
  it "should get_last_contribution" do
    @job.data = ["bob", "mock"]
    @wiki.should_receive(:contributions).with("bob", 1).and_return([{:oldid => "oldid", :page => "page", :date => "bob time"}])
    @wiki.should_receive(:contributions).with("mock", 1).and_return([{:oldid => "oldid", :page => "page", :date => "mock time"}])
    @job.get_last_contribution
    @job.data.should == [["bob", "bob time"], ["mock", "mock time"]]
  end
  
  it "should remove_active" do
    now = Time.local(2007, 1, 9, 10, 40, 12)
    Time.should_receive(:now).with().and_return(now)
    @job.data = [
      ["foo", Time.local(2006, 10, 9, 10, 40, 12)], # exactly 3 monthes ago
      ["bar", Time.local(2006, 10, 9, 10, 40, 11)], # 3 monthes and 1 second ago
      ["bar2", Time.local(2006, 12, 9, 10, 40, 11)], # 1 months and 1 second ago
      ["baz", Time.local(2005, 1, 9, 10, 40, 12)], # 1 year ago
      ["bob", Time.local(2007, 1, 9, 10, 40, 13)], # 1 second in the future
    ]
    @job.remove_active
    @job.data.should == [
      ["bar", Time.local(2006, 10, 9, 10, 40, 11)], # 3 monthes and 1 second ago
      ["baz", Time.local(2005, 1, 9, 10, 40, 12)], # 1 year ago
    ]
  end
  
  it "should publish_list" do
    @job.data = [
      ["bar", t1=Time.local(2006, 10, 9, 10, 40, 11)],
      ["baz", t2=Time.local(2005, 1, 9, 10, 40, 12)],
    ]
    now = Time.local(2007, 1, 9, 10, 40, 12)
    Time.should_receive(:now).with().and_return(now)
    Piglobot::Tools.should_receive(:write_date).with(now).and_return("date0")
    Piglobot::Tools.should_receive(:write_date).with(t2).and_return("date2")
    Piglobot::Tools.should_receive(:write_date).with(t1).and_return("date1")
    @wiki.should_receive(:post).with("Wikipédia:Liste des administrateurs inactifs",
      "Liste des administrateurs inactifs (hors [[Wikipédia:Liste des administrateurs inactifs/Exclusions exclusions]]) depuis plus de 3 mois. Mise à jour le date0 par {{u|Piglobot}}.\n" +
      "* {{u|baz}}, dernière contribution le date2\n" +
      "* {{u|bar}}, dernière contribution le date1\n", "Mise à jour")
    @job.publish_list
  end
end
