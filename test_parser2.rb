
=begin
   * Replace magic variables, templates, and template arguments
   * with the appropriate text. Templates are substituted recursively,
   * taking care to avoid infinite loops.
   *
   * Note that the substitution depends on value of $mOutputType:
   *  OT_WIKI: only {{subst:}} templates
   *  OT_MSG: only magic variables
   *  OT_HTML: all templates and magic variables
   *
   * @param string $tex The text to transform
   * @param array $args Key-value pairs representing template parameters to substitute
   * @param bool $argsOnly Only do argument (triple-brace) expansion, not double-brace expansion
   * @private
=end

require 'rubygems'
require 'ruby-debug'

OT_MSG = 1

@max_include_size = 4096
@output_type = OT_MSG
@arg_stack = []

#function replace_callback ($text, $callbacks) {
def replace_callback(text, callbacks)
  #wfProfileIn( __METHOD__ );
  #$openingBraceStack = array();  # this array will hold a stack of parentheses which are not closed yet
  openingBraceStack = [] # this array will hold a stack of parentheses which are not closed yet

  #$lastOpeningBrace = -1;      # last not closed parentheses
  lastOpeningBrace = -1  # last not closed parentheses

  #$validOpeningBraces = implode( '', array_keys( $callbacks ) );
  validOpeningBraces = callbacks.keys.join

  #$i = 0;
  i = 0
  
  
  #while ( $i < strlen( $text ) ) {
  while i < text.length
    #debugger
    # Find next opening brace, closing brace or pipe
    #if ( $lastOpeningBrace == -1 ) {
      #$currentClosing = '';
      #$search = $validOpeningBraces;
    #} else {
      #$currentClosing = $openingBraceStack[$lastOpeningBrace]['braceEnd'];
      #$search = $validOpeningBraces . '|' . $currentClosing;
    #}

    if lastOpeningBrace == -1
      currentClosing = ''
      search = validOpeningBraces
    else
      currentClosing = openingBraceStack[lastOpeningBrace]['braceEnd']
      search = validOpeningBraces + '|' + currentClosing
    end
    
    #$rule = null;
    rule = nil
    
    #$i += strcspn( $text, $search, $i );
    countUpToSearch = text.index(/[#{Regexp.escape search}]/, i)
    
    #if countUpToSearch
    if countUpToSearch
      i = countUpToSearch
    else
      i = text.length
    end
    #else
    #  i += 1
    #  next
    #end
    
    #if ( $i < strlen( $text ) ) {
    if i < text.length
      #if ( $text[$i] == '|' ) {
      if text[i].chr == '|'
        found = 'pipe'
      elsif text[i].chr == currentClosing
        found = 'close'
      elsif callbacks[text[i].chr]
        found = 'open'
        rule = callbacks[text[i].chr]
      else
        # Some versions of PHP have a strcspn which stops on null characters
        # Ignore and continue
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
        replaceWith = object.send(method, cbArgs)
        if replaceWith
          text = text[0, pieceStart] + replaceWith + text[pieceEnd..-1]
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

  #wfProfileOut( __METHOD__ );
  text
#}
end

def replace_variables(text, args = [], args_only = false )
  # Prevent too big inclusions
  if text.length > @max_include_size
    return text;
  end

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

def braceSubstitution(args)
  puts "Template #{args['title'].inspect} with args #{args['parts'].inspect}"
  #puts "braceSubstitution(#{args.inspect})"
  "(parsed template)"
end

def linkSubstitution(args)
  puts "Link #{args['title'].inspect} with args #{args['parts'].inspect}"
  #puts "braceSubstitution(#{args.inspect})"
end

def argSubstitution(*args)
  puts "argSubstitution(#{args.inspect})"
end


def wikiparse text
  p(replace_variables(text))
end


#wikiparse "{{foo | hello | bob | [[test]] }}"

if true
wikiparse <<EOF
{{Logiciel_simple
| nom = Konqueror
| logo = [[Image:Crystal konqueror.svg|48px]]
| image = [[Image:Konqueror 3.4.1.png|250px|Konqueror 3.4.1 sous [[Debian]]]]
| description = Konqueror
| développeur = Équipe Konqueror de [[KDE]]
| dernière_version = 3.5.7
| date_de_dernière_version = [[22 mai]] [[2007]]
| os = [[Linux]], [[UNIX]], [[Mac OS X]]
| type = [[Navigateur Web]]
| licence = [[Licence publique générale GNU|GPL]]
| site_web = [http://www.konqueror.org konqueror.org]
}}
'''Konqueror''' est un [[navigateur Web]] et un [[gestionnaire de fichiers]] [[logiciel libre|libre]] de l'[[environnement de bureau]] libre [[KDE]].
EOF
end