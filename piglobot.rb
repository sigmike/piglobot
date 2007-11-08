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
    along with Piglobot.  If not, see <http://www.gnu.org/licenses/>.
=end

require 'libs'
require 'yaml'
require 'mediawiki'

class Piglobot
end

require 'editor'
require 'parser'
require 'tools'
require 'wiki'
require 'job'
require 'job_lann'
require 'suivi_portail_informatique'

class Piglobot
  class Disabled < RuntimeError; end
  class ErrorPrevention < RuntimeError; end

  attr_accessor :log_page, :data

  def initialize
    @wiki = Wiki.new
    @log_page = "Utilisateur:Piglobot/Journal"
  end
  
  attr_accessor :job, :wiki, :editor
  
  def Piglobot.jobs
    [
      "Infobox Logiciel",
      "Homonymes",
      "Infobox Aire protégée",
    ]
  end
  
  def code_files
    %w(
      suivi_portail_informatique.rb
      suivi_portail_informatique_spec.rb
      job_lann_spec.rb
      job_lann.rb
      job_spec.rb
      job.rb
      piglobot_spec.rb
      piglobot.rb
      editor_spec.rb
      editor.rb
      tools_spec.rb
      tools.rb
      wiki_spec_live.rb
      wiki_spec.rb
      wiki.rb
      parser.rb
      helper.rb
    )
  end

  def publish_code(comment)
    content = code_files.map do |file|
      lang = case file
        when /\.rb\Z/ then "ruby"
        else "text"
        end
      text = File.read(file)
      wiki = Piglobot::Tools.file_to_wiki(file, text, lang)
      wiki
    end
    content = content.join
    @wiki.post("Utilisateur:Piglobot/Code", content, comment)
  end
  
  def load_data
    @data = begin
      YAML.load File.read("data.yaml")
    rescue Errno::ENOENT
      nil
    end
  end

  def save_data
    File.open("data.yaml", "w") do |f|
      f.write @data.to_yaml
    end
  end
  
  def job_class job
    case job
    when "Homonymes" then HomonymPrevention
    when "Infobox Logiciel" then InfoboxSoftware
    when "Infobox Aire protégée" then InfoboxProtectedArea
    when "LANN" then LANN
    when "AàC" then AaC
    when "SuiviPortailInformatique" then SuiviPortailInformatique
    else raise "Invalid job: #{job.inspect}"
    end
  end

  def process
    job = nil
    load_data
    data = @data
    if data.nil?
      data = {}
    else
      job = job_class(@job).new(self)
      data_id = job.data_id
      job.data = data[data_id]
      job.process
      data[data_id] = job.data
    end
    @data = data
    save_data
    job
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
    begin
      if safety_check
        begin
          job = process
          if job
            if job.done?
              notice("#{job.name} : terminé")
              raise Interrupt, "Terminé"
            else
              if job.changed?
                sleep
              else
                short_sleep
              end
            end
          else
            sleep
          end
        rescue Interrupt, MediaWiki::InternalServerError
          raise
        rescue Exception => e
          log_error(e)
          sleep
        end
      else
        sleep
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
