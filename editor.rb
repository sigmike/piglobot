class Piglobot::Editor
  attr_accessor :name_changes, :template_names, :template_name, :filters, :removable_parameters

  attr_accessor :infobox, :bot, :wiki, :current_article

  def initialize(bot)
    @bot = bot
    @wiki = bot.wiki
  
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
        "caption" => "légende carte",
        "base_width" => "largeur carte",
        "bot_image" => "image pied",
        "bot_caption" => "légende pied",
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
    if @infobox[:name] == "Infobox aire protégée" or @infobox[:name] == "infobox aire protégée" or
      @infobox[:name] == "Infobox_aire protégée" or @infobox[:name] == "infobox_aire protégée"
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
        when "", "[[km²]]", "<!-- {{unité|...|km|2}} -->"
          value = "<!-- {{unité|...|km|2}} -->"
          found = false
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

