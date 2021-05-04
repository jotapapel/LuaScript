local smt, gmt, unpack = setmetatable, getmetatable, table.unpack or unpack

function string.trim(...)
	local r = {}
	for _, v in ipairs({...}) do table.insert(r, string.match(v, "^%s*(.-)%s*$")) end
	return unpack(r)
end

function string.default(s, d, n)
	local d = (d and string.gsub(tostring(d), "%$", s or "")) or s
	return (s ~= nil and d) or (n or "")
end

local function catch_type(v, t, k)
	local e, g, m = t, type(v), string.format("%s expected, got %s %s", t:gsub("^%l", string.upper), type(v), string.default(k, "(var: $).", "."))
	if (e ~= g and g ~= "nil") then error(m, 3) end
	return v
end

local __newindex = function() end
local __index = function(t, d)
	local d = d or {}
	d.hashCode = function(t) return tostring(t):match("^.-:%s+(.-)$") end
	return function(_, k)
		if (t[k]) then return t[k][1] end
		return d and d[k]
	end
end

local function newEntity(n, t)
	local t, mt = (gmt(t) and t) or {}, gmt(t) or t
	local h = tostring(t)
	if (mt.__newindex == nil) then mt.__newindex = __newindex end
	mt.__tostring = function(t) return string.format("%s%s", n, h:match("^%w+(:%s.-)$")) end
	return smt(t, mt)
end

local dmt = {
	__index = __index(t),
	__newindex = function(_, k, v)
	local k, c = k:match("^([%w_]+):?.-$"), (t[k] and t[k][2]) or k:match("^.-:(%w+)$") or type(v)
	local v = ((c == "constant") and ((t[k] and error(string.format("Cannot modify a constant variable %s", string.default(k, "(var: $).", ".")), 2)) or v)) or catch_type(v, c, k)
	t[k] = {v, c}
	end
}

local function newDict(i)
	local t = {}
	local d = newEntity("dict", )
	for k, v in pairs(i) do d[k] = v end
	return d
end

local d = newDict({
	["var1:string"] = "panic",
	["const1:constant"] = 322,
	["method1"] = function(self, n) print(n * 3) end
})
d.var1 = "MEJ"
d:method1(10)
d.method1 = function(self, n) print(n + 10) end
d:method1(5)
print(d.var1)
