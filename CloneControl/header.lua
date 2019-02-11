local AIOClone = {
  Leblanc = true,
  Shaco = true,
}

return {
  id = "CAIO" .. player.charName,
  name = "CloneAIO - " .. player.charName,
  riot = true,
  flag = {
    text = "CloneControl - by Nicky",
    color = {
        text = 0xFF00BB4F,
        background1 = 0x66AAFFFF,
        background2 = 0x99000000
    }
  },
  load = function()
    return AIOClone[player.charName]
  end
}
