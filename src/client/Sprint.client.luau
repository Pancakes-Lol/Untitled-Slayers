-- Player sprint controller.
-- Normal sprint: Workspace.AnimDummy.AnimSaves.Sprint
-- Sword sprint: Workspace.TemplateR6.AnimSaves["Sword Run"]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local player = Players.LocalPlayer
local NORMAL_SPEED = 16
local SPRINT_SPEED = 24
local FADE_TIME = 0.18

local sprintHeld = false
local humanoid
local animator
local normalTrack
local swordTrack
local runningConnection
local childAddedConnection
local childRemovedConnection

local function animationFromSequence(sequence)
	if not sequence or not sequence:IsA("KeyframeSequence") then return nil end
	local ok, id = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
	end)
	if not ok or not id then return nil end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	return animation
end

local function loadTrack(sequence, priority)
	if not animator then return nil end
	local animation = animationFromSequence(sequence)
	if not animation then return nil end
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok then return nil end
	track.Priority = priority
	track.Looped = true
	return track
end

local function hasSwordEquipped()
	local character = player.Character
	if not character then return false end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and (child:GetAttribute("SlayerSword") or child.Name == "Novice Slayer Sword") then
			return true
		end
	end
	return false
end

local function stopTrack(track)
	if track and track.IsPlaying then
		track:Stop(FADE_TIME)
	end
end

local function updateAnimation()
	if not humanoid or humanoid.Health <= 0 then return end
	local moving = humanoid.MoveDirection.Magnitude > 0.05
	local shouldSprint = sprintHeld and moving
	player:SetAttribute("IsSprinting", shouldSprint)

	if shouldSprint then
		humanoid.WalkSpeed = SPRINT_SPEED
		if hasSwordEquipped() then
			stopTrack(normalTrack)
			if swordTrack and not swordTrack.IsPlaying then swordTrack:Play(FADE_TIME) end
		else
			stopTrack(swordTrack)
			if normalTrack and not normalTrack.IsPlaying then normalTrack:Play(FADE_TIME) end
		end
	else
		humanoid.WalkSpeed = NORMAL_SPEED
		stopTrack(normalTrack)
		stopTrack(swordTrack)
	end
end

local function cleanup()
	if runningConnection then runningConnection:Disconnect() runningConnection = nil end
	if childAddedConnection then childAddedConnection:Disconnect() childAddedConnection = nil end
	if childRemovedConnection then childRemovedConnection:Disconnect() childRemovedConnection = nil end
	stopTrack(normalTrack)
	stopTrack(swordTrack)
	normalTrack = nil
	swordTrack = nil
	humanoid = nil
	animator = nil
	player:SetAttribute("IsSprinting", false)
end

local function setupCharacter(character)
	cleanup()
	humanoid = character:WaitForChild("Humanoid")
	animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid

	local normalSaves = workspace:WaitForChild("AnimDummy"):WaitForChild("AnimSaves")
	local swordSaves = workspace:WaitForChild("TemplateR6"):WaitForChild("AnimSaves")
	normalTrack = loadTrack(normalSaves:WaitForChild("Sprint"), Enum.AnimationPriority.Movement)
	swordTrack = loadTrack(swordSaves:WaitForChild("Sword Run"), Enum.AnimationPriority.Movement)

	runningConnection = humanoid.Running:Connect(function()
		updateAnimation()
	end)
	childAddedConnection = character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then task.defer(updateAnimation) end
	end)
	childRemovedConnection = character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then task.defer(updateAnimation) end
	end)
	updateAnimation()
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		sprintHeld = true
		updateAnimation()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		sprintHeld = false
		updateAnimation()
	end
end)

player.CharacterAdded:Connect(setupCharacter)
if player.Character then task.defer(setupCharacter, player.Character) end
