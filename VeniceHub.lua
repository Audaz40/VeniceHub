--==============================================================================
--  THIRD SEA HUB — AOPG NPC / Boss / Farm Script
--  Data mined from ThirdSea.xml (real place file): islands, 8 quest givers,
--  6 utility NPCs, boss markers, mob WorkRig rules, MAIN dispatcher remote.
--  For Xeno / Delta / Wave executors.  No external loadstring / HttpGet.
--==============================================================================

if not game:IsLoaded() then game.Loaded:Wait() end

--========================= CLEANUP OLD INSTANCE =============================
pcall(function()
	if getgenv and getgenv().ThirdSeaHubRoot and typeof(getgenv().ThirdSeaHubRoot) == "Instance" then
		getgenv().ThirdSeaHubRoot:Destroy()
	end
end)

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService       = game:GetService("GuiService")
local CollectionService= game:GetService("CollectionService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
repeat task.wait(0.1) until LocalPlayer.Character or LocalPlayer:FindFirstChild("PlayerGui")

--========================= GAME REFERENCES ==================================
local function ref(o)
	pcall(function()
		if cloneref then o = cloneref(o) end
	end)
	return o
end

local RS            = ref(ReplicatedStorage)
local ALLREMBINDS   = RS:WaitForChild("ALLREMBINDS", 30)
local MainRemoteEvent  = ALLREMBINDS and ALLREMBINDS:WaitForChild("MainRemoteEvent", 10)
local MAIN_KEY      = "EMMFOSS__!ZCNSJNXCSDWQSANBX"

local World         = workspace:WaitForChild("World", 30)
local NPCS_FOLDER   = World:WaitForChild("NPCS", 10)
local CHESTS_FOLDER = World:WaitForChild("Chests", 10)
local BLOXFRUITS    = World:WaitForChild("BloxFruits", 10)
local FRUIT_PLACES  = BLOXFRUITS:WaitForChild("FruitPlaces", 10)
local CHARACTERS    = workspace:WaitForChild("Characters", 10)

local function playerStats()
	return LocalPlayer:FindFirstChild("PlayerStats")
end
local function stat(name)
	local ps = playerStats()
	return ps and ps:FindFirstChild(name)
end

--========================= REAL GAME DATA (from XML) ========================
-- Island pivots (workspace.Map children / IslandModel pivots)
local ISLANDS = {
	{name = "Turtle",           pos = Vector3.new(-10075, 482, 33552)},
	{name = "Port",             pos = Vector3.new(-3407,  177, 42155)},
	{name = "Boat Castle",      pos = Vector3.new(-6573,  778, 38869)},
	{name = "Great Tree",       pos = Vector3.new(-6518, 1057, 26866)},
	{name = "Waterfall",        pos = Vector3.new(-1089,  370, 36160)},
	{name = "Haunted Castle",   pos = Vector3.new(-13863,1865, 44956)},
	{name = "Temple of Time",   pos = Vector3.new(-1236,49328,  2291)},
	{name = "Temple (bajo)",    pos = Vector3.new(-1303,  401, 30095)},
	{name = "Mini Sky",         pos = Vector3.new(-457,   333, 31969)},
	{name = "Fishmen",          pos = Vector3.new(-1554,   61, 32191)},
	{name = "Entrance",         pos = Vector3.new(-9946,  355, 32748)},
	{name = "Raid Map",         pos = Vector3.new(27316,14896, 37656)},
	{name = "Spawn",            pos = Vector3.new(-10520, 333, 34069)},
}

-- Quest Giver models (8 in XML — two share the Turtle south pivot)
local QUEST_GIVERS = {
	{name = "QG Turtle 1",   pos = Vector3.new(-8541,  360, 32752)},
	{name = "QG Turtle 2",   pos = Vector3.new(-11221, 361, 33919)},
	{name = "QG Turtle 3",   pos = Vector3.new(-10628, 421, 31629)},
	{name = "QG Turtle 4",   pos = Vector3.new(-10628, 421, 31629)},
	{name = "QG Port",       pos = Vector3.new(-2975,   65, 41162)},
	{name = "QG Great Tree", pos = Vector3.new(-7255,   56, 27084)},
	{name = "QG Waterfall 1",pos = Vector3.new(-491,   107, 35005)},
	{name = "QG Waterfall 2",pos = Vector3.new(-824,   650, 36834)},
}

-- Utility NPCs (workspace.World.NPCS — the 6 the game's proximity loop uses)
local UTILITY_NPCS = {
	{name = "Instinct Teacher",   pos = Vector3.new(-10583, 336, 34089)},
	{name = "Ability Teacher",    pos = Vector3.new(-10458, 336, 33964)},
	{name = "Aura Editor",        pos = Vector3.new(-10419, 336, 34025)},
	{name = "Colors SpecialList", pos = Vector3.new(-10622, 336, 34025)},
	{name = "Blox Fruit Dealer",  pos = Vector3.new(-10485, 337, 34090)},
	{name = "Blox Fruit Gacha",   pos = Vector3.new(-10459, 337, 34087)},
}

-- Boss / raid markers
local BOSS_MARKERS = {
	{name = "Boss Spawn (Turtle)",  pos = Vector3.new(-10236, 608, 34982)},
	{name = "Boss Room (Waterfall)",pos = Vector3.new(-995,   271, 36169)},
	{name = "Raid Summon A",        pos = Vector3.new(-6175,  318, 38649)},
	{name = "Raid Summon B",        pos = Vector3.new(-6237,  318, 38674)},
	{name = "Raid Map Gate",        pos = Vector3.new(27316,14896, 37656)},
	{name = "Haunted Castle",       pos = Vector3.new(-13863,1865, 44956)},
	{name = "Temple Door",          pos = Vector3.new(-1266, 49341, 2304)},
	{name = "Cursed Pedestals",     pos = Vector3.new(-10236, 608, 34982)},
}

--========================= CONFIG / STATE ===================================
local Config = {
	autoFarm    = false,
	farmMode    = "remote",   -- "remote" | "m1"
	bossOnly    = false,
	bossLevel   = 500,
	nameFilter  = "",
	tpToTarget  = true,
	useSkills   = false,
	autoHaki    = false,
	attackDelay = 0.15,
	kills       = 0,
	noclip      = false,
	walkSpeed   = 16,

	espmobs     = false,
	espbosses   = false,
	esqqg       = false,
	espnpc      = false,
	espchests   = false,
	espfruit    = false,

	fruitSniper = false,
	chestFarm   = false,
	autoOption  = false,
}

local CurrentTarget = nil
local Running = true

--========================= HELPERS ==========================================
local function notify(text, color)
	pcall(function()
		local gui = LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("ThirdSeaToasts")
		if not gui then return end
		local holder = gui:FindFirstChild("Holder")
		if not holder then return end
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 0, 34)
		lbl.BackgroundColor3 = Color3.fromRGB(21, 26, 36)
		lbl.BackgroundTransparency = 0.1
		lbl.Text = "  " .. tostring(text)
		lbl.TextColor3 = color or Color3.fromRGB(34, 211, 238)
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.GothamMedium
		lbl.TextSize = 14
		lbl.Parent = holder
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(56, 72, 96)
		stroke.Parent = lbl
		task.spawn(function()
			task.wait(3)
			local t = TweenService:Create(lbl, TweenInfo.new(0.4), {TextTransparency = 1, BackgroundTransparency = 1})
			t:Play(); t.Completed:Wait()
			lbl:Destroy()
		end)
	end)
end

local function getChar()
	return LocalPlayer.Character
end
local function getHRP()
	local c = getChar()
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
	local c = getChar()
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function teleport(pos, offset)
	local hrp = getHRP()
	if not hrp then return end
	offset = offset or Vector3.new(0, 4, 0)
	local cf = CFrame.new(pos + offset)
	pcall(function()
		local hum = getHum()
		if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end
	end)
	hrp.Velocity = Vector3.zero
	hrp.CFrame = cf
	task.wait(0.05)
	hrp.CFrame = cf -- second set beats physics snapback
end

local function fireMain(fnName, args)
	if not MainRemoteEvent then return end
	pcall(function()
		MainRemoteEvent:FireServer(MAIN_KEY, fnName, args)
	end)
end

-- Lethal damage honoring the game's real formula:
-- TakenDamge = Damge + (Damge/8.5) * (BodyPowerStat - 1)   [MAIN.Main_DamgeR___]
local function lethalDamage(hum)
	local s = stat("BodyPowerStat")
	local power = (s and s.Value) or 500
	local mult = 1 + (power - 1) / 8.5
	local hp = math.max(hum.Health, hum.MaxHealth, 1)
	return math.ceil(hp / mult) + math.random(2, 12)
end

--========================= INPUT SIMULATION =================================
local function mouseClickAt(x, y)
	pcall(function()
		VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
		task.wait(0.05)
		VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
	end)
end

local function clickGuiButton(btn)
	if not btn then return end
	-- fire local connection directly when executor supports it
	pcall(function()
		if type(firesignal) == "function" then
			firesignal(btn.MouseButton1Click)
		end
	end)
	pcall(function()
		local inset = GuiService:GetGuiInset()
		local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
		mouseClickAt(pos.X + inset.X, pos.Y + inset.Y)
	end)
end

local function pressM1()
	-- click at screen center so CoreGui/topbar can't absorb the input
	pcall(function()
		local vp = workspace.CurrentCamera.ViewportSize
		local x, y = math.floor(vp.X / 2), math.floor(vp.Y / 2)
		VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
		task.wait(0.05)
		VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
	end)
	pcall(function()
		local VU = game:GetService("VirtualUser")
		VU:Button1Down()
		task.wait(0.03)
		VU:Button1Up()
	end)
end

local function pressKey(key)
	pcall(function()
		VirtualInputManager:SendKeyEvent(true, key, false, game)
		task.wait(0.12)
		VirtualInputManager:SendKeyEvent(false, key, false, game)
	end)
end

--========================= MOB SCAN =========================================
local function isPlayerChar(m)
	return Players:GetPlayerFromCharacter(m) ~= nil
end

local function mobLevel(m)
	local cs = m:FindFirstChild("CharcterStats")
	local lv = cs and cs:FindFirstChild("Level")
	if lv then return lv.Value end
	local a = m.Name:match("%[Lv%.(%d+)%]")
	return tonumber(a) or 0
end

local function collectTargets()
	local out = {}
	if not CHARACTERS then return out end
	for _, m in ipairs(CHARACTERS:GetChildren()) do
		if m:IsA("Model") and m ~= getChar() and not isPlayerChar(m) then
			local hum = m:FindFirstChildOfClass("Humanoid")
			local hrp = m:FindFirstChild("HumanoidRootPart")
			local cs  = m:FindFirstChild("CharcterStats")
			if hum and hrp and cs and hum.Health > 0 then
				local lvl = mobLevel(m)
				out[#out + 1] = {model = m, hum = hum, hrp = hrp, level = lvl, name = m.Name}
			end
		end
	end
	return out
end

local function targetPasses(t)
	if not t.hum or t.hum.Health <= 0 then return false end
	if Config.nameFilter ~= "" then
		return t.name:lower():find(Config.nameFilter:lower(), 1, true) ~= nil
	end
	if Config.bossOnly then
		return t.level >= Config.bossLevel
	end
	return true
end

local function selectTarget()
	local myHRP = getHRP()
	if not myHRP then return nil end
	local best, bestScore = nil, math.huge
	for _, t in ipairs(collectTargets()) do
		if targetPasses(t) then
			local d = (t.hrp.Position - myHRP.Position).Magnitude
			local score
			if Config.bossOnly then
				-- highest level first, ties broken by distance
				score = -t.level * 1000 + d
			else
				score = d
			end
			if score < bestScore then best, bestScore = t, score end
		end
	end
	return best
end

--========================= FARM ACTIONS =====================================
local function farmAttack(t)
	local mode = Config.farmMode
	if mode == "remote" then
		-- Same remote the legit client fires for every M1/skill hit.
		local dmg = lethalDamage(t.hum)
		fireMain("Main_DamgeR___", {
			t.model,
			{Damge = dmg, FromPlayer = LocalPlayer, Using = "Combat"},
		})
	else
		-- Legit-looking M1: stand in front + synthesize clicks
		local myHRP = getHRP()
		if myHRP and t.hrp then
			local to = (myHRP.Position - t.hrp.Position)
			local off = (to.Magnitude > 0.1 and to.Unit or Vector3.new(0, 0, -1)) * 4.5
			myHRP.CFrame = CFrame.lookAt(t.hrp.Position + off + Vector3.new(0, 2, 0), t.hrp.Position)
		end
		pressM1()
	end
end

local function useCombatSkills()
	local act = stat("ActiveTool")
	if not act or act.Value ~= "Combat" then
		-- try equip Combat
		pcall(function()
			local tool = LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Combat")
				or getChar():FindFirstChild("Combat")
			if tool and getHum() then getHum():EquipTool(tool) end
		end)
		task.wait(0.2)
	end
	local canSk = stat("ForCombatSystem")
	if canSk then
		local cs = canSk:FindFirstChild("CanUseSkills")
		if cs and not cs.Value then return end
	end
	pressKey(Enum.KeyCode.Z)
	task.wait(Config.attackDelay)
	pressKey(Enum.KeyCode.X)
end

local function toggleHaki(forceOn)
	local on = false
	pcall(function()
		local haki = LocalPlayer:FindFirstChild("Haki")
		local v = haki and haki:FindFirstChild("HakiOn")
		on = v and v.Value or false
	end)
	local want = forceOn ~= nil and forceOn or not on
	pcall(function()
		local remote = Lighting:FindFirstChild(want and "HakiOn" or "HakiOff")
		if remote then remote:FireServer() end
	end)
end

--========================= FARM LOOP ========================================
task.spawn(function()
	local lastSkill = 0
	local lastHaki = 0
	local lastTargetModel = nil
	local lastTargetHum = nil
	while Running do
		task.wait(Config.autoFarm and Config.attackDelay or 0.25)
		-- kill detection: watched target died or got destroyed (server damage is async)
		if lastTargetModel then
			local gone = lastTargetModel.Parent == nil
			local dead = (lastTargetHum and lastTargetHum.Parent and lastTargetHum.Health <= 0)
			if gone or dead then
				Config.kills = Config.kills + 1
				lastTargetModel = nil
				lastTargetHum = nil
			end
		end
		if Config.autoFarm then
			local t = selectTarget()
			CurrentTarget = t
			if t and t.model.Parent then
				lastTargetModel = t.model
				lastTargetHum = t.hum
				-- move to target
				if Config.tpToTarget and getHRP() then
					local to = (getHRP().Position - t.hrp.Position)
					local dir = (to.Magnitude > 0.1 and to.Unit or Vector3.new(0, 0, -1))
					getHRP().CFrame = CFrame.lookAt(t.hrp.Position + dir * 5 + Vector3.new(0, 2, 0), t.hrp.Position)
				end
				farmAttack(t)
				if Config.useSkills and (tick() - lastSkill) > 2.4 then
					lastSkill = tick()
					useCombatSkills()
				end
				if Config.autoHaki and (tick() - lastHaki) > 4 then
					lastHaki = tick()
					toggleHaki(true)
				end
			else
				CurrentTarget = nil
			end
		else
			CurrentTarget = nil
			lastTargetModel = nil
			lastTargetHum = nil
		end
	end
end)

--========================= ESP MANAGER ======================================
local ESP_FOLDER_NAME = "ThirdSeaESP"
local espRegistry = {} -- [category] = { [inst] = {hl, bb} }

local function espFolder()
	local f = workspace:FindFirstChild(ESP_FOLDER_NAME)
	if not f then
		f = Instance.new("Folder")
		f.Name = ESP_FOLDER_NAME
		f.Parent = workspace
	end
	return f
end

local function clearCategory(cat)
	local reg = espRegistry[cat]
	if not reg then return end
	for _, pack in pairs(reg) do
		pcall(function() pack.hl:Destroy() end)
		pcall(function() pack.bb:Destroy() end)
	end
	espRegistry[cat] = {}
end

local function ensureTag(cat, inst, text, color, lvl)
	espRegistry[cat] = espRegistry[cat] or {}
	local reg = espRegistry[cat]
	local pack = reg[inst]
	if not pack or not pack.hl.Parent then
		local hl = Instance.new("Highlight")
		hl.FillColor = color
		hl.FillTransparency = 0.65
		hl.OutlineColor = color
		hl.OutlineTransparency = 0.15
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = inst

		local att = inst:FindFirstChild("HumanoidRootPart") or inst:FindFirstChild("Head")
			or (inst:IsA("BasePart") and inst) or inst.PrimaryPart
		local bb = Instance.new("BillboardGui")
		bb.Name = "TS_ESP"
		bb.Size = UDim2.fromOffset(190, 46)
		bb.StudsOffset = Vector3.new(0, 3, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 5000
		local tl = Instance.new("TextLabel")
		tl.Name = "Main"
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Font = Enum.Font.GothamBold
		tl.TextScaled = true
		tl.RichText = true
		tl.TextColor3 = color
		tl.TextStrokeTransparency = 0.25
		tl.Text = text
		tl.Parent = bb
		bb.Parent = att or inst
		pack = {hl = hl, bb = bb, tl = tl}
		reg[inst] = pack
	else
		if pack.tl then pack.tl.Text = text end
	end
	if lvl ~= nil and pack.hl then
		pack.hl.FillTransparency = lvl
	end
	return pack
end

local function pruneCategory(cat, validSet)
	local reg = espRegistry[cat]
	if not reg then return end
	for inst, pack in pairs(reg) do
		if not validSet[inst] then
			pcall(function() pack.hl:Destroy() end)
			pcall(function() pack.bb:Destroy() end)
			reg[inst] = nil
		end
	end
end

local QG_MODELS = nil
local function findQuestGiverModels()
	local out = {}
	pcall(function()
		for _, islandName in ipairs({"Turtle", "Port", "Great Tree", "Waterfall", "Haunted Castle", "Boat Castle"}) do
			local isl = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild(islandName)
			if isl then
				for _, d in ipairs(isl:GetDescendants()) do
					if d:IsA("Model") and d.Name == "Quest Giver" then
						out[d] = true
					end
				end
			end
		end
	end)
	return out
end

local function fruitSpotPositions()
	local out = {}
	pcall(function()
		for _, v in ipairs(FRUIT_PLACES:GetChildren()) do
			if v:IsA("ObjectValue") then
				local pos = v:GetAttribute("POS")
				if typeof(pos) == "Vector3" then out[#out + 1] = pos end
			end
		end
	end)
	return out
end

local function spawnedFruits()
	local out = {}
	pcall(function()
		for _, v in ipairs(BLOXFRUITS:GetChildren()) do
			if v:IsA("Tool") then
				local tagged = false
				pcall(function() tagged = CollectionService:HasTag(v, "FruitT") end)
				if tagged or v.Name:match("Fruit$") then out[v] = true end
			end
		end
	end)
	return out
end

local COLORS = {
	mob    = Color3.fromRGB(226, 232, 240),
	boss   = Color3.fromRGB(248, 113, 113),
	qg     = Color3.fromRGB(74, 222, 128),
	npc    = Color3.fromRGB(34, 211, 238),
	chest  = Color3.fromRGB(250, 204, 21),
	fruit  = Color3.fromRGB(217, 70, 239),
}

local function espRefresh()
	-- mobs + bosses
	if Config.espmobs or Config.espbosses then
		local valid = {}
		for _, t in ipairs(collectTargets()) do
			local isBoss = t.level >= Config.bossLevel
			if (Config.espbosses and isBoss) or (Config.espmobs and not isBoss) then
				valid[t.model] = true
				local pct = math.floor((t.hum.Health / math.max(t.hum.MaxHealth, 1)) * 100)
				local label
				if isBoss then
					label = string.format("<b>[BOSS]</b> %s [Lv.%d]\n%d HP (%d%%)", t.name, t.level, math.floor(t.hum.Health), pct)
				else
					label = string.format("%s [Lv.%d] — %d%%", t.name, t.level, pct)
				end
				local cat = isBoss and "bosses" or "mobs"
				ensureTag(cat, t.model, label, isBoss and COLORS.boss or COLORS.mob)
			end
		end
		if Config.espmobs then pruneCategory("mobs", valid) else clearCategory("mobs") end
		if Config.espbosses then pruneCategory("bosses", valid) else clearCategory("bosses") end
	else
		clearCategory("mobs"); clearCategory("bosses")
	end

	-- quest givers
	if Config.esqqg then
		local valid = {}
		QG_MODELS = findQuestGiverModels()
		for m in pairs(QG_MODELS) do
			if m.Parent then
				valid[m] = true
				ensureTag("qg", m, "Quest Giver", COLORS.qg)
			end
		end
		pruneCategory("qg", valid)
	else
		clearCategory("qg")
	end

	-- utility npcs
	if Config.espnpc then
		local valid = {}
		for _, npc in ipairs(NPCS_FOLDER:GetChildren()) do
			if npc:IsA("Model") then
				valid[npc] = true
				ensureTag("npc", npc, npc.Name, COLORS.npc)
			end
		end
		pruneCategory("npc", valid)
	else
		clearCategory("npc")
	end

	-- chests
	if Config.espchests then
		local valid = {}
		for _, ch in ipairs(CHESTS_FOLDER:GetChildren()) do
			if ch:IsA("BasePart") and ch.Transparency < 1 then
				valid[ch] = true
				ensureTag("chest", ch, ch.Name, COLORS.chest)
			end
		end
		pruneCategory("chest", valid)
	else
		clearCategory("chest")
	end

	-- fruit spots + spawned fruits
	if Config.espfruit then
		local valid = {}
		for _, pos in ipairs(fruitSpotPositions()) do
			local key = "spot:" .. tostring(math.floor(pos.X)) .. ":" .. tostring(math.floor(pos.Z))
			-- marker part (local-only, invisible to server)
			local marker = espFolder():FindFirstChild(key)
			if not marker then
				marker = Instance.new("Part")
				marker.Name = key
				marker.Anchored = true
				marker.CanCollide = false
				marker.Transparency = 1
				marker.Size = Vector3.new(1, 1, 1)
				marker.CFrame = CFrame.new(pos)
				marker.Parent = espFolder()
			end
			valid[marker] = true
			ensureTag("fruit", marker, "Fruit Spot", COLORS.fruit, 0.85)
		end
		for m in pairs(spawnedFruits()) do
			if m.Parent then
				valid[m] = true
				ensureTag("fruit", m, m.Name .. " (spawned!)", COLORS.fruit, 0.1)
			end
		end
		pruneCategory("fruit", valid)
	else
		clearCategory("fruit")
	end
end

task.spawn(function()
	while Running do
		local anyEsp = Config.espmobs or Config.espbosses or Config.esqqg or Config.espnpc
			or Config.espchests or Config.espfruit
		if anyEsp then
			pcall(espRefresh)
		end
		task.wait(1.0)
	end
end)

--========================= LOOT: FRUIT SNIPER ===============================
task.spawn(function()
	while Running do
		task.wait(0.6)
		if Config.fruitSniper then
			for m in pairs(spawnedFruits()) do
				if m.Parent then
					pcall(function()
						local p = m:GetPivot().Position
						teleport(p, Vector3.new(0, 2, 0))
					end)
					notify("Fruta detectada: " .. m.Name, COLORS.fruit)
					task.wait(1.2)
					break
				end
			end
		end
	end
end)

--========================= LOOT: CHEST FARM =================================
task.spawn(function()
	while Running do
		task.wait(1.2)
		if Config.chestFarm then
			for _, ch in ipairs(CHESTS_FOLDER:GetChildren()) do
				if not Config.chestFarm then break end
				if ch:IsA("BasePart") then
					local enabled = ch:GetAttribute("TouchEnable")
					if enabled ~= false and ch.Transparency < 1 then
						teleport(ch.Position, Vector3.new(0, 1, 0))
						task.wait(0.5)
					end
				end
			end
		end
	end
end)

--========================= NPC INTERACTION ==================================
-- Real flow: stand within 7 studs of one of the 6 NPCs -> the game's own
-- PReRender proximity loop sets ClickToINtractTOOO -> a left click opens the
-- dialogue (TalKingTo) -> Option buttons advance CurrcutDialoug.
local function talkToNPC(name)
	local npc = NPCS_FOLDER:FindFirstChild(name)
	local pos
	if npc then
		pcall(function() pos = npc:GetPivot().Position end)
	end
	if not pos then
		for _, e in ipairs(UTILITY_NPCS) do
			if e.name == name then
				pos = e.pos
				break
			end
		end
	end
	if not pos then
		notify("NPC no encontrado: " .. name, COLORS.boss)
		return
	end
	-- stand ~4 studs away (inside the 7-stud interaction range)
	local hrp = getHRP()
	local dir = hrp and (hrp.Position - pos) or Vector3.new(3, 0, 3)
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 1 then dir = Vector3.new(3, 0, 3) end
	teleport(pos, dir.Unit * 4 + Vector3.new(0, 2, 0))
	task.wait(0.45) -- let PReRenderOne register proximity
	pressM1()
	task.wait(0.35)
	notify("Hablando con " .. name .. " — activá 'Auto Opción 1' para avanzar", COLORS.qg)
end

-- Advance the dialogue GUI by clicking the first option that has a MainNum.
local function autoAdvanceDialogue()
	pcall(function()
		local pg = LocalPlayer:FindFirstChild("PlayerGui")
		local main = pg and pg:FindFirstChild("Main")
		local dlg = main and main:FindFirstChild("Dialogue")
		if not dlg then return end
		for _, optName in ipairs({"Option1", "Option2", "Option3"}) do
			local opt = dlg:FindFirstChild(optName)
			if opt and opt:IsA("GuiButton") then
				local vis = opt.Size == UDim2.fromScale(0.35, 0.4)
				local num = opt:GetAttribute("MainNum")
				if vis and num and num ~= false then
					clickGuiButton(opt)
					return
				end
			end
		end
	end)
end

task.spawn(function()
	while Running do
		task.wait(0.7)
		if Config.autoOption then autoAdvanceDialogue() end
	end
end)

-- Interact with any runtime ProximityPrompt / ClickDetector near the player
local function interactNearby()
	local hrp = getHRP()
	if not hrp then return end
	local found = false
	-- ProximityPrompt: official client hold API
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			local parent = d.Parent
			local pp = parent and parent:IsA("BasePart") and parent or nil
			local pos = pp and pp.Position
			if not pos and parent and parent:IsA("Model") then
				pos = parent:GetPivot().Position
			end
			if pos and (pos - hrp.Position).Magnitude < 40 then
				teleport(pos, Vector3.new(0, 3, 0))
				task.wait(0.2)
				pcall(function()
					d:InputHoldBegin()
					task.wait((d.HoldDuration or 0.2) + 0.15)
					d:InputHoldEnd()
				end)
				notify("Prompt usado: " .. (parent and parent.Name or "?"), COLORS.npc)
				found = true
				break
			end
		end
	end
	if not found then
		-- ClickDetector: aim camera + synthetic click
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("ClickDetector") then
				local parent = d.Parent
				local pp = parent and parent:IsA("BasePart") and parent or nil
				local pos = pp and pp.Position
				if pos and (pos - hrp.Position).Magnitude < 40 then
					teleport(pos, Vector3.new(0, 3, 0))
					task.wait(0.2)
					pcall(function()
						local cam = workspace.CurrentCamera
						cam.CFrame = CFrame.lookAt(pos + Vector3.new(0, 6, 8), pos)
						task.wait(0.1)
						local sp, on = cam:WorldToViewportPoint(pos)
						if on then mouseClickAt(sp.X, sp.Y) end
					end)
					notify("Click en: " .. parent.Name, COLORS.npc)
					found = true
					break
				end
			end
		end
	end
	if not found then notify("Nada interactuable cerca", COLORS.boss) end
end

--========================= MISC: NOCLIP / SPEED =============================
RunService.Stepped:Connect(function()
	if Config.noclip then
		local c = getChar()
		if c then
			for _, p in ipairs(c:GetDescendants()) do
				if p:IsA("BasePart") then p.CanCollide = false end
			end
		end
	end
end)

task.spawn(function()
	while Running do
		local h = getHum()
		if h and h.WalkSpeed ~= Config.walkSpeed then
			h.WalkSpeed = Config.walkSpeed
		end
		task.wait(0.5)
	end
end)

--========================= UI LIBRARY =======================================
local C = {
	bg      = Color3.fromRGB(13, 16, 23),
	panel    = Color3.fromRGB(20, 25, 35),
	card     = Color3.fromRGB(27, 33, 46),
	stroke   = Color3.fromRGB(51, 64, 88),
	accent   = Color3.fromRGB(34, 211, 238),
	accent2  = Color3.fromRGB(59, 130, 246),
	text     = Color3.fromRGB(226, 232, 240),
	sub      = Color3.fromRGB(148, 163, 184),
	good     = Color3.fromRGB(74, 222, 128),
	bad      = Color3.fromRGB(248, 113, 113),
	orange   = Color3.fromRGB(251, 146, 60),
}

local function New(cls, props, parent)
	local inst = Instance.new(cls)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then inst[k] = v end
	end
	if parent then inst.Parent = parent end
	return inst
end

-- root GUI
local pg = LocalPlayer:WaitForChild("PlayerGui")
local toastGui = New("ScreenGui", {
	Name = "ThirdSeaToasts", ResetOnSpawn = false, IgnoreGuiInset = true,
}, pg)
New("Frame", {
	Name = "Holder", Size = UDim2.fromOffset(330, 400),
	Position = UDim2.new(1, -350, 1, -430),
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0),
}, toastGui)
New("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder},
	toastGui.Holder)

local root = New("ScreenGui", {
	Name = "ThirdSeaHub", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, pg)
if getgenv then getgenv().ThirdSeaHubRoot = root end

local main = New("Frame", {
	Name = "Main", Size = UDim2.fromOffset(660, 440),
	Position = UDim2.new(0.5, -330, 0.5, -220),
	BackgroundColor3 = C.bg, BorderSizePixel = 0, Active = true, Draggable = true,
}, root)
New("UICorner", {CornerRadius = UDim.new(0, 10)}, main)
New("UIStroke", {Color = C.stroke, Thickness = 1.5}, main)

-- title bar
local titleBar = New("Frame", {
	Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.panel, BorderSizePixel = 0,
}, main)
New("UICorner", {CornerRadius = UDim.new(0, 10)}, titleBar)
New("Frame", {Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12),
	BackgroundColor3 = C.panel, BorderSizePixel = 0}, titleBar)

New("TextLabel", {
	Size = UDim2.new(0.6, 0, 1, 0), BackgroundTransparency = 1,
	Text = "  THIRD SEA HUB  ·  NPC & BOSS", TextColor3 = C.accent,
	Font = Enum.Font.GothamBlack, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left,
}, titleBar)

local statsLabel = New("TextLabel", {
	Size = UDim2.new(0.34, -10, 1, 0), Position = UDim2.new(0.66, 0, 0, 0),
	BackgroundTransparency = 1, Text = "Cargando stats...", TextColor3 = C.sub,
	Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right,
}, titleBar)

local hideBtn = New("TextButton", {
	Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -36, 0, 7),
	BackgroundColor3 = C.card, Text = "–", TextColor3 = C.text,
	Font = Enum.Font.GothamBold, TextSize = 18, AutoButtonColor = true,
}, titleBar)
New("UICorner", {CornerRadius = UDim.new(0, 6)}, hideBtn)

-- body: sidebar + content
local body = New("Frame", {
	Size = UDim2.new(1, 0, 1, -44), Position = UDim2.new(0, 0, 0, 44),
	BackgroundTransparency = 1,
}, main)

local sidebar = New("Frame", {
	Size = UDim2.new(0, 140, 1, 0), BackgroundColor3 = C.panel, BorderSizePixel = 0,
}, body)
New("UICorner", {CornerRadius = UDim.new(0, 10)}, sidebar)

local content = New("Frame", {
	Size = UDim2.new(1, -140, 1, -10), Position = UDim2.new(0, 146, 0, 5),
	BackgroundTransparency = 1,
}, body)

local pages = {}
local tabButtons = {}
local _activePage = nil

local function makeTab(id, label)
	local btn = New("TextButton", {
		Size = UDim2.new(1, -16, 0, 36), Position = UDim2.new(0, 8, 0, 8),
		BackgroundColor3 = C.card, Text = label, TextColor3 = C.sub,
		Font = Enum.Font.GothamMedium, TextSize = 14, AutoButtonColor = true,
	}, sidebar)
	New("UICorner", {CornerRadius = UDim.new(0, 8)}, btn)

	local page = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4, ScrollBarImageColor3 = C.stroke, Visible = false,
	}, content)
	New("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, page)

	pages[id] = page
	tabButtons[id] = btn
	btn.MouseButton1Click:Connect(function()
		for _, p in pairs(pages) do p.Visible = false end
		for _, b in pairs(tabButtons) do
			b.BackgroundColor3 = C.card
			b.TextColor3 = C.sub
		end
		page.Visible = true
		btn.BackgroundColor3 = Color3.fromRGB(23, 53, 66)
		btn.TextColor3 = C.accent
		_activePage = id
	end)
	return btn
end

-- (tab buttons are repositioned deterministically after all makeTab calls)

-- section / control builders -----------------------------------------------
local function section(page, title)
	local f = New("Frame", {
		Size = UDim2.new(1, -6, 0, 26), BackgroundColor3 = C.card, BorderSizePixel = 0,
	}, page)
	New("UICorner", {CornerRadius = UDim.new(0, 6)}, f)
	New("TextLabel", {
		Size = UDim2.new(1, -12, 1, 0), BackgroundTransparency = 1, Text = "  " .. title,
		TextColor3 = C.accent2, Font = Enum.Font.GothamBold, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	return f
end

local function toggle(page, label, key, onChange)
	local btn = New("TextButton", {
		Size = UDim2.new(1, -6, 0, 34), BackgroundColor3 = C.card,
		Text = "", AutoButtonColor = true,
	}, page)
	New("UICorner", {CornerRadius = UDim.new(0, 8)}, btn)
	local lbl = New("TextLabel", {
		Size = UDim2.new(1, -70, 1, 0), Position = UDim2.new(0, 12, 0, 0),
		BackgroundTransparency = 1, Text = label, TextColor3 = C.text,
		Font = Enum.Font.Gotham, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
	}, btn)
	local pill = New("Frame", {
		Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -52, 0.5, -10),
		BackgroundColor3 = Color3.fromRGB(60, 70, 90),
	}, btn)
	New("UICorner", {CornerRadius = UDim.new(1, 0)}, pill)
	local dot = New("Frame", {
		Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0, 3, 0.5, -7),
		BackgroundColor3 = C.sub,
	}, pill)
	New("UICorner", {CornerRadius = UDim.new(1, 0)}, dot)

	local function paint()
		local on = Config[key]
		pill.BackgroundColor3 = on and Color3.fromRGB(14, 94, 110) or Color3.fromRGB(60, 70, 90)
		dot.BackgroundColor3 = on and C.accent or C.sub
		dot.Position = on and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
		lbl.TextColor3 = on and C.accent or C.text
	end
	paint()
	btn.MouseButton1Click:Connect(function()
		Config[key] = not Config[key]
		paint()
		if onChange then onChange(Config[key]) end
	end)
	return btn
end

local function button(page, label, color, cb)
	local btn = New("TextButton", {
		Size = UDim2.new(0.5, -6, 0, 32), BackgroundColor3 = C.card,
		Text = label, TextColor3 = color or C.text,
		Font = Enum.Font.GothamMedium, TextSize = 13, AutoButtonColor = true,
	}, page)
	New("UICorner", {CornerRadius = UDim.new(0, 8)}, btn)
	New("UIStroke", {Color = color and Color3.fromRGB(70, 90, 120) or C.stroke}, btn)
	btn.MouseButton1Click:Connect(function()
		pcall(cb)
	end)
	return btn
end

local function slider(page, label, key, minV, maxV, fmt)
	local holder = New("Frame", {
		Size = UDim2.new(1, -6, 0, 44), BackgroundColor3 = C.card, BorderSizePixel = 0,
	}, page)
	New("UICorner", {CornerRadius = UDim.new(0, 8)}, holder)
	local lbl = New("TextLabel", {
		Size = UDim2.new(1, -20, 0, 20), Position = UDim2.new(0, 10, 0, 4),
		BackgroundTransparency = 1, TextColor3 = C.text, Font = Enum.Font.Gotham,
		TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.format(fmt or "%s: %.2f", label, Config[key]),
	}, holder)
	local bar = New("Frame", {
		Size = UDim2.new(1, -20, 0, 8), Position = UDim2.new(0, 10, 0, 28),
		BackgroundColor3 = Color3.fromRGB(45, 55, 75), BorderSizePixel = 0,
	}, holder)
	New("UICorner", {CornerRadius = UDim.new(1, 0)}, bar)
	local fill = New("Frame", {
		Size = UDim2.new((Config[key] - minV) / (maxV - minV), 0, 1, 0),
		BackgroundColor3 = C.accent, BorderSizePixel = 0,
	}, bar)
	New("UICorner", {CornerRadius = UDim.new(1, 0)}, fill)

	local dragging = false
	local function setFromX(x)
		local rel = math.clamp(x / bar.AbsoluteSize.X, 0, 1)
		local v = minV + rel * (maxV - minV)
		Config[key] = v
		fill.Size = UDim2.new(rel, 0, 1, 0)
		lbl.Text = string.format(fmt or "%s: %.2f", label, v)
	end
	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			setFromX(input.Position.X - bar.AbsolutePosition.X)
		end
	end)
	bar.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			setFromX(input.Position.X - bar.AbsolutePosition.X)
		end
	end)
	return holder
