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

describe Piglobot::Parser do
  before do
    @parser = Piglobot::Parser.new
  end

  it "should find internal links" do
    text = "[[Foo]] [bar] [http://baz] [[/Subpage]] [[/Subpage with space|and alias]] some text"
    result = @parser.internal_links(text)
    result.should == ["Foo", "/Subpage", "/Subpage with space"]
  end

  it "should find internal links with args" do
    text = "[[Foo]] [bar] [http://baz] [[/Subpage]] [[/Subpage with space|and alias]] some text"
    result = @parser.internal_links_with_args(text)
    result.should == [["Foo"], ["/Subpage"], ["/Subpage with space", "and alias"]]
  end
end
