-- Player sword animation controller.
-- Uses the developer animation pack in Workspace.TemplateR6.AnimSaves.
-- Attacks are allowed while sprinting; Action animations override sprint movement temporarily.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local combatRemote = ReplicatedStorage:WaitForChild("SwordCombat")
local animSaves = workspace:WaitForChild("TemplateR6"):WaitForChild("AnimSaves")
local slashTemplate = workspace:FindFirstChild("Slash Particle") or workspace:WaitForChild("Slash Particle", 10)

local SLASH_START_DELAY = 0.07
local SLASH_TRAVEL_DISTANCE = 5.5
local SLASH_TRAVEL_TIME = 0.20
local SLASH_START_FORWARD = 1.0
local SLASH_SCALE = Vector3.new(5.5, 3.1, 0.08)
local SLASH_LIFETIME = 0.32
local ATTACK_COOLDOWN = 0.42

local animationCache = {}

local function resolveAnimation(name)
	if animationCache[name] then return animationCache[name] end

	for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
		if obj:IsA("Animation") and obj.Name == name and obj.AnimationId ~= "" then
			animationCache[name] = obj
			return obj
		end
	end

	local sequence = animSaves:FindFirstChild(name)
	if sequence and sequence:IsA("KeyframeSequence") then
		local ok, id = pcall(function()
			return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
		end)
		if ok and id then
			local anim = Instance.new("Animation")
			anim.Name = name
			anim.AnimationId = id
			animationCache[name] = anim
			return anim
		end
	end

	warn("[SwordCombat] Missing animation: " .. name)
	return nil
end

local function loadTrack(animator, name, priority, looped)
	local anim = resolveAnimation(name)
	if not anim then return nil end
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if not ok then return nil end
	track.Priority = priority
	track.Looped = looped
	return track
end

local function getSlashEmitterTemplate()
	if not slashTemplate then return nil end
	for _, obj in ipairs(slashTemplate:GetDescendants()) do
		if obj:IsA("ParticleEmitter") then return obj end
	end
	return nil
end

local slashEmitterTemplate = getSlashEmitterTemplate()

local function getBladeDirection(handle)
	for _, obj in ipairs(handle:GetDescendants()) do
		if obj:IsA("Trail") and obj.Attachment0 and obj.Attachment1 then
			local a0, a1 = obj.Attachment0, obj.Attachment1
			if a0.Parent == handle and a1.Parent == handle then
				local delta = a1.Position - a0.Position
				if delta.Magnitude > 0.001 then return delta.Unit end
			end
		end
	end
	return Vector3.new(0, 1, 0)
end

local function getSlashTexture()
	return slashEmitterTemplate and slashEmitterTemplate.Texture or ""
end

local function getSlashColor()
	if slashEmitterTemplate then
		local points = slashEmitterTemplate.Color.Keypoints
		if #points > 0 then return points[1].Value end
	end
	return Color3.fromRGB(120, 220, 255)
end

local function getSlashTransparency()
	if slashEmitterTemplate then
		local points = slashEmitterTemplate.Transparency.Keypoints
		if #points > 0 then return math.clamp(points[1].Value, 0, 1) end
	end
	return 0.05
end

