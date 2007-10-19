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
  class Wiki
    def initialize
      @wiki = MediaWiki::Wiki.new("http://fr.wikipedia.org/w", "Piglobot", File.read("password"))
    end
    
    def post(article, text, comment)
      article = @wiki.article(article)
      article.text = text
      article.submit(comment)
    end
  
    def get(article)
      article = @wiki.article(article)
      article.text
    end
    
    def links(name)
      article = @wiki.article(name)
      article.fast_what_links_here(1000)
    end
  end
  
  class Dump
    def initialize(wiki)
      @wiki = wiki
    end
    
    def publish(name, text, comment, lang = "ruby")
      text = "<source lang=\"#{lang}\">\n#{text}</source" + ">"
      article = @wiki.post("Utilisateur:Piglobot/#{name}", text, comment)
    end
    
    def publish_spec(comment)
      publish("Spec", File.read("piglobot_spec.rb"), comment)
    end
  
    def publish_code(comment)
      publish("Code", File.read("piglobot.rb"), comment)
    end
    
    attr_accessor :data
    def load_data
      text = @wiki.get("Utilisateur:Piglobot/Data")
      result = text.scan(/<source lang="text">(.*)<\/source>/m)
      if result.first and result.first.first
        @data = YAML.load(result.first.first)
      else
        @data = nil
      end
    end
  
    def save_data data
      publish("Data", data.to_yaml, "Sauvegarde", "text")
    end
  end
  
  class Editor
    OT_MSG = 1
    
    def initialize(wiki)
      @wiki = wiki
    end
    
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
    
    def parse_infobox(text)
      @max_include_size = 4096
      @output_type = OT_MSG
      @arg_stack = []
      @templates = []
      
      replace_variables(text)
      t = @templates.find { |template|
        title = template[0]["title"]
        title == "Infobox Logiciel" or
          title == "Logiciel simple" or
          title == "Logiciel_simple" or
          title == "Logiciel"
      }
      if t
        parameters = t.first["parts"] || []
        before = t[1]
        after = t[2]
        parameters = parameters.map { |param|
          values = param.split("=", 2).map { |item| item.strip }
          if values.size == 2
            values
          else
            nil
          end
        }.compact
        {
          :before => before,
          :after => after,
          :parameters => parameters,
        }
      else
        nil
      end
    end
    
    def write_infobox(box)
      if box[:parameters].empty?
        args = ""
      else
        args = "\n" + box[:parameters].map { |name, value|
          "| #{name} = #{value}\n"
        }.join
      end
      "#{box[:before]}{{Infobox Logiciel#{args}}}#{box[:after]}"
    end
  end
  
  def initialize
    @wiki = Wiki.new
    @dump = Dump.new(@wiki)
    @editor = Editor.new(@wiki)
  end
  
  def run
    data = @dump.load_data
    if data.nil?
      data = {}
    else
      articles = data["Infobox Logiciel"]
      if articles and !articles.empty?
        article = articles.shift
        text = @wiki.get(article)
        box = @editor.parse_infobox(text)
        if box
          result = @editor.write_infobox(box)
          @wiki.post("Utilisateur:Piglobot/Bac à sable",
            text,
            "Texte initial de l'article [[#{article}]]")
          @wiki.post("Utilisateur:Piglobot/Bac à sable",
            result,
            "Correction de la syntaxe de l'infobox")
        else
          @wiki.post("Utilisateur:Piglobot/Bac à sable",
            text,
            "Infobox non trouvée dans l'article [[#{article}]]")
        end
      else
        data["Infobox Logiciel"] = @wiki.links("Modèle:Infobox Logiciel")
      end
    end
    @dump.save_data(data)
  end
end

if __FILE__ == $0
  bot = Piglobot.new
  bot.run
end
