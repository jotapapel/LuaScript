--[[
	LuaScript library
	beta v.1.4.0
--]]

local smt, gmt, unpack = setmetatable, getmetatable, table.unpack or unpack

local _type = type
function type(v)
	local t, l = _type(v), tostring(v)
	return (t == "table") and l:match("^(.-):.-$") or t
end

local _tonumber = tonumber
function tonumber(v)
	local t = _tonumber(v)
	if (type(t) == "number") then return t end
	return #v
end

function torgb(h)
	local s = function(h, a, b) return string.format("0x%s", h:sub(a, b)) end
	return (#h == 3) and {(tonumber(s(h, 1, 1)) * 17) / 255, (tonumber(s(h, 2, 2)) * 17) / 255, (tonumber(s(h, 3, 3)) * 17) / 255} or {tonumber(s(h, 1, 2)) / 255, tonumber(s(h, 3, 4)) / 255, tonumber(s(h, 5, 6)) / 255}
end

function rawvar(v)
	return smt({}, {__rawvar = v})
end

function var(t)
	return ({["string"] = "", ["number"] = 0, ["table"] = {}, ["function"] = function() end, ["enum"] = enum({}), ["prototype"] = prototype(false)({}), ["class"] = class(false)({}), ["object"] = class(false)({})()})[t] or ""
end

function catch_types(vv, tt, nn)
	local nn = nn or {}
	for p, t in ipairs(tt) do
		local n, m = nn[p] or tostring(p), (#nn == 0) and "return var" or "var"
		catch_type(vv[p], t, n, 3, m)
	end
	return unpack(vv)
end

local catch_type = function(v, t, k, l, m)
	local e, g, m = t:match("%w+"), type(v), m or "var"
	if (t == "constant") then error(string.format("Cannot modify a constant variable (%s: %s).", m, k), l or 3) end
	if (g ~= e and e ~= "any" and (t:sub(-1) ~= "?" and g == "nil")) then error(string.format("%s expected, got %s (%s: %s).", e:gsub("^%l", string.upper), g, m, k), l or 3) end
	return v
end

local catch_key = function(s, l)
	local msg = string.format("Wrong variable name (var: %s).", s)
	return (({pcall(load, catch_type(s, "string", s) .." = 1")})[2] ~= nil) and s or error(msg, l or 4)
end

local catch_var = function(k, l)
	local v, l, i = _G[k], l or 3, 1
	while (true) do
		local lk, lv = debug.getlocal(l, i)
		if (lk) then if (lk == k and v == nil) then v = lv end else break end
		i = i + 1
	end
	return v
end

local __index = function(t, k, d)
	local d = d or {}
	if (gmt(t).__protocol[k]) then return gmt(t).__table[k] end
	return d[k]
end

local __newindex = function()
	-- empty function
end

local entity = function(t)
	local t, mt = gmt(t) and t or {}, gmt(t) or t
	local h, l = tostring(t), mt.__entity
	if (mt.__newindex == nil) then mt.__newindex = __newindex end
	mt.__tostring = function(_) return string.format("%s%s", l, h:match(":%s.-$")) end
	return smt(t, mt)
end

function dict(it)
	local d = entity({
		__entity = "dict",
		__protocol = {},
		__table = {},
		__index = function(t, k) return gmt(t).__table[k] end,
		__newindex = function(t, k, v)
			local mt, _, _, kn, kt = gmt(t), k:find("^(.-):(.-)$")
			kn, kt = catch_key(kn or k, 4), kt or type(v)
			v = (kt ~= "constant") and catch_type(v, kt, kn, 4) or v
			if (mt.__protocol[kn]) then mt.__table[kn] = catch_type(v, mt.__protocol[kn], kn, 3) else mt.__protocol[kn], mt.__table[kn] = kt, v end
		end,
		__add = function(a, b)
			if (type(b) == "dict") then
				for k, v in pairs(gmt(b).__protocol) do gmt(a).__protocol[k] = v end
				for k, v in pairs(gmt(b).__table) do gmt(a).__table[k] = v end
			end
			return a
		end
	})
	local it = catch_type(it, "table", "dictionary definition")
	for k, v in pairs(it) do d[k] = v end
	return d
end

function enum(it)
	local e = entity({
		__entity = "enum",
		__table = {},
		__index = function(t, k) return gmt(t).__table[k] end
	})
	local it = catch_type(it, "table", "enum definition", 3)
	for _, v in ipairs(it) do
		local k = catch_key(v, 4)
		gmt(e).__table[k] = v
	end
	return e
end

function prototype(f, ...)
	local xx, x = {...}, entity({
		__entity = "prototype",
		__prototype = dict({}),
		__static = dict({}),
		__index = function(t, k)
			local lf = {static = gmt(t).__static, isFinal = function() return f end}
			return __index(gmt(t).__prototype, k, lf)
		end,
		__call = function(self, it)
			local it = catch_type(it, "table", "prototype definition", 3)
			for k, v in pairs(it) do
				local _, _, dt, kd = k:find("^(.-)%-(.-)$")
				gmt(self)[string.format("__%s", dt or "prototype")][kd or k] = v
			end
			gmt(self).__call = nil
			return self
		end,
		__add = function(a, b)
			if (type(b) == "prototype") then
				gmt(a).__static = gmt(a).__static + gmt(b).__static
				gmt(a).__prototype = gmt(a).__prototype + gmt(b).__prototype
			end
			return a
		end
	})
	for _, xn in ipairs(xx) do
		local xv = catch_var(xn, 3)
		if (xv and type(xv) == "prototype") then
			if (xv:isFinal()) then error(string.format("Cannot extend a final prototype (var: %s).", xn), 2) else x = x + xv end
		else
			local msg = (xv) and string.format("Prototype expected, got %s (var: %%s)", type(xv)) or "Prototype not found (var: %s)."
			error(string.format(msg, xn), 2)
		end
	end
	return x
end

function super()
	-- super function for class constructor
end

function class(f, ...)
	local ss, c = {...}, entity({
		__entity = "class",
		__prototype = dict({}),
		__static = dict({}),
		__index = function(t, k)
			local lf = {prototype = gmt(t).__prototype, isFinal = function() return f end, getSuperclass = function() return gmt(t).__super end}
			return __index(gmt(t).__static, k, lf) 
		end,
		__newindex = function(t, k, v)
			local kt = gmt(gmt(t).__static).__protocol[k]
			if (kt) then gmt(t).__static[k] = catch_type(v, kt, k, 3) end
		end,
		__call = function(self, it)
			local it = catch_type(it, "table", "class definition", 3)
			for k, v in pairs(it) do
				if (k == "constructor") then 
					gmt(self).__init = catch_type(v, "function", "class init function", 3)
				else
					local _, _, dt, kd = k:find("^(.-)%-(.-)$")
					gmt(self)[string.format("__%s", dt or "prototype")][kd or k] = v
				end
			end
			gmt(self).__call = gmt(self).__newobject
			return self
		end,
		__add = function(a, b)
			if (type(b) == "prototype" or type(b) == "class") then
				gmt(a).__static = gmt(a).__static + gmt(b).__static
				gmt(a).__prototype = gmt(a).__prototype + gmt(b).__prototype
			end
			return a
		end,
		__init = function() end,
		__newobject = function(self, ...)
			local o = entity({
				__entity = "object",
				__protocol = {},
				__table = {},
				__index = function(t, k)
					if (gmt(t).__protocol[k]) then return gmt(t).__table[k] end
					if (gmt(self.prototype).__protocol[k]) then return gmt(self.prototype).__table[k] end
					return ({typeOf = function(_) return self end, instanceOf = function(_, c) return c == self end})[k]
				end,
				__newindex = function(t, k, v)
					local kt = gmt(t).__protocol[k] or gmt(self.prototype).__protocol[k]
					if (kt) then gmt(t).__protocol[k], gmt(t).__table[k] = kt, catch_type(v, kt, k, 3) end
				end
			})
			local s = super
			function super(...) local s = self:getSuperclass() if (s) then gmt(s).__init(o, ...) end end
			gmt(self).__init(o, ...)
			super = s
			return o
		end
	})
	for n, sn in ipairs(ss) do
		local sv = catch_var(sn, 3)
		if (sv and (type(sv) == "prototype" or type(sv) == "class")) then
			if (n == 1 and type(sv) == "class") then
				if (sv:isFinal()) then error(string.format("Cannot extend a final class (var: %s).", sn), 2) end
				gmt(c).__super, gmt(c).__init, c = sv, gmt(sv).__init, c + sv
			else
				c = c + sv
			end
		else
			local msg = (sv) and string.format("Entity expected, got %s (var: %%s).", type(sv)) or "Entity not found (var: %s)."
			error(string.format(msg, sn), 2)
		end
	end
	return c
end
