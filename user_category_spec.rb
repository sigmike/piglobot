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
    @job.changed?.should == false
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
  
  [
    "Catégorie:Utilisateur/foo",
    "Catégorie:Utilisateur bar",
    "Catégorie:Utilisateur",
  ].each do |category|
    it "should know category #{category} is invalid" do
      @job.valid_category?(category).should == false
    end
  end
  
  [
    "Catégorie:foo",
    "Catégorie:bar",
    "Catégorie:foo Utilisateur",
  ].each do |category|
    it "should know category #{category} is valid" do
      @job.valid_category?(category).should == true
    end
  end
  
  it "should not process invalid category" do
    @job.should_receive(:valid_category?).with("cat").and_return(false)
    @job.should_receive(:log).with("Catégorie ignorée : cat")
    @job.process_category("cat")
    @job.changed?.should == false
  end
  
  it "should process valid category" do
    @job.should_receive(:valid_category?).with("cat").and_return(true)
    @job.should_receive(:process_valid_category).with("cat")
    @job.process_category("cat")
  end
  
  it "should detect user pages on valid category" do
    @wiki.should_receive(:category).with("cat").and_return(["foo", "Utilisateur:foo", "bar", "Utilisateur:bob/panda"])
    @job.should_receive(:post_user_category).with("cat", ["Utilisateur:foo", "Utilisateur:bob/panda"])
    @job.process_valid_category("cat")
  end
  
  it "should do nothing when no user page in category" do
    @wiki.should_receive(:category).with("cat").and_return(["foo", "foo Utilisateur:foo", "bar"])
    @job.should_receive(:log).with("Aucune page utilisateur dans cat")
    @job.process_valid_category("cat")
  end
  
  it "should post user category" do
    page = "Utilisateur:Piglobot/Utilisateurs catégorisés dans main"
    text = [
      "== [[:cat]] ==",
      "* [[:foo]]",
      "* [[:Utilisateur:bob/panda]]",
      "",
    ].map { |x| x + "\n" }.join
    
    @wiki.should_receive(:append).with(page, text)
    @job.post_user_category("cat", ["foo", "Utilisateur:bob/panda"])
    @job.changed?.should == true
  end
end
