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

describe Piglobot, :shared => true do
  before do
    @wiki = mock("wiki")
    @dump = mock("dump")
    @editor = mock("editor")
    Piglobot::Wiki.should_receive(:new).and_return(@wiki)
    Piglobot::Dump.should_receive(:new).once.with(@wiki).and_return(@dump)
    Piglobot::Editor.should_receive(:new).once.with(@wiki).and_return(@editor)
    @bot = Piglobot.new
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
end

describe Piglobot, " running" do
  it "should list jobs" do
    Piglobot.jobs.should == ["Infobox Logiciel", "Homonymes"]
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

describe Piglobot, " working on Infobox Logiciel" do
  it_should_behave_like "Piglobot"
  
  before do
    @bot.job = "Infobox Logiciel"
  end
  
  it "should get infobox links when data is empty" do
    @dump.should_receive(:load_data).and_return({})
    @wiki.should_receive(:links, "Modèle:Infobox Logiciel").and_return(["Foo", "Bar", "Baz"])
    text = "~~~~~ : Infobox Logiciel : 3 articles à traiter"
    @wiki.should_receive(:append).with("Utilisateur:Piglobot/Journal", "* #{text}", text)
    @dump.should_receive(:save_data).with({ "Infobox Logiciel" => ["Foo", "Bar", "Baz"]})
    @bot.process.should == false
  end
  
  it "should send infobox links to InfoboxEditor" do
    @dump.should_receive(:load_data).and_return({ "Infobox Logiciel" => ["Article 1", "Article 2"]})
    @wiki.should_receive(:get).with("Article 1").and_return("foo")
    infobox = mock("infobox")
    @editor.should_receive(:parse_infobox).with("foo").and_return(infobox)
    @editor.should_receive(:write_infobox).with(infobox).and_return("result")
    comment = "[[Utilisateur:Piglobot/Travail#Infobox Logiciel|Correction automatique]] de l'[[Modèle:Infobox Logiciel|Infobox Logiciel]]"
    @wiki.should_receive(:post).with("Article 1", "result", comment)
    @dump.should_receive(:save_data).with({ "Infobox Logiciel" => ["Article 2"]})
    @bot.process.should == true
  end
  
  it "should not write infobox if none found" do
    @dump.should_receive(:load_data).and_return({ "Infobox Logiciel" => ["Article 1", "Article 2"]})
    @wiki.should_receive(:get).with("Article 1").and_return("foo")
    @editor.should_receive(:parse_infobox).with("foo").and_return(nil)
    text = "~~~~~, [[Article 1]] : Infobox Logiciel non trouvée dans l'article"
    @wiki.should_receive(:append).with("Utilisateur:Piglobot/Journal", "* #{text}", text)
    @dump.should_receive(:save_data).with({ "Infobox Logiciel" => ["Article 2"]})
    @bot.process.should == true
  end
  
  it "should not write infobox if nothing changed" do
    @dump.should_receive(:load_data).and_return({ "Infobox Logiciel" => ["Article 1", "Article 2"]})
    @wiki.should_receive(:get).with("Article 1").and_return("foo")
    infobox = mock("infobox")
    @editor.should_receive(:parse_infobox).with("foo").and_return(infobox)
    @editor.should_receive(:write_infobox).with(infobox).and_return("foo")
    text = "[[Article 1]] : Aucun changement nécessaire dans l'Infobox Logiciel"
    Piglobot::Tools.should_receive(:log).with(text).once
    @dump.should_receive(:save_data).with({ "Infobox Logiciel" => ["Article 2"]})
    @bot.process.should == false
  end
  
  it "should log parsing error" do
    @dump.should_receive(:load_data).and_return({ "Infobox Logiciel" => ["Article 1", "Article 2"]})
    @wiki.should_receive(:get).with("Article 1").and_return("foo")
    infobox = mock("infobox")
    @editor.should_receive(:parse_infobox).with("foo").and_raise(Piglobot::ErrorPrevention.new("error message"))
    text = "~~~~~, [[Article 1]] : error message (Piglobot::ErrorPrevention)"
    @wiki.should_receive(:append).with("Utilisateur:Piglobot/Journal", "* #{text}", text)
    @dump.should_receive(:save_data).with({ "Infobox Logiciel" => ["Article 2"]})
    @bot.process.should == true
  end
  
  it "should get infobox links when list is empty" do
    @dump.should_receive(:load_data).and_return({"Infobox Logiciel" => [], "Foo" => "Bar"})
    @wiki.should_receive(:links, "Modèle:Infobox Logiciel").and_return(["A", "B"])
    text = "~~~~~ : Infobox Logiciel : 2 articles à traiter"
    @wiki.should_receive(:append).with("Utilisateur:Piglobot/Journal", "* #{text}", text)
    @dump.should_receive(:save_data).with({ "Infobox Logiciel" => ["A", "B"], "Foo" => "Bar"})
    @bot.process.should == false
  end
  
  it "should ignore links in namespace" do
    @dump.should_receive(:load_data).and_return({"Infobox Logiciel" => [], "Foo" => "Bar"})
    @wiki.should_receive(:links, "Modèle:Infobox Logiciel").and_return(["A", "B", "C:D", "E:F", "G::H", "I:J"])
    expected = ["A", "B", "G::H"]
    text = "~~~~~ : Infobox Logiciel : #{expected.size} articles à traiter"
    @wiki.should_receive(:append).with("Utilisateur:Piglobot/Journal", "* #{text}", text)
    @dump.should_receive(:save_data).with({ "Infobox Logiciel" => expected, "Foo" => "Bar"})
    @bot.process.should == false
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
    text = "~~~~~: error message (AnyError)"
    e.should_receive(:backtrace).and_return(["backtrace 1", "backtrace 2"])
    @wiki.should_receive(:append).with("Utilisateur:Piglobot/Journal", "* #{text}", text)
    Piglobot::Tools.should_receive(:log).with("error message (AnyError)\nbacktrace 1\nbacktrace 2").once
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
end

