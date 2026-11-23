local synsaveinstance = loadstring(game:HttpGet("https://raw.githubusercontent.com/verysigmapro/UniversalSynSaveInstance-With-Save-Terrain/refs/heads/main/saveinstance_rewrite.luau", true), "saveinstance")();

--=====================================================================
--  AOPG | THIRD SEA  ::  VENICE HUB  (Xeno / Delta / Wave)
--=====================================================================
if getgenv().VeniceHubLoaded then
    pcall(function() getgenv().VeniceHub.Unload() end)
    task.wait(0.3)
end
getgenv().VeniceHubLoaded = true

local cloneref = cloneref or function(o) return o end
local Players           = cloneref(game:GetService("Players"))
local RunService        = cloneref(game:GetService("RunService"))
local TweenService      = cloneref(game:GetService("TweenService"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local UserInputService  = cloneref(game:GetService("UserInputService"))
local StarterGui        = cloneref(game:GetService("StarterGui"))
local VirtualInputManager = cloneref(game:GetService("VirtualInputManager"))
local HttpService       = cloneref(game:GetService("HttpService"))

local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local VIM = VirtualInputManager

--=========================================================
--  CONFIG / ESTADO
--=========================================================
local S = {
    WalkSpeed = 32, JumpPower = 50,
    InfJump = false, Noclip = false, Fly = false, FlySpeed = 60,
    AntiAFK = true, GodMode = false, Fullbright = false,
    AutoQuest = false, AutoAttack = false, AutoCollect = false,
    AutoBoss = false, AutoSeaBeast = false, AutoChest = false,
    AutoHaki = false, AutoSkill = false,
    KillAura = false, AuraRange = 30,
    QuestDist = 60, FarmDist = 25, TpDelay = 0.15,
    SelectedIsland = "Dawn Island",
    EspPlayers = false, EspNPC = false, EspChest = false, EspFruit = false,
    FruitSniper = false,
}
local Conn = {}
local Flags = {}
local Running = true

local function N(msg, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Venice Hub", Text = tostring(msg),
            Duration = dur or 3, Icon = "rbxassetid://6023426926",
        })
    end)
end

local function safe(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then return nil end
    return res
end

local function char()
    local c = LP.Character
    if not c then return nil, nil, nil end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return nil, nil, nil end
    return c, hrp, hum
end

local function tpTo(cf)
    local c, hrp = char()
    if not c or not hrp then return end
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.CFrame = cf + Vector3.new(0, 3, 0)
    end)
    task.wait(S.TpDelay)
end

--=========================================================
--  DESCUBRIMIENTO DE REMOTES
--=========================================================
local RemoteFolder
for _, n in ipairs({ "Remotes", "RemoteEvents", "Remotes_", "Net" }) do
    local f = ReplicatedStorage:FindFirstChild(n)
    if f then RemoteFolder = f break end
end
if not RemoteFolder then
    for _, v in ipairs(ReplicatedStorage:GetChildren()) do
        if v:IsA("Folder") and #v:GetChildren() > 4 then RemoteFolder = v break end
    end
end

local Invokes, Events = {}, {}
if RemoteFolder then
    for _, v in ipairs(RemoteFolder:GetDescendants()) do
        if v:IsA("RemoteFunction") then table.insert(Invokes, v)
        elseif v:IsA("RemoteEvent") then table.insert(Events, v) end
    end
end

local function invoke(...)
    local args = { ... }
    for _, r in ipairs(Invokes) do
        local ok = pcall(function() r:InvokeServer(unpack(args)) end)
        if ok then return true end
    end
    return false
end

local function fire(...)
    local args = { ... }
    for _, r in ipairs(Events) do
        if pcall(function() r:FireServer(unpack(args)) end) then return true end
    end
    return false
end

--=========================================================
--  ESCANEO DE MUNDO
--=========================================================
local Containers = {}
local function refreshContainers()
    Containers = { workspace }
    for _, n in ipairs({ "NPCs", "Enemies", "Mobs", "Bosses", "SeaBeasts", "Chests", "Fruits", "Map" }) do
        local f = workspace:FindFirstChild(n)
        if f then table.insert(Containers, f) end
    end
