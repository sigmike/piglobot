require 'suivi_portail_informatique'

describe SuiviPortailInformatique do
  before do
    @bot = mock("bot")
    @wiki = mock("wiki")
    @bot.should_receive(:wiki).and_return(@wiki)
    
    @job = SuiviPortailInformatique.new(@bot)
  end
  
  it "should be a job" do
    @job.should be_kind_of(Piglobot::Job)
  end
  
  it "should retreive links and post them" do
    @wiki.should_receive(:links).with("Modèle:Portail informatique").and_return(["foo", "bar"])
    time = mock("time")
    Time.should_receive(:now).with().and_return(time)
    Piglobot::Tools.should_receive(:write_date).with(time).and_return("<date>")
    text = ""
    text << "<noinclude><small>''"
    text << "Liste des articles référencés par le projet « Informatique ». "
    text << "Mise à jour le <date> par {{u|Piglobot}}."
    text << "''</small></noinclude>\n"
    text << "* [[:foo]]\n"
    text << "* [[:bar]]\n"
    @wiki.should_receive(:post) do |page, content, comment|
      page.should == "Projet:Informatique/Suivi"
      content.should == text
      comment.should == "Mise à jour automatique"
    end
    @job.process
    @job.done?.should == true
  end
end
