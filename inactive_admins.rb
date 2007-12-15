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

require 'job'

class InactiveAdmins < Piglobot::Job
  def process
    get_admin_list
    remove_excluded
    get_last_contribution
    remove_active
    publish_list
  end
  
  def get_admin_list
    @data = @wiki.users("sysop")
  end
  
  def remove_excluded
    excluded = @wiki.get("Wikipédia:Liste des administrateurs inactifs/Exclusions")
    excluded = excluded.scan(%r"\{\{u\|(.+?)\}\}").map { |match| match.first }
    @data.delete_if { |admin| excluded.include? admin }
  end
  
  def get_last_contribution
    @data.map! { |user|
      last_contribution = @wiki.contributions(user, 1).first
      [user, last_contribution[:date]]
    }
  end
  
  def remove_active
    now = Time.now
    today = Date.new(now.year, now.month, now.day)
    limit_date = today << 3
    limit = Time.local(limit_date.year, limit_date.month, limit_date.day, now.hour, now.min, now.sec)
    @data.delete_if { |user, time|
      time >= limit
    }
  end
  
  def publish_list
    now = Piglobot::Tools.write_date(Time.now)
    
    text = "Liste des administrateurs inactifs (hors [[Wikipédia:Liste des administrateurs inactifs/Exclusions exclusions]]) depuis plus de 3 mois. Mise à jour le #{now} par {{u|Piglobot}}.\n"
    text << @data.sort_by { |user, date| date }.map { |user, date|
      date = Piglobot::Tools.write_date(date)
      "* {{u|#{user}}}, dernière contribution le #{date}\n"
    }.join
    @wiki.post("Wikipédia:Liste des administrateurs inactifs", text, "Mise à jour")
  end
end
