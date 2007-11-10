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
