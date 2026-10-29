-- Untitled Slayers: server-authoritative melee combat with procedural joint animations.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local remote = ReplicatedStorage:FindFirstChild("CombatAction")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "CombatAction"
	remote.Parent = ReplicatedStorage
end

local MOVES = {
	Punch = {duration = 0.42, hitAt = 0.15, damage = 8, range = 5.5, dot = 0.35},
	Kick = {duration = 0.82, hitAt = 0.33, damage = 16, range = 7, dot = 0.05},
}
local busyUntil = {}
local originals = {}

local function tweenJoint(joint, goal, time)
	if not joint or not joint.Parent then return end
	local tween = TweenService:Create(joint, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {C0 = goal})
	tween:Play()
end

local function jointsFor(character)
	local joints = {}
	for _, inst in character:GetDescendants() do
		if inst:IsA("Motor6D") then joints[inst.Name] = inst end
	end
	return joints
end

local function strike(player, character, move)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local origin = root.Position
	local forward = root.CFrame.LookVector
	local config = MOVES[move]
	for _, model in workspace:GetDescendants() do
		if model:IsA("Humanoid") and model.Health > 0 and model.Parent ~= character then
			local targetRoot = model.Parent:FindFirstChild("HumanoidRootPart")
			if targetRoot then
				local delta = targetRoot.Position - origin
				local flat = Vector3.new(delta.X, 0, delta.Z)
				if flat.Magnitude <= config.range and math.abs(delta.Y) < 5
					and (flat.Magnitude < 0.1 or forward:Dot(flat.Unit) >= config.dot) then
					model:TakeDamage(config.damage)
				end
			end
		end
	end
end

local function animate(character, move, duration)
	local joints = jointsFor(character)
	local isR15 = joints.RightShoulder ~= nil
	local arm = joints[isR15 and "RightShoulder" or "Right Shoulder"]
	local leg = joints[isR15 and "RightHip" or "Right Hip"]
	local waist = joints.Waist or joints.RootJoint
	local selected = {arm, leg, waist}
	local saved = {}
	for _, joint in selected do
		if joint then saved[joint] = joint.C0 end
	end
	local windup = move == "Punch" and 0.10 or 0.19
	local action = move == "Punch" and 0.12 or 0.22
	if arm then
		tweenJoint(arm, saved[arm] * CFrame.Angles(math.rad(-35), 0, math.rad(-18)), windup)
	end
	if leg and move == "Kick" then
		tweenJoint(leg, saved[leg] * CFrame.Angles(math.rad(30), math.rad(-25), math.rad(15)), windup)
	end
	if waist then tweenJoint(waist, saved[waist] * CFrame.Angles(0, math.rad(move == "Punch" and -25 or -45), 0), windup) end
	task.wait(windup)
	if arm then
		local offset = move == "Punch" and CFrame.Angles(math.rad(-105), math.rad(-15), math.rad(10)) or CFrame.Angles(math.rad(-15), 0, math.rad(35))
		tweenJoint(arm, saved[arm] * offset, action)
	end
	if leg and move == "Kick" then
		tweenJoint(leg, saved[leg] * CFrame.Angles(math.rad(-90), math.rad(35), math.rad(-35)), action)
	end
	if waist then tweenJoint(waist, saved[waist] * CFrame.Angles(0, math.rad(move == "Punch" and 30 or 65), 0), action) end
	task.wait(action)
	for joint, original in pairs(saved) do
		tweenJoint(joint, original, math.max(0.12, duration - windup - action))
	end
end

remote.OnServerEvent:Connect(function(player, move)
	if type(move) ~= "string" or not MOVES[move] then return end
	local now = os.clock()
	if (busyUntil[player] or 0) > now then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then return end
	local config = MOVES[move]
	busyUntil[player] = now + config.duration
	task.spawn(animate, character, move, config.duration)
	task.delay(config.hitAt, function()
		if player.Character == character and humanoid.Health > 0 then
			strike(player, character, move)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player) busyUntil[player] = nil end)
