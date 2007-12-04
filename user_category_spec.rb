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
    @job.should_receive(:sleep).ordered.with(5)
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
    initial_data = { :categories => ["foo"], :empty => ["foo", "bar"], :one => ["baz", "bob"], :users => { "Catégorie:cat" => ["foo", "Utilisateur:bob/panda"], "bar" => ["baz"] } }
    @job.data = initial_data.dup
    @wiki.should_not_receive(:all_pages)
    @job.should_receive(:process_category).with("foo")
    @job.should_not_receive(:notice)
    @job.step
    
    done_data = initial_data.dup
    done_data[:done] = true
    
    @job.data.should == done_data
    @job.done?.should == true
  end
  
  it "should write data on step when done" do
    @job.data = { :done => true }
    @wiki.should_not_receive(:all_pages)
    @job.should_not_receive(:process_category)
    @job.should_receive(:log).with("Toutes les catégories ont été traitées")
    @job.should_receive(:write_data).once
    @job.step
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
    @job.should_receive(:log).with("3 pages utilisateur dans Catégorie:cat")
    @job.should_receive(:add_user_category).with("Catégorie:cat", ["Utilisateur:foo", "Utilisateur:bob/panda", "Discussion Utilisateur:test/test"])
    @job.process_valid_category("Catégorie:cat")
  end
  
  it "should do nothing when no user page in category" do
    @wiki.should_receive(:category).with("cat").and_return(["foo", "foo Utilisateur:foo", "bar"])
    @job.should_receive(:log).with("3 pages dans Catégorie:cat")
    @job.should_receive(:log).with("Aucune page utilisateur dans Catégorie:cat")
    @job.process_valid_category("Catégorie:cat")
  end
  
  it "should create user category data" do
    @job.data = {}
    @job.add_user_category("Catégorie:cat", ["foo", "Utilisateur:bob/panda"])
    @job.data.should == { :users => { "Catégorie:cat" => ["foo", "Utilisateur:bob/panda"] } }
    @job.changed?.should == false
  end
  
  it "should append new user category" do
    @job.data = { :users => { "foo" => ["bar"] }}
    @job.add_user_category("cat", ["baz", "bob"])
    @job.data.should == { :users => { "foo" => ["bar"], "cat" => ["baz", "bob"] } }
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
  
  it "should write data" do
    initial_data = { :categories => ["foo"], :empty => ["foo", "bar"], :one => ["baz", "bob"], :users => { "Catégorie:cat" => ["foo", "Utilisateur:bob/panda"], "bar" => (1..13).map { |x| x.to_s } } }
    @job.data = initial_data.dup
    page = "Utilisateur:Piglobot/Utilisateurs catégorisés dans main"
    text = [
      "== [[:bar]] ==",
      "* [[:1]]",
      "* [[:2]]",
      "* [[:3]]",
      "* [[:4]]",
      "* [[:5]]",
      "* [[:6]]",
      "* [[:7]]",
      "* [[:8]]",
      "* [[:9]]",
      "* [[:10]]",
      "* [[:bar|...]]",
      "",
      "== [[:Catégorie:cat]] ==",
      "* [[:foo]]",
      "* [[:Utilisateur:bob/panda]]",
      "",
    ].map { |x| x + "\n" }.join
    
    @wiki.should_receive(:append).with(page, text, "Mise à jour")
    @job.write_data
    @job.data.should == {:categories => ["foo"], :empty => ["foo", "bar"], :one => ["baz", "bob"], :users => {}}
  end
  
  it "should write nothing when data is empty" do
    initial_data = { :categories => ["foo"], :empty => ["foo", "bar"], :one => ["baz", "bob"], :users => {} }
    @job.data = initial_data.dup
    @wiki.should_not_receive(:append)
    @job.write_data
    @job.data.should == {:categories => ["foo"], :empty => ["foo", "bar"], :one => ["baz", "bob"], :users => {}}
  end
end