end
refreshContainers()

local function iterModels(pred)
    local out, seen = {}, {}
    for _, root in ipairs(Containers) do
        for _, v in ipairs(root:GetChildren()) do
            if not seen[v] and (v:IsA("Model") or v:IsA("Folder")) and pred(v) then
                seen[v] = true
                table.insert(out, v)
            end
        end
    end
    return out
end

local function rootOf(obj)
    if obj:IsA("Model") then
        return obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
    end
    return obj:IsA("BasePart") and obj or nil
end

local function alive(m)
    local hum = m:FindFirstChildOfClass("Humanoid")
    return (not hum) or hum.Health > 0
end

local function isMob(m)
    if not alive(m) then return false end
    local n = m.Name:lower()
    for _, k in ipairs({ "dummy", "quest", "bandit", "pirate", "marine", "beast", "boss",
                          "kraken", "shanks", "whitebeard", "mom", "guard", "soldier" }) do
        if n:find(k) then return true end
    end
    return m:FindFirstChildOfClass("Humanoid") ~= nil
end

local function isQuestNPC(m)
    local n = m.Name:lower()
    return n:find("quest") ~= nil or n:find("dummy") ~= nil
end

local function nearest(list, maxDist)
    local _, hrp = char()
    if not hrp then return nil end
    local best, bd = nil, maxDist or math.huge
    for _, m in ipairs(list) do
        local r = rootOf(m)
        if r then
            local d = (r.Position - hrp.Position).Magnitude
            if d < bd then best, bd = m, d end
        end
    end
    return best
end

--=========================================================
--  ATAQUE
--=========================================================
local function click()
    local vu = game:GetService("VirtualUser")
    pcall(function()
        vu:CaptureController()
        vu:Button1Down(Vector2.new(0, 0), Camera.CFrame)
        task.wait(0.03)
        vu:Button1Up(Vector2.new(0, 0), Camera.CFrame)
    end)
end

local SKILLS = { Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V }
local function castSkills()
    for _, k in ipairs(SKILLS) do
        pcall(function() VIM:SendKeyEvent(true, k, false, game) end)
        pcall(function() VIM:SendKeyEvent(false, k, false, game) end)
        task.wait(0.05)
    end
end

--=========================================================
--  LOOPS
--=========================================================
task.spawn(function()
    while Running do
        task.wait(0.1)
        local c, hrp, hum = char()
        if c and hum then
            if S.AntiAFK then
                pcall(function() VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game) end)
            end
            if S.GodMode and hum.Health > 0 then hum.MaxHealth = math.huge; hum.Health = math.huge end
            if S.Noclip then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
                end
            end
        end
    end
end)

task.spawn(function()
    while Running do
        task.wait(0.35)
        if S.AutoHaki then invoke("BuyHaki", "Buso"); invoke("BuyHaki", "Ken") end
        if S.AutoSkill then castSkills() end
    end
end)

task.spawn(function()
    while Running do
        task.wait(0.2)
        if S.AutoQuest then
            local q = nearest(iterModels(isQuestNPC), S.QuestDist * 4)
            if q then
                local r = rootOf(q)
                if r then
                    tpTo(r.CFrame)
                    invoke("StartQuest", q.Name, 1)
                end
            end
        end
    end
end)

task.spawn(function()
    while Running do
        task.wait(0.15)
        if S.AutoAttack or S.KillAura then
            local m = nearest(iterModels(isMob), S.KillAura and S.AuraRange or S.FarmDist)
            if m then
                local r = rootOf(m)
                if r then
                    if S.AutoAttack then tpTo(r.CFrame) end
                    click()
                    castSkills()
                end
            end
        end
    end
end)

