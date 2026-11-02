-- Quest tracking UI using the Studio-authored MainUI QuestTrackerFrame.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remote = ReplicatedStorage:WaitForChild("QuestUpdate")
local dialogGui = playerGui:FindFirstChild("DialogUI") or playerGui:WaitForChild("DialogUI", 10)

local mainUI = playerGui:WaitForChild("MainUI")
local mainFrame = mainUI:WaitForChild("MainFrame")
local questFrame = mainFrame:WaitForChild("QuestTrackerFrame")

-- Exact Studio-authored labels inside QuestTrackerFrame.
local questTitleLabel = questFrame:WaitForChild("QuestTitleLabel")
local questDescriptionLabel = questFrame:WaitForChild("QuestDescriptionLabel")
local trackingLabel = questFrame:WaitForChild("TrackingLabel")
local cashLabel = questFrame:WaitForChild("CashLabel")
local expLabel = questFrame:WaitForChild("EXPLabel")

local progressBar = questFrame:FindFirstChild("ProgressBar")
local progressFill = progressBar and progressBar:FindFirstChild("ProgressBarFrame")

local latestData = {Visible = false}
questFrame.Visible = false

local function setProgress(progress, amount)
	progress = tonumber(progress) or 0
	amount = tonumber(amount) or 0

	if amount <= 0 then
		trackingLabel.Text = "0 / 0"
		if progressFill and progressFill:IsA("GuiObject") then
			progressFill.Size = UDim2.new(0, 0, progressFill.Size.Y.Scale, progressFill.Size.Y.Offset)
		end
		return
	end

	local clampedProgress = math.clamp(progress, 0, amount)
	trackingLabel.Text = string.format("%d / %d", clampedProgress, amount)

	if progressFill and progressFill:IsA("GuiObject") then
		local ratio = clampedProgress / amount
		progressFill.Size = UDim2.new(ratio, 0, progressFill.Size.Y.Scale, progressFill.Size.Y.Offset)
	end
end

local function render(data)
	data = data or {}

	-- QuestTrackerFrame should only ever be visible for an explicitly active quest.
	if data.Visible ~= true then
		questFrame.Visible = false
		return
	end

	if dialogGui and dialogGui.Enabled then
		questFrame.Visible = false
		return
	end

	questTitleLabel.Text = tostring(data.Title or "Quest")
	questDescriptionLabel.Text = tostring(data.Description or "")

	local rewards = type(data.Rewards) == "table" and data.Rewards or {}
	cashLabel.Text = tostring(tonumber(rewards.Cash) or 0)
	expLabel.Text = tostring(tonumber(rewards.XP) or 0)

	if data.Complete then
		trackingLabel.Text = "Complete - Return to Tetsu"
		if progressFill and progressFill:IsA("GuiObject") then
			progressFill.Size = UDim2.new(1, 0, progressFill.Size.Y.Scale, progressFill.Size.Y.Offset)
		end
	else
		setProgress(data.Progress, data.Amount)
	end

	mainUI.Enabled = true
	mainFrame.Visible = true
	questFrame.Visible = true
end

remote.OnClientEvent:Connect(function(data)
	latestData = data or {Visible = false}
	render(latestData)
end)

if dialogGui then
	dialogGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if dialogGui.Enabled then
			questFrame.Visible = false
		else
			render(latestData)
		end
	end)
end
