if app.apiVersion < 21 then
    return app.alert("This script requires Aseprite v1.3-rc1")
end

local Direction = {
    Up = Point(0, 1),
    Down = Point(0, -1),
    Right = Point(1, 0),
    Left = Point(-1, 0)
}

local GameEngine = {_fps = 10, _timer = nil}

function GameEngine:Init(onstart, onupdate, onstop)
    self.onstart = onstart
    self.onupdate = onupdate
    self.onstop = onstop

    self._timer = Timer {interval = 1.0 / self._fps, ontick = self.onupdate}
end

function GameEngine:Start()
    if self.onstart then self.onstart() end
    self._timer:start()
end

function GameEngine:Stop()
    if self.onstop then self.onstop() end
    self._timer:stop()
end

local board = {width = 16, height = 12, data = {}}

-- Initialize board data
for _ = 1, board.height do
    local row = {}

    for _ = 1, board.width do table.insert(row, false) end

    table.insert(board.data, row)
end

local gameSprite, player, direction, tail, fruit, gameOver, blinkingFrame

local OnStart = function()
    player = Point(7, 6)
    tail = {Point(6, 6), Point(5, 6)}
    direction = Point(1, 0)
    fruit = Point(2, 2)
    blinkingFrame = true
    gameOver = false

    if not gameSprite then
        gameSprite = Sprite(board.width, board.height)

        for layerIndex = 2, board.height do
            local layer = gameSprite:newLayer()
            layer.name = "Layer " .. tostring(layerIndex)
        end
        for _ = 2, board.width do gameSprite:newFrame() end

        gameSprite:newCel(gameSprite.layers[player.y], player.x)
    end
end

local PlaceFruit = function()
    while true do
        fruit = Point(math.random(2, board.width - 1),
                      math.random(2, board.height - 1))

        local isUnique = true

        local distance = math.abs(player.x - fruit.x) +
                             math.abs(player.y - fruit.y)

        if distance < 4 then
            isUnique = false
        else
            for _, tailPath in ipairs(tail) do
                if fruit == tailPath then
                    isUnique = false
                    break
                end
            end
        end

        if isUnique then break end
    end
end

local Update = function()
    -- Don't update if the game is over
    if gameOver then return end

    -- Add the previous player positon as the new tail part
    table.insert(tail, player)

    -- Move the player in the current direction
    player = player + direction

    if player.x < 1 or player.x > board.width or player.y < 1 or player.y >
        board.height then
        gameOver = true
        -- Move the player back
        player = player - direction
        return
    end

    for _, tailPart in ipairs(tail) do
        if tailPart == player then
            gameOver = true
            -- Move the player back
            player = player - direction
            return
        end
    end

    if player == fruit then
        PlaceFruit()
    else
        -- Remove tha end of the tail
        table.remove(tail, 1)
    end
end

local DrawLine = function(layer, start, stop)
    gameSprite:newCel(layer, start)

    app.range.layers = {layer}
    local frames = {}

    for i = start, stop do table.insert(frames, i) end

    app.range.frames = frames
    app.command:LinkCels()
end

local Draw = function()
    -- Clear the board data
    for y = 1, #board.data do
        for x = 1, #board.data[1] do board.data[y][x] = false end
    end

    -- Draw the player
    board.data[player.y][player.x] = true

    -- Draw the tail
    for _, tailPart in ipairs(tail) do
        board.data[tailPart.y][tailPart.x] = true
    end

    for y = 1, board.height do
        local rowLayer = gameSprite.layers[y]
        local row = board.data[y]

        -- First delete all cels that shouldn't exist
        for x = 1, board.width do
            local celExists = rowLayer:cel(x) ~= nil
            local celShouldExist = row[x]

            if not celShouldExist and celExists then
                gameSprite:deleteCel(rowLayer, x)
            end
        end

        local start = nil

        -- Draw all lines
        for x = 1, board.width do
            local celShouldExist = row[x]

            -- End if cel shouldn't exist
            if celShouldExist then
                if not start then start = x end
            elseif start ~= nil then
                DrawLine(rowLayer, start, x - 1)
                start = nil
            end
        end

        if start ~= nil then DrawLine(rowLayer, start, board.width) end
    end

    -- Draw the fruit
    local fruitLayer = gameSprite.layers[fruit.y]
    local fruitCel = fruitLayer:cel(fruit.x)

    if fruitCel then
        app.activeCel = fruitCel
    else
        app.activeCel = gameSprite:newCel(fruitLayer, fruit.x)
    end
