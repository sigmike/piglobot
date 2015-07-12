# encoding: utf-8
=begin
    Copyright (c) 2007-2012 by Piglop
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

require File.expand_path('../piglobot', __FILE__)

bot = Piglobot.new

excluded =  bot.api.get_wikitext("Wikipédia:Liste des administrateurs inactifs/Exclusions").body
excluded = excluded.scan(%r"\{\{u\|(.+?)\}\}").map { |match| match.first }
excluded.delete "Nom de l'utilisateur"

admins = bot.admin_names
admins -= excluded

limit = Date.today << 3

last_time = {}

admins.each do |admin|
  last_time[admin] = bot.last_contribution_time(admin)
end

inactive_admins = admins.select do |admin|
  last_time[admin].nil? or last_time[admin] < limit
end

now = bot.format_date(Time.now)

text = "Liste des administrateurs inactifs (hors [[Wikipédia:Liste des administrateurs inactifs/Exclusions|exclusions]]) depuis plus de 3 mois. Mise à jour le #{now} par {{u|Piglobot}}.\n"
text << inactive_admins.sort_by { |admin| last_time[admin] }.map do |admin|
  time = last_time[admin]
  if time
    date = bot.format_date(time)
    "* {{u|#{admin}}}, dernière contribution le #{date}\n"
  else
    "* {{u|#{admin}}}, aucune contribution\n"
  end
end.join

page = "Wikipédia:Liste des administrateurs inactifs"
page = "Utilisateur:Piglobot/Bac à sable"

bot.edit(page, text, "[[Utilisateur:Piglobot/Administrateurs inactifs|Mise à jour des administrateurs inactifs]]")
