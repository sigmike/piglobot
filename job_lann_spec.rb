
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
    links = ["Foo", "Bar"]
    @job.pages = ["Foo", "Baz"]
    
    @wiki.should_receive(:get).with("WP:LANN").and_return("content")
    @job.should_receive(:parse_internal_links).with("content").and_return(links)
    @job.remove_cited
    @job.pages.should == ["Baz"]
  end
  
  it "should respond to all methods" do
    pending "not finished yet" do
      %w(
        get_pages remove_bad_names remove_cited remove_already_done remove_active
        process_remaining parse_internal_links
      ).each do |method|
        @job.should respond_to(method)
      end
    end
  end
end
