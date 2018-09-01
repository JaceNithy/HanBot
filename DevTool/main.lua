local function GetBuffByName(obj, buffname)
    if obj then
      for i = 0, obj.buffManager.count - 1 do
        local buff = obj.buffManager:get(i)
  
        if buff and buff.valid and buff.name == buffname  then
          return true
        end
      end
    end
end

local function GetBuffCount(obj)
    local count = 0
    if obj then
      for i = 0, obj.buffManager.count - 1 do
        local buff = obj.buffManager:get(i)
  
        if buff and buff.valid and buff.name then
            count = count + 1
        end
      end
    end
end

local function GetBuffStack(obj)
    if obj then
      for i = 0, obj.buffManager.count - 1 do
        local buff = obj.buffManager:get(i)
  
        if buff and buff.valid and (buff.stacks > 0 or buff.stacks2 > 0) then
          return true
        end
      end
    end
end

local objHolder = {}
local DevIsTool = menu("KZ", "[Nicky]DevTool")
	DevIsTool:header("script", "[Nicky]DevTool")
	--Combo
	DevIsTool:menu("ss", "DevTool [Settings]")
	DevIsTool.ss:header("xd1", "[Settings]")
	DevIsTool.ss:boolean("Heroinfo", "Draw Hero Info", true)
	DevIsTool.ss:boolean("Cursor", "Draw Cursor Info", true)
	DevIsTool.ss:boolean("BuffsMyHero", "Draw My Buffs [Not Work]", false)
    DevIsTool.ss:boolean("BuffsENemys", "Draw Target Buffs [Nor Work]", false)
    DevIsTool.ss:boolean("DOB", "Draw Objects Info", true)

local function CreateObj(object)
    if object and object.name then
        if string.find(object.name, "Base") then 
            objHolder[object.ptr] = object
         --   objHolder[object.ptr] = player
        end 
    end 
end 

local function DeleteObj(object)
    if object and object.name then
        if string.find(object.name, "Base") then 
            objHolder[object.ptr] = nil
         --   objHolder[object.ptr] = player
        end 
    end 
end 


local function OnDraw()
    --DrawTextToScreen("NAME= " .. unit.CharName,  vec, 80, -140)
    local playerPos = graphics.world_to_screen(player.pos)
    if DevIsTool.ss.Heroinfo:get() then
        
        graphics.draw_text_2D("Name: " .. tostring(player.charName), 20, playerPos.x + 100,  playerPos.y - 140, graphics.argb(255, 255, 255, 255))
        graphics.draw_text_2D("Spell [Q]:" .. tostring(player:spellSlot(0).name), 20, playerPos.x + 100,  playerPos.y - 120, graphics.argb(255, 255, 255, 255))
        graphics.draw_text_2D("Spell [W]:" .. tostring(player:spellSlot(1).name), 20, playerPos.x + 100,  playerPos.y - 100, graphics.argb(255, 255, 255, 255))
        graphics.draw_text_2D("Spell [E]:" .. tostring(player:spellSlot(2).name), 20, playerPos.x + 100,  playerPos.y - 80, graphics.argb(255, 255, 255, 255))
        graphics.draw_text_2D("Spell [R]:" .. tostring(player:spellSlot(3).name), 20, playerPos.x + 100,  playerPos.y - 60, graphics.argb(255, 255, 255, 255))
        --
        graphics.draw_text_2D("Spell [Summoner]:" .. tostring(player:spellSlot(4).name), 20, playerPos.x + 100,  playerPos.y - 40, graphics.argb(255, 255, 255, 255))
        graphics.draw_text_2D("Spell [Summoner]:" .. tostring(player:spellSlot(5).name), 20, playerPos.x + 100,  playerPos.y - 20, graphics.argb(255, 255, 255, 255))
    end 
    --
    if DevIsTool.ss.Cursor:get() then
        local pos3d = game.mousePos
        local pos2d = game.cursorPos
        local lopos = game.mousePos2D
	    local xoff = 40
        local yoff = 0
        if pos2d.x > 900 then 
            xoff = -200 
        end
        if pos2d.y < 100 then 
            yoff = 60 
        end
        graphics.draw_text_2D("WORLD_POS: " .. tostring(math.floor(pos3d.x)) .. " , " .. tostring(math.floor(pos3d.y)) .. " , " .. tostring(math.floor(pos3d.z)), 20,playerPos.x + -600,  playerPos.y - 300,  graphics.argb(255, 255, 255, 255))
        graphics.draw_text_2D("SCREEN_POS: " .. tostring(math.floor(pos2d.x)) .." , ".. tostring(math.floor(pos2d.y)), 20,playerPos.x + -600,  playerPos.y - 280,  graphics.argb(255, 255, 255, 255))
    end 
    --
    if DevIsTool.ss.DOB:get() then
    for k, v in pairs(objHolder) do
      --  if k >= 30 then break end
            local ObjPos = graphics.world_to_screen(v.pos)
            graphics.draw_text_2D("Objects [Player]:" .. tostring(v.name), 20, ObjPos.x - 40,  ObjPos.y + 70, graphics.argb(255, 255, 255, 255))
        end 
    end 
end 

cb.add(cb.draw, OnDraw)
cb.add(cb.create_particle, CreateObj) -- cb.delete_particle
cb.add(cb.delete_particle, DeleteObj)
