--[[
    Telekinesis V6 – множественный захват, управление через кнопки
    Исправлено: объекты двигаются по кнопкам (даже после заморозки/разморозки)
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local _Ins = Instance.new
local _VTR = Vector3.new
local _CF = CFrame.new

-- Инструмент
local Tool = _Ins("Tool")
Tool.Name = "Telekinesis V6"
Tool.Parent = LocalPlayer.Backpack
Tool.RequiresHandle = true
Tool.CanBeDropped = false
Tool.Grip = _CF(0,0,1, 1,0,0, 0,1,0, 0,0,1)
Tool.GripPos = _VTR(0,0,1)

local Handle = _Ins("Part")
Handle.Name = "Handle"
Handle.Parent = Tool
Handle.Size = _VTR(1,1,1)
Handle.Transparency = 1
Handle.CanCollide = false
Handle.Locked = true
Handle.BrickColor = BrickColor.new("Institutional white")

-- Звук
local Sound = _Ins("Sound", Workspace)
Sound.SoundId = "rbxassetid://1092093337"
Sound.Volume = 0.3
Sound:Play()

-- Таблица захваченных объектов
local heldObjects = {}

-- Создание рамки подсветки
local function createSelectionBox(obj, color)
    local box = _Ins("SelectionBox")
    box.LineThickness = 0.03
    box.Color3 = color or Color3.fromRGB(255,255,255)
    box.Adornee = obj
    box.Parent = obj
    return box
end

-- Захват объекта
local function grabObject(target)
    if not target or target.Anchored then return false end
    if heldObjects[target] then return false end
    local char = LocalPlayer.Character
    if char and target:IsDescendantOf(char) then return false end

    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local offset = target.Position - root.Position

    local bp = _Ins("BodyPosition")
    bp.maxForce = _VTR(math.huge, math.huge, math.huge)
    bp.P = 3000
    bp.D = 500
    bp.Parent = target

    local bg = _Ins("BodyGyro")
    bg.maxTorque = _VTR(math.huge, math.huge, math.huge)
    bg.cframe = target.CFrame
    bg.P = 5000
    bg.D = 1000
    bg.Parent = target

    local selBox = createSelectionBox(target, Color3.fromRGB(255,255,255))

    heldObjects[target] = {
        bodyPos = bp,
        bodyGyro = bg,
        offset = offset,
        frozenBP = nil,
        frozenBox = nil,
        isFrozen = false,
        selectionBox = selBox
    }
    return true
end

-- Освободить все
local function releaseAll()
    for obj, data in pairs(heldObjects) do
        if data.bodyPos then data.bodyPos:Destroy() end
        if data.bodyGyro then data.bodyGyro:Destroy() end
        if data.frozenBP then data.frozenBP:Destroy() end
        if data.frozenBox then data.frozenBox:Destroy() end
        if data.selectionBox then data.selectionBox:Destroy() end
    end
    heldObjects = {}
end

-- Освободить конкретный
local function releaseObject(obj)
    local data = heldObjects[obj]
    if not data then return end
    if data.bodyPos then data.bodyPos:Destroy() end
    if data.bodyGyro then data.bodyGyro:Destroy() end
    if data.frozenBP then data.frozenBP:Destroy() end
    if data.frozenBox then data.frozenBox:Destroy() end
    if data.selectionBox then data.selectionBox:Destroy() end
    heldObjects[obj] = nil
end

-- Обновление позиции всех объектов (вызывается каждый кадр)
local function updateAllObjects()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    for obj, data in pairs(heldObjects) do
        if not obj or not obj.Parent then
            releaseObject(obj)
        else
            if data.isFrozen then
                -- Заморожен: держим на текущей позиции
                if data.frozenBP then
                    data.frozenBP.position = obj.Position
                end
            else
                -- Не заморожен: обновляем позицию через BodyPosition
                if not data.bodyPos or not data.bodyPos.Parent then
                    -- Если BodyPosition пропал (например, был удалён), создаём заново
                    local bp = _Ins("BodyPosition")
                    bp.maxForce = _VTR(math.huge, math.huge, math.huge)
                    bp.P = 3000
                    bp.D = 500
                    bp.Parent = obj
                    data.bodyPos = bp
                end
                data.bodyPos.position = root.Position + data.offset
            end
            -- Сохраняем ориентацию (если не заморожен)
            if data.bodyGyro and not data.isFrozen then
                data.bodyGyro.cframe = obj.CFrame
            end
        end
    end
end

-- Движение всех объектов на дельту (меняем offset)
local function moveAllObjects(delta)
    for obj, data in pairs(heldObjects) do
        data.offset = data.offset + delta
    end
end

-- Заморозка/разморозка всех
local function toggleFreezeAll()
    if next(heldObjects) == nil then return end
    local allFrozen = true
    for _, data in pairs(heldObjects) do
        if not data.isFrozen then allFrozen = false break end
    end

    for obj, data in pairs(heldObjects) do
        if allFrozen then
            -- Разморозка
            if data.frozenBP then data.frozenBP:Destroy() data.frozenBP = nil end
            if data.frozenBox then data.frozenBox:Destroy() data.frozenBox = nil end
            data.isFrozen = false
            -- Восстанавливаем BodyPosition (если отсутствует)
            if not data.bodyPos or not data.bodyPos.Parent then
                local bp = _Ins("BodyPosition")
                bp.maxForce = _VTR(math.huge, math.huge, math.huge)
                bp.P = 3000
                bp.D = 500
                bp.Parent = obj
                data.bodyPos = bp
            end
            -- Обновляем offset, чтобы избежать рывка
            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                data.offset = obj.Position - root.Position
            end
        else
            -- Заморозка
            if data.bodyPos then data.bodyPos:Destroy() data.bodyPos = nil end
            local freezeBP = _Ins("BodyPosition")
            freezeBP.maxForce = _VTR(math.huge, math.huge, math.huge)
            freezeBP.P = 5000
            freezeBP.D = 1000
            freezeBP.position = obj.Position
            freezeBP.Parent = obj
            data.frozenBP = freezeBP
            local box = createSelectionBox(obj, Color3.fromRGB(0,255,0))
            data.frozenBox = box
            data.isFrozen = true
        end
    end
end

-- Вращение (включить/выключить)
local function toggleSpinAll()
    if next(heldObjects) == nil then return end
    local hasSpin = false
    for _, data in pairs(heldObjects) do
        if data.bodyGyro and data.bodyGyro.Parent then
            hasSpin = true
            break
        end
    end

    for obj, data in pairs(heldObjects) do
        if hasSpin then
            if data.bodyGyro then data.bodyGyro:Destroy() end
            local bg = _Ins("BodyGyro")
            bg.maxTorque = _VTR(math.huge, math.huge, math.huge)
            bg.cframe = obj.CFrame
            bg.P = 5000
            bg.D = 1000
            bg.Parent = obj
            data.bodyGyro = bg
        else
            if data.bodyGyro then data.bodyGyro:Destroy() end
            local bg = _Ins("BodyGyro")
            bg.maxTorque = _VTR(math.huge, math.huge, math.huge)
            bg.cframe = obj.CFrame * _CF(0, math.rad(45), 0)
            bg.P = 5000
            bg.D = 1000
            bg.Parent = obj
            data.bodyGyro = bg
        end
    end
end

-- Поднять (импульс вверх)
local function liftAll()
    for obj, data in pairs(heldObjects) do
        local bv = _Ins("BodyVelocity")
        bv.maxForce = _VTR(0, math.huge, 0)
        bv.velocity = _VTR(0, 50, 0)
        bv.Parent = obj
        Debris:AddItem(bv, 0.5)
    end
end

-- Бросок (отодвинуть на 90)
local function throwAll()
    moveAllObjects(_VTR(0, 0, 90))
end

-- Кнопочные функции (шаг 1 единица)
local function moveUp()    moveAllObjects(_VTR(0, 1, 0)) end
local function moveDown()  moveAllObjects(_VTR(0, -1, 0)) end
local function moveLeft()  moveAllObjects(_VTR(-1, 0, 0)) end
local function moveRight() moveAllObjects(_VTR(1, 0, 0)) end
local function moveForward() moveAllObjects(_VTR(0, 0, 1)) end
local function moveBackward() moveAllObjects(_VTR(0, 0, -1)) end
local function moveCloser() moveAllObjects(_VTR(0, 0, -1)) end
local function moveFurther() moveAllObjects(_VTR(0, 0, 1)) end

-- ============= УМЕНЬШЕННОЕ GUI =============
local ScreenGui = _Ins("ScreenGui")
ScreenGui.Name = "TelekinesisGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = _Ins("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)
MainFrame.BorderColor3 = Color3.fromRGB(60,60,60)
MainFrame.BorderSizePixel = 1
MainFrame.Position = UDim2.new(1, -150, 0.5, -130)
MainFrame.Size = UDim2.new(0, 140, 0, 260)
MainFrame.Active = true
MainFrame.Draggable = true

local Title = _Ins("TextLabel")
Title.Parent = MainFrame
Title.BackgroundColor3 = Color3.fromRGB(30,30,30)
Title.BorderSizePixel = 0
Title.Size = UDim2.new(1,0,0,20)
Title.Font = Enum.Font.Code
Title.Text = "TELEKINESIS V6"
Title.TextColor3 = Color3.fromRGB(255,255,255)
Title.TextSize = 10

local ScrollFrame = _Ins("ScrollingFrame")
ScrollFrame.Parent = MainFrame
ScrollFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)
ScrollFrame.BorderSizePixel = 0
ScrollFrame.Position = UDim2.new(0,0,0,20)
ScrollFrame.Size = UDim2.new(1,0,1,-20)
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80,80,80)

