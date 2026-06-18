--[[
    Telekinesis V6 – финальная стабильная версия
    GUI создаётся при экипировке и удаляется при смерти/снятии
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

local Sound = _Ins("Sound", Workspace)
Sound.SoundId = "rbxassetid://1092093337"
Sound.Volume = 0.3
Sound:Play()

-- Глобальные данные
local heldObjects = {}
local ScreenGui = nil
local isEquipped = false

-- Функции очистки
local function clearObjectData(obj)
    local data = heldObjects[obj]
    if not data then return end
    if data.bodyPos then data.bodyPos:Destroy() end
    if data.bodyGyro then data.bodyGyro:Destroy() end
    if data.frozenBP then data.frozenBP:Destroy() end
    if data.frozenBox then data.frozenBox:Destroy() end
    if data.selectionBox then data.selectionBox:Destroy() end
    for _, child in ipairs(obj:GetChildren()) do
        if child:IsA("BodyVelocity") or child:IsA("BodyAngularVelocity") or 
           child:IsA("BodyThrust") or child:IsA("BodyForce") then
            child:Destroy()
        end
    end
    obj.Velocity = _VTR(0,0,0)
    obj.RotVelocity = _VTR(0,0,0)
    heldObjects[obj] = nil
end

local function releaseAll()
    for obj, _ in pairs(heldObjects) do
        clearObjectData(obj)
    end
    heldObjects = {}
end

-- Удалить GUI
local function destroyGUI()
    if ScreenGui then
        ScreenGui:Destroy()
        ScreenGui = nil
    end
end

-- Открепление от персонажа
local function detachFromPlayer(obj)
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.SeatPart == obj then
        humanoid.SeatPart = nil
    end
    local function processPart(part)
        for _, weld in ipairs(part:GetChildren()) do
            if weld:IsA("Weld") or weld:IsA("Motor6D") then
                local p0 = weld.Part0
                local p1 = weld.Part1
                if (p0 and p0:IsDescendantOf(char)) or (p1 and p1:IsDescendantOf(char)) then
                    weld:Destroy()
                end
            end
        end
    end
    if obj:IsA("BasePart") then
        processPart(obj)
    elseif obj:IsA("Model") then
        for _, part in ipairs(obj:GetDescendants()) do
            if part:IsA("BasePart") then
                processPart(part)
            end
        end
    end
    for _, weld in ipairs(char:GetDescendants()) do
        if weld:IsA("Weld") or weld:IsA("Motor6D") then
            local p0 = weld.Part0
            local p1 = weld.Part1
            if (p0 and p0:IsDescendantOf(obj)) or (p1 and p1:IsDescendantOf(obj)) then
                weld:Destroy()
            end
        end
    end
end

-- Создание рамки
local function createSelectionBox(obj, color)
    local box = _Ins("SelectionBox")
    box.LineThickness = 0.03
    box.Color3 = color or Color3.fromRGB(255,255,255)
    box.Adornee = obj
    box.Parent = obj
    return box
end

-- Захват
local function grabObject(target)
    if not target or target.Anchored then return false end
    if heldObjects[target] then return false end
    local char = LocalPlayer.Character
    if char and target:IsDescendantOf(char) then return false end

    detachFromPlayer(target)
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    for _, child in ipairs(target:GetChildren()) do
        if child:IsA("BodyVelocity") or child:IsA("BodyAngularVelocity") or 
           child:IsA("BodyThrust") or child:IsA("BodyForce") or 
           child:IsA("BodyPosition") or child:IsA("BodyGyro") then
            child:Destroy()
        end
    end
    target.Velocity = _VTR(0,0,0)
    target.RotVelocity = _VTR(0,0,0)

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

-- Обновление
local function updateAllObjects()
    if not isEquipped then return end
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    for obj, data in pairs(heldObjects) do
        if not obj or not obj.Parent then
            clearObjectData(obj)
        else
            detachFromPlayer(obj)
            for _, child in ipairs(obj:GetChildren()) do
                if child:IsA("BodyVelocity") or child:IsA("BodyAngularVelocity") or 
                   child:IsA("BodyThrust") or child:IsA("BodyForce") then
                    child:Destroy()
                end
            end
            obj.Velocity = _VTR(0,0,0)
            obj.RotVelocity = _VTR(0,0,0)

            if data.isFrozen then
                if data.frozenBP then
                    data.frozenBP.position = obj.Position
                end
            else
                if not data.bodyPos or not data.bodyPos.Parent then
                    local bp = _Ins("BodyPosition")
                    bp.maxForce = _VTR(math.huge, math.huge, math.huge)
                    bp.P = 3000
                    bp.D = 500
                    bp.Parent = obj
                    data.bodyPos = bp
                end
                data.bodyPos.position = root.Position + data.offset
            end
            if data.bodyGyro and not data.isFrozen then
                data.bodyGyro.cframe = obj.CFrame
            end
        end
    end
end

-- Движение
local function moveAllObjects(delta)
    for obj, data in pairs(heldObjects) do
        data.offset = data.offset + delta
    end
end

-- Заморозка
local function toggleFreezeAll()
    if next(heldObjects) == nil then return end
    local allFrozen = true
    for _, data in pairs(heldObjects) do
        if not data.isFrozen then allFrozen = false break end
    end

    for obj, data in pairs(heldObjects) do
        if allFrozen then
            if data.frozenBP then data.frozenBP:Destroy() data.frozenBP = nil end
            if data.frozenBox then data.frozenBox:Destroy() data.frozenBox = nil end
            data.isFrozen = false
            if not data.bodyPos or not data.bodyPos.Parent then
                local bp = _Ins("BodyPosition")
                bp.maxForce = _VTR(math.huge, math.huge, math.huge)
                bp.P = 3000
                bp.D = 500
                bp.Parent = obj
                data.bodyPos = bp
            end
            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                data.offset = obj.Position - root.Position
            end
        else
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

-- Вращение
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

-- Поднять
local function liftAll()
    for obj, data in pairs(heldObjects) do
        local bv = _Ins("BodyVelocity")
        bv.maxForce = _VTR(0, math.huge, 0)
        bv.velocity = _VTR(0, 50, 0)
        bv.Parent = obj
        Debris:AddItem(bv, 0.5)
    end
end

-- Бросок
local function throwAll()
    moveAllObjects(_VTR(0, 0, 90))
end

-- Стоп
local function stopAll()
    for obj, data in pairs(heldObjects) do
        for _, child in ipairs(obj:GetChildren()) do
            if child:IsA("BodyVelocity") or child:IsA("BodyAngularVelocity") or 
               child:IsA("BodyThrust") or child:IsA("BodyForce") then
                child:Destroy()
            end
        end
        obj.Velocity = _VTR(0,0,0)
        obj.RotVelocity = _VTR(0,0,0)
    end
end

-- Кнопочные функции
local function moveUp()    moveAllObjects(_VTR(0, 1, 0)) end
local function moveDown()  moveAllObjects(_VTR(0, -1, 0)) end
local function moveLeft()  moveAllObjects(_VTR(-1, 0, 0)) end
local function moveRight() moveAllObjects(_VTR(1, 0, 0)) end
local function moveForward() moveAllObjects(_VTR(0, 0, 1)) end
local function moveBackward() moveAllObjects(_VTR(0, 0, -1)) end
local function moveCloser() moveAllObjects(_VTR(0, 0, -1)) end
local function moveFurther() moveAllObjects(_VTR(0, 0, 1)) end

-- СОЗДАНИЕ GUI (вызывается при экипировке)
local function createGUI()
    destroyGUI() -- на случай, если уже есть
    ScreenGui = _Ins("ScreenGui")
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
    MainFrame.Size = UDim2.new(0, 140, 0, 270)
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

    createButton("Стоп", stopAll, 0)
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
end

-- События инструмента
Tool.Equipped:Connect(function(mouse)
    isEquipped = true
    createGUI()
    local char = Tool.Parent
    local human = char:FindFirstChildOfClass("Humanoid")
    if human then
        human.Changed:Connect(function()
            if human.Health == 0 then
                releaseAll()
                destroyGUI()
                isEquipped = false
                Tool:Remove()
            end
        end)
    end
    mouse.Button1Down:Connect(function()
        if mouse.Target then
            local target = mouse.Target
            if target and not target.Anchored then
                local char = LocalPlayer.Character
                if char and target:IsDescendantOf(char) then return end
                grabObject(target)
            end
        end
    end)
    mouse.Icon = "rbxasset://textures\\GunCursor.png"
end)

Tool.Unequipped:Connect(function()
    isEquipped = false
    releaseAll()
    destroyGUI()
end)

-- Обновление каждый кадр
RunService.RenderStepped:Connect(updateAllObjects)

-- При респавне очищаем всё и удаляем GUI (если инструмент не в руках)
LocalPlayer.CharacterAdded:Connect(function()
    releaseAll()
    destroyGUI()
    isEquipped = false
    -- Инструмент останется в рюкзаке, но GUI пересоздастся при экипировке
end)

print("Telekinesis V6 (финальная версия) загружена!")
