describe Piglobot::HomonymPrevention do
  before do
    @bot = mock("bot")
    @wiki = mock("wiki")
    @bot.should_receive(:wiki).with().and_return(@wiki)
    @job = Piglobot::HomonymPrevention.new(@bot)
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

module RandomTemplate
  module_function
  def random_name
    chars = ((0..25).map { |i| [?a + i, ?A + i] }.flatten.map { |c| c.chr } + [" ", "_", "-"]).flatten
    @infobox_name ||= (1..(rand(20)+1)).map { chars[rand(chars.size)] }.join
  end
end

describe Piglobot::InfoboxRewriter do
  before do
    @data = nil
    @bot = mock("bot")
    @wiki = mock("wiki")
    @editor = mock("editor")
    @bot.should_receive(:wiki).and_return(@wiki)
    Piglobot::Editor.should_receive(:new).with(@bot).and_return(@editor)
    @name = RandomTemplate.random_name
    @link = "link"
    @links = [@link]
    @rewriter = Piglobot::InfoboxRewriter.new(@bot, @name, @links)
  end
  
  it "should get infobox links when data is empty" do
    @wiki.should_receive(:links).with(@link).and_return(["Foo", "Bar", "Baz"])
    @bot.should_receive(:notice).with("3 articles à traiter pour #@name")
    @editor.should_receive(:setup).with(@name)
    @rewriter.process
    @rewriter.changed?.should == true
    @rewriter.data.should == ["Foo", "Bar", "Baz"]
  end
  
  it "should get infobox multiple links when data is empty" do
    @rewriter.links = ["First", "Second"]
    @wiki.should_receive(:links).with("First").and_return(["Foo", "Bar", "Baz"])
    @wiki.should_receive(:links).with("Second").and_return(["A", "Bar", "C", "D"])
    @bot.should_receive(:notice).with("6 articles à traiter pour #@name")
    @editor.should_receive(:setup).with(@name)
    @rewriter.process
    @rewriter.changed?.should == true
    @rewriter.data.sort.should == ["Foo", "Bar", "Baz", "A", "C", "D"].sort
  end
  
  it "should send infobox links to InfoboxEditor" do
    @rewriter.data = ["Article 1", "Article 2"]
    @wiki.should_receive(:get).with("Article 1").and_return("foo")
    infobox = mock("infobox")
    @editor.should_receive(:current_article=).with("Article 1").ordered
    @editor.should_receive(:parse_infobox).with("foo").ordered.and_return(infobox)
    @editor.should_receive(:write_infobox).with(infobox).ordered.and_return("result")
    comment = "[[Utilisateur:Piglobot/Travail##@name|Correction automatique]] de l'[[Modèle:#@name|#@name]]"
    @wiki.should_receive(:post).with("Article 1", "result", comment)
    @editor.should_receive(:setup).with(@name)
    @rewriter.process
    @rewriter.changed?.should == true
    @rewriter.data.should == ["Article 2"]
  end
  
  it "should not write infobox if none found" do
    @rewriter.data = ["Article 1", "Article 2"]
    @wiki.should_receive(:get).with("Article 1").and_return("foo")
    @editor.should_receive(:current_article=).with("Article 1")
    @editor.should_receive(:parse_infobox).with("foo").and_return(nil)
    @bot.should_receive(:notice).with("#@name non trouvée dans l'article", "Article 1")
    @editor.should_receive(:setup).with(@name)
    @rewriter.process
    @rewriter.changed?.should == true
    @rewriter.data.should == ["Article 2"]
  end
  
  it "should not write infobox if nothing changed" do
    @rewriter.data = ["Article 1", "Article 2"]
    @wiki.should_receive(:get).with("Article 1").and_return("foo")
    infobox = mock("infobox")
    @editor.should_receive(:current_article=).with("Article 1")
    @editor.should_receive(:parse_infobox).with("foo").and_return(infobox)
    @editor.should_receive(:write_infobox).with(infobox).and_return("foo")
    text = "[[Article 1]] : Aucun changement nécessaire dans l'#@name"
    Piglobot::Tools.should_receive(:log).with(text).once
    @editor.should_receive(:setup).with(@name)
    @rewriter.process
    @rewriter.changed?.should == false
    @rewriter.data.should == ["Article 2"]
  end
  
  it "should log parsing error" do
    @rewriter.data = ["Article 1", "Article 2"]
    @wiki.should_receive(:get).with("Article 1").and_return("foo")
    infobox = mock("infobox")
    @editor.should_receive(:current_article=).with("Article 1")
    @editor.should_receive(:parse_infobox).with("foo").and_raise(Piglobot::ErrorPrevention.new("error message"))
    @bot.should_receive(:notice).with("error message", "Article 1")
    @editor.should_receive(:setup).with(@name)
    @rewriter.process
    @rewriter.changed?.should == true
    @rewriter.data.should == ["Article 2"]
  end
  
  it "should get infobox links when list is empty" do
    @rewriter.data = []
    @wiki.should_receive(:links).with(@link).and_return(["A", "B"])
    @bot.should_receive(:notice).with("2 articles à traiter pour #@name")
    @editor.should_receive(:setup).with(@name)
    @rewriter.process
    @rewriter.changed?.should == true
    @rewriter.data.should == ["A", "B"]
  end
  
  it "should ignore links in namespace" do
    @rewriter.data = []
    @wiki.should_receive(:links).with(@link).and_return(["A", "B", "C:D", "E:F", "G::H", "I:J"])
    expected = ["A", "B", "G::H"]
    @bot.should_receive(:notice).with("#{expected.size} articles à traiter pour #@name")
    @editor.should_receive(:setup).with(@name)
    @rewriter.process
    @rewriter.changed?.should == true
    @rewriter.data.should == expected
  end
end

describe Piglobot::InfoboxSoftware do
  before do
    @bot = mock("bot")
    @wiki = mock("wiki")
    @bot.should_receive(:wiki).and_return(@wiki, @wiki)
    @job = Piglobot::InfoboxSoftware.new(@bot)
  end
  
  it "should have infobox" do
    @job.infobox.should == "Infobox Logiciel"
  end
  
  it "should have links" do
    @job.links.should == ["Modèle:Infobox Logiciel"]
  end
end

describe Piglobot, " on real case" do
  it "should continue Infobox Logiciel" do
    @wiki = mock("wiki")
    Piglobot::Wiki.should_receive(:new).and_return(@wiki)
    @bot = Piglobot.new
    @bot.job = "Infobox Logiciel"
    
    File.should_receive(:read).with("data.yaml").and_return({
      "Foo" => "Bar",
      "Infobox Logiciel" => ["Blender", "GNU Emacs"],
      "Infobox Aire protégée" => ["Foo"],
    }.to_yaml)
    
    @wiki.should_receive(:get).with("Blender").and_return("{{Infobox Logiciel | name = Blender }}\nBlender...")
    @wiki.should_receive(:post) do |article, content, comment|
      article.should == "Blender"
      content.should == "{{Infobox Logiciel\n| nom = Blender\n}}\nBlender..."
      comment.should =~ /Correction automatique/
      comment.should =~ /Infobox Logiciel/
    end
    file = mock("file")
    File.should_receive(:open).with("data.yaml", "w").and_yield(file)
    file.should_receive(:write).with({
      "Foo" => "Bar",
      "Infobox Logiciel" => ["GNU Emacs"],
      "Infobox Aire protégée" => ["Foo"],
    }.to_yaml)
    
    @bot.process
  end
end