local UIListLayout = _Ins("UIListLayout")
UIListLayout.Parent = ScrollFrame
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 2)

UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 5)
end)

local UIPadding = _Ins("UIPadding")
UIPadding.Parent = ScrollFrame
UIPadding.PaddingTop = UDim.new(0, 3)
UIPadding.PaddingLeft = UDim.new(0, 5)
UIPadding.PaddingRight = UDim.new(0, 5)

local function createButton(text, callback, order)
    local btn = _Ins("TextButton")
    btn.Parent = ScrollFrame
    btn.BackgroundColor3 = Color3.fromRGB(45,45,45)
    btn.BorderColor3 = Color3.fromRGB(70,70,70)
    btn.BorderSizePixel = 1
    btn.Size = UDim2.new(1, -6, 0, 22)
    btn.Font = Enum.Font.Code
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.TextSize = 10
    btn.LayoutOrder = order
    btn.MouseButton1Click:Connect(callback)
    return btn
end

createButton("Захват (луч)", function()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local origin = cam.CFrame.p
    local direction = cam.CFrame.LookVector * 100
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    local result = Workspace:Raycast(origin, direction, raycastParams)
    if result then
        local hit = result.Instance
        if hit and not hit.Anchored then
            grabObject(hit)
        end
    end
end, 1)