end

local function textInput(page, label, key)
	local holder = New("Frame", {
		Size = UDim2.new(1, -6, 0, 34), BackgroundColor3 = C.card, BorderSizePixel = 0,
	}, page)
	New("UICorner", {CornerRadius = UDim.new(0, 8)}, holder)
	New("TextLabel", {
		Size = UDim2.new(0.42, 0, 1, 0), Position = UDim2.new(0, 10, 0, 0),
		BackgroundTransparency = 1, Text = label, TextColor3 = C.text,
		Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
	}, holder)
	local box = New("TextBox", {
		Size = UDim2.new(0.55, -14, 1, -10), Position = UDim2.new(0.45, 0, 0, 5),
		BackgroundColor3 = C.bg, Text = Config[key], PlaceholderText = "cualquier nombre...",
		TextColor3 = C.accent, PlaceholderColor3 = C.sub,
		Font = Enum.Font.Gotham, TextSize = 13, ClearTextOnFocus = false,
	}, holder)
	New("UICorner", {CornerRadius = UDim.new(0, 6)}, box)
	box.FocusLost:Connect(function()
		Config[key] = box.Text
	end)
	return holder
end

local function label(page, text, color)
	return New("TextLabel", {
		Size = UDim2.new(1, -6, 0, 20), BackgroundTransparency = 1, Text = text,
		TextColor3 = color or C.sub, Font = Enum.Font.Gotham, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
	}, page)
