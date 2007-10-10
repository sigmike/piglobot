
require 'piglobot'

describe Piglobot do
  before do
    @wiki = mock("wiki")
    @bot = Piglobot.new(@wiki)
  end
  
  it "should publish spec" do
    article = mock("article")
    @wiki.should_receive(:article).with("Utilisateur:Piglobot/Spec").once.and_return(article)
    article.should_receive(:text=).with("<source lang=\"ruby\">\n" + File.read("piglobot_spec.rb") + "<" + "/source>")
    article.should_receive(:submit).with("comment")
    @bot.publish_spec("comment")
  end

  it "should publish code" do
    article = mock("article")
    @wiki.should_receive(:article).with("Utilisateur:Piglobot/Code").once.and_return(article)
    article.should_receive(:text=).with("<source lang=\"ruby\">\n" + File.read("piglobot.rb") + "<" + "/source>")
    article.should_receive(:submit).with("comment")
    @bot.publish_code("comment")
  end
end
