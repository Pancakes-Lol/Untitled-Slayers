-- Quest tracking UI using the Studio-authored MainUI QuestTrackerFrame.
-- Rebinds to the current PlayerGui copies after respawn so quest state survives UI replacement.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remote = ReplicatedStorage:WaitForChild("QuestUpdate")

local latestData = {Visible = false}

local mainUI
local mainFrame
local questFrame
local questTitleLabel
local questDescriptionLabel
local trackingLabel
local cashLabel
local expLabel
local progressBar
local progressFill
local dialogGui
local dialogConnection

local function disconnectDialogConnection()
	if dialogConnection then
		dialogConnection:Disconnect()
		dialogConnection = nil
	end
end

local function bindCurrentUI()
	local newMainUI = playerGui:FindFirstChild("MainUI") or playerGui:WaitForChild("MainUI", 10)
	if not newMainUI or not newMainUI:IsA("ScreenGui") then
		return false
	end

	local newMainFrame = newMainUI:FindFirstChild("MainFrame") or newMainUI:WaitForChild("MainFrame", 5)
	local newQuestFrame = newMainFrame and (newMainFrame:FindFirstChild("QuestTrackerFrame") or newMainFrame:WaitForChild("QuestTrackerFrame", 5))
	if not newMainFrame or not newQuestFrame then
		return false
	end

	local newTitle = newQuestFrame:FindFirstChild("QuestTitleLabel") or newQuestFrame:WaitForChild("QuestTitleLabel", 5)
	local newDescription = newQuestFrame:FindFirstChild("QuestDescriptionLabel") or newQuestFrame:WaitForChild("QuestDescriptionLabel", 5)
	local newTracking = newQuestFrame:FindFirstChild("TrackingLabel") or newQuestFrame:WaitForChild("TrackingLabel", 5)
	local newCash = newQuestFrame:FindFirstChild("CashLabel") or newQuestFrame:WaitForChild("CashLabel", 5)
	local newEXP = newQuestFrame:FindFirstChild("EXPLabel") or newQuestFrame:WaitForChild("EXPLabel", 5)
	if not newTitle or not newDescription or not newTracking or not newCash or not newEXP then
		return false
	end

	mainUI = newMainUI
	mainFrame = newMainFrame
	questFrame = newQuestFrame
	questTitleLabel = newTitle
	questDescriptionLabel = newDescription
	trackingLabel = newTracking
	cashLabel = newCash
	expLabel = newEXP
	progressBar = questFrame:FindFirstChild("ProgressBar")
	progressFill = progressBar and progressBar:FindFirstChild("ProgressBarFrame")

	mainUI.ResetOnSpawn = false

	local newDialogGui = playerGui:FindFirstChild("DialogUI")
	if newDialogGui and newDialogGui:IsA("ScreenGui") then
		newDialogGui.ResetOnSpawn = false
	end

	if newDialogGui ~= dialogGui then
		disconnectDialogConnection()
		dialogGui = newDialogGui
	end

	return true
end

local function setProgress(progress, amount)
	if not trackingLabel then return end

	progress = tonumber(progress) or 0
	amount = tonumber(amount) or 0
	local ratio = amount > 0 and math.clamp(progress / amount, 0, 1) or 0

	trackingLabel.Text = amount > 0 and string.format("%d / %d", math.clamp(progress, 0, amount), amount) or "0 / 0"

	if progressBar and progressBar:IsA("GuiObject") then
		progressBar.Visible = true
	end
	if progressFill and progressFill:IsA("GuiObject") then
		progressFill.Visible = true
		progressFill.Size = UDim2.new(ratio, 0, 1, 0)
	end
end

local function render(data)
	data = data or latestData or {Visible = false}
	latestData = data

	if not mainUI or mainUI.Parent ~= playerGui or not questFrame or not questFrame.Parent then
		if not bindCurrentUI() then return end
	end

	if data.Visible ~= true then
		questFrame.Visible = false
		return
	end

	if dialogGui and dialogGui.Parent == playerGui and dialogGui.Enabled then
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
		if progressBar and progressBar:IsA("GuiObject") then progressBar.Visible = true end
		if progressFill and progressFill:IsA("GuiObject") then
			progressFill.Visible = true
			progressFill.Size = UDim2.new(1, 0, 1, 0)
		end
	else
		setProgress(data.Progress, data.Amount)
	end

	mainUI.Enabled = true
	mainFrame.Visible = true
	questFrame.Visible = true
end

local function connectDialogWatcher()
	if not dialogGui or dialogConnection then return end
	dialogConnection = dialogGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not questFrame or not questFrame.Parent then
			bindCurrentUI()
		end
		if not questFrame then return end
		if dialogGui.Enabled then
			questFrame.Visible = false
		else
			render(latestData)
		end
	end)
end

local function rebindAndRender()
	if bindCurrentUI() then
		connectDialogWatcher()
		render(latestData)
	end
end

remote.OnClientEvent:Connect(function(data)
	if not mainUI or mainUI.Parent ~= playerGui then
		rebindAndRender()
	end
	render(data)
end)

rebindAndRender()
if questFrame and latestData.Visible ~= true then
	questFrame.Visible = false
end

-- Roblox or another UI script may replace MainUI/DialogUI during respawn.
-- Always bind to the newest copies instead of keeping stale object references.
playerGui.ChildAdded:Connect(function(child)
	if child.Name == "MainUI" or child.Name == "DialogUI" then
		task.defer(rebindAndRender)
	end
end)

player.CharacterAdded:Connect(function()
	for _, delayTime in ipairs({0, 0.15, 0.6, 1.25, 2.0}) do
		task.delay(delayTime, rebindAndRender)
	end
end)
