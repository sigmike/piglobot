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
    along with Piglobot.  If not, see <http://www.gnu.org/licenses/>.
=end

require 'piglobot'
require 'helper'

describe Piglobot, "using data" do
  include PiglobotHelper
  
  before do
    create_bot
  end
  
  it "should have existing code_files" do
    result = @bot.code_files.map { |file| [file, File.exist?(file)] }
    expected = @bot.code_files.map { |file| [file, true] }
    result.should == expected
  end
  
  it "should publish code" do
    @bot.should_receive(:code_files).with().and_return(["foo.rb", "bar.txt", "foo_spec.rb", "bob"])
    
    [
      ["foo.rb", "ruby"],
      ["bar.txt", "text"],
      ["foo_spec.rb", "ruby"],
      ["bob", "text"],
    ].each do |file, lang|
      File.should_receive(:read).with(file).and_return("#{file} content")
      Piglobot::Tools.should_receive(:file_to_wiki).with(file, "#{file} content", lang).and_return("#{file} wikified")
    end
    result = [
      "foo.rb wikified",
      "bar.txt wikified",
      "foo_spec.rb wikified",
      "bob wikified",
    ].join
      
    @wiki.should_receive(:post).with("Utilisateur:Piglobot/Code", result, "comment")
    @bot.publish_code("comment")
  end
  
  it "should load data" do
    data = "foo"
    File.should_receive(:read).with("data.yaml").and_return(data.to_yaml)
    @bot.load_data
    @bot.data.should == data
  end

  it "should save data" do
    data = "bar"
    text = "<source lang=\"text\">\n" + data.to_yaml + "</source" + ">"
    file = mock("file")
    File.should_receive(:open).with("data.yaml", "w").and_yield(file)
    file.should_receive(:write).with(data.to_yaml)
    @bot.data = data
    @bot.save_data
  end
  
  it "should load nil when no data" do
    File.should_receive(:read).with("data.yaml").and_raise(Errno::ENOENT)
    @bot.load_data
    @bot.data.should == nil
  end
  
  [
    ["Homonymes", Piglobot::HomonymPrevention],
    ["Infobox Logiciel", Piglobot::InfoboxSoftware],
    ["Infobox Aire protégée", Piglobot::InfoboxProtectedArea],
  ].each do |job, klass|
    it "should find job class for job #{job.inspect}" do
      @bot.job_class(job).should == klass
    end
  end
  
  it "should raise exception on unknown job" do
    lambda { @bot.job_class("invalid job") }.should raise_error(RuntimeError)
  end

  class FakeJob
  end
  
  it "should use job class on process" do
    job = mock("job")
    @bot.should_receive(:job_class).with("job name").and_return(FakeJob)
    FakeJob.should_receive(:new).with(@bot).and_return(job)
    job.should_receive(:data_id).with().and_return("data id")
    @bot.should_receive(:load_data).with() do
      @bot.data = {"foo" => "bar", "data id" => "data" }
    end
    job.should_receive(:data=).with("data")
    job.should_receive(:process)
    job.should_receive(:data).with().and_return("result data")
    @bot.should_receive(:save_data).with() do
      @bot.data.should == {"foo" => "bar", "data id" => "result data"}
    end
    @bot.job = "job name"
    @bot.process.should == job
  end
end

describe Piglobot, :shared => true do
  include PiglobotHelper
  
  before do
    create_bot
    @job = mock("job")
  end
  
  it "should initialize data on first process" do
    @bot.should_receive(:load_data) do
      @bot.data = nil
    end
    @bot.should_receive(:save_data) do
      @bot.data.should == {}
    end
    @bot.process.should == nil
  end
  
  it "should fail when job is nil" do
    @bot.job = nil
    lambda { @bot.process }.should raise_error(RuntimeError, "Invalid job: nil")
  end

  it "should fail when job is invalid" do
    @bot.job = "Foo"
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
    @bot.should_receive(:process).with().once.and_return(nil)
    @bot.should_receive(:sleep).with().once
    @bot.step
  end
  
  it "should short_sleep if process job has not changed anything" do
    @bot.should_receive(:safety_check).with().once.and_return(true)
    @job.should_receive(:done?).with().and_return(false)
    @job.should_receive(:changed?).with().and_return(false)
    @bot.should_receive(:process).with().once.and_return(@job)
    @bot.should_receive(:short_sleep).with().once
    @bot.step
  end
  
  it "should sleep normally if job has changed something" do
    @bot.should_receive(:safety_check).with().once.and_return(true)
    @job.should_receive(:done?).with().and_return(false)
    @job.should_receive(:changed?).with().and_return(true)
    @bot.should_receive(:process).with().once.and_return(@job)
    @bot.should_receive(:sleep).with().once
    @bot.step
  end
  
  it "should raise Interrupt if job has done" do
    @bot.should_receive(:safety_check).with().once.and_return(true)
    @job.should_receive(:done?).with().and_return(true)
    @bot.should_receive(:process).with().once.and_return(@job)
    lambda { @bot.step }.should raise_error(Interrupt)
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

