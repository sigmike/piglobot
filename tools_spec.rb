require 'piglobot'
require 'helper'
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


describe Piglobot::Tools do
  it "should convert file to wiki" do
    result = Piglobot::Tools.file_to_wiki("filename", "file\ncontent", "lang")
    result.should == ([
      "== filename ==",
      '<source lang="lang">',
      'file',
      'content',
      '<' + '/source>',
      '',
    ].map { |line| line + "\n" }.join)
  end
  
  it "should use Kernel.puts and append to piglobot.log on log" do
    time = mock("time")
    Time.should_receive(:now).with().and_return(time)
    time.should_receive(:strftime).with("%Y-%m-%d %H:%M:%S").and_return("time string")
    log_line = "time string: text"
    Kernel.should_receive(:puts).with(log_line)
    
    f = mock("file")
    File.should_receive(:open).with("piglobot.log", "a").and_yield(f)
    f.should_receive(:puts).with(log_line).once
    
    Piglobot::Tools.log("text")
  end
  
  [
    ["25 octobre 2007 à 17:17", Time.local(2007, 10, 25, 17, 17, 0)],
    ["25 août 2006 à 09:16", Time.local(2006, 8, 25, 9, 16, 0)],
    ["12 juillet 2006 à 08:40", Time.local(2006, 7, 12, 8, 40, 0)],
    ["10 novembre 2002 à 19:12", Time.local(2002, 11, 10, 19, 12, 0)],
    ["1 décembre 2002 à 11:39", Time.local(2002, 12, 1, 11, 39, 0)],
  ].each do |text, time|
    it "should parse time #{text.inspect}" do
      Piglobot::Tools.parse_time(text).should == time
    end
  end

  [
    "décembre 2002 à 11:39",
    "10 novembre 2002 19:12",
    "10 plop 2002 à 19:12",
    "10 octobre 2002",
    "foo 1 décembre 2002 à 11:39",
    "1 décembre 2002 à 11:39 foo",
  ].each do |text|
    it "should not parse time #{text.inspect}" do
      lambda { Piglobot::Tools.parse_time(text) }.should raise_error(ArgumentError, "Invalid time: #{text.inspect}")
    end
  end
  
  months = %w(janvier février mars avril mai juin juillet août septembre octobre novembre décembre)
  months.each_with_index do |month, i|
    expected_month = i + 1
    it "should parse month #{month.inspect}" do
      Piglobot::Tools.parse_time("25 #{month} 2007 à 17:17").should ==
        Time.local(2007, expected_month, 25, 17, 17, 0)
    end
  end
end
