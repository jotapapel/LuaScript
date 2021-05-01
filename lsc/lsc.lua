--[[
	LuaScript Preprocessor Component
	beta v.2.1
	
	✔ Preprocess lss files, compile the result to a lua file.
	✔ The preprocessor has two variables: --minimal: the preprocessed result will not contain indentation nor comments
																				--verbose: compiles and displays the result
																				--display: only displays the result, without compiling it
	✔ By default the new lua file is created in the same directory as the lss file.
	✔ You can designate a different location for the generated lua file by adding "@compile /.../$" as the first line of the lss file.
--]]

local filename, arg1, arg2, arg3 = ...
local unpack = table.unpack or unpack

local function check_arg(a)
	return (arg1 == a or arg2 == a or arg3 == a)
end

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
	fa.token, fa.len = r, i
	return s, fa
end

function string.gsubr(s, t, rs)
	local t = not(t.token) and error("Replace table missing token string.", 2) or t
	local m, l = string.gsub(t.token, "%$", "%%s"), not(t.len) and error("Replace table missing length.", 2) or t.len
	for i = 1, l do
		local k = string.format("%s%03i", tostring(t):sub(-4), i)
		s = s:gsub(string.format(m, k), function() return string.default(t[k]:trim(), rs) end)
	end
	return s
end

function string.default(s, d, n)
	local n = n or ""
	local d = (d) and string.gsub(tostring(d), "%$", s or "") or s
	return (s ~= nil) and d or n
end