end

local function gridButtons(page, list, color, cb)
	local wrap = New("Frame", {
		Size = UDim2.new(1, -6, 0, 0), BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y,
	}, page)
	New("UIGridLayout", {
		CellSize = UDim2.new(0.5, -6, 0, 30), CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, wrap)
	for _, e in ipairs(list) do
		local b = New("TextButton", {
			Size = UDim2.fromOffset(100, 30), BackgroundColor3 = C.card,
			Text = e.name, TextColor3 = color or C.text,
			Font = Enum.Font.Gotham, TextSize = 12, AutoButtonColor = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, wrap)
		New("UICorner", {CornerRadius = UDim.new(0, 7)}, b)
		b.MouseButton1Click:Connect(function() cb(e) end)
	end
	return wrap
end

--========================= TAB CONTENT ======================================
makeTab("farm",  "⚔ Granja")
makeTab("tele",  "📍 Mapa")
makeTab("esp",   "👁 ESP")
makeTab("loot",  "💰 Botín")
makeTab("npc",   "💬 NPC")

-- fix stacking: sidebar buttons are already created by makeTab with the
-- temporary t_Calls() Position; reposition them deterministically now:
do
	local i = 0
	for _, btn in pairs(tabButtons) do
		btn.Position = UDim2.new(0, 8, 0, 10 + i * 44)
		i = i + 1
	end
end

-- FARM -----------------------------------------------------------------------
do
	local p = pages.farm
	section(p, "Farm de NPCs / Jefes")
	toggle(p, "Auto Farm", "autoFarm", function(on)
		notify(on and "Auto Farm ON" or "Auto Farm OFF", on and C.good or C.bad)
	end)
	button(p, "Modo: Remoto (rápido)", C.accent, function()
		Config.farmMode = "remote"
		notify("Modo remoto: daño vía Main_DamgeR___ (real del juego)", C.accent)
	end)
	button(p, "Modo: M1 (legítimo)", C.accent2, function()
		Config.farmMode = "m1"
		notify("Modo M1: clicks sintéticos + combo real", C.accent2)
	end)
	toggle(p, "Solo Jefes (nivel ≥ mín.)", "bossOnly")
	slider(p, "Nivel mín. jefe", "bossLevel", 50, 5000, "Nivel mín. jefe: %d")
	textInput(p, "Filtro nombre", "nameFilter")
	toggle(p, "TP al objetivo", "tpToTarget")
	toggle(p, "Usar skills Z/X", "useSkills")
	toggle(p, "Auto Haki", "autoHaki", function(on)
		if on then toggleHaki(true) end
	end)
	slider(p, "Delay de ataque", "attackDelay", 0.05, 1.0, "Delay: %.2fs")
	section(p, "Utilidades")
	toggle(p, "Noclip", "noclip")
	slider(p, "Velocidad", "walkSpeed", 16, 100, "WalkSpeed: %d")
	button(p, "Reset Haki", C.orange, function() toggleHaki() end)
	label(p, "Objetivo actual: (ninguno)", C.sub)
	p:WaitForChild("UIListLayout")
	-- live status line
	local status = New("TextLabel", {
		Size = UDim2.new(1, -6, 0, 36), BackgroundColor3 = C.card, BorderSizePixel = 0,
		Text = " Kills: 0  ·  Sin objetivo", TextColor3 = C.sub,
		Font = Enum.Font.GothamMedium, TextSize = 13,
	}, p)
	New("UICorner", {CornerRadius = UDim.new(0, 8)}, status)
	task.spawn(function()
		while status.Parent do
			local t = CurrentTarget
			if t and t.model.Parent then
				status.Text = string.format(" Kills: %d  ·  %s [Lv.%d]  %d HP",
					Config.kills, t.name, t.level, math.floor(t.hum.Health))
				status.TextColor3 = C.accent
			else
				status.Text = string.format(" Kills: %d  ·  Sin objetivo", Config.kills)
				status.TextColor3 = C.sub
			end
			task.wait(0.4)
		end
	end)
end

-- TELEPORT -------------------------------------------------------------------
do
	local p = pages.tele
	section(p, "Islas (coordenadas reales del XML)")
	gridButtons(p, ISLANDS, C.accent, function(e)
		teleport(e.pos); notify("TP → " .. e.name, C.accent)
	end)
	section(p, "Boss / Raid")
	gridButtons(p, BOSS_MARKERS, C.bad, function(e)
		teleport(e.pos); notify("TP → " .. e.name, C.bad)
	end)
	section(p, "Quest Givers (8)")
	gridButtons(p, QUEST_GIVERS, C.good, function(e)
		teleport(e.pos); notify("TP → " .. e.name .. " — usá 'Interactuar cerca' en pestaña NPC", C.good)
	end)
	section(p, "NPCs de utilidad (6)")
	gridButtons(p, UTILITY_NPCS, C.accent2, function(e)
		talkToNPC(e.name)
	end)
end

-- ESP ------------------------------------------------------------------------
do
	local p = pages.esp
	section(p, "Visuales")
	toggle(p, "Mobs", "espmobs")
	toggle(p, "Jefes (nivel alto, rojo)", "espbosses")
	toggle(p, "Quest Givers", "esqqg")
	toggle(p, "NPCs de utilidad", "espnpc")
	toggle(p, "Cofres", "espchests")
	toggle(p, "Frutas (spots + spawn)", "espfruit")
	label(p, "El ESP se refresca cada segundo. Boss highlight usa el nivel mínimo de la pestaña Granja.", C.sub)
end

-- LOOT -----------------------------------------------------------------------
do
	local p = pages.loot
	section(p, "Recolección")
	toggle(p, "Sniper de Frutas", "fruitSniper", function(on)
		notify(on and "Buscando frutas en World.BloxFruits..." or "Sniper off", on and C.good or C.bad)
	end)
	toggle(p, "Farm de Cofres", "chestFarm", function(on)
		notify(on and "Recorriendo World.Chests..." or "Cofres off", on and C.good or C.bad)
	end)
	button(p, "Cofre más cercano", COLORS.chest, function()
		local hrp = getHRP()
		if not hrp then return end
		local best, bd = nil, math.huge
		for _, ch in ipairs(CHESTS_FOLDER:GetChildren()) do
			if ch:IsA("BasePart") and ch.Transparency < 1 then
				local d = (ch.Position - hrp.Position).Magnitude
				if d < bd then best, bd = ch, d end
			end
		end
		if best then
			teleport(best.Position, Vector3.new(0, 1, 0))
			notify("Cofre: " .. best.Name, COLORS.chest)
		else
			notify("No hay cofres visibles (ya abiertos o respawning)", C.bad)
		end
	end)
	button(p, "Ir a spots de frutas", COLORS.fruit, function()
		local spots = fruitSpotPositions()
		if #spots > 0 then
			teleport(spots[math.random(1, #spots)])
			notify("Spot aleatorio de fruta", COLORS.fruit)
		else
			notify("Sin spots (FruitPlaces vacío)", C.bad)
		end
	end)
	label(p, "La fruta spawnea como Tool dentro de World.BloxFruits y se recoge tocándola.", C.sub)
end

-- NPC ------------------------------------------------------------------------
do
	local p = pages.npc
	section(p, "Hablar con NPCs (flujo real del juego)")
	label(p, "Te teletransporta a 4 studs y simula el click; el proximity loop del cliente abre el diálogo.", C.sub)
	for _, e in ipairs(UTILITY_NPCS) do
		button(p, e.name, C.accent2, function() talkToNPC(e.name) end)
	end
	section(p, "Diálogo")
	toggle(p, "Auto avanzar opción 1", "autoOption", function(on)
		notify(on and "Auto-diálogo ON" or "Auto-diálogo OFF", on and C.good or C.bad)
	end)
	button(p, "Cerrar diálogo (click Cancel)", C.orange, function()
		pcall(function()
			local dlg = LocalPlayer.PlayerGui.Main.Dialogue
			clickGuiButton(dlg:FindFirstChild("Cancel"))
		end)
	end)
	section(p, "Interacción de mundo")
	button(p, "Interactuar cerca (Prompt/Click)", C.good, interactNearby)
	label(p, "Quest Givers no usan diálogo del juego: TP desde pestaña Mapa + 'Interactuar cerca' (prompts/click detectors en runtime).", C.sub)
end

--========================= HEADER / HIDE ====================================
local collapsed = false
hideBtn.MouseButton1Click:Connect(function()
	collapsed = not collapsed
	main:TweenSize(collapsed and UDim2.fromOffset(660, 44) or UDim2.fromOffset(660, 440),
		Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
	hideBtn.Text = collapsed and "+" or "–"
end)

-- stats refresh
task.spawn(function()
	while Running do
		pcall(function()
			local lv = stat("Level")
			local exp = stat("EXP")
			local money = stat("Money")
			local parts = {}
			if lv then parts[#parts + 1] = "Lv." .. lv.Value end
			if exp and lv then
				-- game stores flat EXP; show raw
				parts[#parts + 1] = "EXP " .. tostring(exp.Value)
			end
			if money then parts[#parts + 1] = string.format("$%s", tostring(money.Value)) end
			parts[#parts + 1] = "Kills " .. Config.kills
			statsLabel.Text = table.concat(parts, "  ·  ")
		end)
		task.wait(1.5)
	end
end)

--========================= RIGHT-SHIFT TOGGLE ===============================
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		main.Visible = not main.Visible
	end
end)

--========================= BOOT =============================================
task.spawn(function()
	task.wait(1)
	notify("Third Sea Hub listo — datos de ThirdSea.xml", C.accent)
	notify("RightShift muestra/oculta la interfaz", C.sub)
	-- auto equip combat for skills/M1 mode
	pcall(function()
		local tool = LocalPlayer.Backpack:FindFirstChild("Combat")
		local h = getHum()
		if tool and h then h:EquipTool(tool) end
	end)
end)

print("[ThirdSeaHub] cargado — islas:", #ISLANDS, "QG:", #QUEST_GIVERS, "NPCs:", #UTILITY_NPCS, "boss markers:", #BOSS_MARKERS)