describe Piglobot::Editor, " parsing Infobox Logiciel" do
  before do
    @wiki = mock("wiki")
    @editor = Piglobot::Editor.new(@wiki)
    @infobox = {
      :before => "",
      :after => "",
      :parameters => [],
    }
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
    @editor.template_names.should == [
      "Infobox Logiciel",
      "Logiciel simple",
      "Logiciel_simple",
      "Logiciel",
      "Infobox Software",
      "Infobox_Software",
    ]
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
  
  it "should parse infobox_software" do
    text = "{{Infobox_Software |\nname = foo |\nscreenshot = bar|\n}}"
    @infobox[:parameters] = [["name", "foo"], ["screenshot", "bar"]]
    @editor.parse_infobox(text).should == @infobox
  end

  it "should parse infobox software" do
    text = "{{Infobox Software |\nname = foo |\nscreenshot = bar|\n}}"
    @infobox[:parameters] = [["name", "foo"], ["screenshot", "bar"]]
    @editor.parse_infobox(text).should == @infobox
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
      "[[1er #{month}]] [[1998]]" => "{{Date|1|#{emonth}|1998}}",
      "[[18 #{month}]] [[2005]]" => "{{Date|18|#{emonth}|2005}}",
      "[[31 #{month}]] [[2036]]" => "{{Date|31|#{emonth}|2036}}",
      "[[04 #{month}]] [[1950]]" => "{{Date|4|#{emonth}|1950}}",
      "a[[04 #{month}]] [[1950]]" => "a[[04 #{month}]] [[1950]]",
      "[[04 #{month}]] [[1950]]b" => "[[04 #{month}]] [[1950]]b",
      "04 #{month} 1950" => "{{Date|4|#{emonth}|1950}}",
      "04 #{month}? 1950" => "04 #{month}? 1950",
      "le 04 #{month} 1950" => "le 04 #{month} 1950",
      "[[04 fevrier]] [[1950]]" => "[[04 fevrier]] [[1950]]",
      "[[004 #{month}]] [[1950]]" => "[[004 #{month}]] [[1950]]",
      "[[4 #{month}]] [[19510]]" => "[[4 #{month}]] [[19510]]",
      "4 #{month} [[1951]]" => "{{Date|4|#{emonth}|1951}}",
      "[[18 #{month}]], [[2005]]" => "{{Date|18|#{emonth}|2005}}",
      "[[18 #{month}]] foo [[2005]]" => "[[18 #{month}]] foo [[2005]]",
      "01 [[#{month}]] [[2005]]" => "{{Date|1|#{emonth}|2005}}",
      "07 [[#{month} (mois)|#{month}]] [[2005]]" => "{{Date|7|#{emonth}|2005}}",
      "[[#{month}]] [[2003]]" => "[[#{month}]] [[2003]]",
      "[[#{month} (mois)|#{month}]] [[2003]]" => "[[#{month} (mois)|#{month}]] [[2003]]",
      "{{1er #{month}}} [[2007]]" => "{{Date|1|#{emonth}|2007}}",
    }.each do |text, result|
      it "should rewrite_date #{text.inspect} to #{result.inspect}" do
        @editor.rewrite_date(text).should == result
      end
    end
  end
  
  it "should apply filters" do
    params = [["foo", "bar"]]
    @editor.should_receive(:fake_filter).with(params) do |parameters|
      parameters.replace [["a", "b"]]
    end
    
    @editor.filters = [:fake_filter]
    @infobox[:parameters] = params
    @editor.write_infobox(@infobox).should ==
      "{{Infobox Logiciel\n| a = b\n}}"
  end
  
  it "should have default filters" do
    @editor.filters.should == [
      :rename_parameters,
      :remove_open_source,
      :remove_almost_empty,
      :remove_firefox,
      :rewrite_dates,
    ]
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
  
  it "should have default name_changes" do
    @editor.name_changes.should == {
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
end
