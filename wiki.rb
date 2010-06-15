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

require 'rubygems'
$: << File.join(File.dirname(__FILE__), "..", "rwikibot", "lib")
require 'rwikibot'

class Piglobot::Wiki
  def initialize
    @wiki = MediaWiki::Wiki.new("http://fr.wikipedia.org/w", "Piglobot", File.read("password"))
    @bot = RWikiBot.new("Piglobot", File.read("password"), "http://fr.wikipedia.org/w/api.php")
  end
  
  def mediawiki
    @wiki
  end
  
  def internal_post(article_name, text, comment)
    Piglobot::Tools.log("Post [[#{article_name}]] (#{comment})")
    @wiki.fast_post(article_name, text, comment)
  end

  def internal_get(article_name)
    Piglobot::Tools.log("Get [[#{article_name}]]")
    @bot.page(article_name).content["content"]
  end
  
  def internal_append(article_name, text, comment)
    Piglobot::Tools.log("Append [[#{article_name}]] (#{comment})")
    @wiki.fast_append(article_name, text, comment)
  end
  
  def internal_links(name, namespace = nil)
    if namespace
      Piglobot::Tools.log("What links to [[#{name}]] in namespace #{namespace}")
      @wiki.full_links(name, namespace)
    else
      Piglobot::Tools.log("What links to [[#{name}]]")
      @wiki.full_links(name)
    end
  end
  
  def internal_category(category)
    Piglobot::Tools.log("[[Category:#{category}]]")
    @wiki.full_category(category)
  end
  
  def internal_history(name, count, start = nil)
    Piglobot::Tools.log("History [[#{name}]] (#{count})")
    options = { :titles => name, :limit => count }
    options[:startid] = start if start
    history = @bot.revisions(options)
    history = history.fetch("pages").fetch("page").fetch("revisions").fetch("rev")
    history.map do |rev|
      {
        :oldid => rev["revid"],
        :date => Piglobot::Tools.parse_time(rev["timestamp"]),
        :author => rev["user"],
      }
    end           
  end
  
  def internal_contributions(name, count)
    Piglobot::Tools.log("Contributions of #{name} (#{count})")
    contribs = @bot.contributions(:user => name, :limit => count)
    contribs.map do |item|
      {
        :oldid => item["revid"],
        :page => item["title"],
        :date => Piglobot::Tools.parse_time(item["timestamp"])
      }
    end
  end
  
  def internal_all_pages(namespace)
    Piglobot::Tools.log("AllPages in namespace #{namespace}")
    @wiki.full_all_pages(namespace)
  end
  
  def internal_users(group)
    Piglobot::Tools.log("User list in group #{group}")
    @wiki.list_all_users(group)
  end
  
  def retry(method, *args)
    retried = 0
    begin
      send(method, *args)
    rescue => e
      if retried < 9
        Piglobot::Tools.log("Error in #{method}(#{args.map { |x| x.inspect}.join(',')}). Retry in 10 minutes (#{e.message})")
        puts e.backtrace.join("\n") if $VERBOSE
        Kernel.sleep(10*60)
        retried += 1
        retry
      else
        raise e
      end
    end
  end
  
  %w( get post append links category history all_pages users contributions ).each do |method|
    define_method(method.intern) do |*args|
      self.retry("internal_#{method}".intern, *args)
    end
  end
end