local function createSlashWave(tool)
	local handle = tool:FindFirstChild("Handle")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not handle or not handle:IsA("BasePart") or not root then return end

	local bladeDirectionWorld = handle.CFrame:VectorToWorldSpace(getBladeDirection(handle)).Unit
	local playerForward = root.CFrame.LookVector
	local travelDirection = playerForward * 0.85 + bladeDirectionWorld * 0.15
	travelDirection = travelDirection.Magnitude > 0.001 and travelDirection.Unit or playerForward

	local startPosition = handle.Position + playerForward * SLASH_START_FORWARD
	local right = travelDirection:Cross(bladeDirectionWorld)
	right = right.Magnitude > 0.01 and right.Unit or root.CFrame.RightVector
	local up = right:Cross(travelDirection).Unit

	local wave = Instance.new("Part")
	wave.Name = "SwordSlashWave"
	wave.Size = SLASH_SCALE
	wave.Anchored = true
	wave.CanCollide = false
	wave.CanTouch = false
	wave.CanQuery = false
	wave.CastShadow = false
	wave.Transparency = 1
	wave.CFrame = CFrame.fromMatrix(startPosition, right, up, -travelDirection)
	wave.Parent = workspace

	local gui = Instance.new("SurfaceGui")
	gui.Name = "SlashSurface"
	gui.Face = Enum.NormalId.Front
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.PixelsPerStud = 100
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = wave

	local image = Instance.new("ImageLabel")
	image.Name = "SlashImage"
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = getSlashTexture()
	image.ImageColor3 = getSlashColor()
	image.ImageTransparency = getSlashTransparency()
	image.ScaleType = Enum.ScaleType.Stretch
	image.Parent = gui

	local backGui = gui:Clone()
	backGui.Name = "SlashSurfaceBack"
	backGui.Face = Enum.NormalId.Back
	backGui.Parent = wave
	local backImage = backGui:FindFirstChild("SlashImage")

	TweenService:Create(
		wave,
		TweenInfo.new(SLASH_TRAVEL_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{CFrame = wave.CFrame + travelDirection * SLASH_TRAVEL_DISTANCE}
	):Play()
	TweenService:Create(
		image,
		TweenInfo.new(SLASH_LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ImageTransparency = 1}
	):Play()
	if backImage and backImage:IsA("ImageLabel") then
		TweenService:Create(
			backImage,
			TweenInfo.new(SLASH_LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ImageTransparency = 1}
		):Play()
	end
	Debris:AddItem(wave, SLASH_LIFETIME + 0.08)
end

local function bindSword(tool)
	if not tool:IsA("Tool") then return end
	if not tool:GetAttribute("SlayerSword") and tool.Name ~= "Novice Slayer Sword" then return end
	if tool:GetAttribute("CombatClientBound") then return end
	tool:SetAttribute("CombatClientBound", true)

	local equipped = false
	local attacking = false
	local transitioning = false
	local humanoid, animator
	local idleTrack, walkTrack, unsheathTrack, sheathTrack
	local attackTracks = {}
	local runningConnection, sprintConnection
	local lastAttackIndex = 0
	local lastAttackTime = 0
	local equipToken = 0

	local function stopTrack(track, fade)
		if track and track.IsPlaying then track:Stop(fade or 0.14) end
	end

	local function setLocomotion(speed)
		if not equipped or attacking or transitioning then return end
		if player:GetAttribute("IsSprinting") then
			stopTrack(idleTrack, 0.12)
			stopTrack(walkTrack, 0.12)
			return
		end
		if speed > 0.5 then
			stopTrack(idleTrack, 0.18)
			if walkTrack and not walkTrack.IsPlaying then walkTrack:Play(0.18) end
		else
			stopTrack(walkTrack, 0.18)
			if idleTrack and not idleTrack.IsPlaying then idleTrack:Play(0.18) end
		end
	end

	local function clearTracks()
		if runningConnection then runningConnection:Disconnect() runningConnection = nil end
		if sprintConnection then sprintConnection:Disconnect() sprintConnection = nil end
		stopTrack(unsheathTrack, 0.08)
		stopTrack(sheathTrack, 0.08)
		stopTrack(idleTrack, 0.12)
		stopTrack(walkTrack, 0.12)
		for _, track in pairs(attackTracks) do stopTrack(track, 0.08) end
		unsheathTrack, sheathTrack, idleTrack, walkTrack = nil, nil, nil, nil
		table.clear(attackTracks)
		humanoid, animator = nil, nil
	end

	local function setupTracks()
		clearTracks()
		local character = player.Character
		humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
		animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
		animator.Parent = humanoid
		unsheathTrack = loadTrack(animator, "UnsheathingSword", Enum.AnimationPriority.Action, false)
		sheathTrack = loadTrack(animator, "SheathingSword", Enum.AnimationPriority.Action, false)
		idleTrack = loadTrack(animator, "Sword Idle", Enum.AnimationPriority.Idle, true)
		walkTrack = loadTrack(animator, "Sword Walk", Enum.AnimationPriority.Movement, true)
		for i = 1, 5 do
			attackTracks[i] = loadTrack(animator, "Attack" .. i, Enum.AnimationPriority.Action, false)
		end
		runningConnection = humanoid.Running:Connect(setLocomotion)
		sprintConnection = player:GetAttributeChangedSignal("IsSprinting"):Connect(function()
			if humanoid then setLocomotion(humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed) end
		end)
	end

	local function chooseAttack()
		local choices = {}
		for i = 1, 5 do
			if i ~= lastAttackIndex and attackTracks[i] then table.insert(choices, i) end
		end
		if #choices == 0 then return nil end
		local index = choices[math.random(1, #choices)]
		lastAttackIndex = index
		return index
	end

	tool.Equipped:Connect(function()
		equipped = true
		attacking = false
		transitioning = true
		equipToken += 1
		local thisEquip = equipToken
		setupTracks()

		if unsheathTrack then
			unsheathTrack:Play(0.12, 1, 1)
			local duration = unsheathTrack.Length > 0 and math.clamp(unsheathTrack.Length, 0.25, 2) or 0.65
			task.delay(duration, function()
				if not equipped or thisEquip ~= equipToken then return end
				transitioning = false
				if humanoid then setLocomotion(humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed) end
			end)
		else
			transitioning = false
			if humanoid then setLocomotion(humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed) end
		end
	end)

	tool.Unequipped:Connect(function()
		equipped = false
		attacking = false
		transitioning = true
		equipToken += 1
		local thisEquip = equipToken
		stopTrack(idleTrack, 0.16)
		stopTrack(walkTrack, 0.16)
		stopTrack(unsheathTrack, 0.08)
		for _, track in pairs(attackTracks) do stopTrack(track, 0.1) end

		if sheathTrack then
			sheathTrack:Play(0.14, 1, 1)
			local duration = sheathTrack.Length > 0 and math.clamp(sheathTrack.Length, 0.25, 2) or 0.6
			task.delay(duration, function()
				if equipped or thisEquip ~= equipToken then return end
				transitioning = false
				clearTracks()
			end)
		else
			transitioning = false
			clearTracks()
		end
	end)

	tool.Activated:Connect(function()
		-- Sprinting no longer blocks katana attacks.
		if not equipped or attacking or transitioning then return end
		if os.clock() - lastAttackTime < ATTACK_COOLDOWN then return end
		local character = player.Character
		if not character or tool.Parent ~= character then return end

		local index = chooseAttack()
		if not index then return end
		lastAttackTime = os.clock()
		attacking = true
		stopTrack(idleTrack, 0.08)
		stopTrack(walkTrack, 0.08)

		local track = attackTracks[index]
		if track then track:Play(0.08, 1, 1) end

		task.delay(SLASH_START_DELAY, function()
			if equipped and attacking and tool.Parent == player.Character then
				createSlashWave(tool)
			end
		end)

		combatRemote:FireServer(index)
		local duration = track and track.Length > 0 and math.clamp(track.Length * 0.75, 0.32, 0.8) or 0.48
		task.delay(duration, function()
			if not equipped then return end
			attacking = false
			if humanoid then setLocomotion(humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed) end
		end)
	end)

	tool.Destroying:Connect(clearTracks)
end

local function watch(container)
	for _, child in ipairs(container:GetChildren()) do bindSword(child) end
	container.ChildAdded:Connect(bindSword)
end

watch(player:WaitForChild("Backpack"))
player.CharacterAdded:Connect(function(character) watch(character) end)
if player.Character then watch(player.Character) end
