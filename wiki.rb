class Piglobot::Wiki
  def initialize
    @wiki = MediaWiki::Wiki.new("http://fr.wikipedia.org/w", "Piglobot", File.read("password"))
  end
  
  def internal_post(article_name, text, comment)
    article = @wiki.article(article_name)
    article.text = text
    Piglobot::Tools.log("Post [[#{article_name}]] (#{comment})")
    article.submit(comment)
  end

  def internal_get(article_name)
    article = @wiki.article(article_name)
    Piglobot::Tools.log("Get [[#{article_name}]]")
    article.text
  end
  
  def internal_append(article_name, text, comment)
    article = @wiki.article(article_name)
    article.text += text
    Piglobot::Tools.log("Append [[#{article_name}]] (#{comment})")
    article.submit(comment)
  end
  
  def internal_links(name)
    article = @wiki.article(name)
    Piglobot::Tools.log("What links to [[#{name}]]")
    article.fast_what_links_here(5000)
  end
  
  def internal_category(category)
    Piglobot::Tools.log("[[Category:#{category}]]")
    @wiki.full_category(category)
  end
  
  def internal_history(name, count, offset = nil)
    Piglobot::Tools.log("History [[#{name}]] (#{count}, #{offset.inspect})")
    history = @wiki.history(name, count, offset)
    history.each do |result|
      result[:date] = Piglobot::Tools.parse_time(result[:date])
    end
    history
  end
  
  def retry(method, *args)
    begin
      send(method, *args)
    rescue => e
      Piglobot::Tools.log("Retry in 10 minutes (#{e.message})")
      Kernel.sleep(10*60)
      retry
    end
  end
  
  %w( get post append links category history ).each do |method|
    define_method(method.intern) do |*args|
      self.retry("internal_#{method}".intern, *args)
    end
  end
end