task.spawn(function()
    while Running do
        task.wait(0.4)
        if S.AutoChest or S.AutoCollect then
            for _, m in ipairs(iterModels(function(x)
                return x.Name:lower():find("chest") ~= nil
            end)) do
                local r = rootOf(m)
                if r then tpTo(r.CFrame) task.wait(0.1) end
            end
        end
    end
end)

task.spawn(function()
    while Running do
        task.wait(1)
        if S.AutoBoss or S.AutoSeaBeast then
            local want = function(x)
                local n = x.Name:lower()
                if S.AutoSeaBeast and n:find("kraken") then return true end
                if S.AutoBoss then
                    for _, b in ipairs({ "shanks", "whitebeard", "mom", "boss" }) do
                        if n:find(b) then return true end
                    end
                end
                return false
            end
            local t = nearest(iterModels(want), 5000)
            if t then
                local r = rootOf(t)
                if r then tpTo(r.CFrame) click() end
            end
        end
    end
end)

--=========================================================
--  ESP
--=========================================================
local Drawings = {}
local function clearEsp()
    for _, d in pairs(Drawings) do pcall(function() d:Remove() end) end
    Drawings = {}
end

local function newBox(color, text)
    if not Drawing then return end
    local box = Drawing.new("Square")
    box.Thickness = 1 box.Color = color box.Filled = false box.Visible = false
    local label = Drawing.new("Text")
    label.Size = 14 label.Center = true label.Outline = true
    label.Color = color label.Visible = false label.Text = text or ""
    return box, label
end

task.spawn(function()
    while Running do
        task.wait(0.25)
        clearEsp()
        if not Drawing then break end
        local function add(obj, color, name)
            local b, l = newBox(color, name)
            if not b then return end
            Drawings[obj] = b
            Drawings[obj.Name .. "_l"] = l
        end
        if S.EspPlayers then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then add(p.Character, Color3.fromRGB(0, 255, 140), p.Name) end
            end
        end
        if S.EspNPC then
            for _, m in ipairs(iterModels(isMob)) do add(m, Color3.fromRGB(255, 90, 90), m.Name) end
        end
        if S.EspChest then
            for _, m in ipairs(iterModels(function(x) return x.Name:lower():find("chest") ~= nil end)) do
                add(m, Color3.fromRGB(255, 210, 0), "Chest")
            end
        end
        -- render
        for key, d in pairs(Drawings) do
            local obj = (type(key) == "string" and key:find("_l")) and nil or key
            if obj and typeof(obj) == "Instance" then
                local r = rootOf(obj)
                local ok, pos, on = pcall(function()
                    if not r then return Vector2.zero, false end
                    local sp, vis = Camera:WorldToViewportPoint(r.Position)
                    return Vector2.new(sp.X, sp.Y), vis
                end)
                if ok and on and r then
                    local label = Drawings[obj.Name .. "_l"]
                    if d then
                        d.Size = Vector2.new(50, 70) d.Position = pos - Vector2.new(25, 35) d.Visible = true
                    end
                    if label then label.Position = pos - Vector2.new(0, 55) label.Visible = true end
                else
                    if d then d.Visible = false end
                    local label = Drawings[obj.Name .. "_l"]
                    if label then label.Visible = false end
                end
            end
        end
    end
end)

--=========================================================
--  FRUIT SNIPER
--=========================================================
task.spawn(function()
    while Running do
        task.wait(0.6)
        if S.FruitSniper then
            for _, m in ipairs(iterModels(function(x)
                local n = x.Name:lower()
                return n:find("fruit") ~= nil and not x:FindFirstChildOfClass("Humanoid")
            end)) do
                local r = rootOf(m)
                if r then
                    tpTo(r.CFrame)
                    task.wait(0.2)
                    pcall(function() fire("TakeFruit", m.Name) end)
                    pcall(function() invoke("StoreFruit", m.Name) end)
                end
            end
        end
    end
end)

