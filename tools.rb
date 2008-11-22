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

module Piglobot::Tools
  module_function
  
  def file_to_wiki(filename, content, lang)
    result = ""
    result << "== #{filename} ==\n"
    result << "<source lang=\"#{lang}\">\n"
    result << content + "\n"
    result << '<' + "/source>\n"
    result << "\n"
    result
  end
  
  def log(text)
    time = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    line = "#{time}: #{text}"
    Kernel.puts line
    File.open("piglobot.log", "a") { |f|
      f.puts line
    }
  end
  
  MONTHS = %w(janvier février mars avril mai juin
              juillet août septembre octobre novembre décembre)
  
  def parse_time(text)
    if text =~ /\A(\d+) (\S+) (\d{4}) à (\d{2}):(\d{2})\Z/
      month = MONTHS.index($2)
      if month
        return Time.utc($3.to_i, month + 1, $1.to_i, $4.to_i, $5.to_i, 0)
      end
    end
    raise ArgumentError, "Invalid time: #{text.inspect}"
  end
  
  def write_date(time)
    day = time.day
    month = MONTHS[time.month - 1]
    year = time.year
    "{{date|#{day}|#{month}|#{year}}}"
  end
end

