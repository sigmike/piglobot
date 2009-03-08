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
      user_category.rb
      user_category_spec.rb
      change.rb
      change_spec.rb
      infobox_rewriter.rb
      infobox_rewriter_spec.rb
      editor_spec.rb
      editor.rb
      suivi_portail_informatique.rb
      suivi_portail_informatique_spec.rb
      job_lann_spec.rb
      job_lann.rb
      homonym_prevention.rb
      homonym_prevention_spec.rb
      tools_spec.rb
      tools.rb
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
  
  def load_data(data_id)
    @data = begin
      YAML.load File.read("#{data_id}.yaml")
    rescue Errno::ENOENT
      nil
    end
    @data = nil if data == false
    @data
  end

  def save_data(data_id)
    filename = "#{data_id}.yaml"
    new_filename = "#{filename}.new"
    File.open(new_filename, "w") do |f|
      f.write @data.to_yaml
    end
    File.rename(new_filename, filename)
  end
  
  def job_class job
    case job
    when "Homonymes" then require 'homonym_prevention'; HomonymPrevention
    when "Infobox Logiciel" then require 'infobox_rewriter'; InfoboxSoftware
    when "Infobox Aire protégée" then require 'infobox_rewriter'; InfoboxProtectedArea
    when "LANN" then require 'job_lann'; LANN
    when "AàC" then require 'job_lann'; AaC
    else
      if job.is_a? Class and job.superclass == Piglobot::Job
        job
      else
        begin
          require job
          class_name = job.capitalize.gsub(/_([a-z])/) { $1.upcase }
          Object.const_get(class_name)
        rescue NameError, TypeError, LoadError
          raise "Invalid job: #{job.inspect}"
        end
      end
    end
  end

  def process
    job = nil
    job = job_class(@job).new(self)
    data_id = job.data_id
    load_data(data_id)
    job.data = @data
    job.process
    @data = job.data
    save_data(data_id)
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
              msg = "#{job.name} : Terminé"
              notice(msg)
              Tools.log(msg)
              throw :done
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
        rescue Interrupt, MediaWiki::InternalServerError, Timeout::Error
          raise
        rescue Exception => e
          log_error(e)
          throw :done
        end
      else
        throw :done
      end
    rescue MediaWiki::InternalServerError, Timeout::Error => e
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
    catch :done do
      loop do
        bot.step
      end
    end
  end
end

if __FILE__ == $0
  job = ARGV.first
  if job.nil?
    puts "usage: #$0 <job>"
    exit 1
  end
  Piglobot.run(job)
end
