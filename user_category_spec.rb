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
  end
  
  it "should not retreive categories twice" do
    @job.data = { :categories => :anything }
    @wiki.should_not_receive(:all_pages)
    @job.process
    @job.data.should == { :categories => :anything }
  end
end