end

local OnUpdate = function()
    if gameOver then
        if blinkingFrame then
            for _, cel in ipairs(gameSprite.cels) do
                gameSprite:deleteCel(cel)
            end
        else
            Draw()
        end

        blinkingFrame = not blinkingFrame
        return
    end

    Update()
    Draw()
end

GameEngine:Init(OnStart, OnUpdate, nil)

local dialog = Dialog {
    title = "Snake",
    onclose = function()
        GameEngine:Stop()
        if gameSprite then gameSprite:close() end
    end
}

local buttons = {
    ["KeyW"] = {
        text = "W",
        bounds = Rectangle(54, 2, 24, 24),
        isPressed = false,
        onclick = function()
            direction = direction ~= Direction.Down and Direction.Up or
                            direction
        end
    },
    ["KeyS"] = {
        text = "S",
        bounds = Rectangle(54, 28, 24, 24),
        isPressed = false,
        onclick = function()
            direction = direction ~= Direction.Up and Direction.Down or
                            direction
        end
    },
    ["KeyD"] = {
        text = "D",
        bounds = Rectangle(80, 28, 24, 24),
        isPressed = false,
        onclick = function()
            direction = direction ~= Direction.Left and Direction.Right or
                            direction
        end
    },
    ["KeyA"] = {
        text = "A",
        bounds = Rectangle(28, 28, 24, 24),
        isPressed = false,
        onclick = function()
            direction = direction ~= Direction.Right and Direction.Left or
                            direction
        end
    },
    ["KeyQ"] = {
        text = "Q",
        label = "Quit",
        bounds = Rectangle(2, 2, 24, 24),
        isPressed = false,
        onclick = function() dialog:close() end
    },
    ["KeyR"] = {
        text = "R",
        label = "Start",
        bounds = Rectangle(106, 2, 24, 24),
        isPressed = false,
        onclick = function()
            GameEngine:Start()
            -- Refocus on the canvas, opening a sprite resets it
            dialog:modify{id = "canvas", focus = true}
        end
    }
}

dialog --
:canvas{
    id = "canvas",
    width = 132,
    height = 56,
    onkeyup = function()
        for _, button in pairs(buttons) do button.isPressed = false end

        dialog:repaint()
    end,
    onkeydown = function(ev)
        for key, button in pairs(buttons) do
            if ev.code == key and ev.repeatCount == 0 then
                button.onclick()
            end

            button.isPressed = ev.code == key
        end

        dialog:repaint()

        -- This fixes keyboard hit triggering twice
        ev:stopPropagation()
    end,
    onpaint = function(ev)
        local gc = ev.context

        for _, button in pairs(buttons) do
            local bounds = button.bounds

            local partId = button.isPressed and "button_hot" or "button_normal"
            gc:drawThemeRect(partId, bounds.x, bounds.y, bounds.width,
                             bounds.height)

            if button.text then
                local size = gc:measureText(button.text)

                gc:fillText(button.text,
                            bounds.x + bounds.width / 2 - size.width / 2,
                            bounds.y + bounds.height / 2 - size.height / 2)
            end

            if button.label then
                local size = gc:measureText(button.label)

                gc:fillText(button.label,
                            bounds.x + bounds.width / 2 - size.width / 2,
                            bounds.y + bounds.height + 2)
            end
        end
    end
}

dialog:show()
