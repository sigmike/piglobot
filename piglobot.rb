#!/usr/bin/env ruby

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

require 'libs'
require 'yaml'
require 'mediawiki'

class Piglobot
  class Disabled < RuntimeError; end
  class ErrorPrevention < RuntimeError; end

  attr_accessor :log_page, :current_article

  def initialize
    @wiki = Wiki.new
    @dump = Dump.new(@wiki)
    @editor = Editor.new(@wiki)
    @log_page = "Utilisateur:Piglobot/Journal"
    @editor.bot = self
  end
  
  attr_accessor :job
  
  def Piglobot.jobs
    [
      "Infobox Logiciel",
      "Homonymes",
      "Infobox Aire protégée",
    ]
  end
  
  def process_infobox(data, infobox, links)
    changes = false
    
    articles = data[infobox]

    if articles and !articles.empty?
      article = articles.shift
      @current_article = article
      if article =~ /:/
        comment = "Article ignoré car il n'est pas dans le bon espace de nom"
        text = "[[#{article}]] : #{comment}"
        Piglobot::Tools.log(text)
      else
        text = @wiki.get(article)
        begin
          box = @editor.parse_infobox(text)
          if box
            result = @editor.write_infobox(box)
            if result != text
              comment = "[[Utilisateur:Piglobot/Travail##{infobox}|Correction automatique]] de l'[[Modèle:#{infobox}|#{infobox}]]"
              @wiki.post(article,
                result,
                comment)
              changes = true
            else
              text = "[[#{article}]] : Aucun changement nécessaire dans l'#{infobox}"
              Piglobot::Tools.log(text)
            end
          else
            notice("#{infobox} non trouvée dans l'article", article)
            changes = true
          end
        rescue => e
          notice(e.message, article)
          changes = true
        end
      end
      @current_article = nil
    else
      articles = []
      links.each do |link|
        articles += @wiki.links(link)
      end
      articles.uniq!
      articles.delete_if { |name| name =~ /:/ and name !~ /::/ }
      data[infobox] = articles
      notice("#{articles.size} articles à traiter pour #{infobox}")
      changes = true
    end
    changes
  end
  
  def process_homonyms(data)
    changes = false
    data["Homonymes"] ||= {}
    china = data["Homonymes"]["Chine"] || {}
    china = {} if china.is_a?(Array)
    last = china["Last"] || {}
    new = china["New"] || []
    
    if last.empty?
      last = @wiki.links("Chine")
      Piglobot::Tools.log("#{last.size} liens vers la page d'homonymie [[Chine]]")
    else
      current = @wiki.links("Chine")
      
      new.delete_if do |old_new|
        if current.include? old_new
          false
        else
          Piglobot::Tools.log("Le lien vers [[Chine]] dans [[#{old_new}]] a été supprimé avant d'être traité")
          true
        end
      end
      
      current_new = current - last
      last = current
      current_new.each do |new_name|
        Piglobot::Tools.log("Un lien vers [[Chine]] a été ajouté dans [[#{new_name}]]")
      end
      new += current_new
    end
    china["Last"] = last
    china["New"] = new if new
    data["Homonymes"]["Chine"] = china
    changes
  end
  
  def process
    changes = false
    data = @dump.load_data
    if data.nil?
      data = {}
    else
      case @job
      when "Infobox Logiciel"
        @editor.setup("Infobox Logiciel")
        changes = process_infobox(data, "Infobox Logiciel", ["Modèle:Infobox Logiciel"])
      when "Infobox Aire protégée"
        @editor.setup("Infobox Aire protégée")
        changes = process_infobox(data, "Infobox Aire protégée", ["Modèle:Infobox Aire protégée", "Modèle:Infobox aire protégée"])
      when "Homonymes"
        changes = process_homonyms(data)
      else
        raise "Invalid job: #{@job.inspect}"
      end
    end
    @dump.save_data(data)
    changes
  end
  
  def safety_check
    text = @wiki.get("Utilisateur:Piglobot/Arrêt d'urgence")
    if text =~ /stop/im
      Tools.log("Arrêt d'urgence : #{text}")
      false
    else
      true
    end
  end
  
  def sleep
    Tools.log("Sleep 60 seconds")
    Kernel.sleep(60)
  end
  
  def long_sleep
    Tools.log("Sleep 10 minutes")
    Kernel.sleep(10*60)
  end
  
  def short_sleep
    Tools.log("Sleep 10 seconds")
    Kernel.sleep(10)
  end
  
  def log_error(e)
    Tools.log("#{e.message} (#{e.class})\n" + e.backtrace.join("\n"))
    notice(e.message)
  end
  
  def step
    changes = true
    begin
      if safety_check
        begin
          changes = process
        rescue Interrupt, MediaWiki::InternalServerError
          raise
        rescue Exception => e
          log_error(e)
        end
      end
      if changes
        sleep
      else
        short_sleep
      end
    rescue MediaWiki::InternalServerError
      long_sleep
    end
  end
  
  def notice(text, article = @current_article)
    line = "~~~~~ : "
    line << "[[#{article}]] : " if article
    line << text
    @wiki.append(@log_page, "* #{line}", line)
  end
  
  def self.run(job)
    bot = new
    bot.job = job
    loop do
      bot.step
    end
  end
