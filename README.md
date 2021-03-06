# <img src="https://raw.githubusercontent.com/jotapapel/luascript/main/logo.svg" color="red"/> LuaScript
_Library and preprocessor for object-oriented programming in the Lua programming language._\
__Repository__ <big>**·**</big> [Documentation](https://github.com/jotapapel/luascript/wiki) <big>**·**</big> [Releases](https://github.com/jotapapel/luascript/releases)

***

#### Example lss file
```
/*
	Multiline comment
	another line,
	and another
*/

// single line comment

require dir.file

enum EnumName {
	Const1,
	Const2,
	Const3
}

final prototype PrototypeName: Prototype2, Prototype3 {

	static var z: object = Class(2, 3)
	var a: number = 99, b: string = "bootleg"
	const c = math.pi

	func d(...) {
	
	}
	
}

class Class1: Superclass, Prototype2, Prototype3 {

	var a: number = 99, b: string = "bootleg"
	const c = {
		a = 2,
		b = 33
	}
	
	constructor(a: string, b: number?) {
		
	}
	
	static func d(a: string, b: number?, c: any) -> (string) {
		try
			// something
		end
		return "string"
	}

}
```
#### Processed lua file (complete)
``` lua
--[[
	Multiline comment
	another line,
	and another
--]]
-- single line comment
require("dir/file")
EnumName = enum({
	"Const1",
	"Const2",
	"Const3"
})
PrototypeName = prototype(true, "Prototype2", "Prototype3")({
	["static-z:object"] = Class(2, 3),
	["a:number"] = 99,
	["b:string"] = "bootleg",
	["c:constant"] = math.pi,
	["d"] = function(self, ...)
	end
})
Class1 = class(false, "Superclass", "Prototype2", "Prototype3")({
	["a:number"] = 99,
	["b:string"] = "bootleg",
	["c:constant"] = {
		a = 2,
		b = 33
	},
	["constructor"] = function(self, a, b)
		catch_types({"string", "number?"}, true, a, b)
	end,
	["static-d"] = function(self, a, b, c)
		return catch_types({"string"}, false, (function(self, a, b, c)
			catch_types({"string", "number?", "any"}, true, a, b, c)
			try_catch(self, function(self)
				-- something
			end)
			return "string"
		end)(self, a, b, c))
	end
})
````
#### Processed lua file (minimal)
```` lua
require("dir/file")
EnumName = enum({
"Const1",
"Const2",
"Const3"
})
PrototypeName = prototype(true, "Prototype2", "Prototype3")({
["static-z:object"] = Class(2, 3)
["a:number"] = 99,
["b:string"] = "bootleg"
["c:constant"] = math.pi
["d"] = function(self, ...)
end
})
Class1 = class(false, "Superclass", "Prototype2", "Prototype3")({
["a:number"] = 99,
["b:string"] = "bootleg"
["c:constant"] = 
a = 2,
b = 33
})
constructor(a: string, b: catch_index("number")) {
}
static func d(a: string, b: catch_index("number"), c: any) -> (string) {
try_catch(self, function(self)
end)
return "string"
}
}
````
