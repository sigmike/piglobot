
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
    @bot.should_receive(:wiki) { @wiki }
    @job = LANN.new(@bot)
  end
  
  it "should be a job" do
    @job.should be_kind_of(Piglobot::Job)
  end
  
  it "should process steps" do
    @job.should_receive(:get_pages).with()
    @job.should_receive(:remove_bad_names).with()
    @job.should_receive(:remove_cited).with()
    @job.should_receive(:remove_already_done).with()
    @job.should_receive(:remove_active).with()
    @job.should_receive(:remove_active_talk).with()
    @job.should_receive(:process_remaining).with()
    @job.process
  end
  
  it "should get pages" do
    items = ["Foo", "Bar", "Baz:Baz"]
    category = "Wikipédia:Archives Articles non neutres"
    @wiki.should_receive(:category).with(category).and_return(items)
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
    @job.remove_bad_names
    @job.pages.should == [
      "Wikipédia:Liste des articles non neutres/Foo",
      "Wikipédia:Liste des articles non neutres/Baz",
      "Wikipédia:Liste des articles non neutres/Bar",
    ]
  end
  
  it "should remove cited" do
    links = ["/Foo", "Bar"]
    @job.pages = ["Wikipédia:Liste des articles non neutres/Foo", "Wikipédia:Liste des articles non neutres/Bar"]
    
    @wiki.should_receive(:get).with("WP:LANN").and_return("content")
    @job.should_receive(:parse_internal_links).with("content").and_return(links)
    @job.remove_cited
    @job.pages.should == ["Wikipédia:Liste des articles non neutres/Bar"]
  end
  
  it "should remove already done" do
    @job.pages = ["Foo", "Bar", "Baz"]
    @wiki.should_receive(:links).with("Modèle:Archive LANN").and_return(["Foo", "bar", "Baz"])
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
    @job.remove_active
    @job.pages.should == ["Bar"]
  end
  
  it "should remove active talk" do
    @job.pages = ["Foo", "Bar"]
    Time.should_receive(:now).with().and_return(Time.local(2007, 10, 3, 23, 56, 12, 13456))
    @wiki.should_receive(:history).with("Discussion Foo", 1).and_return([
      { :author => "author", :date => Time.local(2007, 9, 26, 23, 56, 13, 0), :oldid => "oldid" }
    ])
    @wiki.should_receive(:history).with("Discussion Bar", 1).and_return([
      { :author => "author2", :date => Time.local(2007, 9, 26, 23, 56, 12, 0), :oldid => "oldid2" }
    ])
    @job.remove_active_talk
    @job.pages.should == ["Foo"]
  end
  
  it "should not remove if talk history is empty" do
    @job.pages = ["Foo", "Bar"]
    Time.should_receive(:now).with().and_return(Time.local(2007, 10, 3, 23, 56, 12, 13456))
    @wiki.should_receive(:history).with("Discussion Foo", 1).and_return([])
    @wiki.should_receive(:history).with("Discussion Bar", 1).and_return([
      { :author => "author2", :date => Time.local(2007, 9, 26, 23, 56, 13, 0), :oldid => "oldid2" }
    ])
    @job.remove_active_talk
    @job.pages.should == ["Foo", "Bar"]
  end
  
  it "should process remaining" do
    @job.pages = ["Foo", "Bar"]
    @job.should_receive(:process_page).with("Foo")
    @job.should_receive(:process_page).with("Bar")
    @job.process_remaining
  end
  
  it "should process page" do
    pending
  end
  
  it "should parse internal links" do
    pending
  end
end
