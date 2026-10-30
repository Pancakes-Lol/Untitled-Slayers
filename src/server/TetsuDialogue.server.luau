-- Tetsu slayer onboarding. Server validates names, quest state and combat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local DataStoreService = game:GetService("DataStoreService")

local npc = workspace:WaitForChild("Tetsu", 30)
if not npc then warn("[Tetsu] Workspace/Tetsu missing") return end
local torso = npc:FindFirstChild("Torso") or npc:FindFirstChild("UpperTorso") or npc:FindFirstChild("HumanoidRootPart")
if not torso or not torso:IsA("BasePart") then warn("[Tetsu] Missing torso") return end
local remote = ReplicatedStorage:FindFirstChild("TetsuDialogue") or Instance.new("RemoteEvent")
remote.Name = "TetsuDialogue"
remote.Parent = ReplicatedStorage
local prompt = torso:FindFirstChild("TetsuTalkPrompt") or Instance.new("ProximityPrompt")
prompt.Name = "TetsuTalkPrompt"
prompt.ActionText = "Talk"
prompt.ObjectText = "Tetsu"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 12
prompt.RequiresLineOfSight = false
prompt.Parent = torso

local store = DataStoreService:GetDataStore("TetsuSlayerJourneyV1")
local state = {}
local dummy
local DUMMY_DISTANCE = 19

local function send(player, kind, data)
	remote:FireClient(player, kind, data or {})
end
local function nearby(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return root and humanoid and humanoid.Health > 0 and (root.Position - torso.Position).Magnitude <= 18
end
local function persist(player)
	local s = state[player]
	if not s or not s.loaded then return end
	local saved = {name=s.name, stage=s.stage}
	local ok, err = pcall(function() store:SetAsync(tostring(player.UserId), saved) end)
	if not ok then warn("[Tetsu] Could not save "..player.Name..": "..tostring(err)) end
end
local function setName(player, name)
	local s = state[player]
	if not s then return end
	s.name = name
	player:SetAttribute("SlayerName", name)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.DisplayName = name end
end
local function grantSword(player)
	local s = state[player]
	if not s or (s.stage ~= "hunt" and s.stage ~= "return" and s.stage ~= "done") then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	if backpack:FindFirstChild("Novice Slayer Sword") or (player.Character and player.Character:FindFirstChild("Novice Slayer Sword")) then return end
	local tool = Instance.new("Tool")
	tool.Name = "Novice Slayer Sword"
	tool.ToolTip = "Your first weapon. Click to strike the training enemy."
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.28, 3.1, 0.6)
	handle.Color = Color3.fromRGB(205, 215, 233)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	local gripPart = Instance.new("Part")
	gripPart.Name = "SwordGrip"
	gripPart.Size = Vector3.new(0.38, 1.1, 0.5)
	gripPart.Color = Color3.fromRGB(36, 34, 49)
	gripPart.Material = Enum.Material.SmoothPlastic
	gripPart.CanCollide = false
	gripPart.Massless = true
	gripPart.CFrame = handle.CFrame * CFrame.new(0, -1.75, 0)
	gripPart.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = gripPart
	weld.Parent = gripPart
	-- Tool Grip is the inverse of the Handle-to-hand offset.
	-- Shift the blade upward so the dark hilt rests in the hand.
	tool.Grip = CFrame.new(0, -1.75, 0)
	local lastAttack = 0
	tool.Activated:Connect(function()
		if os.clock() - lastAttack < 0.55 then return end
		lastAttack = os.clock()
		if tool.Parent ~= player.Character then return end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local playerHum = character and character:FindFirstChildOfClass("Humanoid")
		local enemyHum = dummy and dummy:FindFirstChildOfClass("Humanoid")
		local enemyPart = dummy and dummy.PrimaryPart
		if not root or not playerHum or playerHum.Health <= 0 or not enemyHum or enemyHum.Health <= 0 or not enemyPart then return end
		local offset = enemyPart.Position - root.Position
		if offset.Magnitude > 9 or offset.Magnitude < 0.01 or root.CFrame.LookVector:Dot(offset.Unit) < 0.1 then return end
		enemyHum:SetAttribute("LastHitUserId", player.UserId)
		enemyHum:TakeDamage(25)
	end)
	tool.Parent = backpack