createButton("Отпустить все", releaseAll, 2)
createButton("Вверх", moveUp, 3)
createButton("Вниз", moveDown, 4)
createButton("Влево", moveLeft, 5)
createButton("Вправо", moveRight, 6)
createButton("Вперёд", moveForward, 7)
createButton("Назад", moveBackward, 8)
createButton("Приблизить", moveCloser, 9)
createButton("Отдалить", moveFurther, 10)
createButton("Заморозить", toggleFreezeAll, 11)
createButton("Вращать", toggleSpinAll, 12)
createButton("Поднять", liftAll, 13)
createButton("Бросок", throwAll, 14)

-- Захват по клику мыши
local function onMouseClick(target)
    if target and not target.Anchored then
        local char = LocalPlayer.Character
        if char and target:IsDescendantOf(char) then return end
        grabObject(target)
    end
end

-- События инструмента
Tool.Equipped:Connect(function(mouse)
    local char = Tool.Parent
    local human = char:FindFirstChildOfClass("Humanoid")
    if human then
        human.Changed:Connect(function()
            if human.Health == 0 then
                releaseAll()
                Tool:Remove()
            end
        end)
    end
    mouse.Button1Down:Connect(function()
        if mouse.Target then
            onMouseClick(mouse.Target)
        end
    end)
    mouse.Icon = "rbxasset://textures\\GunCursor.png"
end)

Tool.Unequipped:Connect(releaseAll)

RunService.RenderStepped:Connect(updateAllObjects)

LocalPlayer.CharacterAdded:Connect(function()
    releaseAll()
end)

print("Telekinesis V6 loaded successfully!")
