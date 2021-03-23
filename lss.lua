--[[
	LuaScript Preprocessor
	v1.3.0 by jotapapel
--]]

local unpack, params = table.unpack or unpack, {...}

function string.trim(...)
	local r = {}
	for _, v in ipairs({...}) do table.insert(r, string.match(v, "^%s*(.-)%s*$")) end
	return unpack(r)
end

function string.gsubc(s, m, r)
	local cl = {}
	local ns = s:gsub(m, function(f) table.insert(cl, f) return r end)
	return ns, cl
end

function string.gsubr(s, m, t)
	local r = t or ""
	if (type(t) == "table") then r = table.remove(t, 1) end
	return string.gsub(s, m, function(_) return r end)
end

function string.default(s, d)
	return (s ~= nil) and string.gsub(d or "", "%$", s) or ""
end

function table.tostring(t, k)
	local s = ""
	for i = 1, #t - 1 do s = string.format("%s%s%s", s, t[i], k) end
	return (#t > 0) and string.format("%s%s", s, t[#t]) or nil
end

local function file_exists(file)
	local f = io.open(file, "r")
	if (f) then f:close() end
	return (f ~= nil)
end

local function file_lines(file)
	local ls = {}
	if (file_exists(file) == nil) then return ls end
	for l in io.lines(file) do table.insert(ls, l) end
	return ls
end

local function process(f, d)
	local lines, output = file_lines(f), ""
	local il, is = 0, (d or false) and string.char(32):rep(3) or ""
	local showc, slc = d, nil
	local lss, ins, lfs, fnr = nil, nil, nil, {}
	for n, line in ipairs(lines) do
		local line, comment = line:trim(), ""
		if (lsc == nil) then
			-- placeholders
			local ss34, ss39, ss91, slc
			line, ss91 = line:gsubc("(%[%[.-%]%])", "<string91/>")
			line, ss39 = line:gsubc([[%b'']], "<string39/>")
			line, ss34 = line:gsubc([[%b""]], "<string34/>")
			line, slc = line:gsubc("/%*(.-)%*/", "<comment/>")
			line, _ = line:gsubc("/%*", "<comment>")
			line, _ = line:gsubc("%*/", "</comment>")
			-- manage comments
			if (line:match("^.-//.-$")) then _, _, line, comment = string.trim(line:find("^(.-)//(.-)$")) end
			if (line:match("^.-(<comment>)$")) then lsc = n end
			-- fix variable helpers
			line = line:gsub("([_a-zA-Z0-9%.]+)!", [[rawvar(%1)]])
			line = line:gsub("$([_a-zA-Z0-9%.]+)", [[tostring(%1)]])
			line = line:gsub("#([_a-zA-Z0-9%.]+)", [[tonumber(%1)]])
			line = line:gsub("&([a-zA-Z0-9]+)", [[torgb("%1")]])
			-- fix import statement
			if (line:match("^(import)%s.-$")) then line = string.format([[process("%s.lss")]], line:match("import%s(.*)$"):gsub("%.", "/")) end
			-- fix try/catch control structure
			if (line:match("^(try).-$") and line:match("^.-(do)")) then
				local c = string.format("%s then ", line:match("^try%s(.*)%sdo"))
				if (line:match("^.-end$")) then c = string.format("%s%s", c, line:match("^.-do%s(.*)"):gsub("%scatch%s", " else ")) end
				line = string.format("if %s", c)
			end
			if (line:match("^catch$")) then line = "else" end
			-- fix structure declaration
			local stl, stf, stk
			stl = string.default(line:match("^(local).-$"), "$ ")
			stf = string.default(line:match(string.format("^%s(final).-$", stl)), "$ ")
			stk = line:match(string.format("^%s%s(enum).-$", stl, stf)) or line:match(string.format("^%s%s(extension).-$", stl, stf)) or line:match(string.format("^%s%s(class).-$", stl, stf))
			if (stk) then
				local stn, sta = "", {}
				string.gsub(string.default(line:match(string.format("^%s%s%s%%s(.-)%%s{$", stl, stf, stk)), "$,"), "(.-)%p", function(s) table.insert(sta, s:trim()) end)
				stn, stf, sta = table.remove(sta, 1), (stk == "enum") and "" or ((#stf == 0) and "false" or "true"), string.default(table.tostring(sta, [[", "]]), [[, "$"]])
				line, lss, ins = string.format("%s%s = (%s(%s%s))({", stl, stn, stk, stf, sta), il + 1, stk
			end
			if (line:match('^}$') and il == lss) then line, ins = "})", nil end
			-- fix init function declaration
			local sc = line:match("^(init%()(.-)$")
			if (sc and ins) then
				local fa, ct, as, ast = line:match("^.-%((.-)%)%s{"), "", {}, {}
				for an in string.gmatch(fa .. ",", "(.-),") do local k, t = string.trim(an:match("^(.-):.-$") or an, an:match(":(.-)$")); table.insert(as, k); table.insert(ast, t) end
				fa, ast, rt = table.tostring(as, ", "), (#ast > 0) and string.format([["%s"]], table.tostring(ast, [[", "]])) or nil
				if (ast) then local fa = fa:match("(.-),%s%.%.%.") or fa; ct = string.format("\n%slocal %s = args({%s}, {%s})", is:rep(il + 1), fa, fa, ast) end
				line, comment, lfs = string.format([[["init.function"] = function(self%s)%s]], string.format("%s%s", (#fa > 0) and ", " or "", fa), comment .. ct), "", il + 1
			end
			-- fix variable, constant and function declarations
			local sw = line:match("%s?(func)%s") or line:match("%s?(var)%s") or line:match("%s?(let)%s")
			if (sw and ins) then
				local m = line:match("^(static)%s") or "prototype"
				if (sw == "var" or sw == "let") then
					local vt, aa, kt, kn, kv, i = (sw == "var") and "variable." or "constant", {}, "", "", nil, 0
					local function gv(l)
						local l, kt, kn, kv = l:trim(), "", "", nil
						if (l:match("^(.-)%?$")) then _, _, kn = l:find("(.-)%?$") else _, _, kn, kv = l:find("(.-)%s=%s(.-)$") end
						if (kn:find(":")) then _, _, kn, kt = kn:find("^(.-):%s(.-)$") end
						kt, kn, kv, i = string.default(kt, "$."):trim(), kn:trim(), (kv or string.format([[var("%s")]], kt)):trim(), i + 1
						return string.format([[%s["%s.%s%s%s"] = %s,%s]], (i > 1) and is:rep(il) or "", m, vt, kt, kn, kv, "\n")
					end
					line = string.gsub(string.format("%s,", string.match(string.gsub(line, [[%b()]], function(a) table.insert(aa, a) return "</args>" end), string.format("%s(.-)$", sw))), "(.-),", gv):gsub("</args>", function(s) return table.remove(aa, 1) end):sub(1, -2)
				elseif (sw == "func") then
					local fan, fat, frt, fct, fs, fn, faa, frr = {}, {}, {}, "", line:match("func%s(.-)%s{")
					fn, faa, frr = fs:match("^(.-)%(.-$"), fs:match("^.-%((.-)%).-$"):gsub("(%.%.%.)", "</tripledot>"), fs:match("^.-%s%->%s%((.-)%)$")
					faa, frr = string.trim(string.gsub(string.format("%s,", faa), "(.-),", function(a) 	local a = a:trim() if (#a > 0) then if (a ~= "</tripledot>" and a:find(":")) then table.insert(fan, (a:match("^(.-):.-$")):trim()) table.insert(fat, (a:match("^.-:(.-)$")):trim()) return string.format("%s, ", (a:match("^(.-):.-$")):trim()) else return string.format("%s, ", a:trim()) end else table.insert(fan, "...") return "" end end)):sub(1, -2), string.gsub(string.format("%s,", frr), "(.-),", function(r) table.insert(frt, r) return r end)
					faa, fan, fat, frt = faa:gsub("</tripledot>", "..."), (#fan > 0) and table.tostring(fan, ", ") or nil, (#fat > 0) and string.default(table.tostring(fat, [[", "]]), [["$"]]) or nil, (frr ~= "nil") and string.default(table.tostring(frt, [[", "]]), [["$"]]) or nil
					fct, fnr[il + 1] = (fat) and string.format("\n%slocal %s = args({%s}, {%s})", is:rep(il + 1) or "", fan, fan, fat) or "", frt
					line, comment, lfs = string.format([[["%s.function.%s"] = function(self%s)%s]], m, fn, (#faa > 0) and string.format(", %s", faa) or "", comment .. fct), "", il + 1
				end
			end
			if (line:match("^(return)%s(.-)$") and il >= lfs and fnr[il] and #fnr[il] > 0) then line, fnr[il] = string.format("return args({%s}, {%s})", line:match("^.-%s(.-)$"), fnr[il]), nil end
			if (line:match("^}$") and il == lfs) then line, lfs = "end,", lfs - 1 end
			-- fix last variable inside table
			if (string.trim(lines[n + 1] or "") == "}" and line:sub(-1) == ",") then line = line:sub(1, -2) end
			-- replace placeholders
			if (#ss39 > 0) then line = line:gsubr("<string39/>", ss39) end
			if (#ss34 > 0) then line = line:gsubr("<string34/>", ss34) end
			if (#ss91 > 0) then line = line:gsubr("<string91/>", ss91) end
			line = line:gsubr("<comment>", (showc) and "--[[" or "")
			line = line:gsubr("</comment>", (showc) and "--]]" or "")
			line = line:gsub("<comment/>", function(_) local s = table.remove(slc, 1) or "" return (showc) and string.default(s:trim(), "-- $") or "" end)
			-- indentation
			local l, _ = line:gsubc([[%b""]], ""):gsubc([[%b'']], ""):gsubc("(%[%[.-%]%])", "")
			if (l:match("^(end).-$") or (l:match("^(elseif)%s(.-)%s(then)$") or l:match("^(else)$")) or l:match("^}.?.-$")) then il = il - 1 end
			if (#line > 0 or #comment > 0) then output = string.format("%s%s%s%s\n", output, is:rep(il), (#comment > 0 and #line > 0) and string.format("%s ", line) or line, (#comment) > 0 and string.format("-- %s", comment) or "") end
			if ((l:match("%s?(function)%(?.-$") and l:match("^.-(end).-$") == nil) or (l:match("^.-%s(then)$") or l:match("^(else)$")) or l:match("^.-%s?(do)$") or l:match("^.-%s?{$")) then il = il + 1 end
		elseif (n > lsc) then
			local nextline, _ = string.gsubc(string.trim(lines[n + 1] or ""), "%*/", "</comment>")
			if (nextline:match("^(</comment>)$")) then lsc = nil end
			if (showc) then output = string.format("%s%s%s\n", output, is, line) end
		end
	end
	return output
end

if (params[2] == "true") then
	local output = process(params[1], true)
	print(output)
else
	return process
end