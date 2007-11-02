class Piglobot::Dump
  def initialize(wiki)
    @wiki = wiki
  end
  
  def publish_code(comment)
    content = Piglobot.code_files.map do |file|
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
    begin
      YAML.load File.read("data.yaml")
    rescue Errno::ENOENT
      nil
    end
  end

  def save_data data
    File.open("data.yaml", "w") do |f|
      f.write data.to_yaml
    end
  end
end

