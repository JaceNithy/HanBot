-----------------------------------------------------------------------------
-- Localize standart LUA functions
-----------------------------------------------------------------------------
local base = _G
local assert = base.assert
local collectgarbage = base.collectgarbage
local dofile = base.dofile
local error = base.error
local getfenv = base.getfenv
local getmetatable = base.getmetatable
local ipairs = base.ipairs
local load = base.load
local loadfile = base.loadfile
local loadstring = base.loadstring
local module = base.module
local next = base.next
local pairs = base.pairs
local pcall = base.pcall
local print = base.print
local rawequal = base.rawequal
local rawget = base.rawget
local rawset = base.rawset
local require = base.require
local select = base.select
local setfenv = base.setfenv
local setmetatable = base.setmetatable
local tonumber = base.tonumber
local tostring = base.tostring
local type = base.type
local unpack = base.unpack
local xpcall = base.xpcall

local io_close = base.io.close
local io_flush = base.io.flush
local io_input = base.io.input
local io_lines = base.io.lines
local io_open = base.io.open
local io_output = base.io.output
local io_popen = base.io.popen
local io_read = base.io.read
local io_stderr = base.io.stderr
local io_stdin = base.io.stdin
local io_stdout = base.io.stdout
local io_tmpfile = base.io.tmpfile
local io_type = base.io.type
local io_write = base.io.write

local math_abs = base.math.abs
local math_acos = base.math.acos
local math_asin = base.math.asin
local math_atan = base.math.atan
local math_atan2 = base.math.atan2
local math_ceil = base.math.ceil
local math_cos = base.math.cos
local math_cosh = base.math.cosh
local math_deg = base.math.deg
local math_exp = base.math.exp
local math_floor = base.math.floor
local math_fmod = base.math.fmod
local math_frexp = base.math.frexp
local math_huge = base.math.huge
local math_ldexp = base.math.ldexp
local math_log = base.math.log
local math_log10 = base.math.log10
local math_max = base.math.max
local math_min = base.math.min
local math_modf = base.math.modf
local math_pi = base.math.pi
local math_pow = base.math.pow
local math_rad = base.math.rad
local math_random = base.math.random
local math_randomseed = base.math.randomseed
local math_sin = base.math.sin
local math_sinh = base.math.sinh
local math_sqrt = base.math.sqrt
local math_tan = base.math.tan
local math_tanh = base.math.tanh

local os_clock = base.os.clock
local os_date = base.os.date
local os_difftime = base.os.difftime
local os_execute = base.os.execute
local os_exit = base.os.exit
local os_getenv = base.os.getenv
local os_remove = base.os.remove
local os_rename = base.os.rename
local os_setlocale = base.os.setlocale
local os_time = base.os.time
local os_tmpname = base.os.tmpname

local package_cpath = base.package.cpath
local package_loaded = base.package.loaded
local package_loaders = base.package.loaders
local package_loadlib = base.package.loadlib
local package_path = base.package.path
local package_preload = base.package.preload
local package_seeall = base.package.seeall

local string_byte = base.string.byte
local string_char = base.string.char
local string_dump = base.string.dump
local string_find = base.string.find
local string_format = base.string.format
local string_gmatch = base.string.gmatch
local string_gsub = base.string.gsub
local string_len = base.string.len
local string_lower = base.string.lower
local string_match = base.string.match
local string_rep = base.string.rep
local string_reverse = base.string.reverse
local string_sub = base.string.sub
local string_upper = base.string.upper

local table_concat = base.table.concat
local table_insert = base.table.insert
local table_maxn = base.table.maxn
local table_remove = base.table.remove
local table_sort = base.table.sort

local sdk = { }
myHero = player

-----------------------------------------------------------------------------
-- SDK: Common
-----------------------------------------------------------------------------
function sdk.GetDistanceSqr(p1, p2)
    local p2 = p2 or myHero
    local dx = p1.x - p2.x
    local dz = (p1.z or p1.y) - (p2.z or p2.y)
    return dx * dx + dz * dz
end

function sdk.GetDistance(p1, p2)
    local squaredDistance = sdk.GetDistanceSqr(p1, p2)
    return math_sqrt(squaredDistance)
end

