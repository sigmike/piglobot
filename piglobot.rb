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
end

require 'editor'
require 'dump'
require 'template_parser'
require 'tools'
require 'wiki'

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
  
  attr_accessor :job, :wiki, :editor
  
  def Piglobot.jobs
    [
      "Infobox Logiciel",
      "Homonymes",
      "Infobox Aire protégée",
    ]
  end
  
  def Piglobot.code_files
    %w(
      piglobot_spec.rb
      piglobot.rb
      editor_spec.rb
      editor.rb
      dump_spec.rb
      dump.rb
      tools_spec.rb
      tools.rb
      wiki_spec.rb
      wiki.rb
      template_parser.rb
    )
  end
  
  class Job
    attr_accessor :data
    
    def initialize(bot)
      @bot = bot
      @wiki = bot.wiki
      @editor = bot.editor
      @changed = false
      @data = nil
    end
    
    def data_id
      self.class.name
    end
    
    def changed?
      @changed
    end
  end
  
  class HomonymPrevention < Job
    def data_id
      "Homonymes"
    end
  
    def process
      changes = false
      data = @data
      data ||= {}
      china = data["Chine"] || {}
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
      data["Chine"] = china
      @changed = changes
      @data = data
    end
  end
  
  class InfoboxRewriter < Job
    def data_id
      @infobox
    end
  
    def initialize(bot, infobox, links)
      super(bot)
      @infobox = infobox
      @links = links
    end
    
    def process
      data = @data
      changes = false
      infobox = @infobox
      links = @links
      
      articles = data
  
      if articles and !articles.empty?
        article = articles.shift
        @bot.current_article = article
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
              @bot.notice("#{infobox} non trouvée dans l'article", article)
              changes = true
            end
          rescue => e
            @bot.notice(e.message, article)
            changes = true
          end
        end
        @bot.current_article = nil
      else
        articles = []
        links.each do |link|
          articles += @wiki.links(link)
        end
        articles.uniq!
        articles.delete_if { |name| name =~ /:/ and name !~ /::/ }
        data = articles
        @bot.notice("#{articles.size} articles à traiter pour #{infobox}")
        changes = true
      end
      @changed = changes
      @data = data
    end
  end
  
=begin
  class InfoboxSoftware < InfoboxRewriter
    def initialize(bot)
      super(bot, "Infobox Logiciel", ["Modèle:Infobox Logiciel"])
    end
  end
  
  class InfoboxProtectedArea < InfoboxRewriter
    def initialize(bot)
      super(bot,
        "Infobox Aire protégée",
        ["Modèle:Infobox Aire protégée", "Modèle:Infobox aire protégée"]
      )
    end
  end
=end
      
  def process_infobox(data, infobox, links)
    job = InfoboxRewriter.new(self, infobox, links)
    job.data = data[job.data_id]
    job.process
    data[job.data_id] = job.data
    job.changed?
  end
  
  def process_homonyms(data)
    job = HomonymPrevention.new(self)
    job.data = data[job.data_id]
    job.process
    data[job.data_id] = job.data
    job.changed?
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
    line = ""
    line << "[[#{article}]] : " if article
    line << text
    @wiki.append(@log_page, "* ~~~~~ : #{line}", line)
  end
  
  def self.run(job)
    bot = new
    bot.job = job
    loop do
      bot.step
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
