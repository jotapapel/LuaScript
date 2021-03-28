--[[
	LuaScript Preprocessor
	v1.3.1 by jotapapel
--]]

local unpack, params = table.unpack or unpack, {...}

function string.trim(...)
	local r = {}
	for _, v in ipairs({...}) do table.insert(r, string.match(v, "^%s*(.-)%s*$")) end
	return unpack(r)
end

function string.gsubc(s, m, r, mf)
	local fa, i, mf, r = {}, 1, mf or function(f) return f end, r:gsub("%$", "%%s")
	local s = s:gsub(m, function(f)
		local k = string.format("%s%03i", tostring(fa):sub(-4), i)
		fa[k], i = mf(f), i + 1
		return string.format(r, k)
	end)
	return s, fa
end

function string.gsubr(s, m, t, rs)
	local i, m = 1, m:gsub("%$", "%%s")
	for k, v in pairs(t) do
		local k = string.format(m, k)
		s = s:gsub(k, function() return rs or v end)
	end
	return s
end

function string.default(s, d)
	return (s ~= nil) and string.gsub(d or "", "%$", s) or ""
end

function table.tostring(t, k)
	local s = ""
	for i = 1, #t - 1 do s = string.format("%s%s%s", s, t[i], k) end
	return (#t > 0) and string.format("%s%s", s, t[#t]) or nil
end

local function fileName(path)   
	local start, finish = path:gsub("/", string.char(92)):find("[%w%s!-={-|]+[_%.].+")
	return path:sub(start, #path) 
end


local function fileExists(file)
	local f = io.open(file, "r")
	if (f) then f:close() end
	return (f ~= nil)
end

local function fileLines(file)
	local ls = {}
	table.insert(ls, string.format("-- %s", fileName(file)))
	if (fileExists(file) == nil) then return ls end
	for l in io.lines(file) do if (#l:trim() > 0) then table.insert(ls, l) end end
	return ls
end

local function process(f, d)
	local lines, output = fileLines(f), ""
	local il, is = 0, (d or false) and string.char(32):rep(3) or ""
	local showc, slc = d, nil
	local lss, ins, lfs, fnr, lts = nil, nil, nil, {}, nil
	
	local function postmarks(s)
		local aa, bb = {}, {}
		s, bb = s:gsubc("%b[]", "<brk$>", function(f) return string.format("[%s]", postmarks(f:sub(2, -2))) end)
		s, aa = s:gsubc("%b()", "<arg$>", function(f) return string.format("(%s)", postmarks(f:sub(2, -2))) end)
		s = s:gsub("([{%(].+[}%)])!", [[rawvar(%1)]]):gsub("([%S]*)!", [[rawvar(%1)]]):gsubr("<arg$>", aa)
		s = s:gsub("#({.+})", [[tonumber(%1)]]):gsub("#([%S]*),", [[tonumber(%1),]]):gsub("#([%S]*)", [[tonumber(%1)]])
		s = s:gsub("$({.+})", [[tostring(%1)]]):gsub("$([%S]*),", [[tostring(%1),]]):gsub("$([%S]*)", [[tostring(%1)]])
		s = s:gsub("&([%w]+)", function(f) return (f:match("^([a-fA-F0-9]*)$") and #f < 7) and string.format([[torgb("%s")]], f) or string.format("&%s", f) end)
		return s:gsubr("<brk$>", bb)
	end
	
	for n, line in ipairs(lines) do
		local line, comment = line:trim(), ""
		if (lsc == nil) then
			-- fix comments
			if (line:match("^.-//.-$")) then local _, _, l, c = line:find("^(.-)//(.-)$") line, comment = l:trim(), string.format(" -- %s", c:trim()) end
			if (line:match("^.-/%*.-$")) then local _, _, l, c = line:find("^(.-)/%*(.-)$") line, comment = string.format("%s/*", l:trim()), c:trim() end
			-- placeholders
			local ss34, ss39, ss91, slc, omlc
			line, ss34 = line:gsubc([[%b""]], "<s34$/>")
			line, ss39 = line:gsubc([[%b'']], "<s39$/>")
			line, ss91 = line:gsubc("(%[%[.-%]%])", "<s91$/>")
			line, slc = line:gsubc("/%*(.-)%*/", "<rem/>", function(f) return string.format("-- %s", f:trim()) end)
			line, omlc = line:gsubc("^.-/%*.-$", "<rem>")
			-- manage comments
			if (line:match("^.-(<rem>).-$")) then lsc = n end
			-- fix variable postmarks
			line = postmarks(line)
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
			-- fix enum variable declaration
			if (ins == "enum" and il == lss) then
				local vss = {}
				string.gsub(string.format("%s%s", line, (line:sub(-1) ~= ",") and "," or ""), "(.-),", function(f) table.insert(vss, f:trim()) end)
				line = string.format([["%s",]], table.tostring(vss, [[", "]]))
			end
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
					local vt, aa, kt, kn, kv, i = (sw == "var") and "variable" or "constant", {}, "", "", nil, 0
					local function gv(l)
						local l, kt, kn, kv = l:trim(), nil, "", nil
						if (l:match("^(.-)%?$")) then _, _, kn = l:find("(.-)%?$") else _, _, kn, kv = l:find("(.-)%s=%s(.-)$") end
						if (kn:find(":")) then _, _, kn, kt = kn:find("^(.-):%s(.-)$") end
						kt, kn, kv, i, lts = string.default(kt, "$."):trim(), kn:trim(), (kv or string.format([[var("%s")]], kt)):trim(), i + 1, ((kv or string.format([[var("%s")]], kt)):trim():sub(-1) == "{") and il + 1
						return string.format([[%s["%s.%s.%s%s"] = %s%s%s]], (i > 1) and is:rep(il) or "", m, vt, kt, kn, kv, (kv:sub(-1) ~= "{") and "," or "", "\n")
					end
					line = string.gsub(string.format("%s,", string.match(string.gsub(line, [[%b()]], function(a) table.insert(aa, a) return "</args>" end), string.format("%s(.-)$", sw))), "(.-),", gv):gsub("</args>", function(s) return table.remove(aa, 1) end):sub(1, -2)
				elseif (sw == "func") then
					local fan, fat, frt, fct, fs, fn, faa, frr = {}, {}, {}, "", line:match("func%s(.-)%s{")
					fn, faa, frr = fs:match("^(.-)%(.-$"), fs:match("^.-%((.-)%).-$"):gsub("(%.%.%.)", "</tripledot>"), fs:match("^.-%s%->%s%((.-)%)$")
					faa, frr = string.trim(string.gsub(string.format("%s,", faa), "(.-),", function(a) 	local a = a:trim() if (#a > 0) then if (a ~= "</tripledot>" and a:find(":")) then table.insert(fan, (a:match("^(.-):.-$")):trim()) table.insert(fat, (a:match("^.-:(.-)$")):trim()) return string.format("%s, ", (a:match("^(.-):.-$")):trim()) else return string.format("%s, ", a:trim()) end else table.insert(fan, "...") return "" end end)):sub(1, -2), string.gsub(string.format("%s,", frr), "(.-),", function(r) table.insert(frt, r:trim()) return r end)
					faa, fan, fat, frt = faa:gsub("</tripledot>", "..."), (#fan > 0) and table.tostring(fan, ", ") or nil, (#fat > 0) and string.default(table.tostring(fat, [[", "]]), [["$"]]) or nil, (frr ~= "nil") and string.default(table.tostring(frt, [[", "]]), [["$"]]) or nil
					fct, fnr[il + 1] = (fat) and string.format("\n%slocal %s = args({%s}, {%s})", is:rep(il + 1) or "", fan, fan, fat) or "", frt
					line, comment, lfs = string.format([[["%s.function.%s"] = function(self%s)%s]], m, fn, (#faa > 0) and string.format(", %s", faa) or "", comment .. fct), "", il + 1
				end
			end
			if (line:match("^}$") and il == lfs) then line, lfs = "end,", lfs - 1 end
			if (line:match("^}$") and il == lts) then line, lts = "},", lts - 1 end
			-- fix return statement
			if (line:match("^.-(return).-$") and il >= lfs and fnr[il] and #fnr[il] > 0) then
				if (line:match("^.-(end)$")) then 
					line, fnr[il] = line:gsub("(return)%s(.-)%s(end)$", string.format("%%1 args({%s}, {%s}) end", ({line:find("^.-return%s(.-)%send$")})[3], fnr[il])), nil
				else
					line, fnr[il] = line:gsub("^(return)%s(.-)$", string.format("%%1 args({%s}, {%s})", ({line:find("^return%s(.-)$")})[3], fnr[il])), nil
				end
			end
			-- fix last variable inside table
			if (string.trim(lines[n + 1] or "") == "}" and line:sub(-1) == ",") then line = line:sub(1, -2) end
			-- replace placeholders
			line = line:gsubr("<s91$/>", ss91)
			line = line:gsubr("<s39$/>", ss39)
			line = line:gsubr("<s34$/>", ss34)
			line = line:gsubr("<rem>", omlc, "--[[")
			line = line:gsubr("<rem/>", slc)
			-- manage indentation
			local l, _ = line:gsubc([[%b""]], ""):gsubc([[%b'']], ""):gsubc("(%[%[.-%]%])", "")
			if (l:match("^(end).-$") or (l:match("^(elseif)%s(.-)%s(then)$") or l:match("^(else)$")) or l:match("^}.?.-$")) then il = il - 1 end
			if (#line > 0 or #comment > 0) then output = string.format("%s%s%s%s\n", output, is:rep(il), line, comment) end
			if ((l:match("%s*(function)%(?$") or l:match("%s*(function)%s.-%)$") or l:match("%s*(function)%(.-%)?$") and l:match("^.-(end)$") == nil) or (l:match("^.-%s(then)$") or l:match("^(else)$")) or l:match("^.-%s?(do)$") or l:match("^.-%s?{$")) then il = il + 1 end
		elseif (n > lsc) then
			local icl, line, cmlc = il + 1, line:trim():gsubc("%*/", "</rem>")
			if (line:match("^.-(</rem>)$")) then icl, lsc = il, nil end
			line = line:gsubr("</rem>", cmlc, "--]]")
			if (showc) then output = string.format("%s%s%s\n", output, is:rep(icl), line) end
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