function sdk.SerializeTable(t, name, indent)
    local cart, autoref

        local function isEmptyTable(t)
                return next(t) == nil
        end
        local function basicSerialize(o)
                local ts = tostring(o)

                if type(o) == "function" then
                        return ts
                elseif type(o) == "number" or type(o) == "boolean" then
                        return ts
                else
                        return string_format("%q", ts)
                end
        end
        local function addToCart(value, name, indent, saved, field)
                indent = indent or ""
                saved = saved or {}
                field = field or name

                cart = cart .. indent .. field

                if type(value) ~= "table" then
                        cart = cart .. " = " .. basicSerialize(value) .. ";\n"
                else
                        if saved[value] then
                                cart = cart .. " = {}; -- " .. saved[value]
                                .. " (self reference)\n"
                                autoref = autoref ..  name .. " = " .. saved[value] .. ";\n"
                        else
                                saved[value] = name

                                if isEmptyTable(value) then
                                        cart = cart .. " = {};\n"
                                else
                                        cart = cart .. " = {\n"

                                        for k, v in pairs(value) do
                                              k = basicSerialize(k)

                                              local fname = string_format("%s[%s]", name, k)
                                              field = string_format("[%s]", k)
                                              addToCart(v, fname, indent .. "   ", saved, field)
                                        end

                                        cart = cart .. indent .. "};\n"
                                end
                        end
                end
        end
        name = name or "table"
        if type(t) ~= "table" then
                  return name .. " = " .. basicSerialize(t)
        end
        cart, autoref = "", ""
        addToCart(t, name, indent)
    return cart .. autoref
end

local typeof = function(t)
    local _type = type(t)
    if _type == "userdata" then
        local metatable = getmetatable(t)
        if not metatable or not metatable.__index then
            t, _type = "userdata", "string"

            end
        end
        if _type == "userdata" or _type == "table" then
            local _getType = t.__type or t.type or t.Type
            _type = type(_getType) == "function" and _getType(t) or type(_getType) == "string" and _getType or _type
        end
    return _type
end

function sdk.PrintChat(...)
    local tV, len = {}, select("#", ...)
    for i = 1, len do
        local value = select(i, ...)
        local type = typeof(value)
        if type == "string" then
            tV[i] = value
        elseif type == "vector" then
            tV[i] = tostring(value)
        elseif type == "number" then
            tV[i] = tostring(value)
        elseif type == "table" then
            tV[i] = SerializeTable(value)
        elseif type == "boolean" then
            tV[i] = value and "true" or "false"
        else
            tV[i] = "<" .. type .. ">"
        end
    end
    if len > 0 then
        print(table_concat(tV))
    end
end

function sdk.GetPing()
    local latency = network.latency
    return latency / 1000
end

function sdk.GetTrueAttackRange(unit)
    local unit = unit or myHero
    local attackRange = unit.attackRange
    local boundingRadius = unit.boundingRadius
    return attackRange + boundingRadius
end

function sdk.GetPercentHP(unit)
    return unit.health / unit.maxHealth * 100
end

function sdk.GetPercentMP(unit)
    return unit.mana / unit.maxMana * 100
end

function sdk.IsValidTarget(unit, range)
    local range = range or math_huge
    local distance = sdk.GetDistance(unit)
    return unit and not unit.isDead and unit.isTargetable and unit.isVisible and distance <= range
end

function sdk.GetGameTime() 
    return os.clock()
end 

function sdk.VectorPointProjectionOnLineSegment(v1, v2, v)
    local cx, cy, ax, ay, bx, by = v.x, (v.z or v.y), v1.x, (v1.z or v1.y), v2.x, (v2.z or v2.y)
    local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) ^ 2 + (by - ay) ^ 2)
    local pointLine = { x = ax + rL * (bx - ax), z = ay + rL * (by - ay) }
    local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
    local isOnSegment = rS == rL
    local pointSegment = isOnSegment and pointLine or { x = ax + rS * (bx - ax), z = ay + rS * (by - ay) }
    return pointSegment, pointLine, isOnSegment
end

function sdk.VectorMovementCollision(startPoint1, endPoint1, v1, startPoint2, v2, delay)
    local sP1x, sP1y, eP1x, eP1y, sP2x, sP2y = startPoint1.x, startPoint1.z or startPoint1.y, endPoint1.x, endPoint1.z or endPoint1.y, startPoint2.x, startPoint2.z or startPoint2.y
    local d, e = eP1x - sP1x, eP1y - sP1y
    local dist, t1, t2 = math_sqrt(d * d + e * e), nil, nil
    local S, K = dist ~= 0 and v1 * d / dist or 0, dist ~= 0 and v1 * e / dist or 0
    local GetCollisionPoint = function(t) return t and {x = sP1x + S * t, y = sP1y + K * t} or nil end
    if delay and delay ~= 0 then sP1x, sP1y = sP1x + S * delay, sP1y + K * delay end
    local r, j = sP2x - sP1x, sP2y - sP1y
    local c = r * r + j * j
    if dist > 0 then
        if v1 == math.huge then
            local t = dist / v1
            t1 = v2 * t >= 0 and t or nil
            elseif v2 == math.huge then
                t1 = 0
            else
                local a, b = S * S + K * K - v2 * v2, -r * S - j * K
                if a == 0 then
                    if b == 0 then
                        t1 = c == 0 and 0 or nil
                        else
                            local t = -c / (2 * b)
                            t1 = v2 * t >= 0 and t or nil
                            end
                        else 
                            local sqr = b * b - a * c
                            if sqr >= 0 then
                                local nom = math_sqrt(sqr)
                                local t = (-nom - b) / a
                                t1 = v2 * t >= 0 and t or nil
                                t = (nom - b) / a
                                t2 = v2 * t >= 0 and t or nil
                            end
                    end
            end
    elseif dist == 0 then
        t1 = 0
    end
    return t1, GetCollisionPoint(t1), t2, GetCollisionPoint(t2), dist
