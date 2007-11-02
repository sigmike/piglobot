require 'piglobot'
require 'helper'

describe Piglobot::Dump do
  before do
    @wiki = mock("wiki")
    @dump = Piglobot::Dump.new(@wiki)
  end
  
  it "should publish code" do
    Piglobot.should_receive(:code_files).with().and_return(["foo.rb", "bar.txt", "foo_spec.rb", "bob"])
    
    [
      ["foo.rb", "ruby"],
      ["bar.txt", "text"],
      ["foo_spec.rb", "ruby"],
      ["bob", "text"],
    ].each do |file, lang|
      File.should_receive(:read).with(file).and_return("#{file} content")
      Piglobot::Tools.should_receive(:file_to_wiki).with(file, "#{file} content", lang).and_return("#{file} wikified")
    end
    result = [
      "foo.rb wikified",
      "bar.txt wikified",
      "foo_spec.rb wikified",
      "bob wikified",
    ].join
      
    @wiki.should_receive(:post).with("Utilisateur:Piglobot/Code", result, "comment")
    @dump.publish_code("comment")
  end
  
  it "should load data" do
    data = "foo"
    File.should_receive(:read).with("data.yaml").and_return(data.to_yaml)
    @dump.load_data.should == data
  end

  it "should save data" do
    data = "bar"
    text = "<source lang=\"text\">\n" + data.to_yaml + "</source" + ">"
    file = mock("file")
    File.should_receive(:open).with("data.yaml", "w").and_yield(file)
    file.should_receive(:write).with(data.to_yaml)
    @dump.save_data(data)
  end
  
  it "should load nil when no data" do
    File.should_receive(:read).with("data.yaml").and_raise(Errno::ENOENT)
    @dump.load_data.should == nil
  end
end

