=begin
    Copyright (c) 2007 by Piglop
    This file is part of Piglobot.

    Piglobot is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Piglobot is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Foobar.  If not, see <http://www.gnu.org/licenses/>.
=end

require 'piglobot'

module PiglobotHelper
  def create_bot
    @wiki = mock("wiki")
    @dump = mock("dump")
    @editor = mock("editor")
    Piglobot::Wiki.should_receive(:new).and_return(@wiki)
    Piglobot::Dump.should_receive(:new).once.with(@wiki).and_return(@dump)
    Piglobot::Editor.should_receive(:new).once.with(@wiki).and_return(@editor)
    received_bot = nil
    @editor.should_receive(:bot=) { |bot| received_bot = bot }
    @bot = Piglobot.new
    received_bot.should == @bot
    @bot
  end
end

describe Piglobot, :shared => true do
  include PiglobotHelper
  
  before do
    create_bot
  end
  
  it "should initialize data on first process" do
    @dump.should_receive(:load_data).and_return(nil)
    @dump.should_receive(:save_data).with({})
    @bot.process.should == false
  end
  
  it "should fail when job is nil" do
    @bot.job = nil
    @dump.should_receive(:load_data).and_return({})
    lambda { @bot.process }.should raise_error(RuntimeError, "Invalid job: nil")
  end

  it "should fail when job is invalid" do
    @bot.job = "Foo"
    @dump.should_receive(:load_data).and_return({})
    lambda { @bot.process }.should raise_error(RuntimeError, "Invalid job: \"Foo\"")
  end

  [
    "STOP",
    "stop",
    "Stop",
    "fooStOpbar",
    "\nStop!\nsnul",
  ].each do |text|
    it "should return false and log on safety_check when #{text.inspect} is on disable page" do
      @wiki.should_receive(:get).with("Utilisateur:Piglobot/Arrêt d'urgence").and_return(text)
      Piglobot::Tools.should_receive(:log).with("Arrêt d'urgence : #{text}").once
      @bot.safety_check.should == false
    end
  end
  
  [
    "STO",
    "foo",
    "S t o p",
    "ST\nOP",
  ].each do |text|
    it "should return true on safety_check when #{text.inspect} is on disable page" do
      @wiki.should_receive(:get).with("Utilisateur:Piglobot/Arrêt d'urgence").and_return(text)
      @bot.safety_check.should == true
    end
  end
  
  it "should sleep 60 seconds on sleep" do
    log_done = false
    Piglobot::Tools.should_receive(:log).with("Sleep 60 seconds").once {
      log_done = true
    }
    Kernel.should_receive(:sleep).ordered.with(60).once {
      log_done.should == true
    }
    @bot.sleep
  end
  
  it "should sleep 10 minutes on long_sleep" do
    log_done = false
    Piglobot::Tools.should_receive(:log).with("Sleep 10 minutes").once {
      log_done = true
    }
    Kernel.should_receive(:sleep).ordered.with(10*60).once {
      log_done.should == true
    }
    @bot.long_sleep
  end
  
  it "should sleep 10 seconds on short_sleep" do
    log_done = false
    Piglobot::Tools.should_receive(:log).with("Sleep 10 seconds").once {
      log_done = true
    }
    Kernel.should_receive(:sleep).ordered.with(10).once {
      log_done.should == true
    }
    @bot.short_sleep
  end
  
  it "should log error" do
    e = AnyError.new("error message")
    e.should_receive(:backtrace).and_return(["backtrace 1", "backtrace 2"])
    Piglobot::Tools.should_receive(:log).with("error message (AnyError)\nbacktrace 1\nbacktrace 2").once
    @bot.should_receive(:notice).with("error message")
    @bot.log_error(e)
  end
  
  it "should safety_check, process and sleep on step" do
    @bot.should_receive(:safety_check).with().once.and_return(true)
    @bot.should_receive(:process).with().once.and_return(true)
    @bot.should_receive(:sleep).with().once
    @bot.step
  end
  
  it "should short_sleep if process returned false" do
    @bot.should_receive(:safety_check).with().once.and_return(true)
    @bot.should_receive(:process).with().once.and_return(false)
    @bot.should_receive(:short_sleep).with().once
    @bot.step
  end
  
  it "should not process if safety_check failed" do
    @bot.should_receive(:safety_check).with().once.and_return(false)
    @bot.should_receive(:sleep).with().once
    @bot.step
  end
  
  it "should long_sleep on Internal Server Error during safety_check" do
    @bot.should_receive(:safety_check).with().once.and_raise(MediaWiki::InternalServerError)
    @bot.should_receive(:long_sleep).with().once
    @bot.step
  end
  
  it "should long_sleep on Internal Server Error during process" do
    @bot.should_receive(:safety_check).with().once.and_return(true)
    @bot.should_receive(:process).with().once.and_raise(MediaWiki::InternalServerError)
    @bot.should_receive(:long_sleep).with().once
    @bot.step
  end
  
  class AnyError < Exception; end
  it "should log exceptions during process" do
    @bot.should_receive(:safety_check).with().once.and_return(true)
    e = AnyError.new
    @bot.should_receive(:process).with().once.and_raise(e)
    @bot.should_receive(:log_error).with(e).once
    @bot.should_receive(:sleep).with().once
    @bot.step
  end
  
  it "should abort on Interrupt during process" do
    @bot.should_receive(:safety_check).with().once.and_return(true)
    @bot.should_receive(:process).with().once.and_raise(Interrupt.new("interrupt"))
    lambda { @bot.step }.should raise_error(Interrupt)
  end
  
  it "should abort on Interrupt during safety_check" do
    @bot.should_receive(:safety_check).with().once.and_raise(Interrupt.new("interrupt"))
    lambda { @bot.step }.should raise_error(Interrupt)
  end
  
  it "should abort on Interrupt during sleep" do
    @bot.should_receive(:safety_check).with().once.and_return(true)
    @bot.should_receive(:process).with().once.and_return(true)
    @bot.should_receive(:sleep).with().once.and_raise(Interrupt.new("interrupt"))
    lambda { @bot.step }.should raise_error(Interrupt)
  end
  
  it "should have a log page" do
    @bot.log_page.should == "Utilisateur:Piglobot/Journal"
  end
  
  it "should append to log on notice" do
    text = "~~~~~ : foo bar"
    @wiki.should_receive(:append).with(@bot.log_page, "* #{text}", text)
    @bot.notice "foo bar"
  end
  
  it "should append link to article on notice with link" do
    text = "~~~~~ : [[article name]] : foo bar"
    @wiki.should_receive(:append).with(@bot.log_page, "* #{text}", text)
    @bot.notice "foo bar", "article name"
  end

  it "should append link to current_article on notice with link" do
    text = "~~~~~ : [[current article name]] : foo bar"
    @wiki.should_receive(:append).with(@bot.log_page, "* #{text}", text)
    @bot.current_article = "current article name"
    @bot.notice "foo bar"
  end