--=========================================================
--  FLY / NOCLIP
--=========================================================
local flyBV, flyBG
local function setFly(on)
    local c, hrp = char()
    if not c or not hrp then return end
    if on then
        flyBV = Instance.new("BodyVelocity")
        flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        flyBV.Velocity = Vector3.zero
        flyBV.Parent = hrp
        flyBG = Instance.new("BodyGyro")
        flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        flyBG.P = 2000
        flyBG.Parent = hrp
        Conn.Fly = RunService.RenderStepped:Connect(function()
            local dir = Vector3.zero
            local cf = Camera.CFrame
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cf.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cf.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cf.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cf.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0, 1, 0) end
            if flyBV then flyBV.Velocity = dir * S.FlySpeed end
            if flyBG then flyBG.CFrame = cf end
        end)
    else
        if Conn.Fly then Conn.Fly:Disconnect() end
        if flyBV then flyBV:Destroy() end
        if flyBG then flyBG:Destroy() end
        flyBV, flyBG = nil, nil
    end
end

--=========================================================
--  ISLAS (Sea 3)
--=========================================================
local ISLANDS = {
    "Dawn Island", "Shanks Island", "Volcano Island", "Tall Island",
    "Leopard Island", "Ruined Marineford", "Cake Island", "Punk Hazard",
}

local function gotoIsland(name)
    for _, m in ipairs(workspace:GetDescendants()) do
        if (m:IsA("Model") or m:IsA("BasePart")) and m.Name:lower() == name:lower() then
            local r = rootOf(m)
            if r then tpTo(r.CFrame) N("TP: " .. name) return end
        end
    end
    N("No encontré: " .. name, 4)
end

--=========================================================
--  UI
--=========================================================
local Gui = Instance.new("ScreenGui")
Gui.Name = "VeniceHub"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 520, 0, 340)
Main.Position = UDim2.new(0.5, -260, 0.5, -170)
Main.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = Gui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", Main).Color = Color3.fromRGB(120, 80, 255)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 34)
Title.BackgroundColor3 = Color3.fromRGB(24, 22, 34)
Title.BorderSizePixel = 0
Title.Text = "  VENICE HUB  •  AOPG THIRD SEA"
Title.TextColor3 = Color3.fromRGB(190, 170, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Main
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 10)

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(0, 110, 1, -34)
TabBar.Position = UDim2.new(0, 0, 0, 34)
TabBar.BackgroundColor3 = Color3.fromRGB(20, 19, 26)
TabBar.BorderSizePixel = 0
TabBar.Parent = Main

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -110, 1, -34)
Content.Position = UDim2.new(0, 110, 0, 34)
Content.BackgroundTransparency = 1
Content.Parent = Main

local Pages = {}
local function makePage(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(28, 26, 36)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(200, 200, 210)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 12
    btn.Parent = TabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, -8, 1, -8)
    page.Position = UDim2.new(0, 4, 0, 4)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = Content

    local lay = Instance.new("UIListLayout")
    lay.Padding = UDim.new(0, 6)
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Parent = page

    Pages[name] = { btn = btn, page = page, count = 0 }
    btn.MouseButton1Click:Connect(function()
        for _, p in pairs(Pages) do
            p.btn.BackgroundColor3 = Color3.fromRGB(28, 26, 36)
            p.page.Visible = false
        end
        btn.BackgroundColor3 = Color3.fromRGB(60, 45, 110)
        page.Visible = true
    end)
    return page
end

local function label(page, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -10, 0, 22)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(140, 130, 190)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = page
end

local function toggle(page, text, default, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -10, 0, 28)
    b.BackgroundColor3 = Color3.fromRGB(30, 28, 40)
    b.Text = "  " .. text
    b.TextColor3 = Color3.fromRGB(210, 210, 220)
    b.Font = Enum.Font.Gotham
    b.TextSize = 12
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Parent = page
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    local state = default or false
    local function paint()
        b.BackgroundColor3 = state and Color3.fromRGB(80, 55, 160) or Color3.fromRGB(30, 28, 40)
    end
    paint()
    b.MouseButton1Click:Connect(function()
        state = not state
        paint()
        pcall(cb, state)
    end)
    return b
end

