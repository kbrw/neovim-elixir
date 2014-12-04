defmodule Editor do
  require Logger
  def complete_from(line,cursor) do
    [tomatch] = Regex.run(~r"[\w\.]*$",String.slice(line,0..cursor))
    cursor - String.length(tomatch)
  end
  def complete(base) do
    case (base |> to_char_list |> Enum.reverse |> IEx.Autocomplete.expand) do
      {:yes,one,alts}-> 
        Enum.map([one|alts],fn comp->
          comp = "#{base}#{comp}"
          %{"word"=>String.replace(comp,~r"/[0-9]+$",""),
            "abbr"=>comp,
            "info"=>"coucou c'est de la doc"}
        end)
      {:no,_,_}-> [base]
    end
  end
end