end

describe Piglobot, " running" do
  it "should list jobs" do
    Piglobot.jobs.should == ["Infobox Logiciel", "Homonymes", "Infobox Aire protégée"]
  end
  
  it "should step continously until Interrupt on run" do
    bot = mock("bot")
    Piglobot.should_receive(:new).with().and_return(bot)
    bot.should_receive(:job=).with("foo")
    step = 0
    bot.should_receive(:step).with().exactly(3).and_return {
      step += 1
      raise Interrupt.new("interrupt") if step == 3
    }
    lambda { Piglobot.run("foo") }.should raise_error(Interrupt)
  end
end

describe Piglobot, " working on homonyms" do
  it_should_behave_like "Piglobot"

  before do
    @bot.job = "Homonymes"
  end
  
  it "should store links to Chine and keep Infobox Logiciel" do
    @dump.should_receive(:load_data).and_return({ "Infobox Logiciel" => ["Foo", "Bar", "Baz"]})
    @wiki.should_receive(:links, "Chine").and_return(["a", "b", "c"])
    Piglobot::Tools.should_receive(:log).with("3 liens vers la page d'homonymie [[Chine]]")
    @dump.should_receive(:save_data).with({ "Infobox Logiciel" => ["Foo", "Bar", "Baz"], "Homonymes" => { "Chine" => {"Last" => ["a", "b", "c"], "New" => [] }}})
    @bot.process.should == false
  end
  
  it "should find new links" do
    @dump.should_receive(:load_data).and_return({"Homonymes" => 
      { "Chine" => {"Last" => ["a", "b", "c"], "New" => [] }}
    })
    @wiki.should_receive(:links, "Chine").and_return(["a", "b", "d", "c", "e"])
    Piglobot::Tools.should_receive(:log).with("Un lien vers [[Chine]] a été ajouté dans [[d]]")
    Piglobot::Tools.should_receive(:log).with("Un lien vers [[Chine]] a été ajouté dans [[e]]")
    @dump.should_receive(:save_data).with({"Homonymes" => { "Chine" => {"Last" => ["a", "b", "d", "c", "e"], "New" => ["d", "e"] }}})
    @bot.process.should == false
  end
  
  it "should keep new links" do
    @dump.should_receive(:load_data).and_return({"Homonymes" => 
      { "Chine" => {"Last" => ["a", "b"], "New" => ["b"] }}
    })
    @wiki.should_receive(:links, "Chine").and_return(["a", "b"])
    Piglobot::Tools.should_not_receive(:log)
    @dump.should_receive(:save_data).with({"Homonymes" => { "Chine" => {"Last" => ["a", "b"], "New" => ["b"] }}})
    @bot.process
  end
  
  it "should ignore removed pending links" do
    @dump.should_receive(:load_data).and_return({"Homonymes" => 
      { "Chine" => {"Last" => ["a", "b"], "New" => ["b"] }}
    })
    @wiki.should_receive(:links, "Chine").and_return(["a"])
    Piglobot::Tools.should_receive(:log).with("Le lien vers [[Chine]] dans [[b]] a été supprimé avant d'être traité")
    @dump.should_receive(:save_data).with({"Homonymes" => { "Chine" => {"Last" => ["a"], "New" => [] }}})
    @bot.process
  end
end

describe Piglobot, " working on infoboxes" do
  it_should_behave_like "Piglobot"
  
  [
    ["Infobox Logiciel", ["Modèle:Infobox Logiciel"]],
    ["Infobox Aire protégée", ["Modèle:Infobox Aire protégée", "Modèle:Infobox aire protégée"]],
  ].each do |infobox, link|
    it "should process #{infobox}" do
      data = mock("data")
      changes = mock("changes")
      
      @dump.should_receive(:load_data).and_return(data)
      @editor.should_receive(:setup).with(infobox)
      @bot.should_receive(:process_infobox).with(data, infobox, link).and_return(changes)
      @dump.should_receive(:save_data).with(data)
      
      @bot.job = infobox
      @bot.process.should == changes
    end
  end
end

module RandomTemplate
  module_function
  def random_name
    chars = ((0..25).map { |i| [?a + i, ?A + i] }.flatten.map { |c| c.chr } + [" ", "_", "-"]).flatten
    @infobox_name ||= (1..(rand(20)+1)).map { chars[rand(chars.size)] }.join
  end
end