local function button(page, text, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -10, 0, 28)
    b.BackgroundColor3 = Color3.fromRGB(40, 34, 58)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(225, 225, 235)
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 12
    b.Parent = page
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function() pcall(cb) end)
end

local function slider(page, text, min, max, default, cb)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -10, 0, 40)
    holder.BackgroundColor3 = Color3.fromRGB(26, 24, 34)
    holder.Parent = page
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 6)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -10, 0, 18)
    l.Position = UDim2.new(0, 8, 0, 2)
    l.BackgroundTransparency = 1
    l.Text = text .. ": " .. default
    l.TextColor3 = Color3.fromRGB(200, 200, 215)
    l.Font = Enum.Font.Gotham
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = holder
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -20, 0, 6)
    bar.Position = UDim2.new(0, 10, 0, 26)
    bar.BackgroundColor3 = Color3.fromRGB(50, 45, 70)
    bar.Parent = holder
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(130, 90, 255)
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    local dragging = false
    local function set(x)
        local a = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local v = math.floor(min + (max - min) * a)
        fill.Size = UDim2.new(a, 0, 1, 0)
        l.Text = text .. ": " .. v
        pcall(cb, v)
    end
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true set(i.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            set(i.Position.X)
        end
    end)
end

-- arrastre
local drag, dStart, sStart = false, nil, nil
Title.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        drag = true dStart = i.Position sStart = Main.Position
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = false end
end)
UserInputService.InputChanged:Connect(function(i)
    if drag and dStart then
        local d = i.Position - dStart
        Main.Position = UDim2.new(sStart.X.Scale, sStart.X.Offset + d.X, sStart.Y.Scale, sStart.Y.Offset + d.Y)
    end
end)

--=========================================================
--  PESTAÑAS
--=========================================================
local pPlayer = makePage("Jugador")
local pTp     = makePage("Teleport")
local pFarm   = makePage("Farm")
local pEsp    = makePage("ESP")
local pMisc   = makePage("Misc")

