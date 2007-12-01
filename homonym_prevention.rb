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
  class HomonymPrevention < Job
    def data_id
      "Homonymes"
    end
  
    def done?
      false
    end
    
    def process
      changes = false
      data = @data
      data ||= {}
      china = data["Chine"] || {}
      china = {} if china.is_a?(Array)
      last = china["Last"] || {}
      new = china["New"] || []
      
      if last.empty?
        last = @wiki.links("Chine")
        Piglobot::Tools.log("#{last.size} liens vers la page d'homonymie [[Chine]]")
      else
        current = @wiki.links("Chine")
        
        new.delete_if do |old_new|
          if current.include? old_new
            false
          else
            Piglobot::Tools.log("Le lien vers [[Chine]] dans [[#{old_new}]] a été supprimé avant d'être traité")
            true
          end
        end
        
        current_new = current - last
        last = current
        current_new.each do |new_name|
          Piglobot::Tools.log("Un lien vers [[Chine]] a été ajouté dans [[#{new_name}]]")
        end
        new += current_new
      end
      china["Last"] = last
      china["New"] = new if new
      data["Chine"] = china
      @changed = changes
      @data = data
    end
  end
end