describe Piglobot, " processing random infobox (#{RandomTemplate.random_name.inspect})" do
  include PiglobotHelper
  
  before do
    @data = { "Foo" => "Bar"}
    create_bot
    @name = RandomTemplate.random_name
    @link = "link"
    @links = [@link]
  end
  
  def process
    @bot.process_infobox(@data, @name, @links)
  end
  
  def set_data(data)
    @data = { @name => data, "Foo" => "Bar" }
  end
  
  def get_data
    @data[@name]
  end
  
  after do
    @data["Foo"].should == "Bar"
  end
  
  it "should get infobox links when data is empty" do
    @wiki.should_receive(:links).with(@link).and_return(["Foo", "Bar", "Baz"])
    @bot.should_receive(:notice).with("3 articles à traiter pour #@name")
    process.should == true
    get_data.should == ["Foo", "Bar", "Baz"]
  end
  
  it "should get infobox multiple links when data is empty" do
    @links = ["First", "Second"]
    @wiki.should_receive(:links).with("First").and_return(["Foo", "Bar", "Baz"])
    @wiki.should_receive(:links).with("Second").and_return(["A", "Bar", "C", "D"])
    @bot.should_receive(:notice).with("6 articles à traiter pour #@name")
    process.should == true
    get_data.sort.should == ["Foo", "Bar", "Baz", "A", "C", "D"].sort
  end
  
  it "should send infobox links to InfoboxEditor" do
    set_data ["Article 1", "Article 2"]
    @wiki.should_receive(:get).with("Article 1").and_return("foo")
    infobox = mock("infobox")
    @editor.should_receive(:parse_infobox).with("foo") do
      @bot.current_article.should == "Article 1"
      infobox
    end
    @editor.should_receive(:write_infobox).with(infobox) do
      @bot.current_article.should == "Article 1"
      "result"
    end
    comment = "[[Utilisateur:Piglobot/Travail##@name|Correction automatique]] de l'[[Modèle:#@name|#@name]]"
    @wiki.should_receive(:post).with("Article 1", "result", comment)
    process.should == true
    @bot.current_article.should == nil
    get_data.should == ["Article 2"]
  end
  
  it "should not write infobox if none found" do
    set_data ["Article 1", "Article 2"]
    @wiki.should_receive(:get).with("Article 1").and_return("foo")
    @editor.should_receive(:parse_infobox).with("foo").and_return(nil)
    @bot.should_receive(:notice).with("#@name non trouvée dans l'article", "Article 1")
    process.should == true
    get_data.should == ["Article 2"]
  end
  
  it "should not write infobox if nothing changed" do
    set_data ["Article 1", "Article 2"]
    @wiki.should_receive(:get).with("Article 1").and_return("foo")
    infobox = mock("infobox")
    @editor.should_receive(:parse_infobox).with("foo").and_return(infobox)
    @editor.should_receive(:write_infobox).with(infobox).and_return("foo")
    text = "[[Article 1]] : Aucun changement nécessaire dans l'#@name"
    Piglobot::Tools.should_receive(:log).with(text).once
    process.should == false
    get_data.should == ["Article 2"]
  end
  
  it "should log parsing error" do
    set_data ["Article 1", "Article 2"]
    @wiki.should_receive(:get).with("Article 1").and_return("foo")
    infobox = mock("infobox")
    @editor.should_receive(:parse_infobox).with("foo").and_raise(Piglobot::ErrorPrevention.new("error message"))
    @bot.should_receive(:notice).with("error message", "Article 1")
    process.should == true
    get_data.should == ["Article 2"]
  end
  
  it "should get infobox links when list is empty" do
    set_data []
    @wiki.should_receive(:links).with(@link).and_return(["A", "B"])
    @bot.should_receive(:notice).with("2 articles à traiter pour #@name")
    process.should == true
    get_data.should == ["A", "B"]
  end
  
  it "should ignore links in namespace" do
    set_data []
    @wiki.should_receive(:links).with(@link).and_return(["A", "B", "C:D", "E:F", "G::H", "I:J"])
    expected = ["A", "B", "G::H"]
    @bot.should_receive(:notice).with("#{expected.size} articles à traiter pour #@name")
    process.should == true
    get_data.should == expected
  end
end

describe Piglobot::Editor, " with default values", :shared => true do
  before do
    @wiki = mock("wiki")
    @editor = Piglobot::Editor.new(@wiki)
    @bot = mock("bot")
    @editor.bot = @bot
    
    @template_names = []
    @filters = []
    @template_name = nil
    @name_changes = {}
    @removable_parameters = []
  end
  
  it "should have template_names" do
    @editor.template_names.should == @template_names
  end

  it "should have filters" do
    @editor.filters.should == @filters
  end

  it "should have template_name" do
    @editor.template_name.should == @template_name
  end
  
  it "should have name_changes" do
    @editor.name_changes.should == @name_changes
  end

  it "should have removable_parameters" do
    @editor.removable_parameters.should == @removable_parameters
  end
end

describe Piglobot::Editor, " with real default values" do
  it_should_behave_like "Piglobot::Editor with default values"
end

describe Piglobot::Editor, " working on Infobox Logiciel" do
  it_should_behave_like "Piglobot::Editor with default values"
  
  before do
    @editor.setup "Infobox Logiciel"
    @template_names = [
      "Infobox Logiciel",
      "Logiciel simple",
      "Logiciel_simple",
      "Logiciel",
      "Infobox Software",
      "Infobox_Software",
    ]
    @filters = [
      :rename_parameters,
      :remove_open_source,
      :remove_almost_empty,
      :remove_firefox,
      :rewrite_dates,
    ]
    @template_name = "Infobox Logiciel"
    @name_changes = {
      "dernière_version" => "dernière version",
      "date_de_dernière_version" => "date de dernière version",
      "version_avancée" => "version avancée",
      "date_de_version_avancée" => "date de version avancée",
      "os" => "environnement",
      "site_web" => "site web",
      "name" => "nom",
      "screenshot" => "image",
      "caption" => "description",
      "developer" => "développeur",
      "latest release version" => "dernière version",
      "latest release date" => "date de dernière version",
      "latest preview version" => "dernière version avancée",
      "latest preview date" => "date de dernière version avancée",
      "latest_release_version" => "dernière version",
      "latest_release_date" => "date de dernière version",
      "latest_preview_version" => "dernière version avancée",
      "latest_preview_date" => "date de dernière version avancée",
      "platform" => "environnement",
      "operating system" => "environnement",
      "operating_system" => "environnement",
      "language" => "langue",
      "genre" => "type",
      "license" => "licence",
      "website" => "site web",
    }
  end
end

describe Piglobot::Editor, " working on Infobox Aire protégée" do
  it_should_behave_like "Piglobot::Editor with default values"
  
  before do
    @editor.setup "Infobox Aire protégée"
    @template_names = [
      "Infobox Aire protégée",
      "Infobox aire protégée",
    ]
    @filters = [
      :rename_parameters,
      :remove_parameters,
      :rewrite_dates,
      :rename_image_protected_area,
      :rewrite_coordinates,
      :rewrite_area,
    ]
    @template_name = "Infobox Aire protégée"
    @name_changes = {
      "name" => "nom",
      "iucn_category" => "catégorie iucn",
      "locator_x" => "localisation x",
      "locator_y" => "localisation y",
      "top_caption" => "légende image",
      "location" => "situation",
      "localisation" => "situation",
      "nearest_city" => "ville proche",
      "area" => "superficie",
      "established" => "création",
      "visitation_num" => "visiteurs",
      "visitation_year" => "visiteurs année",
      "governing_body" => "administration",
      "web_site" => "site web",
      "comments" => "remarque",
    }
    @removable_parameters = ["back_color", "label"]
  end
  
  it "should parse and write real case" do
    text = File.read("parc_national_des_arches.txt")
    result = File.read("parc_national_des_arches_result.txt")
    infobox = @editor.parse_infobox(text)
    infobox[:parameters].should include(["name", "Arches"])
    @editor.write_infobox(infobox).should == result
  end
  
  it "should rewrite template name" do
    box = { :before => "", :after => "", :parameters => "" }
    @editor.write_infobox(box).should == "{{Infobox Aire protégée}}"
  end
