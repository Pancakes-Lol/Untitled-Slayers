-- Visible overhead Slayer Name tag for all players, including the local player.
local Players = game:GetService("Players")

local function attachTag(player, character)
	local head = character:WaitForChild("Head", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not head or not humanoid then return end
	if player.Character ~= character then return end

	-- Hide Roblox's default name to prevent duplicate labels.
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local old = head:FindFirstChild("SlayerOverheadTag")
	if old then old:Destroy() end

	local gui = Instance.new("BillboardGui")
	gui.Name = "SlayerOverheadTag"
	gui.Adornee = head
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(220, 66)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.7, 0)
	gui.MaxDistance = 110
	gui.ResetOnSpawn = false
	gui.Parent = head

	local name = Instance.new("TextLabel")
	name.Name = "SlayerName"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 34)
	name.Position = UDim2.fromOffset(0, 0)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 19
	name.TextColor3 = Color3.fromRGB(247, 240, 255)
	name.TextStrokeColor3 = Color3.fromRGB(18, 14, 34)
	name.TextStrokeTransparency = 0.25
	name.TextScaled = false
	name.Text = player:GetAttribute("SlayerName") or player.DisplayName
	name.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "SlayerTitle"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 25)
	title.Position = UDim2.fromOffset(0, 32)
	title.Font = Enum.Font.GothamSemibold
	title.TextSize = 13
	title.TextColor3 = Color3.fromRGB(186, 165, 255)
	title.TextStrokeColor3 = Color3.fromRGB(18, 14, 34)
	title.TextStrokeTransparency = 0.3
	title.Text = "NOVICE SLAYER"
	title.Parent = gui

	local connection
	connection = player:GetAttributeChangedSignal("SlayerName"):Connect(function()
		if not gui.Parent then
			connection:Disconnect()
			return
		end
		name.Text = player:GetAttribute("SlayerName") or player.DisplayName
	end)
	gui.Destroying:Connect(function()
		if connection then connection:Disconnect() end
	end)
end

local function onPlayer(player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(attachTag, player, character)
	end)
	if player.Character then
		task.spawn(attachTag, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end
