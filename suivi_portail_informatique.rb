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

class SuiviPortailInformatique < Piglobot::Job
  def initialize(*args)
    super
    @name = "[[Projet:Informatique/Suivi]]"
  end

  def process
    pages = @wiki.links("Modèle:Portail informatique")
    now = Time.now
    date = Piglobot::Tools.write_date(now)
    bot = "{{u|Piglobot}}"
    text = "<noinclude><small>''Liste des articles référencés par le projet « Informatique ». Mise à jour le #{date} par #{bot}.''</small></noinclude>\n"
    text << pages.map { |page| "* [[:#{page}]]\n" }.join
    @wiki.post("Projet:Informatique/Suivi", text, "Mise à jour automatique")
  end
end
