
class SuiviPortailInformatique < Piglobot::Job
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
