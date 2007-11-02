module PiglobotHelper
  def create_bot
    @wiki = mock("wiki")
    @dump = mock("dump")
    Piglobot::Wiki.should_receive(:new).and_return(@wiki)
    Piglobot::Dump.should_receive(:new).once.with(@wiki).and_return(@dump)
    received_bot = nil
    @bot = Piglobot.new
    @bot
  end
end

