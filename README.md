# luascript
Library and preprocessor for object-oriented programming in the Lua programming language.

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

