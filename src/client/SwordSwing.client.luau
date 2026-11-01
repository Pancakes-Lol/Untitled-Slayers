-- Player sword animation controller.
-- Uses the developer animation pack in Workspace.TemplateR6.AnimSaves.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local combatRemote = ReplicatedStorage:WaitForChild("SwordCombat")
local animSaves = workspace:WaitForChild("TemplateR6"):WaitForChild("AnimSaves")
local slashTemplate = workspace:WaitForChild("Slash Particle", 30)

if slashTemplate and slashTemplate:IsA("BasePart") then
	slashTemplate.LocalTransparencyModifier = 1
end

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
	local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
	if not ok then return nil end
	track.Priority = priority
	track.Looped = looped
	return track
end

-- ParticleEmitter textures are camera-facing billboards. Rotating the invisible
-- Part does not rotate the visible slash, so each attack rotates the emitter itself.
local slashRotationByAttack = {
	[1] = -48,
	[2] = 48,
	[3] = 88,
	[4] = -72,
	[5] = 72,
}

local function scaleSequence(sequence, scale)
	local points = {}
	for _, point in ipairs(sequence.Keypoints) do
		table.insert(points, NumberSequenceKeypoint.new(
			point.Time,
			point.Value * scale,
			point.Envelope * scale
		))
	end
	return NumberSequence.new(points)
end

local function emitSlash(tool, attackIndex)
	if not slashTemplate or not slashTemplate:IsA("BasePart") then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local handle = tool:FindFirstChild("Handle")
	if not root or not handle or not handle:IsA("BasePart") or tool.Parent ~= character then return end

	local slash = slashTemplate:Clone()
	slash.Name = "Player Slash Particle"
	slash.Anchored = true
	slash.CanCollide = false
	slash.CanTouch = false
	slash.CanQuery = false
	slash.Massless = true
	slash.Transparency = 1

	-- Sample the sword during the actual swing, then keep the burst just ahead of it.
	local slashPosition = handle.Position + root.CFrame.LookVector * 0.8 + Vector3.new(0, 0.2, 0)
	slash.CFrame = CFrame.new(slashPosition)
	slash.Parent = workspace

	local rotation = slashRotationByAttack[attackIndex] or 0
	for _, obj in ipairs(slash:GetDescendants()) do
		if obj:IsA("ParticleEmitter") then
			obj.Enabled = false
			obj.Rotation = NumberRange.new(rotation)
			obj.RotSpeed = NumberRange.new(0)
			obj.Size = scaleSequence(obj.Size, 0.58)
			obj:Emit(obj:GetAttribute("EmitCount") or 1)
		end
	end

	Debris:AddItem(slash, 1.5)
end

local function bindSword(tool)
	if not tool:IsA("Tool") then return end
	if not tool:GetAttribute("SlayerSword") and tool.Name ~= "Novice Slayer Sword" then return end
	if tool:GetAttribute("CombatClientBound") then return end
	tool:SetAttribute("CombatClientBound", true)

	local equipped = false
	local attacking = false
	local unsheathing = false
	local humanoid, animator
	local idleTrack, walkTrack, unsheathTrack
	local attackTracks = {}
	local runningConnection
	local lastAttackIndex = 0
	local lastAttackTime = 0
	local equipToken = 0

	local function stopTrack(track, fade)
		if track and track.IsPlaying then track:Stop(fade or 0.1) end
	end

	local function setLocomotion(speed)
		if not equipped or attacking or unsheathing then return end
		if speed > 0.5 then
			stopTrack(idleTrack, 0.15)
			if walkTrack and not walkTrack.IsPlaying then walkTrack:Play(0.15) end
		else
			stopTrack(walkTrack, 0.15)
			if idleTrack and not idleTrack.IsPlaying then idleTrack:Play(0.15) end
		end
	end

	local function clearTracks()
		if runningConnection then runningConnection:Disconnect() runningConnection = nil end
		stopTrack(unsheathTrack, 0.05)
		stopTrack(idleTrack, 0.1)
		stopTrack(walkTrack, 0.1)
		for _, track in pairs(attackTracks) do stopTrack(track, 0.05) end
		unsheathTrack, idleTrack, walkTrack = nil, nil, nil
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
		idleTrack = loadTrack(animator, "Sword Idle", Enum.AnimationPriority.Idle, true)
		walkTrack = loadTrack(animator, "Sword Walk", Enum.AnimationPriority.Movement, true)
		for i = 1, 5 do
			attackTracks[i] = loadTrack(animator, "Attack" .. i, Enum.AnimationPriority.Action, false)
		end
		runningConnection = humanoid.Running:Connect(setLocomotion)
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
		unsheathing = true
		equipToken += 1
		local thisEquip = equipToken
		setupTracks()
		stopTrack(idleTrack, 0)
		stopTrack(walkTrack, 0)

		if unsheathTrack then
			unsheathTrack:Play(0.06, 1, 1)
			local duration = 0.65
			if unsheathTrack.Length > 0 then duration = math.clamp(unsheathTrack.Length, 0.25, 2) end
			task.delay(duration, function()
				if not equipped or thisEquip ~= equipToken then return end
				unsheathing = false
				if humanoid then
					setLocomotion(humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed)
				end
			end)
		else
			unsheathing = false
			if humanoid then setLocomotion(humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed) end
		end
	end)

	tool.Unequipped:Connect(function()
		equipped = false
		attacking = false
		unsheathing = false
		equipToken += 1
		clearTracks()
	end)

	tool.Activated:Connect(function()
		if not equipped or attacking or unsheathing then return end
		if os.clock() - lastAttackTime < 0.42 then return end
		local character = player.Character
		if not character or tool.Parent ~= character then return end
		local index = chooseAttack()
		if not index then return end
		lastAttackTime = os.clock()
		attacking = true
		stopTrack(idleTrack, 0.08)
		stopTrack(walkTrack, 0.08)
		local track = attackTracks[index]
		if track then track:Play(0.06, 1, 1) end

		-- Wait until the sword has visibly entered the swing before sampling its position.
		task.delay(0.09, function()
			if equipped and tool.Parent == player.Character then
				emitSlash(tool, index)
			end
		end)

		combatRemote:FireServer(index)
		local duration = 0.48
		if track and track.Length > 0 then duration = math.clamp(track.Length * 0.75, 0.32, 0.8) end
		task.delay(duration, function()
			if not equipped then return end
			attacking = false
			if humanoid then
				setLocomotion(humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed)
			end
		end)
	end)

	tool.Destroying:Connect(clearTracks)
end

local function watch(container)
	for _, child in ipairs(container:GetChildren()) do bindSword(child) end
	container.ChildAdded:Connect(bindSword)
end

watch(player:WaitForChild("Backpack"))
player.CharacterAdded:Connect(function(character)
	watch(character)
end)
if player.Character then watch(player.Character) end
