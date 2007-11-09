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

class Piglobot
  class Job
    attr_accessor :data, :name
    
    def initialize(bot)
      @bot = bot
      @wiki = bot.wiki
      @changed = false
      @data = nil
      @name = self.class.name
    end
    
    def data_id
      self.class.name
    end
    
    def changed?
      @changed
    end
    
    def process
      raise "No process defined in this job"
    end
    
    def done?
      true
    end
    
    def notice(text)
      @bot.notice("#@name : #{text}")
    end
  end
  
end
