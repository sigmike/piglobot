
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
end
