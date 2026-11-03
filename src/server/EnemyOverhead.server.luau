-- Mount the Studio-authored enemy overhead display above every live enemy.
-- Template path: ReplicatedStorage.Assets.EnemyDisplayAttachement
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local assets = ReplicatedStorage:WaitForChild("Assets")
local displayTemplate = assets:WaitForChild("EnemyDisplayAttachement")
local liveEnemies = workspace:WaitForChild("LiveEnemies")

-- Extra clearance above the top of the Head so hair/accessories do not clip the UI.
local OVERHEAD_CLEARANCE = 2.4

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

local function isTextObject(obj)
	return obj:IsA("TextLabel") or obj:IsA("TextButton")
end

local function setLevelText(instance, level)
	local levelText = "Lvl. " .. tostring(level)
	for _, obj in ipairs(instance:GetDescendants()) do
		if isTextObject(obj) then
			local lowerName = string.lower(obj.Name)
			local lowerText = string.lower(obj.Text or "")
			if string.find(lowerName, "level", 1, true)
				or string.find(lowerName, "lvl", 1, true)
				or string.find(lowerText, "lvl", 1, true)
				or string.find(lowerText, "level", 1, true)
			then
				obj.Text = levelText
			end
		end
	end
end

local function setEnemyName(instance, displayName)
	for _, obj in ipairs(instance:GetDescendants()) do
		if isTextObject(obj) then
			local lowerName = string.lower(obj.Name)
			local lowerText = string.lower(obj.Text or "")
			if string.find(lowerName, "enemyname", 1, true)
				or lowerName == "namelabel"
				or lowerName == "enemyname"
				or string.find(lowerText, "test name", 1, true)
			then
				obj.Text = displayName
			end
		end
	end
end

local function isGreenish(frame)
	if not frame:IsA("Frame") then return false end
	local color = frame.BackgroundColor3
	return color.G > color.R + 0.12 and color.G > color.B + 0.12
end

local function findHealthFill(instance)
	-- Prefer the actual green frame from the authored GUI. The old lookup could grab
	-- the black health-bar container when its name included "fill/progress".
	local bestGreen
	local bestGreenScore = -math.huge
	for _, obj in ipairs(instance:GetDescendants()) do
		if obj:IsA("Frame") and isGreenish(obj) and obj.Parent and obj.Parent:IsA("GuiObject") then
			local color = obj.BackgroundColor3
			local score = color.G - math.max(color.R, color.B)
			if score > bestGreenScore then
				bestGreen = obj
				bestGreenScore = score
			end
		end
	end
	if bestGreen then
		return bestGreen
	end

	-- Fallback only if the template is later redesigned without a green fill.
	for _, obj in ipairs(instance:GetDescendants()) do
		if obj:IsA("Frame") then
			local lowerName = string.lower(obj.Name)
			if string.find(lowerName, "healthfill", 1, true)
				or string.find(lowerName, "hpfill", 1, true)
				or lowerName == "fill"
				or string.find(lowerName, "healthbarfill", 1, true)
			then
				return obj
			end
		end
	end
	return nil
end

local function updatePercentText(instance, ratio)
	local percentText = tostring(math.floor(ratio * 100 + 0.5)) .. "%"
	for _, obj in ipairs(instance:GetDescendants()) do
		if isTextObject(obj) then
			local lowerName = string.lower(obj.Name)
			local text = obj.Text or ""
			if string.find(lowerName, "health", 1, true)
				or string.find(lowerName, "percent", 1, true)
				or lowerName == "hp"
				or string.find(text, "%", 1, true)
			then
				obj.Text = percentText
			end
		end
	end
end

local function bindHealth(display, humanoid)
	local fill = findHealthFill(display)

	if fill then
		-- Treat the green frame as the real health fill. At full health it spans the
		-- entire bar, then shrinks from right to left while staying anchored on the left.
		fill.AnchorPoint = Vector2.new(0, fill.AnchorPoint.Y)
		fill.Position = UDim2.new(0, 0, fill.Position.Y.Scale, fill.Position.Y.Offset)
	end

	local function refresh()
		if not display.Parent or not humanoid.Parent then return end
		local maxHealth = math.max(humanoid.MaxHealth, 1)
		local ratio = math.clamp(humanoid.Health / maxHealth, 0, 1)

		if fill and fill.Parent then
			fill.Size = UDim2.new(
				ratio,
				0,
				fill.Size.Y.Scale,
				fill.Size.Y.Offset
			)
		end
		updatePercentText(display, ratio)
	end

	refresh()
	local healthConnection = humanoid:GetPropertyChangedSignal("Health"):Connect(refresh)
	local maxHealthConnection = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(refresh)

	display.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			healthConnection:Disconnect()
			maxHealthConnection:Disconnect()
		end
	end)
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

	local humanoid = model:FindFirstChildOfClass("Humanoid") or model:WaitForChild("Humanoid", 5)
	if not humanoid then
		warn("[EnemyOverhead] " .. model.Name .. " has no Humanoid for the health display")
		return
	end

	local old = head:FindFirstChild("EnemyDisplayAttachement")
	if old then
		old:Destroy()
	end

	local display = displaySource:Clone()
	display.Name = "EnemyDisplayAttachement"

	local verticalOffset = (head.Size.Y * 0.5) + OVERHEAD_CLEARANCE
	if display:IsA("Attachment") then
		display.Position = Vector3.new(0, verticalOffset, 0)
		display.Parent = head
	elseif display:IsA("BillboardGui") then
		display.Adornee = head
		display.StudsOffsetWorldSpace = Vector3.new(0, verticalOffset, 0)
		display.Parent = head
	end

	local displayName = config.DisplayName or config.ModelName or enemyType or model.Name
	setEnemyName(display, displayName)
	setLevelText(display, tonumber(config.Level) or 1)
	bindHealth(display, humanoid)

	-- The custom overhead replaces Roblox's built-in enemy name/health display.
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	model:SetAttribute("EnemyDisplayAttached", true)
end

for _, enemy in ipairs(liveEnemies:GetChildren()) do
	task.spawn(attachDisplay, enemy)
end

liveEnemies.ChildAdded:Connect(function(enemy)
	task.defer(attachDisplay, enemy)
end)
