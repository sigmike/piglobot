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
  
  
  def parse_time(text)
    months = %w(janvier février mars avril mai juin
                juillet août septembre octobre novembre décembre)
    if text =~ /\A(\d+) (\S+) (\d{4}) à (\d{2}):(\d{2})\Z/
      month = months.index($2)
      if month
        return Time.local($3.to_i, month + 1, $1.to_i, $4.to_i, $5.to_i, 0)
      end
    end
    raise ArgumentError, "Invalid time: #{text.inspect}"
  end
end