end

describe Piglobot::Editor, " parsing Infobox Logiciel" do
  before do
    @wiki = mock("wiki")
    @editor = Piglobot::Editor.new(@wiki)
    @bot = mock("bot")
    @editor.bot = @bot
    @infobox = {
      :name => "Infobox Logiciel",
      :before => "",
      :after => "",
      :parameters => [],
    }
    @editor.template_names = ["Infobox Logiciel"]
  end
  
  it "should parse empty infobox" do
    @editor.parse_infobox("{{Infobox Logiciel}}").should == @infobox
  end
  
  it "should return nil on empty string" do
    @editor.parse_infobox("").should == nil
  end
  
  it "should return nil on 'foo'" do
    @editor.parse_infobox("foo").should == nil
  end
  
  it "should return nil on '{{foo}}'" do
    @editor.parse_infobox("{{foo}}").should == nil
  end
  
  it "should return nil on '{{Infobox Logiciel}'" do
    @editor.parse_infobox("{{Infobox Logiciel}").should == nil
  end
  
  it "should return nil on 'Infobox Logiciel'" do
    @editor.parse_infobox("Infobox Logiciel").should == nil
  end
  
  it "should keep text before infobox on parsing" do
    @infobox[:before] = "text before"
    @editor.parse_infobox("text before{{Infobox Logiciel}}").should == @infobox
  end
  
  it "should keep text after infobox on parsing" do
    @infobox[:after] = "text after"
    @editor.parse_infobox("{{Infobox Logiciel}}text after").should == @infobox
  end
  
  it "should allow line breaks before and after" do
    @infobox[:before] = "\nfoo\n\nbar\n"
    @infobox[:after] = "bob\n\nmock\n\n"
    text = "#{@infobox[:before]}{{Infobox Logiciel}}#{@infobox[:after]}"
    @editor.parse_infobox(text).should == @infobox
  end
  
  it "should parse simple parameter" do
    text = "{{Infobox Logiciel | nom = Nom }}"
    @infobox[:parameters] = [["nom", "Nom"]]
    @editor.parse_infobox(text).should == @infobox
  end
  
  it "should parse multiple parameters" do
    text = "{{Infobox Logiciel | nom = Nom | foo = bar }}"
    @infobox[:parameters] = [["nom", "Nom"], ["foo", "bar"]]
    @editor.parse_infobox(text).should == @infobox
  end
  
  it "should parse parameters on multiple lines" do
    text = "{{Infobox Logiciel\n|\n  nom = \nNom\nsuite\n | foo\n = \nbar\n\nbaz\n\n }}"
    @infobox[:parameters] = [["nom", "Nom\nsuite"], ["foo", "bar\n\nbaz"]]
    @editor.parse_infobox(text).should == @infobox
  end
  
  it "should parse parameters with pipes" do
    text = "{{Infobox Logiciel | logo = [[Image:Logo.svg|80px]] | foo = bar }}"
    @infobox[:parameters] = [["logo", "[[Image:Logo.svg|80px]]"], ["foo", "bar"]]
    @editor.parse_infobox(text).should == @infobox
  end
  
  it "should parse parameters with template" do
    text = "{{Infobox Logiciel | date = {{Date|12|janvier|2008}} | foo = bar }}"
    @infobox[:parameters] = [["date", "{{Date|12|janvier|2008}}"], ["foo", "bar"]]
    @editor.parse_infobox(text).should == @infobox
  end
  
  it "should parse parameters with ref" do
    text = "{{Infobox Logiciel | dernière version = 1.12<ref>[http://foo.com/bar ref]</ref>}}"
    @infobox[:parameters] = [["dernière version", "1.12<ref>[http://foo.com/bar ref]</ref>"]]
    @editor.parse_infobox(text).should == @infobox
  end
  
  it "should parse parameters with new lines" do
    text = "{{Infobox Logiciel | nom = foo\n\n  bar\n | foo = bar }}"
    @infobox[:parameters] = [["nom", "foo\n\n  bar"], ["foo", "bar"]]
    @editor.parse_infobox(text).should == @infobox
  end
  
  it "should parse parameters with weird new lines" do
    text = "{{Infobox Logiciel |\nnom = foo |\nimage = |\n}}"
    @infobox[:parameters] = [["nom", "foo"], ["image", ""]]
    @editor.parse_infobox(text).should == @infobox
  end
  
  [
    ["Logiciel simple", ["Logiciel simple"]],
    ["logiciel simple", ["Logiciel simple"]],
    ["foo", ["foo", "bar"]],
    ["foo", ["bar", "foo"]],
    ["f", ["f"]],
    ["f", ["F"]],
    ["foo", ["Foo"]],
    ["Foo", ["foo"]],
  ].each do |template, template_names|
    it "should find #{template.inspect} using template_names #{template_names.inspect}" do
      @editor.template_names = template_names
      text = "{{#{template} | bob = mock }}"
      @infobox[:parameters] = [["bob", "mock"]]
      @infobox[:name] = template
      @editor.parse_infobox(text).should == @infobox
    end
  end
  
  [
    ["Logiciel Simple", ["Logiciel simple"]],
    ["foo", ["bar"]],
    ["foo", ["bar", "baz"]],
    ["foo", ["fooo"]],
    ["foo", ["fo"]],
    ["foo", ["foO"]],
    ["foO", ["foo"]],
  ].each do |template, template_names|
    it "should not find #{template.inspect} using template_names #{template_names.inspect}" do
      @editor.template_names = template_names
      text = "{{#{template} | bob = mock }}"
      @infobox[:parameters] = [["bob", "mock"]]
      @editor.parse_infobox(text).should == nil
    end
  end
  
  it "should have default template_names" do
    @editor.setup
    @editor.template_names.should == []
  end
  
  it "should parse mono.sample" do
    text = File.read("mono.sample")
    @infobox[:parameters] = [
      ["nom", "Mono"],
      ["logo", "[[Image:Mono project logo.svg|80px]]"],
      ["image", ""],
      ["description", ""],
      ["développeur", "[[Novell]]"],
      ["dernière version", "1.2.5.1"],
      ["date de dernière version", "{{Date|20|septembre|2007}}"],
      ["version avancée", ""],
      ["date de version avancée", ""],
      ["environnement", "[[Multiplate-forme]]"],
      ["langue", ""],
      ["type", ""],
      ["licence", "[[Licence Publique Générale|GPL]], [[Licence publique générale limitée GNU|LGPL]] ou [[X11]]"],
      ["site web", "[http://www.mono-project.com www.mono-project.com]"],
    ]
    @editor.parse_infobox(text)[:parameters].should == @infobox[:parameters]
  end

  it "should parse limewire.sample" do
    text = File.read("limewire.sample")
    @editor.template_names = ["Logiciel_simple"]
    box = @editor.parse_infobox(text)
    box.should_not == nil
    @editor.write_infobox(box).should_not == text
  end
  
  it "should raise an error when an html comment is over parameters (name => name)" do
    text = "{{Infobox Logiciel |\nnom = foo \n |\n <!-- image = | --> a = b\n}}"
    lambda { @editor.parse_infobox(text) }.should raise_error(Piglobot::ErrorPrevention,
      "L'infobox contient un commentaire qui dépasse un paramètre")
  end

  it "should raise an error when an html comment is over parameters (value => value)" do
    text = "{{Infobox Logiciel |\nnom = foo \n<!-- |\nimage = --> | a = b\n}}"
    lambda { @editor.parse_infobox(text) }.should raise_error(Piglobot::ErrorPrevention,
      "L'infobox contient un commentaire qui dépasse un paramètre")
  end

  it "should not raise an error when an html comment is only in value" do
    text = "{{Infobox Logiciel |\nnom= foo \n |\nimage = <!-- comment --> | <!-- a --> = b\n}}"
    lambda { @editor.parse_infobox(text) }.should_not raise_error
  end
  
  it "should raise an error when an parameter has no name" do
    text = "{{Infobox Logiciel |\nnom = foo \n |\n bar | a = b\n}}"
    lambda { @editor.parse_infobox(text) }.should raise_error(Piglobot::ErrorPrevention,
      "L'infobox contient un paramètre sans nom")
  end
