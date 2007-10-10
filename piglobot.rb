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
    along with Foobar.  If not, see <http://www.gnu.org/licenses/>.
=end

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
