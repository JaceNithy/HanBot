return {
    id = "NickyMissFortune".. player.charName,
    name = "[Nicky]MissFortune",
    riot = true,
    type = "Champion",
    load = function()
      return player.charName == "MissFortune"
    end
}