end

describe Piglobot::Editor, " writing Infobox Logiciel" do
  before do
    @wiki = mock("wiki")
    @editor = Piglobot::Editor.new(@wiki)
    @infobox = {
      :before => "",
      :after => "",
      :parameters => [],
    }
    @editor.template_name = "Infobox Logiciel"
    @bot = mock("bot")
    @editor.bot = @bot
  end
  
  it "should write empty infobox" do
    @editor.write_infobox(@infobox).should == "{{Infobox Logiciel}}"
  end
  
  it "should write infobox with surrounding text" do
    @infobox[:before] = "before"
    @infobox[:after] = "after"
    @editor.write_infobox(@infobox).should == "before{{Infobox Logiciel}}after"
  end
  
  it "should write infobox with parameters" do
    @infobox[:parameters] = [["nom", "value"], ["other name", "other value"]]
    @editor.write_infobox(@infobox).should ==
      "{{Infobox Logiciel\n| nom = value\n| other name = other value\n}}"
  end
  
  it "should write infobox with new lines in parameter" do
    @infobox[:parameters] = [["nom", "first line\n  second line\nthird line"]]
    @editor.write_infobox(@infobox).should ==
      "{{Infobox Logiciel\n| nom = first line\n  second line\nthird line\n}}"
  end
  
  it "should remove [[open source]] from type" do
    params = [["type", "foo ([[open source]])"]]
    @editor.remove_open_source(params)
    params.should == [["type", "foo"]]
  end
  
  it "should remove [[open source]] and spaces from type" do
    params = [["type", "foo   ([[open source]])"]]
    @editor.remove_open_source(params)
    params.should == [["type", "foo"]]
  end
  
  [
    "?",
    "??",
    "-",
  ].each do |text|
    it "should remove values containing only #{text.inspect}" do
      params = [["foo", text], ["bar", "uh?"], ["baz", "--"]]
      @editor.remove_almost_empty(params)
      params.should == [["foo", ""], ["bar", "uh?"], ["baz", "--"]]
    end
  end
  
  it "should write unnammed parameters" do
    @infobox[:parameters] = [["foo", "foo"], ["", "bar"], [nil, "baz"]]
    @editor.write_infobox(@infobox).should ==
      "{{Infobox Logiciel\n| foo = foo\n| = bar\n| baz\n}}"
  end
  
  it "should remove values like {{{latest preview date|}}}" do
    params = [["foo", "{{{foo bar|}}}"], ["bar", "{{{bar}}}"], ["baz", "foo {{{bar|}}}"]]
    @editor.remove_almost_empty(params)
    params.should == [["foo", ""], ["bar", "{{{bar}}}"], ["baz", "foo {{{bar|}}}"]]
  end
  
  it "should remove notice about firefox screenshot" do
    params = [["image", "foo <!-- Ne pas changer la capture d'écran, sauf grand changement. Et utilisez la page d'accueil de Wikipédia pour la capture, pas la page de Firefox. Prenez une capture à une taille « normale » (de 800*600 à 1024*780), désactiver les extensions et prenez le thème par défaut. -->bar"]]
    @editor.remove_firefox(params)
    params.should == [["image", "foo bar"]]
  end
  
  it "should remove notice about firefox screenshot with newline and spaces" do
    params = [["image", "<!-- 
                             * Ne pas changer la capture d'écran, sauf grand changement.
                             * Utiliser la page d'accueil de Wikipédia pour la capture, pas la page de Firefox.
                             * Prendre une capture à une taille « normale » (de 800*600 à 1024*780).
                             * Désactiver les extensions et prendre le thème par défaut.
                             -->bar"]]
    @editor.remove_firefox(params)
    params.should == [["image", "bar"]]
  end
  
  %w(janvier février mars avril mai juin
     juillet août septembre octobre novembre décembre).map { |month|
      [month, month.capitalize]
  }.flatten.each do |month|
    emonth = month.downcase
    {
      "[[1er #{month}]] [[1998]]" => "{{date|1|#{emonth}|1998}}",
      "[[18 #{month}]] [[2005]]" => "{{date|18|#{emonth}|2005}}",
      "[[31 #{month}]] [[2036]]" => "{{date|31|#{emonth}|2036}}",
      "[[04 #{month}]] [[1950]]" => "{{date|4|#{emonth}|1950}}",
      "a[[04 #{month}]] [[1950]]" => "a[[04 #{month}]] [[1950]]",
      "[[04 #{month}]] [[1950]]b" => "[[04 #{month}]] [[1950]]b",
      "04 #{month} 1950" => "{{date|4|#{emonth}|1950}}",
      "04 #{month}? 1950" => "04 #{month}? 1950",
      "le 04 #{month} 1950" => "le 04 #{month} 1950",
      "[[04 fevrier]] [[1950]]" => "[[04 fevrier]] [[1950]]",
      "[[004 #{month}]] [[1950]]" => "[[004 #{month}]] [[1950]]",
      "[[4 #{month}]] [[19510]]" => "[[4 #{month}]] [[19510]]",
      "4 #{month} [[1951]]" => "{{date|4|#{emonth}|1951}}",
      "[[18 #{month}]], [[2005]]" => "{{date|18|#{emonth}|2005}}",
      "[[18 #{month}]] foo [[2005]]" => "[[18 #{month}]] foo [[2005]]",
      "01 [[#{month}]] [[2005]]" => "{{date|1|#{emonth}|2005}}",
      "07 [[#{month} (mois)|#{month}]] [[2005]]" => "{{date|7|#{emonth}|2005}}",
      "[[#{month}]] [[2003]]" => "[[#{month}]] [[2003]]",
      "[[#{month} (mois)|#{month}]] [[2003]]" => "[[#{month} (mois)|#{month}]] [[2003]]",
      "{{1er #{month}}} [[2007]]" => "{{date|1|#{emonth}|2007}}",
      "1{{er}} #{month} 1928" => "{{date|1|#{emonth}|1928}}",
      "{{Date|1|#{emonth}|1928}}" => "{{Date|1|#{emonth}|1928}}",
      "{{date|1|#{emonth}|1928}}" => "{{date|1|#{emonth}|1928}}",
    }.each do |text, result|
      it "should rewrite_date #{text.inspect} to #{result.inspect}" do
        @editor.rewrite_date(text).should == result
      end
    end
  end
  
  it "should apply filters" do
    params = [["foo", "bar"]]
    @editor.should_receive(:fake_filter).with(params) do |parameters|
      @editor.infobox.should == @infobox
      parameters.replace [["a", "b"]]
    end
    
    @editor.filters = [:fake_filter]
    @infobox[:parameters] = params
    @editor.write_infobox(@infobox).should ==
      "{{Infobox Logiciel\n| a = b\n}}"
  end
  
  it "should call rewrite_date with all values and replace with result" do
    params = [
      ["foo", "bar"],
      ["baz", "baz2"],
    ]
    @editor.should_receive(:rewrite_date).with("bar").and_return("1")
    @editor.should_receive(:rewrite_date).with("baz2").and_return("baz2")
    @editor.rewrite_dates(params)
    params.should == [
      ["foo", "1"],
      ["baz", "baz2"],
    ]
  end
  
  it "should rename_parameters with name_changes" do
    params = [["foo", "foo"], ["bar baz", "value"]]
    @editor.name_changes = { "foo" => "new foo", "bar baz" => "bob" }
    @editor.rename_parameters(params)
    params.should == [["new foo", "foo"], ["bob", "value"]]
  end
  
  ["infobox aire protégée", "Infobox aire protégée"].each do |name|
    it "should rename image on protected_area when template is #{name}" do
      params = [["image", "map"], ["top_image", "illustration"]]
      @editor.infobox = { :name => name }
      @editor.rename_image_protected_area(params)
      params.should == [["carte", "map"], ["image", "illustration"]]
    end
  
    it "should rename image on protected_area when template is #{name}, inverted order" do
      params = [["top_image", "illustration"], ["image", "map"]]
      @editor.infobox = { :name => name }
      @editor.rename_image_protected_area(params)
      params.should == [["image", "illustration"], ["carte", "map"]]
    end
  end

  it "should not rename image on protected_area when already done" do
    params = [["carte", "map"], ["image", "illustration"]]
    @editor.infobox = { :name => "Infobox Aire protégée" }
    @editor.rename_image_protected_area(params)
    params.should == [["carte", "map"], ["image", "illustration"]]
  end

  it "should not rename image on protected_area when already done, inverted order" do
    params = [["image", "illustration"], ["carte", "map"]]
    @editor.infobox = { :name => "Infobox Aire protégée" }
    @editor.rename_image_protected_area(params)
    params.should == [["image", "illustration"], ["carte", "map"]]
  end
  
  it "should rewrite coordinates" do
    params = [
      ["foo", "bar"],
      ["lat_degrees", "1"],
      ["lat_minutes", "2"],
      ["lat_seconds", "3"],
      ["lat_direction", "4"],
      ["long_degrees", "5"],
      ["long_minutes", "6"],
      ["long_seconds", "7"],
      ["long_direction", "8"],
      ["bar", "baz"]
    ]
    @editor.rewrite_coordinates(params)
    params.should == [["foo", "bar"], ["coordonnées", "{{coord|1|2|3|4|5|6|7|8}}"], ["bar", "baz"]]
  end
  
  it "should rewrite coordinates without seconds" do
    params = [
      ["foo", "bar"],
      ["lat_degrees", "1"],
      ["lat_minutes", "2"],
      ["lat_seconds", ""],
      ["lat_direction", "4"],
      ["long_degrees", "5"],
      ["long_minutes", "6"],
      ["long_seconds", ""],
      ["long_direction", "8"],
      ["bar", "baz"]
    ]
    @editor.rewrite_coordinates(params)
    params.should == [["foo", "bar"], ["coordonnées", "{{coord|1|2|4|5|6|8}}"], ["bar", "baz"]]
  end
  
  it "should rewrite coordinates without data" do
    params = [
      ["foo", "bar"],
      ["lat_degrees", ""],
      ["lat_minutes", ""],
      ["lat_seconds", ""],
      ["lat_direction", ""],
      ["long_degrees", ""],
      ["long_minutes", ""],
      ["long_seconds", ""],
      ["long_direction", ""],
      ["bar", "baz"]
    ]
    @editor.rewrite_coordinates(params)
    params.should == [["foo", "bar"], ["coordonnées", "<!-- {{coord|...}} -->"], ["bar", "baz"]]
  end
  
  it "should not rewrite anything when no coordinates" do
    params = [
      ["alat_degrees", "1"],
      ["alat_minutes", "2"],
      ["alat_seconds", "3"],
      ["alat_direction", "4"],
      ["along_degrees", "5"],
      ["along_minutes", "6"],
      ["along_seconds", "7"],
      ["along_direction", "8"],
    ]
    @editor.rewrite_coordinates(params)
    params.should == [
      ["alat_degrees", "1"],
      ["alat_minutes", "2"],
      ["alat_seconds", "3"],
      ["alat_direction", "4"],
      ["along_degrees", "5"],
      ["along_minutes", "6"],
      ["along_seconds", "7"],
      ["along_direction", "8"],
    ]
  end
  
  %w( area superficie ).each do |name|

    [
      ["{{unité|4800|km|2}}", "4800"],
      ["{{unité|150|km|2}}", "150"],
      ["{{formatnum:2219799}} acres<br />{{formatnum:8983}} km²", "8983"],
      ["{{unité|761266|acres}}<br />{{unité|3081|km|2}}", "3081"],
      ["76 519 acres<br />310 km²", "310"],
      ["741,5 km²", "741.5"],
      ["35 835 acres<br />145 km²", "145"],
      ["10 878 km²", "10878"],
      ["337 598 acres<br />1 366,21 km²", "1366.21"],
      ["789 745 acres<br />3 196 km²", "3196"],
      ["{{formatnum:922561}} acres ({{formatnum:3734}} km²)", "3734"],
      ["112 511 acres<br />455 km²", "455"],
      ["163 513 ha (1,635 km²)", "1635"],
      ["{{formatnum:3400}} km²", "3400"],
      ["{{formatnum:13762}} km²", "13762"],
      ["244 km²", "244"],
      ["22 470 ha", "224.7"],
      ["590 ha", "5.9"],
      ["3 ha", "0.03"],
      ["1 438 km<sup>2<sup>", "1438"],
      ["12345", "12345"],
      ["123.45", "123.45"],
    ].each do |value, result|
      expected = "{{unité|#{result}|km|2}}"
      it "should rewrite #{name} with #{value.inspect} to #{expected.inspect}" do
        params = [[name, value], ["foo", "bar"]]
        @editor.rewrite_area(params)
        params.should == [[name, expected], ["foo", "bar"]]
      end
    end
    
    [
      ["17 300 ha (zone centrale)<br/>16 200 ha (zone périphérique)",
       "{{unité|173.0|km|2}} (zone centrale)<br/>{{unité|162.0|km|2}} (zone périphérique)"],
      ["", "<!-- {{unité|...|km|2}} -->"],
    ].each do |value, result|
      it "should rewrite #{name} with #{value.inspect} to #{result.inspect}" do
        params = [[name, value], ["foo", "bar"]]
        @editor.rewrite_area(params)
        params.should == [[name, result], ["foo", "bar"]]
      end
    end
    
    [
      "foo",
      "?",
      "36 m",
      "12 km² foo",
      "foo {{formatnum:12}} km²",
      "36 hab",
      "foo 3 ha",
      "497,3 km² en 2005",
    ].each do |value|
      it "should raise an ErrorPrevention on rewrite #{name} with #{value.inspect}" do
        params = [[name, value]]
        @bot.should_receive(:notice).with("Superficie non gérée : <nowiki>#{value}</nowiki>")
        @editor.rewrite_area(params)
        params.should == [[name, value]]
      end
    end
  end

  it "should have default name_changes" do
    @editor.name_changes.should == {}
  end
  
  it "should use template_name" do
    @infobox[:parameters] = [
      ["foo", "bar"],
    ]
    @editor.template_name = "foo"
    @editor.write_infobox(@infobox).should ==
      "{{foo\n| foo = bar\n}}"
  end
  
  it "should have a default template_name" do
    @editor.template_name.should == "Infobox Logiciel"
  end
  
  it "should remove parameters" do
    @editor.removable_parameters = ["foo", "baz", "bob"]
    params = [["foo", "bar"], ["bar", "baz"], ["baz", ""]]
    @editor.remove_parameters(params)
    params.should == [["bar", "baz"]]
  end
end

describe Piglobot::Dump do
  before do
    @wiki = mock("wiki")
    @dump = Piglobot::Dump.new(@wiki)
  end
  
  it "should publish spec" do
    File.should_receive(:read).with("piglobot_spec.rb").and_return("file content")
    Piglobot::Tools.should_receive(:spec_to_wiki).with("file content").and_return("result")
    @wiki.should_receive(:post).with("Utilisateur:Piglobot/Spec", "result", "comment")
    @dump.publish_spec("comment")
  end

  it "should publish code" do
    File.should_receive(:read).with("piglobot.rb").and_return("file content")
    Piglobot::Tools.should_receive(:code_to_wiki).with("file content").and_return("result")
    @wiki.should_receive(:post).with("Utilisateur:Piglobot/Code", "result", "comment")
    @dump.publish_code("comment")
  end
  
  it "should load data" do
    data = "foo"
    File.should_receive(:read).with("data.yaml").and_return(data.to_yaml)
    @dump.load_data.should == data
  end

  it "should save data" do
    data = "bar"
    text = "<source lang=\"text\">\n" + data.to_yaml + "</source" + ">"
    file = mock("file")
    File.should_receive(:open).with("data.yaml", "w").and_yield(file)
    file.should_receive(:write).with(data.to_yaml)
    @dump.save_data(data)
  end
  
  it "should load nil when no data" do
    File.should_receive(:read).with("data.yaml").and_raise(Errno::ENOENT)
    @dump.load_data.should == nil
  end
end

describe Piglobot::Wiki do
  before do
    @mediawiki = mock("mediawiki")
    MediaWiki::Wiki.should_receive(:new).once.with(
      "http://fr.wikipedia.org/w",
      "Piglobot",
      File.read("password").strip
    ).and_return(@mediawiki)
    @article = mock("article")
    @wiki = Piglobot::Wiki.new
  end
  
  it "should post text" do
    @mediawiki.should_receive(:article).with("Article name").once.and_return(@article)
    @article.should_receive(:text=).with("article content")
    @article.should_receive(:submit).with("comment")
    Piglobot::Tools.should_receive(:log).with("Post [[Article name]] (comment)")
    @wiki.post "Article name", "article content", "comment"
  end
  
  it "should get text" do
    @mediawiki.should_receive(:article).with("Article name").once.and_return(@article)
    @article.should_receive(:text).with().and_return("content")
    Piglobot::Tools.should_receive(:log).with("Get [[Article name]]")
    @wiki.get("Article name").should == "content"
  end
  
  it "should append text" do
    @mediawiki.should_receive(:article).with("Article name").once.and_return(@article)
    @article.should_receive(:text).with().and_return("content")
    @article.should_receive(:text=).with("contentnew text")
    @article.should_receive(:submit).with("append comment")
    Piglobot::Tools.should_receive(:log).with("Append [[Article name]] (append comment)")
    @wiki.append("Article name", "new text", "append comment")
  end
  
  it "should use fast_what_links_here on links" do
    name = "Article name"
    links = ["Foo", "Bar", "Foo:Bar", "Hello:Bob", "Baz"]
    expected_links = links
    Piglobot::Tools.should_receive(:log).with("What links to [[Article name]]")
    @mediawiki.should_receive(:article).with(name).once.and_return(@article)
    @article.should_receive(:fast_what_links_here).with(5000).and_return(links)
    @wiki.links(name).should == expected_links
  end
end

describe Piglobot::Tools do
  it "should convert spec to wiki" do
    result = Piglobot::Tools.spec_to_wiki([
      "foo",
      "describe FooBar do",
      "  bar",
      "end",
      'describe FooBar, " with baz" do',
      '  foo',
      'end',
      "describe FooBar, ' with baz2' do",
      '  foo',
      'end',
      "describe 'baz' do",
      "  baz",
      "end",
    ].map { |line| line + "\n" }.join)
    result.should == ([
      '<source lang="ruby">',
      'foo',
      '<' + '/source>',
      '== FooBar ==',
      '<source lang="ruby">',
      'describe FooBar do',
      "  bar",
      "end",
      '<' + '/source>',
      '== FooBar with baz ==',
      '<source lang="ruby">',
      'describe FooBar, " with baz" do',
      '  foo',
      'end',
      '<' + '/source>',
      '== FooBar with baz2 ==',
      '<source lang="ruby">',
      "describe FooBar, ' with baz2' do",
      '  foo',
      'end',
      '<' + '/source>',
      '== baz ==',
      '<source lang="ruby">',
      "describe 'baz' do",
      "  baz",
      "end",
      '<' + '/source>',
    ].map { |line| line + "\n" }.join)
  end
  
  it "shouldn't split spec if describe is not at the beginning of the line" do
    result = Piglobot::Tools.spec_to_wiki([
      " describe FooBar do",
    ].map { |line| line + "\n" }.join)
    result.should == ([
      '<source lang="ruby">',
      ' describe FooBar do',
      '<' + '/source>',
    ].map { |line| line + "\n" }.join)
  end
  
  it "should convert class to title in code_to_wiki" do
    result = Piglobot::Tools.code_to_wiki([
      "foo",
      "class Foo",
      "  foo",
      "end",
      "foo then bar",
      "module Foo::Bar",
      "  bar",
      "  class Baz",
      "    baz",
      "  end",
      "end",
    ].map { |line| line + "\n" }.join)
    result.should == ([
      '<source lang="ruby">',
      'foo',
      '<' + '/source>',
      '== Foo ==',
      '<source lang="ruby">',
      "class Foo",
      "  foo",
      "end",
      "foo then bar",
      '<' + '/source>',
      '== Foo::Bar ==',
      '<source lang="ruby">',
      "module Foo::Bar",
      "  bar",
      "  class Baz",
      "    baz",
      "  end",
      "end",
      '<' + '/source>',
    ].map { |line| line + "\n" }.join)
  end
  
  it "should use Kernel.puts and append to piglobot.log on log" do
    time = mock("time")
    Time.should_receive(:now).with().and_return(time)
    time.should_receive(:strftime).with("%Y-%m-%d %H:%M:%S").and_return("time string")
    log_line = "time string: text"
    Kernel.should_receive(:puts).with(log_line)
    
    f = mock("file")
    File.should_receive(:open).with("piglobot.log", "a").and_yield(f)
    f.should_receive(:puts).with(log_line).once
    
    Piglobot::Tools.log("text")
  end
  
  [
    ["25 octobre 2007 à 17:17", Time.local(2007, 10, 25, 17, 17, 0)],
    ["25 août 2006 à 09:16", Time.local(2006, 8, 25, 9, 16, 0)],
    ["12 juillet 2006 à 08:40", Time.local(2006, 7, 12, 8, 40, 0)],
    ["10 novembre 2002 à 19:12", Time.local(2002, 11, 10, 19, 12, 0)],
    ["1 décembre 2002 à 11:39", Time.local(2002, 12, 1, 11, 39, 0)],
  ].each do |text, time|
    it "should parse time #{text.inspect}" do
      Piglobot::Tools.parse_time(text).should == time
    end
  end

  [
    "décembre 2002 à 11:39",
    "10 novembre 2002 19:12",
    "10 plop 2002 à 19:12",
    "10 octobre 2002",
    "foo 1 décembre 2002 à 11:39",
    "1 décembre 2002 à 11:39 foo",
  ].each do |text|
    it "should not parse time #{text.inspect}" do
      lambda { Piglobot::Tools.parse_time(text) }.should raise_error(ArgumentError, "Invalid time: #{text.inspect}")
    end
  end
  
  months = %w(janvier février mars avril mai juin juillet août septembre octobre novembre décembre)
  months.each_with_index do |month, i|
    expected_month = i + 1
    it "should parse month #{month.inspect}" do
      Piglobot::Tools.parse_time("25 #{month} 2007 à 17:17").should ==
        Time.local(2007, expected_month, 25, 17, 17, 0)
    end
  end
end
