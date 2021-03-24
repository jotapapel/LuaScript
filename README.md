<img height="64" alt="logo-big" src="https://user-images.githubusercontent.com/59461733/112255197-814c7800-8c40-11eb-9220-24fc6778a975.png">

Library and preprocessor for object-oriented programming in the Lua programming language.

### Example main.lss
```
import engine.schema

local fieldController
local class Love2d: Callbacks {
	let fieldController = FieldController()
	let mainWindow = Canvas(320, 200, &000)

	func load() {
		fieldController = self.fieldController
		fieldController:goTo(Field, "TestField", 640, 640)
	}
	
	func update(dt: number) {
		fieldController:getCurrent():update(dt)
	}

	func draw() {
		local w, h, _ = love.window.getMode()
		local x, y = (w - (dimens.screen.width * dimens.scale)) / 2, (h - (dimens.screen.height * dimens.scale)) / 2
		
		love.graphics.clear()
		fieldController:getCurrent():draw()
	}

	func keypressed(key: string, scancode: string, isrepeat: boolean) {
		fieldController:getCurrent():keypressed(key, scancode, isrepeat)
		if (key == "return") then fieldController:goTo(Field, "AnotherField", 320, 200) end
	}
}

return Love2d
````
### Processed lua file
``` lua
process("engine/schema.lss")
local fieldController
local Love2d = (class(false, "Callbacks"))({
   ["prototype.constant.fieldController"] = FieldController(),
   ["prototype.constant.mainWindow"] = Canvas(320, 200, torgb("000")),
   ["prototype.function.load"] = function(self)
      fieldController = self.fieldController
      fieldController:goTo(Field, "TestField", 640, 640)
   end,
   ["prototype.function.update"] = function(self, dt)
      local dt = args({dt}, {"number"})
      fieldController:getCurrent():update(dt)
   end,
   ["prototype.function.draw"] = function(self)
      local w, h, _ = love.window.getMode()
      local x, y = (w - (dimens.screen.width * dimens.scale)) / 2, (h - (dimens.screen.height * dimens.scale)) / 2
      love.graphics.clear()
      fieldController:getCurrent():draw()
   end,
   ["prototype.function.keypressed"] = function(self, key, scancode, isrepeat)
      local key, scancode, isrepeat = args({key, scancode, isrepeat}, {"string", "string", "boolean"})
      fieldController:getCurrent():keypressed(key, scancode, isrepeat)
      if (key == "return") then fieldController:goTo(Field, "return", 320, 200) end
   end
})
return Love2d
````

