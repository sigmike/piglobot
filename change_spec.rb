
require 'change'

describe Change do
  before do
    @bot = mock("bot")
    @wiki = mock("wiki")
    @bot.should_receive(:wiki).with().and_return(@wiki)
    @job = Change.new(@bot)
  end
  
  it "should process" do
    @job.should_receive(:get_raw_data).with()
    @job.should_receive(:parse_raw_data).with()
    @job.should_receive(:publish_data).with()
    @job.process
  end
  
  it "should get_raw_data" do
    url = URI.parse("http://xurrency.com/")
    @browser = mock("browser")
    MediaWiki::MiniBrowser.should_receive(:new).with(url).and_return(@browser)
    @browser.should_receive(:get_content).with("/usd/feed").and_return("content")
    @job.get_raw_data
    @job.raw_data.should == "content"
  end
  
  it "should parse_raw_data" do
    @job.raw_data = File.read("sample_currency.xhtml")
    @job.parse_raw_data
    {
      "EUR" => "0.6818",
      "GBP" => "0.4747",
      "JPY" => "113.6364",
      "CAD" => "0.9293",
      "CHF" => "1.1320",
    }.each do |name, value|
      { name => @job.currencies[name] }.should == { name => value }
    end
  end
  
  it "should publish_data" do
    @job.currencies = {
      "EUR" => "0.6818",
      "GBP" => "0.4747",
      "JPY" => "113.6364",
      "CAD" => "0.9293",
      "CHF" => "1.1320",
    }
    @job.currencies.each do |name, value|
      @wiki.should_receive(:post).with("Modèle:Change/#{name}", value, "[[Utilisateur:Piglobot/Travail#Change|Mise à jour automatique]]")
    end
    @job.publish_data
  end
  
  it "should notice when a currency is missing" do
    @job.currencies = {}
    %w( EUR GBP JPY CAD CHF ).each do |name|
      @job.should_receive(:notice).with("[[Modèle:Change/#{name}]] : Aucune donnée")
    end
    @job.publish_data
  end
  
  it "should always be done" do
    @job.done?.should == true
  end
  
  it "should have a better name" do
    @job.name.should == "{{m|Change}}"
  end
end
