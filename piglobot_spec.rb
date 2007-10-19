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

describe Piglobot::Dump do
  before do
    @wiki = mock("wiki")
    @dump = Piglobot::Dump.new(@wiki)
  end
  
  it "should publish spec" do
    text = "<source lang=\"ruby\">\n" + File.read("piglobot_spec.rb") + "<" + "/source>"
    @wiki.should_receive(:post).with("Utilisateur:Piglobot/Spec", text, "comment")
    @dump.publish_spec("comment")
  end

  it "should publish code" do
    text = "<source lang=\"ruby\">\n" + File.read("piglobot.rb") + "<" + "/source>"
    @wiki.should_receive(:post).with("Utilisateur:Piglobot/Code", text, "comment")
    @dump.publish_code("comment")
  end
  
  it "should load data" do
    data = "foo"
    text = "<source lang=\"text\">\n" + data.to_yaml + "</source" + ">"
    @wiki.should_receive(:get).with("Utilisateur:Piglobot/Data").once.and_return(text)
    @dump.load_data.should == data
  end

  it "should save data" do
    data = "bar"
    text = "<source lang=\"text\">\n" + data.to_yaml + "</source" + ">"
    @wiki.should_receive(:post).with("Utilisateur:Piglobot/Data", text, "Sauvegarde").once
    @dump.save_data(data)
  end
  
  it "should load nil when no data" do
    text = "\n"
    @wiki.should_receive(:get).with("Utilisateur:Piglobot/Data").once.and_return(text)
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
    @wiki.post "Article name", "article content", "comment"
  end
  
  it "should get text" do
    @mediawiki.should_receive(:article).with("Article name").once.and_return(@article)
    @article.should_receive(:text).with().and_return("content")
    @wiki.get("Article name").should == "content"
  end

    
  it "should use fast_what_links_here on links" do
    name = Object.new
    links = Object.new
    @mediawiki.should_receive(:article).with(name).once.and_return(@article)
    @article.should_receive(:fast_what_links_here).with(1000).and_return(links)
    @wiki.links(name).should == links
  end
end

describe Piglobot do
  before do
    @wiki = mock("wiki")
    @dump = mock("dump")
    @editor = mock("editor")
    Piglobot::Wiki.should_receive(:new).and_return(@wiki)
    Piglobot::Dump.should_receive(:new).once.with(@wiki).and_return(@dump)
    Piglobot::Editor.should_receive(:new).once.with(@wiki).and_return(@editor)
    @bot = Piglobot.new
  end
  
  it "should initialize data on first run" do
    @dump.should_receive(:load_data).and_return(nil)
    @dump.should_receive(:save_data).with({})
    @bot.run
  end
  
  it "should get infobox links on second run" do
    @dump.should_receive(:load_data).and_return({})
    @wiki.should_receive(:links, "Modèle:Infobox Logiciel").and_return(["Foo", "Bar"])
    @dump.should_receive(:save_data).with({ "Infobox Logiciel" => ["Foo", "Bar"]})
    @bot.run
  end
  
  it "should send infobox links to InfoboxEditor" do
    @dump.should_receive(:load_data).and_return({ "Infobox Logiciel" => ["Article 1", "Article 2"]})
    @wiki.should_receive(:get).with("Article 1").and_return("foo")
    comment = "Texte initial de l'article [[Article 1]]"
    @wiki.should_receive(:post).with("Utilisateur:Piglobot/Bac à sable", "foo", comment)
    infobox = mock("infobox")
    @editor.should_receive(:parse_infobox).with("foo").and_return(infobox)
    @editor.should_receive(:write_infobox).with(infobox).and_return("result")
    comment = "Correction de la syntaxe de l'infobox"
    @wiki.should_receive(:post).with("Utilisateur:Piglobot/Bac à sable", "result", comment)
    @dump.should_receive(:save_data).with({ "Infobox Logiciel" => ["Article 2"]})
    @bot.run
  end
  
  it "should not write infobox if none found" do
    @dump.should_receive(:load_data).and_return({ "Infobox Logiciel" => ["Article 1", "Article 2"]})
    @wiki.should_receive(:get).with("Article 1").and_return("foo")
    @editor.should_receive(:parse_infobox).with("foo").and_return(nil)
    @wiki.should_receive(:post).with("Utilisateur:Piglobot/Bac à sable", "foo", "Infobox non trouvée dans l'article [[Article 1]]")
    @dump.should_receive(:save_data).with({ "Infobox Logiciel" => ["Article 2"]})
    @bot.run
  end

  it "should get infobox links when list is empty" do
    @dump.should_receive(:load_data).and_return({"Infobox Logiciel" => [], "Foo" => "Bar"})
    @wiki.should_receive(:links, "Modèle:Infobox Logiciel").and_return(["A", "B"])
    @dump.should_receive(:save_data).with({ "Infobox Logiciel" => ["A", "B"], "Foo" => "Bar"})
    @bot.run
  end
  
end

describe Piglobot::Editor do
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
    text = "{{Infobox Logiciel | dernière version = 1.12<ref>[http://foo.com/bar ref]</ref> | foo = bar }}"
    @infobox[:parameters] = [["dernière version", "1.12<ref>[http://foo.com/bar ref]</ref>"], ["foo", "bar"]]
    @editor.parse_infobox(text).should == @infobox
  end
  
  it "should parse parameters with new lines" do
    text = "{{Infobox Logiciel | name = foo\n\n  bar\n | foo = bar }}"
    @infobox[:parameters] = [["name", "foo\n\n  bar"], ["foo", "bar"]]
    @editor.parse_infobox(text).should == @infobox
  end
  
  it "should parse parameters with weird new lines" do
    text = "{{Infobox Logiciel |\nname = foo |\nimage = |\n}}"
    @infobox[:parameters] = [["name", "foo"], ["image", ""]]
    @editor.parse_infobox(text).should == @infobox
  end
  
  it "should parse Logicel simple" do
    text = "{{Logiciel simple | bob = mock }}"
    @infobox[:parameters] = [["bob", "mock"]]
    @editor.parse_infobox(text).should == @infobox
  end
  
  it "should parse Logicel_simple" do
    text = "{{Logiciel_simple}}"
    @editor.parse_infobox(text).should == @infobox
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
    @infobox[:parameters] = [["name", "value"], ["other name", "other value"]]
    @editor.write_infobox(@infobox).should == "{{Infobox Logiciel\n| name = value\n| other name = other value\n}}"
  end
  
  it "should write infobox with new lines in parameter" do
    @infobox[:parameters] = [["name", "first line\n  second line\nthird line"]]
    @editor.write_infobox(@infobox).should == "{{Infobox Logiciel\n| name = first line\n  second line\nthird line\n}}"
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
end
