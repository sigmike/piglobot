require 'job'
require 'ruby-mediawiki/lib/mediawiki/minibrowser'

class Change < Piglobot::Job
  attr_accessor :raw_data, :currencies

  def initialize(*args)
    super
    @name = "{{m|Change}}"
  end

  def process
    get_raw_data
    parse_raw_data
    publish_data
  end
  
  def get_raw_data
    uri = URI.parse("http://xurrency.com/")
    browser = MediaWiki::MiniBrowser.new(uri)
    @raw_data = browser.get_content("/usd/feed")
  end
  
  def parse_raw_data
    regexp = %r{<title xml:lang="en"><!\[CDATA\[1 USD = ([\d\.]+) ([A-Z]+)\]\]></title>}
    @currencies = {}
    @raw_data.scan(regexp).each do |value, name|
      @currencies[name] = value
    end
  end
  
  def publish_data
    %w( EUR GBP JPY CAD CHF ).each do |name|
      value = @currencies[name]
      if value
        @wiki.post("Modèle:Change/#{name}", value, "[[Utilisateur:Piglobot/Travail#Change|Mise à jour automatique]]")
      else
        notice("[[Modèle:Change/#{name}]] : Aucune donnée")
      end
    end
  end
end
