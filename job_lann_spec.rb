
require 'piglobot'

describe Piglobot, " on LANN job" do
  it "should know LANN job" do
    @wiki = mock("wiki")
    Piglobot::Wiki.should_receive(:new).with().and_return(@wiki)
    @bot = Piglobot.new
    @bot.job_class("LANN").should == LANN
  end
end

describe LANN do
  before do
    @bot = mock("bot")
    @wiki = mock("wiki")
    @parser = mock("parser")
    @bot.should_receive(:wiki) { @wiki }
    @job = LANN.new(@bot)
  end
  
  it "should be a job" do
    @job.should be_kind_of(Piglobot::Job)
  end
  
  [
    nil,
    { :pages => [] },
  ].each do |initial_data|
    it "should get pages when data is #{initial_data.inspect}" do
      @job.data = initial_data
      @job.should_receive(:get_pages).with()
      @job.should_receive(:remove_bad_names).with()
      @job.should_receive(:remove_cited).with()
      @job.should_receive(:remove_already_done).with() do
        @job.pages = ["foo", "bar", "baz"]
      end
      @bot.should_receive(:notice).with("[[WP:LANN]] : 3 pages à traiter")
      @job.process
      @job.data[:pages].should == ["foo", "bar", "baz"]
      @job.done?.should == false
    end
  end
  
  it "should process first page if pages filled" do
    @job.data = { :pages => ["foo", "bar"] }
    @job.should_receive(:process_page).with("foo")
    @job.process
    @job.data.should == { :pages => ["bar"] }
    @job.done?.should == false
  end
  
  it "should be done when pages are empty" do
    @job.data = { :pages => ["bar"] }
    @job.should_receive(:process_page).with("bar")
    @job.process
    @job.data.should == { :pages => [] }
    @job.done?.should == true
  end
  
  it "should get pages" do
    items = ["Foo", "Bar", "Baz:Baz"]
    category = "Wikipédia:Archives Articles non neutres"
    @wiki.should_receive(:category).with(category).and_return(items)
    @job.should_receive(:log).with("3 articles dans la catégorie")
    @job.get_pages
    @job.pages.should == items
  end
  
  it "should remove bad names" do
    @job.pages = [
      "Wikipédia:Liste des articles non neutres/Foo",
      "Foo",
      "Liste des articles non neutres/Foo",
      "Wikipédia:Liste des articles non neutres/Baz",
      "Wikipédia:Liste des articles non neutres",
      "Wikipédia:Liste des articles non neutres/Bar",
      "Modèle:Wikipédia:Liste des articles non neutres/Foo",
    ]
    @job.should_receive(:log).with("3 articles avec un nom valide")
    @job.remove_bad_names
    @job.pages.should == [
      "Wikipédia:Liste des articles non neutres/Foo",
      "Wikipédia:Liste des articles non neutres/Baz",
      "Wikipédia:Liste des articles non neutres/Bar",
    ]
  end
  
  def parser_should_return(content, links)
    parser = mock("parser")
    Piglobot::Parser.should_receive(:new).with().and_return(parser)
    parser.should_receive(:internal_links).with(content).and_return(links)
  end
  
  it "should remove cited" do
    links = ["/Foo", "Bar"]
    @job.pages = ["Wikipédia:Liste des articles non neutres/Foo", "Wikipédia:Liste des articles non neutres/Bar"]
    
    @wiki.should_receive(:get).with("Wikipédia:Liste des articles non neutres").and_return("content")
    parser_should_return("content", links)
    @job.should_receive(:log).with("1 articles non cités")
    @job.remove_cited
    @job.pages.should == ["Wikipédia:Liste des articles non neutres/Bar"]
  end
  
  it "should raise an error if none are cited" do
    @job.pages = ["Foo", "Bar"]
    @wiki.should_receive(:get).with("Wikipédia:Liste des articles non neutres").and_return("content")
    parser_should_return("content", ["Baz", "Bob"])
    lambda { @job.remove_cited }.should raise_error(Piglobot::ErrorPrevention, "Aucun article de la catégorie n'est cité dans [[WP:LANN]]")
  end
  
  it "should remove already done" do
    @job.pages = ["Foo", "Bar", "Baz"]
    @wiki.should_receive(:links).with("Modèle:Archive LANN").and_return(["Foo", "bar", "Baz"])
    @job.should_receive(:log).with("1 articles non traités")
    @job.remove_already_done
    @job.pages.should == ["Bar"]
  end
  
  it "should remove active" do
    @job.pages = ["Foo", "Bar"]
    Time.should_receive(:now).with().and_return(Time.local(2007, 10, 3, 23, 56, 12, 13456))
    @wiki.should_receive(:history).with("Foo", 1).and_return([
      { :author => "author", :date => Time.local(2007, 9, 26, 23, 56, 13, 0), :oldid => "oldid" }
    ])
    @wiki.should_receive(:history).with("Bar", 1).and_return([
      { :author => "author2", :date => Time.local(2007, 9, 26, 23, 56, 12, 0), :oldid => "oldid2" }
    ])
    @job.should_receive(:log).with("[[Bar]] ignoré car actif")
    @job.should_receive(:log).with("1 articles inactifs")
    @job.remove_active
    @job.pages.should == ["Foo"]
  end
  
  it "should remove if history is empty" do
    @job.pages = ["Foo", "Bar"]
    Time.should_receive(:now).with().and_return(Time.local(2007, 10, 3, 23, 56, 12, 13456))
    @wiki.should_receive(:history).with("Foo", 1).and_return([])
    @wiki.should_receive(:history).with("Bar", 1).and_return([
      { :author => "author2", :date => Time.local(2007, 9, 26, 23, 56, 13, 0), :oldid => "oldid2" }
    ])
    @job.should_receive(:log).with("[[Foo]] ignoré car sans historique")
    @job.should_receive(:log).with("1 articles inactifs")
    @job.remove_active
    @job.pages.should == ["Bar"]
  end
  
  it "should remove active talk" do
    @job.pages = ["Foo", "Bar"]
    now = 
    Time.should_receive(:now).with().and_return(Time.local(2007, 10, 3, 23, 56, 12))
    @wiki.should_receive(:history).with("Discussion Foo", 1).and_return([
      { :author => "author", :date => Time.local(2007, 9, 26, 23, 57, 0), :oldid => "oldid" }
    ])
    @wiki.should_receive(:history).with("Discussion Bar", 1).and_return([
      { :author => "author2", :date => Time.local(2007, 9, 26, 23, 56, 0), :oldid => "oldid2" }
    ])
    @job.should_receive(:log).with("[[Bar]] ignoré car discussion active")
    @job.should_receive(:log).with("1 articles avec discussion inactive")
    @job.remove_active_talk
    @job.pages.should == ["Foo"]
  end
  
  it "should not remove if talk history is empty" do
    @job.pages = ["Foo", "Bar"]
    Time.stub!(:now).and_return(Time.local(2007, 10, 3, 23, 56, 12))
    @wiki.should_receive(:history).with("Discussion Foo", 1).and_return([])
    @wiki.should_receive(:history).with("Discussion Bar", 1).and_return([
      { :author => "author2", :date => Time.local(2007, 9, 26, 23, 57, 0), :oldid => "oldid2" }
    ])
    @job.should_receive(:log).with("2 articles avec discussion inactive")
    @job.remove_active_talk
    @job.pages.should == ["Foo", "Bar"]
  end
  
  it "should use Piglobot::Tools.log on log" do
    Piglobot::Tools.should_receive(:log).with("text")
    @job.log("text")
  end
  
  def time_travel(*now)
    Time.should_receive(:now).and_return(Time.local(*now))
  end
  
  def next_history_date(page, *now)
    @wiki.should_receive(:history).with(page, 1).and_return([
      { :author => "author2", :date => Time.local(*now), :oldid => "oldid2" }
    ])
  end
  
  def next_history_empty(page)
    @wiki.should_receive(:history).with(page, 1).and_return([])
  end
  
  it "should detect active page when page history is recent" do
    time_travel(2007, 10, 3, 23, 56, 12)
    next_history_date("foo", 2007, 9, 26, 23, 57, 0)
    @job.active?("foo").should == true
  end
  
  it "should detect active page when page history is old but talk history is recent" do
    time_travel(2007, 10, 3, 23, 56, 12)
    next_history_date("foo", 2007, 9, 26, 23, 56, 0)
    next_history_date("Discussion foo", 2007, 9, 26, 23, 57, 0)
    @job.active?("foo").should == true
  end
  
  it "should detect inactive page when both histories are old" do
    time_travel(2007, 10, 3, 23, 56, 12)
    next_history_date("foo", 2007, 9, 26, 23, 56, 0)
    next_history_date("Discussion foo", 2007, 9, 25, 23, 57, 0)
    @job.active?("foo").should == false
  end
  
  it "should detect inactive page when page history is old and no talk page" do
    time_travel(2007, 10, 3, 23, 56, 12)
    next_history_date("foo", 2007, 9, 26, 23, 56, 0)
    next_history_empty("Discussion foo")
    @job.active?("foo").should == false
  end
  
  it "should consider active if page history is empty (but shouldn't happend)" do
    time_travel(2007, 10, 3, 23, 56, 12)
    next_history_empty("foo")
    @job.active?("foo").should == true
  end
  
  it "should not empty page if active" do
    @job.should_receive(:active?).with("foo").and_return(true)
    @bot.should_receive(:notice).with("[[WP:LANN]] : [[foo]] non blanchie car active")
    @job.should_receive(:log).with("[[foo]] ignorée car active")
    @job.should_not_receive(:empty_page)
    @job.process_page("foo")
    @job.changed?.should == true
  end

  it "should empty page if inactive" do
    @job.should_receive(:active?).with("foo").and_return(false)
    @job.should_receive(:empty_page).with("foo")
    @job.should_receive(:empty_talk_page).with("foo")
    @job.process_page("foo")
    @job.changed?.should == true
  end
  
  it "should empty page with" do
    page = "Wikipédia:Liste des articles non neutres/Bar"
    
    @wiki.should_receive(:history).with(page, 1).and_return([
      { :author => "author2", :date => Time.now, :oldid => "123456" }
    ])
    
    content = "{{subst:Blanchiment LANN | article = [[:Bar]] | oldid = 123456 }}"
    comment = "[[Utilisateur:Piglobot/Travail#Blanchiment LANN|Blanchiment automatique de courtoisie]]"
    
    @job.should_receive(:log).with("Blanchiment de [[#{page}]]")
    @wiki.should_receive(:post).with(page, content, comment)
    @job.empty_page(page)
  end
  
  it "should empty talk page" do
    page = "Wikipédia:Liste des articles non neutres/Bar"
    
    @wiki.should_receive(:history).with("Discussion " + page, 1).and_return([
      { :author => "author2", :date => Time.now, :oldid => "123456" }
    ])
    
    content = "{{Blanchiment de courtoisie}}"
    comment = "[[Utilisateur:Piglobot/Travail#Blanchiment LANN|Blanchiment automatique de courtoisie]]"
    
    @job.should_receive(:log).with("Blanchiment de [[Discussion #{page}]]")
    @wiki.should_receive(:post).with("Discussion " + page, content, comment)
    @job.empty_talk_page(page)
  end
  
  it "should not empty inexistant talk page" do
    page = "Wikipédia:Liste des articles non neutres/Bar"
    
    @wiki.should_receive(:history).with("Discussion " + page, 1).and_return([])
    
    @job.should_receive(:log).with("Blanchiment inutile de [[Discussion #{page}]]")
    @job.empty_talk_page(page)
  end
end
