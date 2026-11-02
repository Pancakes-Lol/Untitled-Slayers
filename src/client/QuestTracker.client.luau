-- Quest tracking UI. Uses an existing quest ScreenGui when present, otherwise builds a lightweight fallback.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remote = ReplicatedStorage:WaitForChild("QuestUpdate")

local function findExistingGui()
	for _, name in ipairs({"QuestUI", "QuestTrackerUI", "QuestTrackingUI", "QuestTracker"}) do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("ScreenGui") then return gui end
	end
	return nil
end

local function findText(root, names)
	for _, name in ipairs(names) do
		local obj = root:FindFirstChild(name, true)
		if obj and (obj:IsA("TextLabel") or obj:IsA("TextButton")) then return obj end
	end
	return nil
end

local function buildFallback()
	local gui = Instance.new("ScreenGui")
	gui.Name = "QuestTrackerUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Enabled = false
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "TrackerFrame"
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -24, 0, 110)
	frame.Size = UDim2.fromOffset(330, 154)
	frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local function label(name, size, transparency)
		local text = Instance.new("TextLabel")
		text.Name = name
		text.Size = UDim2.new(1, 0, 0, size)
		text.BackgroundTransparency = 1
		text.TextColor3 = Color3.fromRGB(245, 245, 245)
		text.TextTransparency = transparency or 0
		text.Font = Enum.Font.GothamMedium
		text.TextSize = name == "QuestTitle" and 19 or 15
		text.TextWrapped = true
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextYAlignment = Enum.TextYAlignment.Top
		text.Parent = frame
		return text
	end

	label("QuestTitle", 24)
	label("QuestDescription", 42, 0.08)
	label("QuestProgress", 24)
	label("QuestRewards", 30, 0.15)
	return gui
end

local gui = findExistingGui() or buildFallback()
local titleLabel = findText(gui, {"QuestTitle", "Title", "QuestName"})
local descriptionLabel = findText(gui, {"QuestDescription", "Description", "QuestText"})
local progressLabel = findText(gui, {"QuestProgress", "Progress", "Amount"})
local rewardsLabel = findText(gui, {"QuestRewards", "Rewards", "RewardText"})

local function rewardText(rewards)
	if type(rewards) ~= "table" then return "" end
	local pieces = {}
	if tonumber(rewards.XP) and rewards.XP > 0 then table.insert(pieces, tostring(rewards.XP) .. " XP") end
	if tonumber(rewards.Cash) and rewards.Cash > 0 then table.insert(pieces, "$" .. tostring(rewards.Cash)) end
	if type(rewards.Materials) == "table" then
		for material, amount in pairs(rewards.Materials) do
			if tonumber(amount) and amount > 0 then table.insert(pieces, tostring(amount) .. "x " .. tostring(material)) end
		end
	end
	return table.concat(pieces, "  •  ")
end

local function setText(label, value)
	if label then label.Text = tostring(value or "") end
end

remote.OnClientEvent:Connect(function(data)
	data = data or {}
	if data.Visible == false then
		gui.Enabled = false
		return
	end

	setText(titleLabel, data.Title or "Quest")
	setText(descriptionLabel, data.Description or "")
	if data.Complete then
		setText(progressLabel, "Complete — return to Tetsu")
	else
		setText(progressLabel, string.format("%d / %d", tonumber(data.Progress) or 0, tonumber(data.Amount) or 0))
	end
	setText(rewardsLabel, rewardText(data.Rewards))
	gui.Enabled = true
end)
