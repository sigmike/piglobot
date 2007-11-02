require 'piglobot'
require 'helper'

describe Piglobot::Editor, " with default values", :shared => true do
  before do
    @bot = mock("bot")
    @wiki = mock("wiki")
    @bot.should_receive(:wiki).with().and_return(@wiki)
    @editor = Piglobot::Editor.new(@bot)
    @editor.bot.should == @bot
    @editor.wiki.should == @wiki
    
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
      "Infobox_aire protégée",
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
      "caption" => "légende carte",
      "base_width" => "largeur carte",
      "bot_image" => "image pied",
      "bot_caption" => "légende pied",
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
    @bot = mock("bot")
    @wiki = mock("wiki")
    @bot.should_receive(:wiki).with().and_return(@wiki)
    @editor = Piglobot::Editor.new(@bot)
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
    @bot = mock("bot")
    @wiki = mock("wiki")
    @bot.should_receive(:wiki).with().and_return(@wiki)
    @editor = Piglobot::Editor.new(@bot)
    @infobox = {
      :before => "",
      :after => "",
      :parameters => [],
    }
    @editor.template_name = "Infobox Logiciel"
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
  
  ["infobox aire protégée", "Infobox aire protégée", "infobox_aire protégée", "Infobox_aire protégée"].each do |name|
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
      ["lat_direction", "S"],
      ["long_degrees", "5"],
      ["long_minutes", "6"],
      ["long_seconds", "7"],
      ["long_direction", "E"],
      ["bar", "baz"]
    ]
    @editor.rewrite_coordinates(params)
    params.should == [["foo", "bar"], ["coordonnées", "{{coord|1|2|3|S|5|6|7|E}}"], ["bar", "baz"]]
  end
  
  it "should rewrite coordinates without seconds" do
    params = [
      ["foo", "bar"],
      ["lat_degrees", "1"],
      ["lat_minutes", "2"],
      ["lat_seconds", ""],
      ["lat_direction", "N"],
      ["long_degrees", "5"],
      ["long_minutes", "6"],
      ["long_seconds", ""],
      ["long_direction", "W"],
      ["bar", "baz"]
    ]
    @editor.rewrite_coordinates(params)
    params.should == [["foo", "bar"], ["coordonnées", "{{coord|1|2|N|5|6|W}}"], ["bar", "baz"]]
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
  
  [
    { "lat_direction" => "" },
    { "long_direction" => "" },
    { "lat_minutes" => "" },
    { "lat_direction" => "", "long_direction" => "" },
    { "lat_direction" => "O" },
    { "long_direction" => "O" },
    { "lat_direction" => "1" },
    { "long_direction" => "F" },
  ].each do |new_values|
    it "should notice on invalid coordinates #{new_values.inspect}" do
      params = [
        ["lat_degrees", "1"],
        ["lat_minutes", "2"],
        ["lat_seconds", "3"],
        ["lat_direction", "4"],
        ["long_degrees", "5"],
        ["long_minutes", "6"],
        ["long_seconds", "7"],
        ["long_direction", "8"],
      ]
      new_values.each do |k,v|
        params.map! do |name, value|
          if name == k
            [name, v]
          else
            [name, value]
          end
        end
      end
      old_params = YAML.load(params.to_yaml)
      @bot.should_receive(:notice).with("Coordonnées invalides")
      @editor.rewrite_coordinates(params)
      params.should == old_params
    end
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
      ["1 438 km<sup>2<sup>", "1438"],
      ["12345", "12345"],
      ["123.45", "123.45"],
      ["181,414 ha", "1814.14"],
      ["12.000 ha", "120"],
      ["565,69 ha", "5.66"],
      ["{{unité|5.6569|km|2}}", "5.66"],
      ["105 447 ha (cœur)", "1054.47", " (cœur)"],
      ["6.7 km² de terres", "6.7", " de terres"],
      ["497,3 km² en 2005", "497.3", " en 2005"],
      ["591 [[km²]]", "591"],
      ["{{formatnum:458}} km{{2}}", "458"],
      ["{{unité|0.12|km|2}}", "0.12"],
      ["12 ha", "0.12"],
    ].each do |value, result, extra|
      expected = "{{unité|#{result}|km|2}}#{extra}"
      it "should rewrite #{name} with #{value.inspect} to #{expected.inspect}" do
        params = [[name, value], ["foo", "bar"]]
        @editor.rewrite_area(params)
        params.should == [[name, expected], ["foo", "bar"]]
      end
    end
    
    [
      ["8,9 ha", "89000"],
      ["3 ha", "30000"],
      ["4,67 ha", "46700"],
      ["{{unité|0.0467|km|2}}", "46700"],
      ["{{unité|0.023|km|2}}", "23000"],
      ["{{unité|34567|m|2}}", "34567"],
    ].each do |value, result, extra|
      expected = "{{unité|#{result}|m|2}}#{extra}"
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
      ["[[km²]]", "<!-- {{unité|...|km|2}} -->"],
      ["<!-- {{unité|...|km|2}} -->", "<!-- {{unité|...|km|2}} -->"],
      #["22 015 km² <br>''parc:'' 5 900 km²<br>''réserve de parc:''16 115 km²",
      # "{{unité|22015|km|2}} <br>''parc:'' {{unité|5900|km|2}}<br>''réserve de parc:''{{unité|16115|km|2}}"],
      #["{{unité|22015|km|2}} <br>''parc:'' 5 900 km²<br>''réserve de parc:''16 115 km²",
      # "{{unité|22015|km|2}} <br>''parc:'' {{unité|5900|km|2}}<br>''réserve de parc:''{{unité|16115|km|2}}"],
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
      "foo {{formatnum:12}} km²",
      "36 hab",
      "foo 3 ha",
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

