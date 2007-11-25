require 'user_category'

describe UserCategory do
  before do
    @bot = mock("bot")
    @wiki = mock("wiki")
    @bot.should_receive(:wiki).with().and_return(@wiki)
    @job = UserCategory.new(@bot)
  end
  
  it "should step 20 times at each process" do
    @job.should_receive(:step_and_sleep).with().exactly(20).times
    @job.process
  end
  
  it "should step and sleep" do
    @job.should_receive(:step).ordered
    @job.should_receive(:sleep).ordered.with(2)
    @job.step_and_sleep
  end
  
  it "should retreive categories" do
    @wiki.should_receive(:all_pages).with("14").and_return(["foo", "bar", "baz"])
    @job.should_receive(:valid_category?).ordered.with("foo").and_return(true)
    @job.should_receive(:valid_category?).ordered.with("bar").and_return(true)
    @job.should_receive(:valid_category?).ordered.with("baz").and_return(false)
    @job.step
    @job.data.should == { :categories => ["foo", "bar"], :empty => [], :one => [] }
    @job.changed?.should == true
    @job.done?.should == false
  end
  
  it "should process next category" do
    @job.data = { :categories => ["foo", "bar"] }
    @wiki.should_not_receive(:all_pages)
    @job.should_receive(:process_category).with("foo")
    @job.step
    @job.data.should == { :categories => ["bar"] }
    @job.changed?.should == false
    @job.done?.should == false
  end
  
  it "should be done and save special categories when out of category" do
    @job.data = { :categories => ["foo"], :empty => ["foo", "bar"], :one => ["baz", "bob"] }
    @wiki.should_not_receive(:all_pages)
    @job.should_receive(:process_category).with("foo")
    @job.should_not_receive(:notice)
    @wiki.should_receive(:post).with("Utilisateur:Piglobot/Catégories vides", "* [[:foo]]\n* [[:bar]]\n", "Mise à jour")
    @wiki.should_receive(:post).with("Utilisateur:Piglobot/Catégories avec une seule page", "* [[:baz]]\n* [[:bob]]\n", "Mise à jour")
    @job.step
    @job.data.should == nil
    @job.done?.should == true
  end
  
  [
    [100, false],
    [1000, true],
    [1, false],
    [9, false],
    [10, false],
    [99, false],
    [999, false],
    [1001, false],
  ].each do |count, notice|
    it "should #{notice ? '' : 'not' } notice when on #{count} categories remaining" do
      @job.data = { :categories => ["foo", "bar"] + ["baz"] * (count - 1) }
      @job.should_receive(:process_category).with("foo")
      if notice
        @job.should_receive(:notice).with("#{count} catégories à traiter (dernière : [[:foo]])")
      else
        @job.should_not_receive(:notice)
      end
      @job.step
    end
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
    @job.should_receive(:valid_category?).with("Catégorie:cat").and_return(false)
    @job.should_receive(:log).with("Catégorie ignorée : Catégorie:cat")
    @job.process_category("Catégorie:cat")
    @job.changed?.should == false
  end
  
  it "should process valid category" do
    @job.should_receive(:valid_category?).with("Catégorie:cat").and_return(true)
    @job.should_receive(:process_valid_category).with("Catégorie:cat")
    @job.process_category("Catégorie:cat")
  end
  
  it "should detect user pages on valid category" do
    @wiki.should_receive(:category).with("cat").and_return(["foo", "Utilisateur:foo", "bar", "Utilisateur:bob/panda", "Discussion Utilisateur:test/test"])
    @job.should_receive(:log).with("5 pages dans Catégorie:cat")
    @job.should_receive(:post_user_category).with("Catégorie:cat", ["Utilisateur:foo", "Utilisateur:bob/panda", "Discussion Utilisateur:test/test"])
    @job.process_valid_category("Catégorie:cat")
  end
  
  it "should do nothing when no user page in category" do
    @wiki.should_receive(:category).with("cat").and_return(["foo", "foo Utilisateur:foo", "bar"])
    @job.should_receive(:log).with("3 pages dans Catégorie:cat")
    @job.should_receive(:log).with("Aucune page utilisateur dans Catégorie:cat")
    @job.process_valid_category("Catégorie:cat")
  end
  
  it "should post user category" do
    page = "Utilisateur:Piglobot/Utilisateurs catégorisés dans main"
    text = [
      "== [[:Catégorie:cat]] ==",
      "* [[:foo]]",
      "* [[:Utilisateur:bob/panda]]",
      "",
    ].map { |x| x + "\n" }.join
    
    @wiki.should_receive(:append).with(page, text, "2 pages dans [[:Catégorie:cat]]")
    @job.post_user_category("Catégorie:cat", ["foo", "Utilisateur:bob/panda"])
    @job.changed?.should == true
  end
  
  it "should save empty category" do
    @job.data = {}
    @job.data[:empty] = mock("empty list")
    @job.data[:empty].should_receive(:<<).with("Catégorie:foo")
    @wiki.should_receive(:category).with("foo").and_return([])
    @job.should_receive(:log).twice
    @job.process_valid_category("Catégorie:foo")
  end

  it "should save category with one item" do
    @job.data = {}
    @job.data[:one] = mock("empty list")
    @job.data[:one].should_receive(:<<).with("Catégorie:foo")
    @wiki.should_receive(:category).with("foo").and_return(["foo"])
    @job.should_receive(:log).twice
    @job.process_valid_category("Catégorie:foo")
  end
end
