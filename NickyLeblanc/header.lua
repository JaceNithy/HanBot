return { id = 'NickyLeBlanc', name = '[Nicky]LeBlanc',
    flag = {
      text = '[Nicky]LeBlanc',
      color = {
        text = 0xffeeeeee,
        background1 = 0xFFaaafff,
        background2 = 0xFF010200,
      },
    },
    riot = true,
   -- champion = 'Leblanc',
    load = function()
        return player.charName == 'Leblanc'
    end,
  }