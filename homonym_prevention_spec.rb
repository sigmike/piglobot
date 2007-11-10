require 'homonym_prevention'

describe Piglobot, " on HomonymPrevention job" do
  it "should know job" do
    @wiki = mock("wiki")
    Piglobot::Wiki.should_receive(:new).with().and_return(@wiki)
    @bot = Piglobot.new
    @bot.job_class("Homonymes").should == Piglobot::HomonymPrevention
  end
end

describe Piglobot::HomonymPrevention do
  before do
    @bot = mock("bot")
    @wiki = mock("wiki")
    @bot.should_receive(:wiki).with().and_return(@wiki)
    @job = Piglobot::HomonymPrevention.new(@bot)
  end
  
  it "should never be done" do
    @job.done?.should == false
  end
  
  it "should find new links" do
    @job.data = { "Chine" => {"Last" => ["a", "b", "c"], "New" => [] }}
    @wiki.should_receive(:links, "Chine").and_return(["a", "b", "d", "c", "e"])
    Piglobot::Tools.should_receive(:log).with("Un lien vers [[Chine]] a été ajouté dans [[d]]")
    Piglobot::Tools.should_receive(:log).with("Un lien vers [[Chine]] a été ajouté dans [[e]]")
    @job.process
    @job.changed?.should == false
    @job.data.should == { "Chine" => {"Last" => ["a", "b", "d", "c", "e"], "New" => ["d", "e"] }}
  end
  
  it "should keep new links" do
    @job.data = { "Chine" => {"Last" => ["a", "b"], "New" => ["b"] }}
    @wiki.should_receive(:links, "Chine").and_return(["a", "b"])
    Piglobot::Tools.should_not_receive(:log)
    @job.process
    @job.data.should == { "Chine" => {"Last" => ["a", "b"], "New" => ["b"] }}
  end
  
  it "should ignore removed pending links" do
    @job.data = { "Chine" => {"Last" => ["a", "b"], "New" => ["b"] }}
    @wiki.should_receive(:links, "Chine").and_return(["a"])
    Piglobot::Tools.should_receive(:log).with("Le lien vers [[Chine]] dans [[b]] a été supprimé avant d'être traité")
    @job.process
    @job.data.should == { "Chine" => {"Last" => ["a"], "New" => [] }}
  end
end

