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
require 'helper'

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
    text = "foo bar"
    @wiki.should_receive(:append).with(@bot.log_page, "* ~~~~~ : #{text}", text)
    @bot.notice "foo bar"
  end
  
  it "should append link to article on notice with link" do
    text = "[[article name]] : foo bar"
    @wiki.should_receive(:append).with(@bot.log_page, "* ~~~~~ : #{text}", text)
    @bot.notice "foo bar", "article name"
  end

  it "should append link to current_article on notice with link" do
    text = "[[current article name]] : foo bar"
    @wiki.should_receive(:append).with(@bot.log_page, "* ~~~~~ : #{text}", text)
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

