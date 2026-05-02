local function getService(serviceName)
    return cloneref(game:GetService(serviceName))
end

local Players = getService("Players")
local RunService = getService("RunService")
local Teams = getService("Teams")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Aimbot = {
    Settings = {
        Smoothness = 8,
        CurrentMode = "mousemoverel",
        AimMode = "FOV",
        WallCheck = true,
        TargetPart = "Head",
        TeamCheck = true,
        BlacklistTeam = {},
        StickyAim = true,
        Prediction = true
    },

    FOVSettings = {
        Radius = 200,
        ShowCircle = true,
        CircleColor = Color3.new(1, 0, 0),
        CircleTransparency = 0.5
    },

    AimbotConnection = nil,
    FOVCircle = nil,
    CurrentTarget = nil,
}

local function getTargetPart(character)
    if not character then
        return nil
    end

    local targetPartName = Aimbot.Settings.TargetPart

    local part = character:FindFirstChild(targetPartName)

    if part then
        return part
    end

    if targetPartName == "Head" then
        return character:WaitForChild("Head", 0.2)
    end

    return character:FindFirstChild("Head")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("LowerTorso")
end

local function isAlive(character)
    if not character then
        return false
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return false
    end

    return humanoid.Health > 0
end

local function getPredictedPosition(part)
    if not Aimbot.Settings.Prediction then
        return part.Position
    end

    local velocity = part.Velocity
    local distance = (Camera.CFrame.Position - part.Position).Magnitude

    local predictionTime = distance / 100

    return part.Position + (velocity * predictionTime)
end

local function isVisible(targetPosition)
    local character = LocalPlayer.Character
    if not character then
        return false
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then
        return false
    end

    local origin = root.Position

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {character, Camera}

    local result = workspace:Raycast(origin, targetPosition - origin, rayParams)

    if not result then
        return true
    end

    local hitModel = result.Instance:FindFirstAncestorWhichIsA("Model")

    if hitModel and hitModel:FindFirstChild("Humanoid") then
        local player = Players:GetPlayerFromCharacter(hitModel)
        if player then
            return true
        end
    end

    return false
end

local function getMousePosition()
    local mouse = LocalPlayer:GetMouse()
    return Vector2.new(mouse.X, mouse.Y)
end

local function isValidTarget(player)
    if player == LocalPlayer then
        return false
    end

    local character = player.Character
    if not isAlive(character) then
        return false
    end

    if Aimbot.Settings.TeamCheck then
        if player.Team == LocalPlayer.Team then
            return false
        end
    end

    if player.Team and Aimbot.Settings.BlacklistTeam[player.Team] then
        return false
    end

    return true
end

local function getClosestTargetInFOV()
    local closestPlayer = nil
    local closestDistance = math.huge

    local mousePos = getMousePosition()
    local fovRadius = Aimbot.FOVSettings.Radius

    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return nil
    end

    for _, player in pairs(Players:GetPlayers()) do
        if isValidTarget(player) then
            local targetCharacter = player.Character

            if targetCharacter and isAlive(targetCharacter) then
                local targetPart = getTargetPart(targetCharacter)

                if targetPart then
                    local screenPos, onScreen =
                        Camera:WorldToScreenPoint(targetPart.Position)

                    if onScreen then
                        local point2D = Vector2.new(screenPos.X, screenPos.Y)
                        local distance = (point2D - mousePos).Magnitude

                        if distance <= fovRadius and distance < closestDistance then
                            if not Aimbot.Settings.WallCheck
                                or isVisible(targetPart.Position) then
                                closestDistance = distance
                                closestPlayer = player
                            end
                        end
                    end
                end
            end
        end
    end

    return closestPlayer, closestDistance
end

local function getNearestTarget()
    local closestPlayer = nil
    local closestDistance = math.huge

    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return nil
    end

    local myPosition = character.HumanoidRootPart.Position

    for _, player in pairs(Players:GetPlayers()) do
        if isValidTarget(player) then
            local targetCharacter = player.Character

            if targetCharacter and isAlive(targetCharacter) then
                local targetPart = getTargetPart(targetCharacter)

                if targetPart then
                    local distance =
                        (targetPart.Position - myPosition).Magnitude

                    local visible = true

                    if Aimbot.Settings.WallCheck then
                        visible = isVisible(targetPart.Position)
                    end

                    if distance < closestDistance and visible then
                        closestDistance = distance
                        closestPlayer = player
                    end
                end
            end
        end
    end

    return closestPlayer, closestDistance
end

local function getCurrentTarget()
    if Aimbot.Settings.StickyAim and Aimbot.CurrentTarget then
        if isValidTarget(Aimbot.CurrentTarget) then
            local char = Aimbot.CurrentTarget.Character
            if char and isAlive(char) then
                return Aimbot.CurrentTarget
            end
        end
        Aimbot.CurrentTarget = nil
    end

    local target

    if Aimbot.Settings.AimMode == "FOV" then
        target = getClosestTargetInFOV()
    else
        target = getNearestTarget()
    end

    if Aimbot.Settings.StickyAim then
        Aimbot.CurrentTarget = target
    end

    return target
