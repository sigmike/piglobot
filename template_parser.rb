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