end

class Piglobot::Editor
  attr_accessor :name_changes, :template_names, :template_name, :filters, :removable_parameters

  attr_accessor :infobox, :bot

  def initialize(wiki)
    @wiki = wiki
  
    @name_changes = {}
    @template_names = []
    @template_name = nil
    @filters = []
    @removable_parameters = []
  end
  
  def setup(action = nil)
    case action
    when "Infobox Logiciel"
      @template_names = ["Infobox Logiciel",
        "Logiciel simple",
        "Logiciel_simple",
        "Logiciel",
        "Infobox Software",
        "Infobox_Software",
      ]
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
      @filters = [
        :rename_parameters,
        :remove_open_source,
        :remove_almost_empty,
        :remove_firefox,
        :rewrite_dates,
      ]

      @template_name = "Infobox Logiciel"
    when "Infobox Aire protégée"
      @template_names = [
        "Infobox Aire protégée",
        "Infobox aire protégée",
        "Infobox_aire protégée",
      ]
      @name_changes = {
      }
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
    else
      @template_names = []
    end
  end
  
  def parse_infobox(text)
    parser = Piglobot::TemplateParser.new
    parser.template_names = @template_names.map { |name|
      [name, name[0].chr.swapcase + name[1..-1]]
    }.flatten
    parser.find_template(text)
  end
  
  def rename_parameters(parameters)
    changes = @name_changes
    parameters.map! { |name, value|
      if changes.has_key? name
        name = changes[name]
      end
      [name, value]
    }
  end
  
  def rename_image_protected_area(parameters)
    if @infobox[:name] == "Infobox aire protégée" or @infobox[:name] == "infobox aire protégée"
      parameters.map! { |name, value|
        name = "carte" if name == "image"
        [name, value]
      }
      parameters.map! { |name, value|
        name = "image" if name == "top_image"
        [name, value]
      }
    end
  end
  
  def rewrite_coordinates(params)
    names = %w(lat_degrees lat_minutes lat_seconds lat_direction long_degrees long_minutes long_seconds long_direction)
    hash = {}
    found_any = false
    names.each do |name|
      arg = params.find { |n, v| n == name }
      if arg
        arg = arg.last
        arg = nil if arg.empty?
        hash[name.intern] = arg
        found_any = true
      end
    end
    
    if found_any
      coord = nil
      if hash[:lat_degrees] and hash[:lat_minutes] and %w(N S).include?(hash[:lat_direction]) and
          hash[:long_degrees] and hash[:long_minutes] and %w(E W).include?(hash[:long_direction])
        if hash[:lat_seconds] and hash[:long_seconds]
          coord = "{{" + [
            "coord",
            hash[:lat_degrees],
            hash[:lat_minutes],
            hash[:lat_seconds],
            hash[:lat_direction],
            hash[:long_degrees],
            hash[:long_minutes],
            hash[:long_seconds],
            hash[:long_direction],
          ].join("|") + "}}"
        else
          coord = "{{" + [
            "coord",
            hash[:lat_degrees],
            hash[:lat_minutes],
            hash[:lat_direction],
            hash[:long_degrees],
            hash[:long_minutes],
            hash[:long_direction],
          ].join("|") + "}}"
        end
      elsif hash.values.all? { |arg| arg == nil }
        coord = "<!-- {{coord|...}} -->"
      else
        @bot.notice("Coordonnées invalides")
      end
    
      if coord
        done = false
        params.map! { |n, v|
          if names.include? n and !done
            done = true
            ["coordonnées", coord]
          else
            [n, v]
          end
        }
        params.delete_if { |n, v| names.include? n }
      end
    end
  end
  
  def rewrite_area(params)
    params.map! do |name, value|
      if name == "area" or name == "superficie"
        extra = nil
        found = true
        n = /[\d,.\s]+/
        case value
        when /\A([\d\.]+)\Z/
          value = $1
        when /\A(#{n}) km<sup>2<\/?sup>\Z/
          value = $1
        when /\A\{\{formatnum:(#{n})\}\} km²\Z/
          value = $1
        when /\A#{n} ha \((#{n}) km²\)\Z/
          value = $1
        when /\A#{n} acres<br \/>(#{n}) km²\Z/
          value = $1
        when /\A\{\{unité\|(#{n})\|km\|2\}\}\Z/
          value = $1.to_f
          value = (value * 100).round / 100.0 unless value < 0.1
          if value == value.to_i
            value = value.to_i
          end
        when /\A\{\{unité\|(#{n})\|m\|2\}\}\Z/
          value = $1.to_f / 1000000
        when /\A\{\{unité\|#{n}\|acres\}\}<br \/>\{\{unité\|(#{n})\|km\|2\}\}\Z/
          value = $1
        when /\A\{\{formatnum:#{n}\}\} acres \(\{\{formatnum:(#{n})\}\} km²\)\Z/
          value = $1
        when /\A\{\{formatnum:#{n}\}\} acres<br \/>\{\{formatnum:(#{n})\}\} km²\Z/
          value = $1
        when /\A(#{n}) ha (.+?)<br\/>(#{n}) ha (.+?)\Z/
          v1 = $1
          t1 = $2
          v2 = $3
          t2 = $4
          v1, v2 = [v1, v2].map { |v|
            v = v.tr(" ", "").to_i * 0.01
            v = v.to_s
            v.gsub!(/,(\d{3})/, "\\1")
            v.sub!(/,/, ".")
            v.gsub!(/ /, "")
            v = "{{unité|#{v}|km|2}}"
          }
          value = "#{v1} #{t1}<br/>#{v2} #{t2}"
          found = false
        when /\A(#{n}) ha( .+)?\Z/
          extra = $2
          value = $1.tr(" ", "").gsub(/,(\d{3})/, "\\1").gsub(/\.(\d{3})/, "\\1").sub(/,/, ".").to_f * 0.01
          value = (value * 100).round / 100.0 unless value < 0.1
          if value == value.to_i
            value = value.to_i
          end
        when /\A(#{n}) km²( .+)?\Z/
          value = $1
          extra = $2
        when /\A(#{n}) \[\[km²\]\]\Z/
          value = $1
        when /\A\{\{formatnum:(#{n})\}\} km\{\{2\}\}\Z/
          value = $1
        when "", "[[km²]]"
          value = "<!-- {{unité|...|km|2}} -->"
          found = false
        else
          @bot.notice("Superficie non gérée : <nowiki>#{value}</nowiki>")
          found = false
        end
        if found
          if value.to_f < 0.1
            value *= 1000000
            value = value.to_i if value.to_s =~ /\.0\Z/
            unit = "m"
          else
            unit = "km"
          end
          value = value.to_s
          value.gsub!(/,(\d{3})/, "\\1")
          value.sub!(/,/, ".")
          value.gsub!(/ /, "")
          value = "{{unité|#{value}|#{unit}|2}}"
          value << extra if extra
        end
      end
      [name, value]
    end
  end
  
  def remove_parameters(params)
    params.delete_if { |name, value|
      @removable_parameters.include? name
    }
  end
  
  def gsub_value(parameters, param_name, regexp, replacement)
    parameters.map! { |name, value|
      if param_name == :any or name == param_name
        value = value.gsub regexp, replacement
      end
      [name, value]
    }
  end
  
  def rewrite_date(value)
    if value =~ /\A\{\{(1er) (.+)\}\} \[\[(\d{4})\]\]\Z/ or
      value =~ /\A(1)\{\{er\}\} (.+) (\d{4})\Z/ or
      value =~ /\A\[\[(.+) (.+)\]\],? \[\[(\d{4})\]\]\Z/ or
      value =~ /\A(.+) (.+) (\d{4})\Z/ or
      value =~ /\A(.+) \[\[(.+) \(mois\)\|.+\]\] \[\[(\d{4})\]\]\Z/ or
      value =~ /\A(.+) \[\[(.+)\]\] \[\[(\d{4})\]\]\Z/ or
      value =~ /\A(.+) (.+) \[\[(\d{4})\]\]\Z/
      if $3
        day = $1
        month = $2
        year = $3
      else
        day = ""
        month = $1
        year = $2
      end
      if ((day =~ /\A\d+\Z/ and day.size <= 2) or day == "1er" or day.empty?) and
        %w(janvier février mars avril mai juin juillet août septembre
        octobre novembre décembre).map { |m|
          [m, m.capitalize]
        }.flatten.include? month
        day = "1" if day == "1er"
        day.sub! /\A0+/, ""
        value = "{{date|#{day}|#{month.downcase}|#{year}}}"
      end
    end
    value
  end
  
  def rewrite_dates(parameters)
    parameters.map! { |name, value|
      value = rewrite_date(value)
      [name, value]
    }
  end
  
  def remove_firefox(parameters)
    firefox_text = "<!-- Ne pas changer la capture d'écran, sauf grand changement. Et utilisez la page d'accueil de Wikipédia pour la capture, pas la page de Firefox. Prenez une capture à une taille « normale » (de 800*600 à 1024*780), désactiver les extensions et prenez le thème par défaut. -->"
    gsub_value(parameters, "image", /\A(.*)#{Regexp.escape(firefox_text)}(.*)\Z/, '\1\2')
    firefox_text = "<!-- 
                             * Ne pas changer la capture d'écran, sauf grand changement.
                             * Utiliser la page d'accueil de Wikipédia pour la capture, pas la page de Firefox.
                             * Prendre une capture à une taille « normale » (de 800*600 à 1024*780).
                             * Désactiver les extensions et prendre le thème par défaut.
                             -->"
    gsub_value(parameters, "image", /\A#{Regexp.escape(firefox_text)}(.*)\Z/, '\1')
  end
  
  def remove_open_source(parameters)
    gsub_value(parameters, "type", /(.+?) +\(\[\[open source\]\]\)$/, '\1')
  end
  
  def remove_almost_empty(parameters)
    gsub_value(parameters, :any, /\A\?\??\Z/, "")
    gsub_value(parameters, :any, /\A-\Z/, "")
    gsub_value(parameters, :any, /\A\{\{\{.+\|\}\}\}\Z/, "")
  end
  
  def write_infobox(box)
    if box[:parameters].empty?
      args = ""
    else
      parameters = box[:parameters]
      
      @infobox = box
      @filters.each do |method|
        send(method, parameters)
      end
      
      args = "\n" + parameters.map { |name, value|
        if name.nil?
          "| #{value}\n"
        elsif name.empty?
          "| = #{value}\n"
        else
          "| #{name} = #{value}\n"
        end
      }.join
    end
    "#{box[:before]}{{#{@template_name}#{args}}}#{box[:after]}"
  end
end

class Piglobot::Wiki
  def initialize
    @wiki = MediaWiki::Wiki.new("http://fr.wikipedia.org/w", "Piglobot", File.read("password"))
  end
  
  def internal_post(article_name, text, comment)
    article = @wiki.article(article_name)
    article.text = text
    Piglobot::Tools.log("Post [[#{article_name}]] (#{comment})")
    article.submit(comment)
  end

  def internal_get(article_name)
    article = @wiki.article(article_name)
    Piglobot::Tools.log("Get [[#{article_name}]]")
    article.text
  end
  
  def internal_append(article_name, text, comment)
    article = @wiki.article(article_name)
    article.text += text
    Piglobot::Tools.log("Append [[#{article_name}]] (#{comment})")
    article.submit(comment)
  end
  
  def internal_links(name)
    article = @wiki.article(name)
    Piglobot::Tools.log("What links to [[#{name}]]")
    article.fast_what_links_here(5000)
  end
  
  def retry(method, *args)
    begin
      send(method, *args)
    rescue => e
      Piglobot::Tools.log("Retry in 10 minutes (#{e.message})")
      Kernel.sleep(10*60)
      retry
    end
  end
  
  %w( get post append links ).each do |method|
    define_method(method.intern) do |*args|
      self.retry("internal_#{method}".intern, *args)
    end
  end
end

class Piglobot::Dump
  def initialize(wiki)
    @wiki = wiki
  end
  
  def publish_spec(comment)
    text = File.read("piglobot_spec.rb")
    @wiki.post("Utilisateur:Piglobot/Spec", Piglobot::Tools.spec_to_wiki(text), comment)
  end

  def publish_code(comment)
    text = File.read("piglobot.rb")
    @wiki.post("Utilisateur:Piglobot/Code", Piglobot::Tools.code_to_wiki(text), comment)
  end
  
  def load_data
    begin
      YAML.load File.read("data.yaml")
    rescue Errno::ENOENT
      nil
    end
  end

  def save_data data
    File.open("data.yaml", "w") do |f|
      f.write data.to_yaml
    end
  end
end

module Piglobot::Tools
  module_function
  
  def spec_to_wiki(spec)
    wiki = spec.dup
    wiki.gsub! /^describe (.+) do/ do |line|
      match = $1
      case match
      when /(.+), ["'](.+)["']/
        title = "#$1#$2"
      when /["'](.+)["']/
        title = $1
      else
        title = match
      end
      result = '<' + "/source>\n"
      result << "== #{title} ==\n"
      result << "<source lang=\"ruby\">\n"
      result << line
      result
    end
    wiki = "<source lang=\"ruby\">\n" + wiki + '<' + "/source>\n"
    wiki
  end

  def code_to_wiki(spec)
    wiki = spec.dup
    wiki.gsub! /^(class|module) (.+)/ do |line|
      match = $2
      title = match
      result = '<' + "/source>\n"
      result << "== #{title} ==\n"
      result << "<source lang=\"ruby\">\n"
      result << line
      result
    end
    wiki = "<source lang=\"ruby\">\n" + wiki + '<' + "/source>\n"
    wiki
  end
  
  def log(text)
    time = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    line = "#{time}: #{text}"
    Kernel.puts line
    File.open("piglobot.log", "a") { |f|
      f.puts line
    }
  end
  
  
  def parse_time(text)
    months = %w(janvier février mars avril mai juin
                juillet août septembre octobre novembre décembre)
    if text =~ /\A(\d+) (\S+) (\d{4}) à (\d{2}):(\d{2})\Z/
      month = months.index($2)
      if month
        return Time.local($3.to_i, month + 1, $1.to_i, $4.to_i, $5.to_i, 0)
      end
    end
    raise ArgumentError, "Invalid time: #{text.inspect}"
  end
end

class Piglobot::TemplateParser
  # Code ported from http://svn.wikimedia.org/svnroot/mediawiki/trunk/phase3/includes/Parser.php
  # on revision 26849
  
  attr_accessor :template_names
  
  OT_MSG = 1
  
  def replace_callback(text, callbacks)
    openingBraceStack = [] # this array will hold a stack of parentheses which are not closed yet
    lastOpeningBrace = -1  # last not closed parentheses
    validOpeningBraces = callbacks.keys.join
    i = 0
    
    while i < text.length
      if lastOpeningBrace == -1
        currentClosing = ''
        search = validOpeningBraces
      else
        currentClosing = openingBraceStack[lastOpeningBrace]['braceEnd']
        search = validOpeningBraces + '|' + currentClosing
      end
      
      rule = nil
      
      countUpToSearch = text.index(/[#{Regexp.escape search}]/, i)
      
      if countUpToSearch
        i = countUpToSearch
      else
        i = text.length
      end
      
      if i < text.length
        if text[i].chr == '|'
          found = 'pipe'
        elsif text[i].chr == currentClosing
          found = 'close'
        elsif callbacks[text[i].chr]
          found = 'open'
          rule = callbacks[text[i].chr]
        else
          i += 1
          next
        end
      else
        # All done
        break
      end
  
      if found == 'open'
        # found opening brace, let's add it to parentheses stack
        piece = { 'brace' => text[i].chr,
                  'braceEnd' => rule['end'],
                  'title' => '',
                  'parts' => nil }
  
        # count opening brace characters
        piece['count'] = text[i..-1].scan(/^#{Regexp.escape piece['brace']}+/).first.size
        piece['startAt'] = piece['partStart'] = i + piece['count']
        i += piece['count']
  
        # we need to add to stack only if opening brace count is enough for one of the rules
        if piece['count'] >= rule['min']
          lastOpeningBrace += 1
          openingBraceStack[lastOpeningBrace] = piece
        end
      elsif found == 'close'
        # lets check if it is enough characters for closing brace
        maxCount = openingBraceStack[lastOpeningBrace]['count']
        count = text[i..-1].scan(/^#{Regexp.escape text[i].chr}+/).first.size
        count = maxCount if count > maxCount
  
        # check for maximum matching characters (if there are 5 closing
        # characters, we will probably need only 3 - depending on the rules)
        matchingCount = 0
        matchingCallback = nil
        cbType = callbacks[openingBraceStack[lastOpeningBrace]['brace']]
        if count > cbType['max']
          # The specified maximum exists in the callback array, unless the caller
          # has made an error
          matchingCount = cbType['max']
        else
          # Count is less than the maximum
          # Skip any gaps in the callback array to find the true largest match
          # Need to use array_key_exists not isset because the callback can be null
          matchingCount = count
          while matchingCount > 0 && !cbType['cb'].has_key?(matchingCount)
            matchingCount -= 1
          end
        end
  
        if matchingCount <= 0
          i += count
          next
        end
        matchingCallback = cbType['cb'][matchingCount]
  
        # let's set a title or last part (if '|' was found)
        if openingBraceStack[lastOpeningBrace]['parts'] == nil
          openingBraceStack[lastOpeningBrace]['title'] =
            text[openingBraceStack[lastOpeningBrace]['partStart'],
            i - openingBraceStack[lastOpeningBrace]['partStart']]
        else
          openingBraceStack[lastOpeningBrace]['parts'] <<
            text[openingBraceStack[lastOpeningBrace]['partStart'],
            i - openingBraceStack[lastOpeningBrace]['partStart']]
        end
  
        pieceStart = openingBraceStack[lastOpeningBrace]['startAt'] - matchingCount
        pieceEnd = i + matchingCount
  
        if matchingCallback
          cbArgs = {
                    'text' => text[pieceStart, pieceEnd - pieceStart],
                    'title' => openingBraceStack[lastOpeningBrace]['title'].strip,
                    'parts' => openingBraceStack[lastOpeningBrace]['parts'],
                    'lineStart' => ((pieceStart > 0) && (text[pieceStart-1].chr == "\n")),
                    }
          # finally we can call a user callback and replace piece of text
          object, method = matchingCallback
          before = text[0, pieceStart]
          after = text[pieceEnd..-1]
          replaceWith = object.send(method, cbArgs, before, after)
          if replaceWith
            text = before + replaceWith + after
            i = pieceStart + replaceWith.length
          else
            i = pieceEnd
          end
        else
          # null value for callback means that parentheses should be parsed, but not replaced
          i += matchingCount
        end
  
        # reset last opening parentheses, but keep it in case there are unused characters
        piece = { 'brace' => openingBraceStack[lastOpeningBrace]['brace'],
                  'braceEnd' => openingBraceStack[lastOpeningBrace]['braceEnd'],
                  'count' => openingBraceStack[lastOpeningBrace]['count'],
                  'title' => '',
                  'parts' => nil,
                  'startAt' => openingBraceStack[lastOpeningBrace]['startAt'] }
        openingBraceStack[lastOpeningBrace] = nil
        lastOpeningBrace -= 1
  
        if matchingCount < piece['count']
          piece['count'] -= matchingCount
          piece['startAt'] -= matchingCount
          piece['partStart'] = piece['startAt']
          # do we still qualify for any callback with remaining count?
          currentCbList = callbacks[piece['brace']]['cb'];
          while piece['count'] != 0
            if currentCbList[piece['count']]
              lastOpeningBrace += 1
              openingBraceStack[lastOpeningBrace] = piece
              break
            end
            piece['count'] -= 1
          end
        end
      elsif found == 'pipe'
        # lets set a title if it is a first separator, or next part otherwise
        if openingBraceStack[lastOpeningBrace]['parts'] == nil
          openingBraceStack[lastOpeningBrace]['title'] =
            text[openingBraceStack[lastOpeningBrace]['partStart'],
            i - openingBraceStack[lastOpeningBrace]['partStart']]
          openingBraceStack[lastOpeningBrace]['parts'] = []
        else
          openingBraceStack[lastOpeningBrace]['parts'] <<
            text[openingBraceStack[lastOpeningBrace]['partStart'],
            i - openingBraceStack[lastOpeningBrace]['partStart']]
        end
        openingBraceStack[lastOpeningBrace]['partStart'] = (i += 1)
      end
    end
  
    text
  end
  
  def replace_variables(text, args = [], args_only = false )
    # This function is called recursively. To keep track of arguments we need a stack:
    @arg_stack << args
  
    brace_callbacks = {}
    if !args_only
      brace_callbacks[2] = [self, 'braceSubstitution']
    end
    if @output_type != OT_MSG
      brace_callbacks[3] = [self, 'argSubstitution']
    end
    unless brace_callbacks.empty?
      callbacks = {
        '{' => {
          'end' => '}',
          'cb' => brace_callbacks,
          'min' => args_only ? 3 : 2,
          'max' => (brace_callbacks[3] ? 3 : 2),
        },
        '[' => {
          'end' => ']',
          'cb' => { 2 => nil },
  #        'cb' => { 2 => [self, 'linkSubstitution'] },
          'min' => 2,
          'max' => 2,
        }
      }
      text = replace_callback(text, callbacks)
  
      @arg_stack.pop
    end
    text
  end
  
  def braceSubstitution(args, before, after)
    @templates << [args, before, after]
    nil
  end
  
  def linkSubstitution(args, before, after)
  end
  
  def argSubstitution(args, before, after)
  end
  
  def find_template(text)
    @max_include_size = 4096
    @output_type = OT_MSG
    @arg_stack = []
    @templates = []
    
    replace_variables(text)
    t = @templates.find { |template|
      title = template[0]["title"]
      @template_names.include? title
    }
    if t
      title = t.first["title"]
      parameters = t.first["parts"] || []
      before = t[1]
      after = t[2]
      parameters = parameters.map { |param|
        values = param.split("=", 2).map { |item| item.strip }
        if values.size == 2
          values
        else
          param = param.strip
          if param.empty?
            nil
          else
            [nil, param.strip]
          end
        end
      }.compact
      parameters.each do |name, value|
        if (name =~ /<!--/ and name !~ /-->/) or (value =~ /<!--/ and value !~ /-->/)
          raise Piglobot::ErrorPrevention, "L'infobox contient un commentaire qui dépasse un paramètre"
        end
        if name.nil? or name.empty?
          raise Piglobot::ErrorPrevention, "L'infobox contient un paramètre sans nom"
        end
      end
      {
        :name => title,
        :before => before,
        :after => after,
        :parameters => parameters,
      }
    else
      nil
    end
  end
end

if __FILE__ == $0
  job = ARGV.shift
  if job.nil?
    puts "usage: #$0 <job>"
    puts "Jobs: #{Piglobot.jobs.join(', ')}"
    exit 1
  end
  Piglobot.run(job)
end
