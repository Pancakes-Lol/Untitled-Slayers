-- Mount the Studio-authored enemy overhead display above every live enemy.
-- Template path: ReplicatedStorage.Assets.EnemyDisplayAttachement
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local assets = ReplicatedStorage:WaitForChild("Assets")
local displayTemplate = assets:WaitForChild("EnemyDisplayAttachement")
local liveEnemies = workspace:WaitForChild("LiveEnemies")

local function resolveEnemyConfig()
	local configs = assets:FindFirstChild("Configs")
	local primary = configs and configs:FindFirstChild("EnemyConfig")
	if primary and primary:IsA("ModuleScript") then
		local ok, result = pcall(require, primary)
		if ok and type(result) == "table" then
			return result
		end
	end

	local shared = ReplicatedStorage:FindFirstChild("GameShared")
	local fallback = shared and shared:FindFirstChild("EnemyConfig")
	if fallback and fallback:IsA("ModuleScript") then
		return require(fallback)
	end

	return {}
end

local EnemyConfig = resolveEnemyConfig()

local function findDisplaySource()
	if displayTemplate:IsA("Attachment") or displayTemplate:IsA("BillboardGui") then
		return displayTemplate
	end

	local attachment = displayTemplate:FindFirstChildWhichIsA("Attachment", true)
	if attachment then
		return attachment
	end

	return displayTemplate:FindFirstChildWhichIsA("BillboardGui", true)
end

local displaySource = findDisplaySource()
if not displaySource then
	warn("[EnemyOverhead] EnemyDisplayAttachement needs an Attachment or BillboardGui")
	return
end

local function setLevelText(instance, level)
	local levelText = "Lvl. " .. tostring(level)
	for _, obj in ipairs(instance:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			local lowerName = string.lower(obj.Name)
			if string.find(lowerName, "level", 1, true) or string.find(lowerName, "lvl", 1, true) then
				obj.Text = levelText
			end
		end
	end
end

local function setEnemyName(instance, displayName)
	for _, obj in ipairs(instance:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			local lowerName = string.lower(obj.Name)
			if string.find(lowerName, "enemyname", 1, true)
				or lowerName == "namelabel"
				or lowerName == "enemyname"
			then
				obj.Text = displayName
			end
		end
	end
end

local function attachDisplay(model)
	if not model:IsA("Model") or model:GetAttribute("EnemyDisplayAttached") then
		return
	end

	local enemyType = model:GetAttribute("SpawnEnemyType")
	local config = enemyType and EnemyConfig[enemyType]
	if not config then
		return
	end

	local head = model:FindFirstChild("Head") or model:WaitForChild("Head", 5)
	if not head or not head:IsA("BasePart") then
		warn("[EnemyOverhead] " .. model.Name .. " has no Head to mount the display on")
		return
	end

	local old = head:FindFirstChild("EnemyDisplayAttachement")
	if old then
		old:Destroy()
	end

	local display = displaySource:Clone()
	display.Name = "EnemyDisplayAttachement"

	if display:IsA("Attachment") then
		-- Keep the overhead physically mounted to the enemy head and above the top of it.
		display.Position = Vector3.new(0, (head.Size.Y * 0.5) + 1.1, 0)
		display.Parent = head
	elseif display:IsA("BillboardGui") then
		display.Adornee = head
		display.StudsOffsetWorldSpace = Vector3.new(0, (head.Size.Y * 0.5) + 1.1, 0)
		display.Parent = head
	end

	setLevelText(display, tonumber(config.Level) or 1)
	setEnemyName(display, config.DisplayName or config.ModelName or enemyType or model.Name)

	-- The custom overhead replaces Roblox's built-in enemy name/health display.
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end

	model:SetAttribute("EnemyDisplayAttached", true)
end

for _, enemy in ipairs(liveEnemies:GetChildren()) do
	task.spawn(attachDisplay, enemy)
end

liveEnemies.ChildAdded:Connect(function(enemy)
	task.defer(attachDisplay, enemy)
end)