label(pPlayer, "MOVIMIENTO")
slider(pPlayer, "WalkSpeed", 16, 300, 32, function(v)
    S.WalkSpeed = v
    local _, _, hum = char() if hum then hum.WalkSpeed = v end
end)
slider(pPlayer, "JumpPower", 50, 400, 50, function(v)
    S.JumpPower = v
    local _, _, hum = char() if hum then hum.UseJumpPower = true hum.JumpPower = v end
end)
toggle(pPlayer, "Infinite Jump", false, function(v)
    S.InfJump = v
    if v then
        Conn.Jump = UserInputService.JumpRequest:Connect(function()
            local _, _, hum = char() if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    else
        if Conn.Jump then Conn.Jump:Disconnect() end
    end
end)
toggle(pPlayer, "Noclip", false, function(v) S.Noclip = v end)
toggle(pPlayer, "Fly (WASD)", false, function(v) S.Fly = v setFly(v) end)
slider(pPlayer, "FlySpeed", 20, 400, 60, function(v) S.FlySpeed = v end)
toggle(pPlayer, "GodMode", false, function(v)
    S.GodMode = v
    local _, _, hum = char()
    if hum and not v then hum.MaxHealth = 100 end
end)
toggle(pPlayer, "Anti AFK", true, function(v) S.AntiAFK = v end)

label(pTp, "ISLAS — SEA 3")
for _, isl in ipairs(ISLANDS) do
    button(pTp, "→ " .. isl, function() gotoIsland(isl) end)
end
label(pTp, "UTILIDADES")
button(pTp, "TP a jugador aleatorio", function()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then table.insert(list, p) end
    end
    if #list > 0 then
        local t = list[math.random(1, #list)]
        tpTo(t.Character.HumanoidRootPart.CFrame)
        N("TP a " .. t.Name)
    end
end)
button(pTp, "Guardar waypoint", function()
    local _, hrp = char() if not hrp then return end
    getgenv().VeniceHub.Waypoint = hrp.CFrame
    N("Waypoint guardado")
end)
button(pTp, "Ir a waypoint", function()
    local wp = getgenv().VeniceHub.Waypoint
    if wp then tpTo(wp) else N("Sin waypoint") end
end)

label(pFarm, "AUTOMATIZACIÓN")
toggle(pFarm, "Auto Quest", false, function(v) S.AutoQuest = v end)
toggle(pFarm, "Auto Attack", false, function(v) S.AutoAttack = v end)
toggle(pFarm, "Auto Chest", false, function(v) S.AutoChest = v end)
toggle(pFarm, "Auto Boss (Shanks/BigMom/WB)", false, function(v) S.AutoBoss = v end)
toggle(pFarm, "Auto Sea Beast (Kraken)", false, function(v) S.AutoSeaBeast = v end)
toggle(pFarm, "Auto Haki (Buso/Ken)", false, function(v) S.AutoHaki = v end)
toggle(pFarm, "Auto Skills (ZXCV)", false, function(v) S.AutoSkill = v end)
toggle(pFarm, "Kill Aura", false, function(v) S.KillAura = v end)
slider(pFarm, "Aura Range", 10, 120, 30, function(v) S.AuraRange = v end)
slider(pFarm, "Farm Distance", 5, 80, 25, function(v) S.FarmDist = v end)
label(pFarm, "FRUTAS")
toggle(pFarm, "Fruit Sniper", false, function(v) S.FruitSniper = v end)

label(pEsp, "VISUAL")
toggle(pEsp, "ESP Jugadores", false, function(v) S.EspPlayers = v end)
toggle(pEsp, "ESP NPC/Mobs", false, function(v) S.EspNPC = v end)
toggle(pEsp, "ESP Cofres", false, function(v) S.EspChest = v end)
toggle(pEsp, "Fullbright", false, function(v)
    S.Fullbright = v
    if v then
        Conn.Bright = RunService.RenderStepped:Connect(function()
            Camera.FieldOfView = 70
            game:GetService("Lighting").Ambient = Color3.new(1, 1, 1)
            game:GetService("Lighting").Brightness = 3
        end)
    elseif Conn.Bright then Conn.Bright:Disconnect() end
end)

label(pMisc, "SERVIDOR")
button(pMisc, "Server Hop", function()
    local req = safe(function()
        return HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
    end)
    if req and req.data then
        for _, srv in ipairs(req.data) do
            if srv.playing < srv.maxPlayers and srv.id ~= game.JobId then
                game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, srv.id, LP)
                return
            end
        end
    end
    N("No encontré servidor")
end)
button(pMisc, "Rejoin", function()
    game:GetService("TeleportService"):Teleport(game.PlaceId, LP)
end)
label(pMisc, "CONFIG")
button(pMisc, "Guardar config", function()
    if writefile then
        writefile("VeniceHub_AOPG.json", HttpService:JSONEncode(S))
        N("Config guardada")
    end
end)
button(pMisc, "Cargar config", function()
    if readfile and isfile and isfile("VeniceHub_AOPG.json") then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile("VeniceHub_AOPG.json")) end)
        if ok and data then
            for k, v in pairs(data) do S[k] = v end
            N("Config cargada (re-ejecuta para aplicar toggles)")
        end
    end
end)
button(pMisc, "Destruir GUI", function()
    Running = false
    for _, c in pairs(Conn) do pcall(function() c:Disconnect() end) end
    clearEsp()
    Gui:Destroy()
    getgenv().VeniceHubLoaded = false
end)

Pages["Jugador"].btn.BackgroundColor3 = Color3.fromRGB(60, 45, 110)
Pages["Jugador"].page.Visible = true

UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        Main.Visible = not Main.Visible
    end
end)

getgenv().VeniceHub = {
    Unload = function()
        Running = false
        pcall(function() Gui:Destroy() end)
        getgenv().VeniceHubLoaded = false
    end,
    State = S,
    Invoke = invoke,
    Fire = fire,
}

N("Venice Hub cargado • RightShift oculta", 5)