end
local function spawnDummy()
	if dummy and dummy.Parent then dummy:Destroy() end
	local model = Instance.new("Model")
	model.Name = "Slayer Training Enemy"
	local body = Instance.new("Part")
	body.Name = "HumanoidRootPart"
	body.Size = Vector3.new(3, 4, 2)
	body.Anchored = true
	body.Color = Color3.fromRGB(127, 78, 58)
	body.Material = Enum.Material.Wood
	body.CFrame = torso.CFrame * CFrame.new(0, 0, -DUMMY_DISTANCE)
	body.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(2.2, 2.2, 2.2)
	head.Anchored = true
	head.CanCollide = false
	head.Color = Color3.fromRGB(154, 108, 79)
	head.CFrame = body.CFrame * CFrame.new(0, 3, 0)
	head.Parent = model
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.Parent = model
	model.PrimaryPart = body
	model.Parent = workspace
	dummy = model
	humanoid.Died:Connect(function()
		local userId = humanoid:GetAttribute("LastHitUserId")
		local player = userId and Players:GetPlayerByUserId(userId)
		local s = player and state[player]
		if s and s.stage == "hunt" then
			s.stage = "return"
			send(player, "Quest", {text="Training enemy defeated! Return to Tetsu to finish your first quest."})
			task.spawn(persist, player)
		end
		task.delay(5, function()
			if dummy == model then spawnDummy() end
		end)
	end)
end
spawnDummy()

local function talk(player)
	local s = state[player]
	if not s or not s.loaded or not nearby(player) then return end
	if s.stage == "name" then
		send(player, "Question", {question="Welcome, traveler. What should I call you?", answers={"Captain Noodles", player.DisplayName, "Choose my own name..."}})
	elseif s.stage == "math" then
		send(player, "Question", {question="One last test. What's 9 + 10?", answers={"19", "21", "910"}})
	elseif s.stage == "offer" then
		send(player, "Story", {text="You have potential, "..(s.name or "traveler")..". Take this sword and defeat the training enemy to begin your slayer journey.", button="Accept sword & quest"})
	elseif s.stage == "hunt" then
		grantSword(player)
		send(player, "Story", {text="Equip your Novice Slayer Sword and defeat the training enemy near me. Click or tap to attack!", button="Let's go"})
	elseif s.stage == "return" then
		s.stage = "done"
		task.spawn(persist, player)
		send(player, "Story", {text="Well done, "..(s.name or "slayer").."! You defeated your first enemy. Your slayer journey has officially begun!", button="Thank you!"})
	else
		send(player, "Story", {text="Welcome back, "..(s.name or "slayer")..". Keep training. Your greatest battles are still ahead!", button="Goodbye"})
	end
end
prompt.Triggered:Connect(talk)

remote.OnServerEvent:Connect(function(player, action, value)
	local s = state[player]
	if not s or not s.loaded or not nearby(player) then return end
	if action == "Close" then return end
	if action == "Choose" and s.stage == "name" and type(value) == "number" and value % 1 == 0 then
		if value == 3 then send(player, "NameEntry") return end
		if value ~= 1 and value ~= 2 then return end
		setName(player, value == 1 and "Captain Noodles" or player.DisplayName)
		s.stage = "math"
		talk(player)
	elseif action == "CustomName" and s.stage == "name" and type(value) == "string" then
		local name = value:match("^%s*(.-)%s*$")
		if #name < 3 or #name > 20 or not name:match("^[%w_ ]+$") then
			send(player, "NameError", {text="Use 3–20 letters, numbers, spaces or underscores."}) return
		end
		local ok, filtered = pcall(function()
			return TextService:FilterStringAsync(name, player.UserId):GetNonChatStringForBroadcastAsync()
		end)
		if not ok or not filtered or filtered == "" or filtered:find("#", 1, true) then
			send(player, "NameError", {text="That name can't be used. Try another."}) return
		end
		setName(player, filtered)
		s.stage = "math"
		talk(player)
	elseif action == "Choose" and s.stage == "math" and type(value) == "number" and value % 1 == 0 and value >= 1 and value <= 3 then
		s.stage = "offer"
		send(player, "Story", {text=(value == 2 and "21?! Ha! I like your confidence. " or value == 1 and "Correct! " or "That's... creative. ").."Now let's begin your slayer journey.", button="Continue"})
	elseif action == "Continue" and s.stage == "offer" then
		talk(player)
	elseif action == "Accept" and s.stage == "offer" then
		s.stage = "hunt"
		grantSword(player)
		task.spawn(persist, player)
		talk(player)
	elseif action == "Continue" then
		send(player, "Close")
	end
end)

Players.PlayerAdded:Connect(function(player)
	local s = {stage="name", loaded=false}
	state[player] = s
	local ok, data = pcall(function() return store:GetAsync(tostring(player.UserId)) end)
	if ok and type(data) == "table" then
		if type(data.name) == "string" and #data.name <= 20 then s.name = data.name end
		if data.stage == "hunt" or data.stage == "return" or data.stage == "done" then s.stage = data.stage
		elseif s.name then s.stage = "math" end
	end
	s.loaded = true
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		if state[player] ~= s then return end
		if s.name then setName(player, s.name) end
		grantSword(player)
	end)
	if player.Character then
		task.defer(function()
			if s.name then setName(player, s.name) end
			grantSword(player)
		end)
	end
end)
Players.PlayerRemoving:Connect(function(player)
	persist(player)
	state[player] = nil
end)
game:BindToClose(function()
	for player in pairs(state) do persist(player) end
end)
