require 'user_category'

describe UserCategory do
  before do
    @bot = mock("bot")
    @wiki = mock("wiki")
    @bot.should_receive(:wiki).with().and_return(@wiki)
    @job = UserCategory.new(@bot)
  end
  
  it "should retreive categories" do
    @wiki.should_receive(:all_pages).with("14").and_return(["foo", "bar"])
    @job.process
    @job.data.should == { :categories => ["foo", "bar"] }
    @job.changed?.should == true
    @job.done?.should == false
  end
  
  it "should process next category" do
    @job.data = { :categories => ["foo", "bar"] }
    @wiki.should_not_receive(:all_pages)
    @job.should_receive(:process_category).with("foo")
    @job.process
    @job.data.should == { :categories => ["bar"] }
    @job.changed?.should == true
    @job.done?.should == false
  end
  
  it "should be done when out of category" do
    @job.data = { :categories => ["foo"] }
    @wiki.should_not_receive(:all_pages)
    @job.should_receive(:process_category).with("foo")
    @job.process
    @job.data.should == nil
    @job.done?.should == true
  end
  
  it "should not process user category" do
    pending
  end
  
  it "should detect user pages in category" do
    pending
  end
  
  it "should do nothing when no user page in category" do
    pending
  end
end