end

local function aimAt(position)
    local mode = string.lower(Aimbot.Settings.CurrentMode)

    if mode == "camera" then
        Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, position)
    elseif mode == "mousemoverel" then
        local screenPos, onScreen = Camera:WorldToViewportPoint(position)
        if not onScreen then
            return
        end

        local viewport = Camera.ViewportSize
        local center = Vector2.new(viewport.X / 2, viewport.Y / 2)

        local deltaX = screenPos.X - center.X
        local deltaY = screenPos.Y - center.Y

        local distance =
            (Camera.CFrame.Position - position).Magnitude

        local scale = math.clamp(distance / 25, 1, 6)

        local smoothness = math.max(Aimbot.Settings.Smoothness, 1)

        deltaX = (deltaX * scale) / smoothness
        deltaY = (deltaY * scale) / smoothness

        mousemoverel(deltaX, deltaY)
    end
end

local function updateAimbot()
    local targetPlayer = getCurrentTarget()
    if not targetPlayer then
        return
    end

    local character = targetPlayer.Character
    if not character then
        character = targetPlayer.CharacterAdded:Wait()
    end

    local targetPart = getTargetPart(character)
    if not targetPart then
        return
    end

    if Aimbot.Settings.WallCheck
        and not isVisible(targetPart.Position) then
        return
    end

    local predictedPosition = getPredictedPosition(targetPart)
    aimAt(predictedPosition)
end

local function createFOVCircle()
    if not Aimbot.FOVSettings.ShowCircle then
        return
    end

    if Aimbot.FOVCircle then
        Aimbot.FOVCircle:Remove()
        Aimbot.FOVCircle = nil
    end

    local success, DrawingLib = pcall(function()
        return Drawing
    end)

    if not success then
        return
    end

    local circle = DrawingLib.new("Circle")
    circle.Visible = true
    circle.Filled = false
    circle.Thickness = 2
    circle.Radius = Aimbot.FOVSettings.Radius
    circle.Color = Aimbot.FOVSettings.CircleColor
    circle.Transparency = Aimbot.FOVSettings.CircleTransparency

    Aimbot.FOVCircle = circle

    if Aimbot.FOVConnection then
        Aimbot.FOVConnection:Disconnect()
    end

    Aimbot.FOVConnection = RunService.RenderStepped:Connect(function()
        if not Aimbot.FOVCircle then
            return
        end

        local mouse = LocalPlayer:GetMouse()

        Aimbot.FOVCircle.Position = Vector2.new(mouse.X, mouse.Y)
        Aimbot.FOVCircle.Radius = Aimbot.FOVSettings.Radius
        Aimbot.FOVCircle.Visible = Aimbot.FOVSettings.ShowCircle
    end)
end

local function removeFOVCircle()
    if Aimbot.FOVConnection then
        Aimbot.FOVConnection:Disconnect()
        Aimbot.FOVConnection = nil
    end

    if Aimbot.FOVCircle then
        Aimbot.FOVCircle:Remove()
        Aimbot.FOVCircle = nil
    end
end

local function startAimbot()
    if Aimbot.AimbotConnection then
        return
    end

    Aimbot.AimbotConnection = RunService.RenderStepped:Connect(updateAimbot)
end

local function stopAimbot()
    if Aimbot.AimbotConnection then
        Aimbot.AimbotConnection:Disconnect()
        Aimbot.AimbotConnection = nil
    end
end

function Aimbot:Start()
    createFOVCircle()
    startAimbot()
end

function Aimbot:Stop()
    stopAimbot()
    removeFOVCircle()
end

function Aimbot:UpdateSettings(key, value)
    if self.Settings[key] ~= nil then
        self.Settings[key] = value
        return true
    end

    return false
end

function Aimbot:UpdateFov(key, value)
    if self.FOVSettings[key] ~= nil then
        self.FOVSettings[key] = value

        if key == "Radius" and self.FOVCircle then
            self.FOVCircle.Radius = value
        elseif key == "ShowCircle" and self.FOVCircle then
            self.FOVCircle.Visible = value
        end

        return true
    end

    return false
end

function Aimbot:blacklistTeam(teamName)
    if typeof(teamName) ~= "string" then
        return false
    end

    local teamInstance = Teams:FindFirstChild(teamName)
    if not teamInstance then
        return false
    end

    self.Settings.BlacklistTeam[teamInstance] = true
    return true
end

function Aimbot:unblacklistTeam(teamName)
    if typeof(teamName) ~= "string" then
        return false
    end

    local teamInstance = Teams:FindFirstChild(teamName)
    if not teamInstance then
        return false
    end

    self.Settings.BlacklistTeam[teamInstance] = nil
    return true
end

return Aimbot
