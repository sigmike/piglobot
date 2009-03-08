=begin
    This file is part of Ruby-MediaWiki.

    Ruby-MediaWiki is free software: you can redistribute it and/or
    modify it under the terms of the GNU General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    Ruby-MediaWiki is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Ruby-MediaWiki.  If not, see
    <http://www.gnu.org/licenses/>.
=end


require 'uri'
require 'logger'


# Logger is required by article.rb
module MediaWiki
  def self.logger
    if defined? @@logger
      @@logger
    else
      @@logger = Logger.new(STDERR)
    end
  end
end

require 'mediawiki/article'
require 'mediawiki/specialpage'
require 'mediawiki/category'
require 'mediawiki/minibrowser'

##
# =Ruby-MediaWiki - manipulate MediaWiki pages from Ruby.
#
# Please note that documents spit out by MediaWiki *must* be valid
# XHTML (or XML)!
#
# You may not want to use MediaWiki::Wiki directly but let MediaWiki.dotfile
# create your instance. This gives you the power of the dotfile
# infrastructure. See sample apps and <tt>mediawikirc.sample</tt>.
module MediaWiki
  ##
  # There's no need for any language attribute, the "Special:" prefix
  # works in any MediaWiki, regardless of localization settings.
  class Wiki
    ##
    # The MiniBrowser instance used by this Wiki.
    # This must be readable as it's used by Article and Category
    # to fetch themselves.
    attr_reader :browser 
    
    ##
    # The URL-Path to index.php (without index.php) as given 
    # to Wiki#initialize
    attr_reader :url
    
    ##
    # Initialize a new Wiki instance.
    # url:: [String] URL-Path to index.php (without index.php), may containt <tt>user:password</tt> combination.
    # user:: [String] If not nil, log in with that MediaWiki username (see Wiki#login)
    # password:: [String] If not nil, log in with that MediaWiki password (see Wiki#login)
    # loglevel:: [Integer] Loglevel, default is to log all messages >= Logger::WARN = 2
    def initialize(url, user = nil, password = nil, loglevel = Logger::WARN)
      if ENV['MEDIAWIKI_DEBUG']
        MediaWiki::logger.level = Logger::DEBUG
      else 
        MediaWiki::logger.level = loglevel
      end
      
      @url = URI.parse( url.match(/\/$/) ? url : url + '/' )
      @browser = MiniBrowser.new(@url)

      login( user, password ) if user and password
    end

    ##
    # Log in into MediaWiki
    #
    # This is *not* HTTP authentication
    # (put HTTP-Auth into [url] of Wiki#initialize!)
    # user:: [String] MediaWiki username
    # password:: [String] MediaWiki password
    #
    # May raise an exception if cannot authenticate
    def login( username, password )
      data = {'wpName' => username, 'wpPassword' => password, 'wpLoginattempt' => 'Log in'}
      data = @browser.post_content( @url.path + 'index.php?title=Special:Userlogin&action=submitlogin', data )
      if data =~ /<p class='error'>/
        raise "Unable to authenticate as #{username}"
      end
    end

    ##
    # Return a new Category instance with given name,
    # will be constructed with [self] (for MiniBrowser usage)
    # name:: [String] Category name (to be prepended with "Category:")
    def category(name)
      Category.new(self, name)
    end

    ##
    # Return a new Article instance with given name,
    # will be constructed with [self] (for MiniBrowser usage)
    # name:: [String] Article name
    # section:: [Fixnum] Optional section number
    def article(name, section = nil)
      Article.new(self, name, section)
    end

    ##
    # Retrieve all namespaces and their IDs, which could be used for Wiki#allpages
    # result:: [Hash] String => Fixnum
    def namespace_ids
      ids = {}
      SpecialPage.new( self, 'Special:Allpages', nil, false ).xhtml.each_element('//select[@name=\'namespace\']/option') do | o |
        ids[o.text] = o.attributes['value'].to_i
      end
      ids
    end

    ##
    # Returns the pages listed on "Special:Allpages"
    #
    # TODO: Handle big wikis with chunked Special:Allpages
    # namespace_id:: Optional namespace for article index (see Wiki#namespace_ids to retrieve id)
    # result:: [Array] of [String] Articlenames
    def allpages(namespace_id=nil)
      # Dirty, but works
      article_name = 'Special:Allpages'
      article_name += "&namespace=#{namespace_id}" if namespace_id

      pages = []
      SpecialPage.new( self, article_name, nil, false ).xhtml.each_element('table[2]/tr/td/a') do | a |
        pages.push( a.text )
      end
      pages
    end

    ##
    # Construct the URL to a specific article
    #
    # Uses the [url] the Wiki instance was constructed with,
    # appends "index.php", the name parameter and, optionally,
    # the section.
    #
    # Often called by Article, Category, ...
    # name:: [String] Article name
    # section:: [Fixnum] Optional section number
    def article_url(name, section = nil)
      "#{@url.path}index.php?title=#{CGI::escape(name.gsub(' ', '_'))}#{section ? "&section=#{CGI::escape(section.to_s)}" : ''}"
    end

    def full_article_url(name, section=nil)
      uri = @url.dup
      uri.path, uri.query = article_url(name, section).split(/\?/, 2)
      uri.to_s
    end

    def history(name, count, offset = nil)
      url_name = CGI::escape(name.gsub(' ', '_'))
      oldid_url = "#{@url.path}index.php?title=#{url_name}"
      url = "#{@url.path}index.php?title=#{url_name}&limit=#{count}"
      url << "&offset=#{offset}" if offset
      url << "&action=history"
      content = @browser.get_content(url)
      doc = REXML::Document.new(content)
      result = []
      doc.each_element("//li") do |li|
        oldid = nil
        date = nil
        author = nil
        comment = nil
        li.each_element("a") do |a|
          href = a.attributes["href"]
          if href !~ /diff=/ and href =~ /\oldid=(\d+)/
            if $1 != "0"
              oldid = $1
              date = a.text
              break
            end
          end
        end
    
        if oldid
          li.each_element("span") do |span|
            case span.attributes["class"]
            when "history-user"
              span.each_element("a") do |a|
                author = a.text
                break
              end
            when "comment"
              comment = span.to_a.join.sub(/\A\((.*)\Z\)/, "\\1")
            end
          end
          result << {
            :oldid => oldid,
            :author =>  author,
            :date => date,
          }
        end
      end
      result
    end
    
    def old_text(name, oldid)
      url_name = CGI::escape(name.gsub(' ', '_'))
      content = @browser.get_content("#{@url.path}index.php?title=#{url_name}&action=edit&oldid=#{oldid}")
      doc = REXML::Document.new(content)
      if form = doc.elements['//form'] and form.attributes["name"] == "editform"
        # we got an editable article
        form.elements['textarea'].text
      end
    end
  
    def category_slice(name, next_id = nil)
      url_name = CGI::escape("Category:" + name.gsub(' ', '_'))
      url = "#{@url.path}index.php?title=#{url_name}"
      url << "&from=#{next_id}" if next_id
      puts url if $VERBOSE
      content = @browser.get_content(url)
      res = []
      content.scan(%r{<li><a href=".+?" title="(.+?)">(.+?)</a></li>}).each do |title, text|
        title.gsub! /&#039;/, "'"
        if title == text
          res << title.gsub("&amp;", "&")
        end
      end
      next_id = nil
      content.scan(%r{\(<a href=".+?\?title=.+?&amp;from=(.+?)" title=".+?">200 éléments suivants</a>\)}).each do |id,|
        next_id = id
      end
      [res, next_id]
    end
    
    def full_category(name)
      res = []
      next_id = nil
      loop do
        msg = "Getting pages in category #{name}"
        msg << " starting at #{next_id.inspect}" if next_id
        puts msg
        items, next_id = category_slice(name, next_id)
        res += items
        break unless next_id
      end
      res
    end
  
    def links(page, offset = "0", namespace = nil)
      res = []
      count = 500
      url = article_url("Special:Whatlinkshere/#{page}")
      url << "&limit=#{count}" if count
      url << "&from=#{offset}"
      url << "&namespace=#{namespace}" if namespace
      content = @browser.get_content(url)
      items = content.scan(%r{<li><a href=".+?" title="(.+?)">.+?</a>.+?</li>}).flatten.map { |title|
        REXML::Text.unnormalize(title)
      }
      next_id = nil
      # <a href="/w/index.php?title=Special:Pages_li%C3%A9es/Mod%C3%A8le:Archive_LANN&amp;from=493505&amp;back=0" title="Special:Pages liées/Modèle:Archive LANN">50 suivantes</a>
      if content =~ %r{<a href="[^"]+&amp;from=(\d+)&amp;back=\d+[^"?]*" title="Sp(e|é)cial:[^"]+">\d+ suivante?s</a>}
        next_id = $1
      end
      [items, next_id]
    end
    
    def full_links(page, namespace = nil)
      result = []
      next_id = "0"
      loop do
        args = [page, next_id]
        args << namespace if namespace
        items, next_id = links(*args)
        result += items
        break unless next_id
      end
      result
    end
  
    def all_pages(offset, namespace)
      res = []
      url = article_url("Special:Allpages")
      url << "&from=#{offset}"
      url << "&namespace=#{namespace}"
      content = @browser.get_content(url)
      table = content.scan(%r{<table style="background: inherit;" border="0" width="100%">(.+?)</table>}m).first
      raise "Table not found in AllPages" if table.nil? or table.empty?
      items = table.first.scan(%r{<td><a href=".+?" title="(.+?)">.+?</a></td>}).flatten.map { |title|
        REXML::Text.unnormalize(title)
      }
      next_id = nil
      if content =~ %r{<a href="[^"]+title=Special:Allpages&amp;from=([^&]+)&amp;namespace=[^"]+" title="Special:Allpages">Page suivante \(.+?\)</a>}
        next_id = $1
      end
      [items, next_id]
    end
    
    def full_all_pages(namespace)
      result = []
      next_id = ""
      loop do
        args = [next_id, namespace]
        puts "All pages starting at #{next_id.inspect}"
        items, next_id = all_pages(*args)
        result += items
        break unless next_id
      end
      puts "All pages done"
      result
    end
  
    def page_url(name, data)
      "/w/index.php?title=" +
        CGI.escape(name.gsub(" ", "_")).gsub("%3A", ":").gsub("%2F", "/") +
        "&" + data.sort.map { |name, value| CGI.escape(name) + "=" + CGI.escape(value) }.join("&")
    end
    
    def raw_get(name)
      url = page_url(name, "action" => "edit")
      content = @browser.get_content(url)
    end
    
    def fast_get(name)
      content = raw_get(name)
      result = content.scan(%r{<textarea name="wpTextbox1" id="wpTextbox1" cols="80" rows="25" tabindex="1" accesskey=",">(.*?)</textarea>}m).first
      raise "textbox not found in #{url}" if result.nil? or result.empty?
      result.first
    end
  
    def fast_post(name, text, comment)
      c = raw_get(name)
      data = {
        "wpEditToken" => c.scan(%r{<input type='hidden' value="(.+?)" name="wpEditToken" />}).first.first,
        "wpStarttime" => c.scan(%r{<input type='hidden' value="(.+?)" name="wpStarttime" />}).first.first,
        "wpEdittime" => c.scan(%r{<input type='hidden' value="(.+?)" name="wpEdittime" />}).first.first,
       "wpTextbox1" => text,
       "wpSummary" => comment,
      }
      url = page_url(name, "action" => "submit")
      @browser.post_content(url, data)
    end
  
    def fast_append(name, text, comment)
      c = raw_get(name)
      data = {
        "wpEditToken" => c.scan(%r{<input type='hidden' value="(.+?)" name="wpEditToken" />}).first.first,
        "wpStarttime" => c.scan(%r{<input type='hidden' value="(.+?)" name="wpStarttime" />}).first.first,
        "wpEdittime" => c.scan(%r{<input type='hidden' value="(.+?)" name="wpEdittime" />}).first.first,
       "wpTextbox1" => c.scan(%r{<textarea name="wpTextbox1" id="wpTextbox1" cols="80" rows="25" tabindex="1" accesskey=",">(.+?)</textarea>}m).first.first + text,
       "wpSummary" => comment,
      }
      url = page_url(name, "action" => "submit")
      @browser.post_content(url, data)
    end
    
    def list_users(group, offset = nil)
      items = []
      next_id = nil
      options = { "limit" => "50", "group" => group }
      options["offset"] = CGI.unescape(offset) if offset
      url = page_url("Special:Listusers", options)
      content = @browser.get_content(url)
      res = content.scan(%r{<li><a href="/wiki/Utilisateur:.+?" title="Utilisateur:.+?">(.+?)</a>})
      items = res.map { |match| match.first }
      #  (<a href="/w/index.php?title=Sp%C3%A9cial:Liste_des_utilisateurs&amp;offset=GL&amp;group=sysop" title="Spécial:Liste des utilisateurs" rel="next" class="mw-nextlink">50 suivantes</a>)
      next_id = content.scan(%r{offset=([^&]+)&amp;group=#{group}" title="(Special:Listusers|Sp(e|é)cial:Liste des utilisateurs)"[^>]*>50 éléments suivants</a>}).first
      next_id = next_id.first if next_id
      
      [items, next_id]
    end
    
    def list_all_users(group)
      items, offset = list_users(group)
      while offset do
        new_items, offset = list_users(group, offset)
        items += new_items
      end
      items
    end
    
    def unquote(text)
      text.gsub("&amp;", "&").gsub("&quot;", "\"")
    end
  
    def contributions(user, count)
      items = []
      options = { "limit" => count.to_s, "target" => user }
      url = page_url("Special:Contributions", options)
      content = @browser.get_content(url)
      res = content.scan(%r{<li class="">.+?">(.+?)</a> \(<a href="[^"]+" title="([^"]+)">hist</a>\) \(<a href=".+?&amp;oldid=([^"]+?)"})
      items = res.map { |match| { :date => match[0], :page => unquote(match[1]), :oldid => match[2] } }
      
      items
    end
    
  end
end

