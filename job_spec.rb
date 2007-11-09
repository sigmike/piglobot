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
end