end

function sdk.FileExists(path)
    local f = io_open(path, 3)
    if f then
        io_close(f)
        return true
    else
        return false
    end
end

function sdk.WriteFile(text, path, mode)
    local path = path or SCRIPT_PATH .. "\\" .. "out.txt"
    local f = io_open(path, mode or "w+")
    if not f then
        return false
    end
    f:write(text)
    f:close()
    return true
end

function sdk.ReadFile(path)
    local f = io_open(path, 3)
    if not f then
            return "WRONG PATH"
    end
    local text = f:read("*all")
    f:close()
    return text
end

local delayedActions, delayedActionsExecuter = {}, nil
function sdk.DelayAction(func, delay, args) 
    if not delayedActionsExecuter then
        function delayedActionsExecuter()
            for t, funcs in pairs(delayedActions) do
                if t <= os.clock() then
                    for i = 1, #funcs do
						local f = funcs[i]
                        if f and f.func then
							f.func(unpack(f.args or {}))
						end
					end
					delayedActions[t] = nil
				end
			end
		end
		cb.add(cb.tick, delayedActionsExecuter)
	end
	local t = os.clock() + (delay or 0)
	if delayedActions[t] then
		delayedActions[t][#delayedActions[t] + 1] = { func = func, args = args }
	else
		delayedActions[t] = { { func = func, args = args } }
	end
end

function sdk.GetPath(unit, index) -- In test
	return vec3(unit.GetPath(index - 1))
end

function sdk.GetRealHP(unit, dmgType)
    local mod = (dmgType == "AP" or dmgType == "AP") and unit.magicalShield or unit.allShield
    return unit.health + mod
end

function sdk.table.contains(t, what, member)
    for i, v in pairs(t) do
        if member and v[member] == what or v == what then
            return i, v
        end
    end
end

-----------------------------------------------------------------------------
-- SDK: Vector
-----------------------------------------------------------------------------
local Vector = { }
local function IsVector(v)
    return v and v.x and type(v.x) == "number" and ((v.y and type(v.y) == "number") or (v.z and type(v.z) == "number"))
end

function sdk.Vector:__init(a, b, c)
    self.type = "vector"

    if a == nil then
            self.x, self.y, self.z = 0.0, 0.0, 0.0
    elseif b == nil then

            self.x, self.y, self.z = a.x, a.y, a.z
    else
            self.x = a
            if b and type(b) == "number" then self.y = b end
            if c and type(c) == "number" then self.z = c end
    end
end

function sdk.Vector:__tostring()
    if self.y and self.z then
            return "Vector(" .. tostring(self.x) .. "," .. tostring(self.y) .. "," .. tostring(self.z) .. ")"
    else
            return "Vector(" .. tostring(self.x) .. "," .. self.y and tostring(self.y) or tostring(self.z) .. ")"
    end
end

function sdk.Vector:__add(v)
    return sdk.Vector(self.x + v.x, (v.y and self.y) and self.y + v.y, (v.z and self.z) and self.z + v.z)
end

function sdk.Vector:__sub(v)
    return sdk.Vector(self.x - v.x, (v.y and self.y) and self.y - v.y, (v.z and self.z) and self.z - v.z)
end

function sdk.Vector.__mul(a, b)
    if type(a) == "number" and IsVector(b) then
            return sdk.Vector({ x = b.x * a, y = b.y and b.y * a, z = b.z and b.z * a })
    elseif type(b) == "number" and IsVector(a) then
            return sdk.Vector({ x = a.x * b, y = a.y and a.y * b, z = a.z and a.z * b })
    else
            return a:DotProduct(b)
    end
end

function sdk.Vector.__div(a, b)
    if type(a) == "number" and IsVector(b) then
            return sdk.Vector({ x = a / b.x, y = b.y and a / b.y, z = b.z and a / b.z })
    else
            return sdk.Vector({ x = a.x / b, y = a.y and a.y / b, z = a.z and a.z / b })
    end
end

function sdk.Vector.__lt(a, b)
    return a:Len() < b:Len()
end

function sdk.Vector.__le(a, b)
    return a:Len() <= b:Len()
end

function sdk.Vector:__eq(v)
    return self.x == v.x and self.y == v.y and self.z == v.z
end

function sdk.Vector:__unm()
    return sdk.Vector(-self.x, self.y and -self.y, self.z and -self.z)
end

function sdk.Vector:Clone()
    return sdk.Vector(self)
end

function sdk.Vector:Unpack()
return self.x, self.y, self.z
end

function sdk.Vector:Len2(v)
    local v = v and sdk.Vector(v) or self
    return self.x * v.x + (self.y and self.y * v.y or 0) + (self.z and self.z * v.z or 0)
end

function sdk.Vector:Len()
    return math_sqrt(self:Len2())
end

function sdk.Vector:DistanceTo(v)
    local a = self - v
    return a:Len()
end

function sdk.Vector:Normalize()
    local l = self:Len()
    self.x = self.x / l
    self.y = self.y / l
    self.z = self.z / l
end

function sdk.Vector:Normalized()
    local v = self:Clone()
    v:Normalize()
    return v
end

function sdk.Vector:Center(v)
    return sdk.Vector((self + v) / 2)
end

function sdk.Vector:CrossProduct(v)
    return sdk.Vector({ x = v.z * self.y - v.y * self.z, y = v.x * self.z - v.z * self.x, z = v.y * self.x - v.x * self.y })
end

function sdk.Vector:DotProduct(v)
    return self.x * v.x + (self.y and (self.y * v.y) or 0) + (self.z and (self.z * v.z) or 0)
end

function sdk.Vector:ProjectOn(v)
    local s = self:Len2(v) / v:Len2()
    return sdk.Vector(v * s)
end

function sdk.Vector:MirrorOn(v)
    return self:ProjectOn(v) * 2
end

function sdk.Vector:Sin(v)
    local a = self:CrossProduct(v)
    return math_sqrt(a:Len2() / (self:Len2() * v:Len2()))
end

function sdk.Vector:Cos(v)
    return self:Len2(v) / math_sqrt(self:Len2() * v:Len2())
end

function sdk.Vector:Angle(v)
    return math_acos(self:Cos(v))
end

function sdk.Vector:AffineArea(v)
    local a = self:CrossProduct(v)
    return math_sqrt(a:Len2())
end

function sdk.Vector:TriangleArea(v)
    return self:AffineArea(v) / 2
end

function sdk.Vector:RotateX(phi)
    local c, s = math_cos(phi), math_sin(phi)
    self.y, self.z = self.y * c - self.z * s, self.z * c + self.y * s
end

function sdk.Vector:RotateY(phi)
    local c, s = math_cos(phi), math_sin(phi)
    self.x, self.z = self.x * c + self.z * s, self.z * c - self.x * s
end

function sdk.Vector:RotateZ(phi)
    local c, s = math_cos(phi), math_sin(phi)
    self.x, self.y = self.x * c - self.z * s, self.y * c + self.x * s
end

function sdk.Vector:Rotate(phiX, phiY, phiZ)
    if phiX ~= 0 then self:RotateX(phiX) end
    if phiY ~= 0 then self:RotateY(phiY) end
    if phiZ ~= 0 then self:RotateZ(phiZ) end
end

function sdk.Vector:Rotated(phiX, phiY, phiZ)
    local v = self:Clone()
    v:Rotate(phiX, phiY, phiZ)
    return v
end

local function close(a, b, eps)
    eps = eps or 1e-9
    return math_abs(a - b) <= eps
end

function sdk.Vector:Polar()
    if close(self.x, 0, 0) then
            if self.z or self.y > 0 then
                    return 90
            elseif self.z or self.y < 0 then
                    return 270
            else
                    return 0
            end
    else
            local theta = math_deg(math_atan((self.z or self.y) / self.x))

            if self.x < 0 then
                    theta = theta + 180
            end

            if theta < 0 then
                    theta = theta + 360
            end

            return theta
    end
end

function sdk.Vector:AngleBetween(v1, v2)
    local p1, p2 = (-self + v1), (-self + v2)
    local theta = p1:Polar() - p2:Polar()

    if theta < 0 then
            theta = theta + 360
    end

    if theta > 180 then
            theta = 360 - theta
    end

    return theta
end

function sdk.Vector:Perpendicular()
    return sdk.Vector(-self.z, self.y, self.x)
end

function sdk.Vector:Perpendicular2()
    return sdk.Vector(self.z, self.y, -self.x)
end

function sdk.Vector:Extended(to, distance)
    return self + (to - self):Normalized() * distance
end

function sdk.Vector:RotateAroundPoint(v, angle)
    local cos, sin = math_cos(angle), math_sin(angle)
    local x = ((self.x - v.x) * cos) - ((v.y - self.y) * sin) + v.x
    local y = ((v.y - self.y) * cos) + ((self.x - v.x) * sin) + v.y
    return sdk.Vector(x, y, self.z or 0)
end

return sdk




