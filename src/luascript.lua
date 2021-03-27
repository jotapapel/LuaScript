--[[
	LuaScript Library
	v1.3.0 by jotapapel
--]]

_LSSPATH = "src/lss"

local smt, gmt, __newindex, unpack = setmetatable, getmetatable, function() end, table.unpack or unpack

-- global functions
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
	local function s(h, a, b) return string.format("0x%s", h:sub(a, b)) end
	return (#h == 3) and {(tonumber(s(h, 1, 1)) * 17) / 255, (tonumber(s(h, 2, 2)) * 17) / 255, (tonumber(s(h, 3, 3)) * 17) / 255} or {tonumber(s(h, 1, 2)) / 255, tonumber(s(h, 3, 4)) / 255, tonumber(s(h, 5, 6)) / 255}
end

function rawvar(v)
	return smt({}, {__rawvar = v})
end

function var(t)
	return ({["string"] = "", ["number"] = 0, ["table"] = {}, ["function"] = function() end, ["enum"] = enum({}), ["extension"] = extension()({}), ["class"] = class(false)({}), ["object"] = class(false)({})()})[t] or ""
end

function process(n, ld)
	local output = (require(_LSSPATH))(n, not(ld))
	if (ld == nil or ld == true) then output = assert(load(output))() end
	return output
end

-- local luascript functions
local function catch_type(k, v, t, l)
	local g, e = type(v), t
	if (gmt(v) and gmt(v).__rawvar) then g, v = t, gmt(v).__rawvar end
	if (e == "constant") then error(string.format("[LuaScript] Cannot modify a constant variable (var: %s).", k), l or 4) end
	if (g ~= "any" and e ~= "any" and g ~= e) then error(string.format("[LuaScript] %s expected, got %s (var: %s).", e:gsub("^%l", string.upper), g, k), l or 4) end
	return v
end

local function var_get(k, l)
	local v, l, i = _G[k], l or 3, 1
	while (true) do
		local _k, _v = debug.getlocal(l, i)
		if (_k) then if (_k == k and not(v)) then v = _v end else break end
		i = i + 1
	end
	return v
end

local function var_copy(v)
	local c = v
	if (type(v) == "table") then
		c = {}
		for _k, _v in pairs(v) do c[var_copy(_k)] = var_get(_v) end
		if (gmt(v)) then smt(c, var_copy(gmt(v))) end
	end
	return c
end

local function var_is_key(s, l)
	local msg = string.format("[LuaScript] Wrong variable name (var: %s)", s)
	return (({pcall(load, catch_type(s, s, "string") .." = 1")})[2] ~= nil) and s or error(msg, l or 4)
end

-- luascript structures
local function struct(t)
	local t, mt = gmt(t) and t or {}, gmt(t) or t
	local h, l = tostring(t), mt.__struct
	mt.__tostring = function(_) return string.format("%s%s", l, h:match(":%s.-$")) end
	return smt(t, mt)
end

local function dict()
	return smt({}, {
		__table = {},
		__protocol = {},
		__index = function(t, k) return gmt(t).__table[k] end,
		__newindex = function(t, k, v) gmt(t).__newvar(t, k, v, 4) end,
		__call = function(self, t) return self + t end,
		__add = function(a, b)
			if (gmt(b) and gmt(b).__table and gmt(b).__protocol) then
				for k, v in pairs(gmt(b).__protocol) do gmt(a).__protocol[k] = v end
				for k, v in pairs(gmt(b).__table) do gmt(a).__table[k] = v end
			else
				for k, v in pairs(b) do gmt(a).__newvar(a, k, v, 5) end
			end
			return a
		end,
		__newvar = function(t, k, v, l)
			local m, d = k:match("^(%g+)%p.-$"), k:match("^.-%p(%g+)$") or k
			local dn, dt, pt = var_is_key(d:match("^.-%p(%g+)$") or d, 4), d:match("^(%g+)%p.-$") or type(v)
			if (gmt(t).__protocol[dn]) then v = catch_type(dn, v, gmt(t).__protocol[dn], l) elseif (m == "constant") then pt = m else pt = dt end
			gmt(t).__protocol[dn], gmt(t).__table[dn] = pt, catch_type(dn, v, dt, l)
		end
	})
end

function args(vs, ts)
	for i = 1, #ts do
		local v, msg = vs[i], string.format("[LuaScript] %s expected, got %s (arg: %i).", ts[i]:gsub("^%l", string.upper), type(vs[i]), i)
		if (type(v) ~= ts[i]) then error(msg, 3) end
	end
	return unpack(vs)
end

function enum()
	return struct({
		__struct = "enum",
		__table = {},
		__index = function(t, k) return gmt(t).__table[k] end,
		__newindex = __newindex,
		__call = function(self, t)
			local mt = gmt(self)
			for _, v in ipairs(t) do mt.__table[v] = var_is_key(v, 3) end
			mt.call = nil
			return self
		end
	})
end

function extension(f, ...)
	local ext_list, ext_names = {}, {...}
	for p, n in ipairs(ext_names) do
		local v, msg = var_get(n), string.format("[LuaScript] Extension not found or variable not (var: %s).", n)
		if (v) then table.insert(ext_list, v) else error(msg, 2) end
	end
	return struct({
		__struct = "extension",
		__static = dict(),
		__prototype = dict(),
		__index = function(t, k) return ({isFinal = function() return f end, static = gmt(t).__static, prototype = gmt(t).__prototype})[k] end,
		__newindex = __newindex,
		__call = function(self, t)
			local mt, t = gmt(self), catch_type("extension declaration", t, "table", 3)
			for p, ext in ipairs(ext_list) do if (type(ext) == "extension" and ext:isFinal() == false) then mt.__static, mt.__prototype = mt.__static + gmt(ext).__static, mt.__prototype + gmt(ext).__prototype else error(string.format("[LuaScript] Extension expected, got %s (var: %s).", type(ext), ext_names[p]), 2) end end
			for k, v in pairs(t) do mt[string.format("__%s", k:match("(.-)%."))][k:match("^.-%.(.-)$")] = v end
			mt.__call = nil
			return self
		end
	})
end

function class(f, ...)
	local st_list, st_names = {}, {...}
	for p, n in ipairs(st_names) do
		local v, msg = var_get(n), string.format("[LuaScript] Structure not found (var: %s).", n)
		if (v) then table.insert(st_list, v) else error(msg, 2) end
	end
	return struct({
		__struct = "class",
		__static = dict(),
		__prototype = dict(),
		__init = function() end,
		__index = function(t, k) return gmt(t).__static[k] or ({isFinal = function() return f end, getSuperclass = function() return gmt(t).__super end, prototype = gmt(t).__prototype})[k] end,
		__newindex = function(t, k, v) if (gmt(t).__static[k]) then gmt(t).__static[k] = v end end,
		__call = function(self, t)
			local mt, t, superclass = gmt(self), catch_type("class definition", t, "table", 3)
			if (type(st_list[1]) == "class") then superclass = table.remove(st_list, 1) end
			if (superclass and superclass:isFinal() == false) then mt.__static, mt.__prototype, mt.__super = mt.__static + gmt(superclass).__static, mt.__prototype + gmt(superclass).__prototype, superclass end
			for p, ext in ipairs(st_list) do if (type(ext) == "extension") then mt.__static, mt.__prototype = mt.__static + gmt(ext).__static, mt.__prototype + gmt(ext).__prototype else error(string.format("[LuaScript] Extension expected, got %s (var: %s).", type(ext), st_names[p]), 2) end end
			for k, v in pairs(t) do
				local fk = k:match("(.-)%.")
				if (fk == "init") then mt.__init = catch_type(fk, v, k:match("^.-%.(.-)$"), 4) end
				if (fk == "prototype" or fk == "static") then mt[string.format("__%s", fk)][k:match("^.-%.(.-)$")] = v end
			end
			mt.__call = mt.__newobj
			return self
		end,
		__newobj = function(self, ...)
			local obj = struct({
				__struct = "object",
				__table = {},
				__index = function(t, k) return ({typeOf = function() return self end, instanceOf = function(self, c) return self == c end, hashCode = string.match(tostring(t), ":%s*.-$"):sub(3)})[k] or gmt(t).__table[k] or self.prototype[k] end,
				__newindex = function(t, k, v) if (self.prototype[k]) then gmt(t).__table[k] = catch_type(k, v, gmt(self.prototype).__protocol[k], 4) end end,
			})
			local prev = super
			super = function(...) local s = self:getSuperclass() if (s) then gmt(s).__init(obj, ...) end end
			gmt(self).__init(obj, ...)
			super = prev
			return obj
		end
	})
end