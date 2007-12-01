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

describe Piglobot::Job do
  before do
    @bot = mock("bot")
    @wiki = mock("wiki")
    @bot.should_receive(:wiki).and_return(@wiki)
    @job = Piglobot::Job.new(@bot)
  end
  
  it "should always be done" do
    @job.done?.should == true
  end

  it "should have a name" do
    @job.name.should == @job.class.name
  end
  
  it "should notice with name" do 
    @job.name = "foo"
    @bot.should_receive(:notice).with("foo : text")
    @job.notice("text")
  end

  it "should use Piglobot::Tools.log on log" do
    Piglobot::Tools.should_receive(:log).with("text")
    @job.log("text")
  end
end

