
class Piglobot
  def initialize(wiki)
    @wiki = wiki
  end
  
  def publish(name, file, comment)
    article = @wiki.article("Utilisateur:Piglobot/#{name}")
    article.text = "<source lang=\"ruby\">\n" +
      File.read(file) +
      "<" + "/source>"
    article.submit(comment)
  end
  
  def publish_spec(comment)
    publish("Spec", "piglobot_spec.rb", comment)
  end

  def publish_code(comment)
    publish("Code", "piglobot.rb", comment)
  end
end