function table.expand(t, k)
	local s = ""
	for i = 1, #t - 1 do s = string.format("%s%s%s", s, t[i], k) end
	return (#t > 0) and string.format("%s%s", s, t[#t]) or nil
end

function language_helpers(str)
	local ss34, ss39, pp, aa, bb
	str, ss34 = str:gsubc('%b""', "<str$/>")
	str, ss39 = str:gsubc("%b''", "<str$/>")
	str, ss91 = str:gsubc("(%[%[.-%]%])", "<p$/>")
	str, bb = str:gsubc("%b[]", "<brackets$/>", function(f) return string.format("[%s]", language_helpers(f:sub(2, -2))) end)
	str, aa = str:gsubc("%b()", "<parenthesis$/>", function(f) return string.format("(%s)", language_helpers(f:sub(2, -2))) end)
	str = str:gsub("(%s*)(%S+)%?", function(s, k) return string.format('%scatch_index("%s")', s, k:gsub("%??%.", '", "')) end)
	str = str:gsub("([^,%s]+)!", "rawvar(%1)")
	str = str:gsub("#([^,%s]+)", "tonumber(%1)")
	str = str:gsub("$([^,%s]+)", "tostring(%1)")
	str = str:gsub("&(%w+)", function(f) return (f:match("^([a-fA-F0-9]+)$") and (#f == 3 or #f == 6)) and string.format('torgb("%s")', f) or string.format("&%s", f) end)
	return str:gsubr(aa):gsubr(bb):gsubr(ss91):gsubr(ss39):gsubr(ss34)
end

local function process(f)
	local minimal, file, lines, output, newlines = check_arg("--minimal"), io.open(f, "r"), {}, "", {}
	local il, is = 0, (minimal == false) and string.char(9) or ""
	local showc, lsc, isc = not(minimal), nil, false
	-- read file
	if (file) then
		for l in io.lines(f) do table.insert(lines, l) end
		file:close()
	end
	-- processor auxiliaries
	local eis, ine, ifs, itbs, irs, fnr, its, ics, itbs = nil, nil, nil, nil, nil, {}, nil, nil, nil
	for n, line in ipairs(lines) do
		-- replace comments
		line = line:gsub("/%*", "--[["):gsub("%*/", "--]]"):gsub("//", "--")
		if (lsc == nil) then
			local line, comment = line:trim(), ""
			-- prepare line for parsing, insert placeholders
			local slc, omlc, ss34, ss39, ss91, oss91, css91
			line, slc = line:gsubc("%-%-%[%[(.-)%-%-%]%]", "<comment/>")
			if (line:match("^.-%-%-%[%[.-$")) then local _, _, l, c = line:find("^(.-)%-%-%[%[(.-)$"); line, comment = string.trim(string.format("%s --[[", l:trim())), c:trim() 	end
			line, omlc = line:gsubc("%-%-%[%[", "<comment>")
			if (line:match("^.-%-%-.-$")) then 	local _, _, l, c = line:find("^(.-)%-%-(.-)$"); line, comment = string.format("%s%s", l:trim(), (#l > 0) and string.char(32) or ""), string.format("-- %s", c:trim()) 	end
			line, ss91 = line:gsubc("(%[%[.-%]%])", "<str$/>")
			line, oss91 = line:gsubc("%[%[", "<str>")
			line, ss39 = line:gsubc([[%b'']], "<str$/>")
			line, ss34 = line:gsubc([[%b""]], "<str$/>")
			-- comments and long strings
			if (line:match("^.-(<comment>)$")) then lsc, isc = n, true end
			if (line:match("^.-(<str>).-$") and line:match("^.-(<str.-/>).-$") == nil) then lsc, isc = n, false end
			-- import function
			if (line:match("^(require%s+).-$")) then line = string.format('require("%s")', line:match("^require%s+(.-)$"):gsub("%.", "/")) end
			-- entities
			local etk, fnl
			fnl = line:match("^(final%s).-{$")
			etk = line:match("^(enum)%s+.-{$") or line:match(string.format("^%s(prototype)%%s+.-{$", string.default(fnl))) or line:match(string.format("^%s(class)%%s+.-{$", string.default(fnl)))
			if (etk) then 
				local ek, es, en = etk:trim(), line:match(string.format("^%s%s(.-){$", string.default(fnl), etk)), nil
				es = string.gsub(string.format("%s,", es:trim():gsub(":", ",")), "(.-),", function(e) if (en == nil) then en = e:trim() return "" else return string.default(e:trim(), '"$", ') end end)
				local ea = (ek == "enum") and "" or string.format("(%s%s)", (fnl) and "true" or "false", (#es > 0) and string.format(", %s", es:sub(1, -3)) or "")
				line, eis, ine = string.format("%s = %s%s({", en, ek, ea), il + 1, ek
			end
			if (line:match("^}$") and il == eis) then 
				line, eis, ine = "})", nil, nil
				if (newlines[#newlines]:sub(-1) == ",") then output = output:sub(1, -3) .. "\n" end
			end
			-- enum variables
			if (ine and ine:trim() == "enum" and il >= eis) then
				local l = (line:sub(-1) == ",") and line or string.format("%s,", line)
				line = l:gsub("(.-),", function(c) return string.default(c:trim(), '"$", ') end):trim()
			end
			-- prototype and class variables and functions
			if (ine and ine:trim() ~= "enum") then
				local isw, iss
				isw = line:match("^(weak)%s+.-{}?$")
				iss = line:match(string.format("^%s%%s*(static)%%s+.-{?}?$", string.default(isw)))
				-- variables and constants
				local vrk, vrs
				vrk = line:match(string.format("^%s%%s*(var)%%s+.-$", string.default(iss))) or line:match(string.format("^%s%%s*(const)%%s+.-$", string.default(iss)))
				vrd = line:match(string.format("^%s%%s*%s%%s+(.-)$", string.default(iss), vrk))
				if (vrk and vrd) then
					local l, vda = "", {}
					vrd, vda = vrd:gsubc("%b()", "<args$/>")
					l = string.gsub(string.format("%s,", vrd), "(.-),", function(p)
						local k = string.match(p:trim(), "^(.-):%s*.-$") or string.match(p:trim(), "^(.-)%s+=.-$")
						local t = string.default(string.match(p:trim(), "^.-:%s*([%w%?]+).-$"), ":$")
						local v = (t:match("^.-(%?)$")) and string.format('var("%s")', t:match("%w+")) or string.match(p:trim(), "^.-%s+=%s+(.-)$")
						local c = ","
						if (v:sub(-1) == "{") then c, itbs = "", il + 1 end
						return string.format('["%s%s%s"] = %s%s\n%s', string.default(iss, "static-"), k, (vrk == "const") and ":constant" or (t and t:match(":%w+") or ""), v, c, is:rep(il))
					end)
					line = l:gsubr(vda):sub(1, -2 - il)
				end
				-- functions and constructor
				local olf, fnk, fdk, fdp, fdr, fda, fdt
				olf, fnk, fdr = line:match("^.-%s+{}$"), line:match(string.format("^%s%%s*%s%%s*(func)%%s+.-{}?$", string.default(isw), string.default(iss))) or line:match("^(constructor)%(.-{}?$"), line:match("^.-%s+%->%s+%((.-)%)%s+{$")
				if (fnk == "func") then fdk, fdp = line:match(string.format("^%s%%s*%s%%s*func%%s+([_%%w]+)%%((.-)%%).-{}?$", string.default(isw), string.default(iss))) end
				if (fnk == "constructor") then fdk, fdp = "constructor", line:match("^constructor%((.-)%)%s+{}?$") end
				if (fdk and fdp) then
					fda = string.gsub(string.format("%s,", fdp), "(.-),", function(p)
						local k, t = string.match(p:trim(), "^([_%w]+):%s*([%w%?]+)$")
						if (t) then fdt = string.format('%s"%s", ', string.default(fdt), t) end
						return string.default(k or p:match("%.%.%."), "$, ")
					end)
					fda, fdt = string.trim(string.match(string.default(fda), "^(.-),%s+$"), string.match(string.default(fdt), "^(.-),%s+$"))
					if (fdr) then fdr = string.gsub(string.format("%s,", fdr), "(.-),", function(t) return string.default(t:trim(), '"$", ') end):match("^(.-),%s+$") end
					if (olf) then
						line = string.format('["%s%s"] = function() end,', string.default(iss, "static-"), fdk)
					else
						local ni, fcs = (fdr) and 2 or 1, fdt and string.format("\n%s", string.format("%scatch_types({%s}, true, %s)", is:rep(il + 1), fdt, string.match(string.default(fda), "^(.-),%s+%.%.%.$") or fda))
						if (fcs) then table.insert(lines, n + 1, fcs) end
						line, ifs = string.format('["%s%s"] = function(%s%s%s)', string.default(iss, "static-"), fdk, string.default(isw, "", "self"), (isw == nil and fda) and ", " or "", string.default(fda)), il + ni
						if (fdr) then 
							local mda = string.format("%s%s%s", string.default(isw, "", "self"), (isw == nil and fda) and ", " or "", string.default(fda))
							local mds = (fdr) and string.format("return catch_types({%s}, false, (function(%s)", fdr, mda) or string.format("(function(%s)", string.default(fda))
							table.insert(lines, n + 1, mds)
							fnr[il + 1] = mda
						end
					end
				end
				-- closing functions
				if (line:match("^}$")) then
					if (il == ifs) then
						line, ifs = "end,", ifs - 1
						if (fnr[ifs]) then line, fnr[ifs] = string.format("end)(%s))", string.default(fnr[ifs])), nil ; table.insert(lines, n + 1, "end,") end
					end
					if (il == itbs) then line, itbs = "},", nil end
				end
			end
			-- try .. catch structure
			if (line:match("^(try)$")) then line, its = "try_catch(self, function(self)", il + 1 end
			if (line:match("^(catch)%s+.-%s+(do)$")) then line, ics = string.format("end, function(%s)", line:match("^catch%s+(.-)%s+do$"):trim():match("[_%w]+")), il end
			if (line:match("^(end)$")) then
				if (il == ics) then line, ics = "end)", nil end
				if (il == its) then line, its = "end)", nil end
			end
			-- replace language helpers
			line = language_helpers(line)
			-- finish parsing, replace placeholders
			line = line:gsubr(ss34):gsubr(ss39):gsubr(ss91):gsubr(oss91, "[[")
			-- replace comments
			line = line:gsubr(omlc, (showc) and "--[[" or ""):gsubr(slc, "-- $")
			-- do indentation
			local l, c = line:gsub("%b()", "<parenthesis/>"):gsub("(%[%[(.-)%]%])", "<p/>"):gsub([[%b'']], "<str/>"):gsub([[%b""]], "<str/>"), (showc) and comment or ""
			l = l:gsub("function<parenthesis/>.-end", "<function/>"):gsub("function%s+.-<parenthesis/>.-end", "<function/>")
			if (l:match("^(catch).-(do)$") or l:match("^(until).-$") or l:match("^(end).-$") or (l:match("^(elseif)%s+.-%s+(then)$") or l:match("^(else)$")) or l:match("^%s*(})%s*.-$")) then il = il - 1 end
			if ((#l > 0) or (#c > 0)) then output = string.format("%s%s%s%s\n", output, is:rep(il), line, c) table.insert(newlines, line) end
			if (l:match("^(while).-$") or l:match("^(try)$") or l:match("^(repeat)$") or (l:match("^.-%s*(function<parenthesis/>)$") or l:match("^.-%s*(function)%s+.-$")) or l:match("^.-%s+(then)$") or l:match("^(else)$") or (l:match("^.-(do)$") and l:match("^.-(end).-$") == nil) or l:match("^.-%s*({)%s*$")) then il = il + 1 end
		elseif (n > lsc) then
			local cmlc, css91
			line, cmlc = line:gsubc("%-%-%]%]", "</comment>")
			line, css91 = line:gsubc("%]%]", "</str>")
			if (line:match("^.-(</comment>)$")) then lsc, isc = nil, false end
			if (line:match("^.-(</str>)$")) then 
				if (il == ilgs - 1) then line, ilgs = string.format("%s,", line), nil end
				lsc, isc = nil, false
			end
			-- replace comments
			 line = line:gsubr(css91, "]]"):gsubr(cmlc, (showc) and "--]]" or "")
			-- display comment or long string
			if (showc or (isc == false) and (#line > 0)) then output = string.format("%s%s\n", output, line) end
		end
	end
	return output, lines[1]:match("^@compile%s+(.-)$")
end

if (filename) then
	local lines = {}
	local output, outpath = process(filename)
	local dirbits, namebits, basepath, strip = {}, {}, filename, 1
	-- generate file content
	string.gsub(output, "(.-)\n", function(l) table.insert(lines, l) end)
	if (outpath) then table.remove(lines, 1) end
	-- create a lua file
	if (check_arg("--display") == false) then
		-- get basepath for new file
		if (outpath) then basepath, strip = string.gsub(debug.getinfo(1).short_src, "^(.+\\)[^\\]+$", "%1"), 2 end
		local i, _, l = 0, string.gsub(string.format("%s/", basepath), "/", "")
		string.gsub(string.format("%s/", basepath), "(.-)/", function(b) if (i < l - strip) then table.insert(dirbits, b) end i = i + 1 end)
		-- get the name of the new file from the og filename
		string.gsub(string.format("%s/", filename), "(.-)/", function(b) table.insert(namebits, b) end)
		local name = string.gsub(outpath or "/$", "%$", string.format("%s.lua", table.remove(namebits):sub(1, -5))):sub(2)
		table.insert(dirbits, name)
		-- write new lua file
		local file = io.open(table.expand(dirbits, "/"), "w")
		file:write(table.expand(lines, "\n"))
		file:close()
	end
	-- print contents to terminal
	if (check_arg("--display") or check_arg("--verbose")) then
		local f = string.format(" %%0%si %%s", math.max(2, #tostring(#lines)))
		for n, line in ipairs(lines) do print(string.format(f, n, line)) end
	end
else
	print("usage: lua ../lsc.lua path/to/file.lss [--minimal] [--display] [--verbose]")
end