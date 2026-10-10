--[[
    MOCHICLUB EGG VIEWER
    COMPACT LANDSCAPE EGG UI WITH EGG & VISUAL TABS (RED GLOW THEME)
    v5: Banner wallpaper + floating dots
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--==================================================
-- ANTI-DEATH / BYPASS TP (FROM tp.txt)
-- Humanoid swap + anti-die. Self-contained (own scope)
-- so it adds NO extra main-chunk locals.
-- Auto-ON on load and on every respawn.
--==================================================

pcall(function()
    shared.MochiBypass = (function()
        local Enabled = true
        local AntiDieConnections = {}
        local StashedHumanoids = {}

        -- Safety net every frame: if the current Humanoid drops to 0 HP
        -- (e.g. during a long teleport), refill it before Died can finish.
        RunService.Heartbeat:Connect(function()
            if not Enabled then return end
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            if h and h.MaxHealth > 0 and h.Health <= 0 then
                pcall(function() h.Health = h.MaxHealth end)
            end
        end)

        local function DisconnectAntiDie()
            for _, connection in ipairs(AntiDieConnections) do
                pcall(function() connection:Disconnect() end)
            end
            table.clear(AntiDieConnections)
        end

        local function GetCharacter()
            return LocalPlayer.Character
        end

        local function RestoreNormalHumanoid()
            local character = GetCharacter()
            if not character then return end

            DisconnectAntiDie()

            local stashed = StashedHumanoids[character]
            local current = character:FindFirstChildOfClass("Humanoid")

            if stashed and not stashed:IsDescendantOf(game) and stashed.Parent ~= nil then
                stashed = nil
            end

            local target = stashed

            if not target then
                local old = character:FindFirstChild("_OldHumanoid")
                local replaced = character:FindFirstChild("ReplacedHumanoid")
                if old and old:IsA("Humanoid") then
                    target = old
                elseif replaced and replaced:IsA("Humanoid") then
                    target = replaced
                end
            end

            if not target then target = current end
            if not target then return end

            for _, obj in ipairs(character:GetChildren()) do
                if obj:IsA("Humanoid") and obj ~= target then
                    pcall(function() obj:Destroy() end)
                end
            end

            target.Name = "Humanoid"
            target:SetAttribute("VxzBypassHumanoid", nil)

            if target.Parent ~= character then
                target.Parent = character
            end

            pcall(function()
                target:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
                target.BreakJointsOnDeath = true
                target.Enabled = true
            end)

            if target.Health <= 0 then
                pcall(function() target.Health = target.MaxHealth end)
            end

            local camera = workspace.CurrentCamera
            if camera then camera.CameraSubject = target end

            local animate = character:FindFirstChild("Animate")
            if animate and animate:IsA("LocalScript") then
                animate.Disabled = false
            end

            StashedHumanoids[character] = nil
        end

        local function CreateBypassHumanoid(character)
            if not character then return nil end

            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid then return nil end

            if humanoid:GetAttribute("VxzBypassHumanoid") == true then
                return humanoid
            end

            local animate = character:FindFirstChild("Animate")

            local walkSpeed = humanoid.WalkSpeed
            local jumpPower = humanoid.JumpPower
            local jumpHeight = humanoid.JumpHeight
            local maxHealth = humanoid.MaxHealth
            local health = humanoid.Health
            local autoRotate = humanoid.AutoRotate

            local animator = humanoid:FindFirstChildOfClass("Animator")
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    pcall(function() track:Stop(0) end)
                end
            end

            if animate and animate:IsA("LocalScript") then
                animate.Disabled = true
            end

            humanoid.Archivable = true

            local clone
            local success = pcall(function()
                clone = humanoid:Clone()
            end)

            if not success or not clone then
                if animate and animate:IsA("LocalScript") then
                    animate.Disabled = false
                end
                return nil
            end

            clone.Name = "_BypassHumanoid"
            clone:SetAttribute("VxzBypassHumanoid", true)

            for _, object in ipairs(clone:GetChildren()) do
                if object:IsA("Animator") then
                    object:Destroy()
                end
            end

            pcall(function()
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
                humanoid.BreakJointsOnDeath = false
                humanoid.Enabled = false
            end)

            humanoid.Name = "_OldHumanoid"
            humanoid:SetAttribute("VxzBypassHumanoid", nil)

            StashedHumanoids[character] = humanoid
            humanoid.Parent = nil

            clone.Name = "Humanoid"
            clone.Parent = character

            clone.WalkSpeed = walkSpeed
            clone.JumpPower = jumpPower
            clone.JumpHeight = jumpHeight
            clone.MaxHealth = maxHealth
            clone.Health = math.clamp(health, 0, maxHealth)
            clone.AutoRotate = autoRotate

            local newAnimator = Instance.new("Animator")
            newAnimator.Parent = clone

            local camera = workspace.CurrentCamera
            if camera then camera.CameraSubject = clone end

            if animate and animate:IsA("LocalScript") then
                task.defer(function()
                    if animate.Parent and Enabled then
                        animate.Disabled = false
                        task.wait()
                        if animate.Parent and Enabled then
                            animate.Disabled = true
                            task.wait()
                            if animate.Parent and Enabled then
                                animate.Disabled = false
                            end
                        end
                    end
                end)
            end

            return clone
        end

        local function ActivateAntiDie()
            if not Enabled then return end

            DisconnectAntiDie()

            local character = GetCharacter()
            if not character then return end

            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid then return end

            humanoid:SetAttribute("VxzBypassHumanoid", true)

            pcall(function()
                humanoid.BreakJointsOnDeath = false
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            end)

            local healthConnection = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
                if not Enabled then return end
                if humanoid.Parent and humanoid.Health <= 0 then
                    pcall(function() humanoid.Health = humanoid.MaxHealth end)
                end
            end)
            table.insert(AntiDieConnections, healthConnection)

            local diedConnection = humanoid.Died:Connect(function()
                if not Enabled then return end
                task.defer(function()
                    if not Enabled then return end
                    local currentCharacter = GetCharacter()
                    if not currentCharacter or currentCharacter ~= character or not currentCharacter.Parent then
                        return
                    end
                    local currentHumanoid = currentCharacter:FindFirstChildOfClass("Humanoid")
                    if currentHumanoid and currentHumanoid ~= humanoid then
                        return
                    end
                    local newHumanoid = Instance.new("Humanoid")
                    newHumanoid.Name = "ReplacedHumanoid"
                    newHumanoid:SetAttribute("VxzBypassHumanoid", true)
                    newHumanoid.Parent = currentCharacter
                    pcall(function()
                        newHumanoid.BreakJointsOnDeath = false
                        newHumanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
                    end)
                    local camera = workspace.CurrentCamera
                    if camera then camera.CameraSubject = newHumanoid end
                    pcall(function() humanoid:Destroy() end)
                    ActivateAntiDie()
                end)
            end)
            table.insert(AntiDieConnections, diedConnection)
        end

        local function ActivateBypass()
            if not Enabled then return end
            local character = GetCharacter()
            if not character then return end
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid then return end
            if humanoid.Name == "Humanoid" and humanoid:GetAttribute("VxzBypassHumanoid") ~= true then
                CreateBypassHumanoid(character)
            end
            ActivateAntiDie()
        end

        LocalPlayer.CharacterAdded:Connect(function(character)
            if not Enabled then return end
            task.spawn(function()
                local humanoid = character:WaitForChild("Humanoid", 5)
                if not humanoid then return end
                task.wait(0.15)
                if Enabled and LocalPlayer.Character == character then
                    ActivateBypass()
                end
            end)
        end)

        LocalPlayer.CharacterRemoving:Connect(function(character)
            if StashedHumanoids[character] then
                pcall(function() StashedHumanoids[character]:Destroy() end)
                StashedHumanoids[character] = nil
            end
        end)

        task.spawn(function()
            task.wait(0.2)
            if Enabled then ActivateBypass() end
        end)

        return {
            Activate = ActivateBypass,
            Set = function(state)
                Enabled = state == true
                if Enabled then
                    ActivateBypass()
                else
                    RestoreNormalHumanoid()
                end
            end,
        }
    end)()
end)

--==================================================
-- JUMP FIX
-- The bypass swaps the character's Humanoid object, but the
-- default PlayerModule controls keep a reference to the OLD
-- Humanoid (which is disabled), so jump presses did nothing.
-- Every jump request now goes to the CURRENT Humanoid.
--==================================================

local BLOCKED_JUMP_STATES = {
    [Enum.HumanoidStateType.Dead] = true,
    [Enum.HumanoidStateType.Seated] = true,
    [Enum.HumanoidStateType.Physics] = true,
    [Enum.HumanoidStateType.Ragdoll] = true,
    [Enum.HumanoidStateType.FallingDown] = true,
    [Enum.HumanoidStateType.PlatformStanding] = true,
}

local function DoJump()
    local character = LocalPlayer.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    if BLOCKED_JUMP_STATES[humanoid:GetState()] then return end

    humanoid.Jump = true
    pcall(function()
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end)
end

UserInputService.JumpRequest:Connect(DoJump)

-- Mobile jump button (the green up arrow). The default touch jump
-- does NOT fire JumpRequest, so hook the button itself.
local JumpButtonsHooked = setmetatable({}, { __mode = "k" })

local function HookJumpButton(obj)
    if not obj:IsA("GuiButton") then return end
    if obj.Name ~= "JumpButton" then return end
    if JumpButtonsHooked[obj] then return end
    JumpButtonsHooked[obj] = true

    obj.MouseButton1Down:Connect(DoJump)
end

local function ScanJumpButtons(root)
    for _, obj in ipairs(root:GetDescendants()) do
        HookJumpButton(obj)
    end
end

ScanJumpButtons(PlayerGui)
PlayerGui.DescendantAdded:Connect(HookJumpButton)

--==================================================
-- REMOVE OLD UI
--==================================================

local old = PlayerGui:FindFirstChild("EggViewerUI")
if old then old:Destroy() end

local oldToggle = PlayerGui:FindFirstChild("EggViewerToggleUI")
if oldToggle then oldToggle:Destroy() end

local oldStats = PlayerGui:FindFirstChild("EggViewerStatsUI")
if oldStats then oldStats:Destroy() end

for _, notifyName in ipairs({ "EggViewerNotifyUI" }) do
    local oldNotify = PlayerGui:FindFirstChild(notifyName)
    if oldNotify then oldNotify:Destroy() end
end

--==================================================
-- SAFE REQUIRE
--==================================================

local function SafeRequire(path)
    local current = ReplicatedStorage

    for _, name in ipairs(path) do
        current = current:WaitForChild(name, 10)

        if not current then
            return nil
        end
    end

    local ok, result = pcall(require, current)

    if ok then
        return result
    end

    return nil
end

--==================================================
-- MODULES
--==================================================

local EggState =
    SafeRequire({
        "Client",
        "EggState"
    })

local Assets =
    SafeRequire({
        "Data",
        "Assets"
    })

local EggRecords =
    SafeRequire({
        "Shared",
        "Util",
        "EggRecords"
    })

local Mutations =
    SafeRequire({
        "Shared",
        "Modules",
        "Mutations"
    })

--==================================================
-- GUI
--==================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "EggViewerUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior =
    Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = PlayerGui

--==================================================
-- FLOATING STATS BOX
--==================================================

local StatsGui = Instance.new("ScreenGui")
StatsGui.Name = "EggViewerStatsUI"
StatsGui.ResetOnSpawn = false
StatsGui.IgnoreGuiInset = true
StatsGui.ZIndexBehavior =
    Enum.ZIndexBehavior.Sibling
StatsGui.DisplayOrder = 999998
StatsGui.Parent = PlayerGui

local StatsBox = Instance.new("Frame")
StatsBox.Name = "StatsBox"
StatsBox.Size =
    UDim2.fromOffset(130, 26)
StatsBox.Position =
    UDim2.new(0.5, -65, 0, 10)
StatsBox.BackgroundColor3 =
    Color3.fromRGB(30, 30, 35)
StatsBox.BackgroundTransparency = 0.5
StatsBox.BorderSizePixel = 0
StatsBox.Visible = false
StatsBox.Parent = StatsGui

local StatsBoxCorner =
    Instance.new("UICorner")

StatsBoxCorner.CornerRadius =
    UDim.new(0, 5)

StatsBoxCorner.Parent =
    StatsBox

local StatsBoxStroke =
    Instance.new("UIStroke")

StatsBoxStroke.Thickness = 1.5
StatsBoxStroke.Color =
    Color3.fromRGB(255, 50, 50)
StatsBoxStroke.Transparency = 0.2
StatsBoxStroke.Parent = StatsBox

local PingIcon =
    Instance.new("ImageLabel")

PingIcon.Name = "PingIcon"
PingIcon.Size =
    UDim2.fromOffset(14, 14)

PingIcon.Position =
    UDim2.new(0, 6, 0.5, -7)

PingIcon.BackgroundTransparency = 1
PingIcon.Image =
    "rbxassetid://11419714892"

PingIcon.ImageColor3 =
    Color3.fromRGB(255, 100, 100)

PingIcon.Parent = StatsBox

local PingLabel =
    Instance.new("TextLabel")

PingLabel.Name = "PingLabel"
PingLabel.Size =
    UDim2.fromOffset(50, 20)

PingLabel.Position =
    UDim2.new(0, 22, 0.5, -10)

PingLabel.BackgroundTransparency = 1
PingLabel.Text = "0ms"

PingLabel.TextColor3 =
    Color3.fromRGB(255, 180, 180)

PingLabel.Font =
    Enum.Font.GothamBold

PingLabel.TextSize = 9

PingLabel.TextXAlignment =
    Enum.TextXAlignment.Left

PingLabel.Parent = StatsBox

local Divider =
    Instance.new("Frame")

Divider.Size =
    UDim2.fromOffset(1, 14)

Divider.Position =
    UDim2.new(0.5, -0.5, 0.5, -7)

Divider.BackgroundColor3 =
    Color3.fromRGB(255, 50, 50)

Divider.BackgroundTransparency = 0.4
Divider.BorderSizePixel = 0
Divider.Parent = StatsBox

local FpsIcon =
    Instance.new("ImageLabel")

FpsIcon.Name = "FpsIcon"
FpsIcon.Size =
    UDim2.fromOffset(14, 14)

FpsIcon.Position =
    UDim2.new(0.5, 8, 0.5, -7)

FpsIcon.BackgroundTransparency = 1
FpsIcon.Image =
    "rbxassetid://11419708779"

FpsIcon.ImageColor3 =
    Color3.fromRGB(255, 100, 100)

FpsIcon.Parent = StatsBox

local FpsLabel =
    Instance.new("TextLabel")

FpsLabel.Name = "FpsLabel"
FpsLabel.Size =
    UDim2.fromOffset(50, 20)

FpsLabel.Position =
    UDim2.new(0.5, 24, 0.5, -10)

FpsLabel.BackgroundTransparency = 1
FpsLabel.Text = "0 FPS"

FpsLabel.TextColor3 =
    Color3.fromRGB(255, 180, 180)

FpsLabel.Font =
    Enum.Font.GothamBold

FpsLabel.TextSize = 9

FpsLabel.TextXAlignment =
    Enum.TextXAlignment.Left

FpsLabel.Parent = StatsBox

--==================================================
-- STATS DRAG
--==================================================

local statsDragging = false
local statsDragStart
local statsStartPos

StatsBox.InputBegan:Connect(
    function(input)

        if input.UserInputType ==
            Enum.UserInputType.MouseButton1
            or input.UserInputType ==
            Enum.UserInputType.Touch then

            statsDragging = true
            statsDragStart = input.Position
            statsStartPos = StatsBox.Position

            input.Changed:Connect(
                function()

                    if input.UserInputState ==
                        Enum.UserInputState.End then

                        statsDragging = false
                    end
                end
            )
        end
    end
)

UserInputService.InputChanged:Connect(
    function(input)

        if not statsDragging then
            return
        end

        if input.UserInputType ~=
            Enum.UserInputType.MouseMovement
            and input.UserInputType ~=
            Enum.UserInputType.Touch then

            return
        end

        local delta =
            input.Position - statsDragStart

        StatsBox.Position =
            UDim2.new(
                statsStartPos.X.Scale,
                statsStartPos.X.Offset
                    + delta.X,

                statsStartPos.Y.Scale,
                statsStartPos.Y.Offset
                    + delta.Y
            )
    end
)

--==================================================
-- FPS & PING
--==================================================

local lastTick = tick()
local frameCount = 0

RunService.RenderStepped:Connect(
    function()

        frameCount += 1

        local currentTick = tick()

        if currentTick - lastTick >= 0.5 then

            local fps =
                math.round(
                    frameCount
                    / (currentTick - lastTick)
                )

            if StatsBox.Visible then

                FpsLabel.Text =
                    fps .. " FPS"

                local pingVal = 0

                pcall(
                    function()
                        pingVal =
                            math.round(
                                LocalPlayer:
                                GetNetworkPing()
                                * 1000
                            )
                    end
                )

                PingLabel.Text =
                    pingVal .. "ms"
            end

            frameCount = 0
            lastTick = currentTick
        end
    end
)

--==================================================
-- TOGGLE / LOGO
--==================================================

local ToggleGui =
    Instance.new("ScreenGui")

ToggleGui.Name =
    "EggViewerToggleUI"

ToggleGui.ResetOnSpawn = false
ToggleGui.IgnoreGuiInset = true

ToggleGui.ZIndexBehavior =
    Enum.ZIndexBehavior.Sibling

ToggleGui.DisplayOrder = 1000000
ToggleGui.Parent = PlayerGui

local ToggleButton =
    Instance.new("ImageButton")

ToggleButton.Name =
    "ToggleButton"

ToggleButton.Size =
    UDim2.fromOffset(42, 42)

ToggleButton.Position =
    UDim2.new(1, -56, 0.5, -150)

ToggleButton.BackgroundTransparency = 0.2

ToggleButton.BackgroundColor3 =
    Color3.fromRGB(35, 35, 40)

ToggleButton.Image =
    "rbxassetid://134755717495073"

ToggleButton.ScaleType =
    Enum.ScaleType.Stretch

ToggleButton.BorderSizePixel = 0
ToggleButton.Parent = ToggleGui

-- Logo polish: fill the circle, round it, and add a pulsing blue glow ring
ToggleButton.Size = UDim2.fromOffset(48, 48)
ToggleButton.ScaleType = Enum.ScaleType.Crop
do
    local round = Instance.new("UICorner")
    round.CornerRadius = UDim.new(1, 0)
    round.Parent = ToggleButton

    local ring = Instance.new("UIStroke")
    ring.Name = "LogoGlow"
    ring.Color = Color3.fromRGB(198, 35, 45) -- matches MochiClub title bar
    ring.Thickness = 2.5
    ring.Parent = ToggleButton

    task.spawn(function()
        while ToggleButton.Parent do
            ring.Transparency = 0.2 + (math.sin(os.clock() * 2.5) + 1) * 0.2
            task.wait(1 / 30)
        end
    end)
end

local ToggleCorner =
    Instance.new("UICorner")

ToggleCorner.CornerRadius =
    UDim.new(0, 6)

ToggleCorner.Parent =
    ToggleButton

local ToggleStroke =
    Instance.new("UIStroke")

ToggleStroke.Thickness = 2
ToggleStroke.Color =
    Color3.fromRGB(255, 30, 30)

ToggleStroke.Parent =
    ToggleButton

--==================================================
-- MAIN FRAME
--==================================================

local Main =
    Instance.new("Frame")

Main.Name = "EggPanel"

Main.Size =
    UDim2.fromOffset(305, 330)

Main.Position =
    UDim2.new(
        1,
        -320,
        0.5,
        -165
    )

Main.BackgroundColor3 =
    Color3.fromRGB(13, 15, 21)

Main.BackgroundTransparency = 0.12
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = ScreenGui

local MainCorner =
    Instance.new("UICorner")

MainCorner.CornerRadius =
    UDim.new(0, 8)

MainCorner.Parent = Main

local MainStroke =
    Instance.new("UIStroke")

MainStroke.Thickness = 1.5
MainStroke.Color =
    Color3.fromRGB(220, 55, 65)

MainStroke.Transparency = 0.28
MainStroke.Parent = Main

--==================================================
-- WALLPAPER
--==================================================

local Wallpaper =
    Instance.new("ImageLabel")

Wallpaper.Name =
    "Wallpaper"

Wallpaper.AnchorPoint =
    Vector2.new(0, 0)

Wallpaper.Position =
    UDim2.fromOffset(0, 0)

Wallpaper.Size =
    UDim2.new(1, 0, 1, 0)

Wallpaper.BackgroundTransparency = 1
Wallpaper.BorderSizePixel = 0

Wallpaper.Image =
    "rbxassetid://101941202704989"
Wallpaper.ImageTransparency = 0.28

Wallpaper.ScaleType =
    Enum.ScaleType.Crop

Wallpaper.ClipsDescendants = true
Wallpaper.ZIndex = 0
Wallpaper.Parent = Main

local WallpaperCorner =
    Instance.new("UICorner")

WallpaperCorner.CornerRadius =
    UDim.new(0, 8)

WallpaperCorner.Parent =
    Wallpaper

-- Dark glass veil keeps the wallpaper visible without competing
-- with the actual Egg information.
local GlassVeil = Instance.new("Frame")
GlassVeil.Name = "GlassVeil"
GlassVeil.Size = UDim2.new(1, 0, 1, 0)
GlassVeil.BackgroundColor3 = Color3.fromRGB(8, 10, 15)
GlassVeil.BackgroundTransparency = 0.62
GlassVeil.BorderSizePixel = 0
GlassVeil.ZIndex = 1
GlassVeil.Parent = Main

local GlassVeilCorner = Instance.new("UICorner")
GlassVeilCorner.CornerRadius = UDim.new(0, 8)
GlassVeilCorner.Parent = GlassVeil

--==================================================
-- HEADER
--==================================================

local Header =
    Instance.new("Frame")

Header.Name = "Header"

Header.Size =
    UDim2.new(1, 0, 0, 34)

Header.BackgroundColor3 =
    Color3.fromRGB(198, 35, 45)

Header.BackgroundTransparency = 0.04
Header.BorderSizePixel = 0
Header.ZIndex = 2
Header.Parent = Main

local HeaderCorner =
    Instance.new("UICorner")

HeaderCorner.CornerRadius =
    UDim.new(0, 8)

HeaderCorner.Parent =
    Header

local HeaderCover =
    Instance.new("Frame")

HeaderCover.Size =
    UDim2.new(1, 0, 0, 8)

HeaderCover.Position =
    UDim2.new(0, 0, 1, -8)

HeaderCover.BackgroundColor3 =
    Header.BackgroundColor3

HeaderCover.BackgroundTransparency = 0.1
HeaderCover.BorderSizePixel = 0
HeaderCover.ZIndex = 2
HeaderCover.Parent = Header

--==================================================
-- TITLE
--==================================================

local Title =
    Instance.new("TextLabel")

Title.Name = "Title"

Title.Size =
    UDim2.new(1, -16, 1, 0)

Title.Position =
    UDim2.fromOffset(9, 0)

Title.BackgroundTransparency = 1
Title.Text = "MochiClub"

Title.TextColor3 =
    Color3.new(1, 1, 1)

Title.Font =
    Enum.Font.GothamBold

Title.TextSize = 14
Title.TextStrokeTransparency = 0.75
Title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

Title.TextXAlignment =
    Enum.TextXAlignment.Left

Title.TextYAlignment =
    Enum.TextYAlignment.Center

Title.ZIndex = 3
Title.Parent = Header

--==================================================
-- TAB BAR
--==================================================

local TabBar =
    Instance.new("Frame")

TabBar.Name = "TabBar"

TabBar.Size =
    UDim2.new(1, -16, 0, 25)

TabBar.Position =
    UDim2.fromOffset(8, 39)

TabBar.BackgroundTransparency = 1
TabBar.ZIndex = 2
TabBar.Parent = Main

local EggTabButton =
    Instance.new("TextButton")

EggTabButton.Name = "EggTab"

EggTabButton.Size =
    UDim2.new(0.5, -2, 1, 0)

EggTabButton.BackgroundColor3 =
    Color3.fromRGB(230, 40, 40)

EggTabButton.BackgroundTransparency = 0.05
EggTabButton.BorderSizePixel = 0
EggTabButton.Text = "Egg"

EggTabButton.TextColor3 =
    Color3.new(1, 1, 1)

EggTabButton.Font =
    Enum.Font.GothamBold

EggTabButton.TextSize = 9
EggTabButton.ZIndex = 2
EggTabButton.Parent = TabBar

local EggTabCorner =
    Instance.new("UICorner")

EggTabCorner.CornerRadius =
    UDim.new(0, 4)

EggTabCorner.Parent =
    EggTabButton

local VisualTabButton =
    Instance.new("TextButton")

VisualTabButton.Name =
    "VisualTab"

VisualTabButton.Size =
    UDim2.new(0.5, -2, 1, 0)

VisualTabButton.Position =
    UDim2.new(0.5, 2, 0, 0)

VisualTabButton.BackgroundColor3 =
    Color3.fromRGB(52, 52, 60)

VisualTabButton.BackgroundTransparency = 0.05
VisualTabButton.BorderSizePixel = 0
VisualTabButton.Text = "Visual"

VisualTabButton.TextColor3 =
    Color3.fromRGB(205, 205, 210)

VisualTabButton.Font =
    Enum.Font.GothamBold

VisualTabButton.TextSize = 9
VisualTabButton.ZIndex = 2
VisualTabButton.Parent = TabBar

local VisualTabCorner =
    Instance.new("UICorner")

VisualTabCorner.CornerRadius =
    UDim.new(0, 4)

VisualTabCorner.Parent =
    VisualTabButton

--==================================================
-- STATUS & SORT
--==================================================

local Status =
    Instance.new("TextLabel")

Status.Name = "Status"

Status.Size =
    UDim2.new(1, -14, 0, 16)

Status.Position =
    UDim2.fromOffset(9, 67)

Status.BackgroundTransparency = 1
Status.Text = "Select an egg to steal"

Status.TextColor3 =
    Color3.fromRGB(245, 245, 250)

Status.Font =
    Enum.Font.GothamMedium

Status.TextSize = 9
Status.TextStrokeTransparency = 0.7
Status.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

Status.TextXAlignment =
    Enum.TextXAlignment.Left

Status.ZIndex = 2
Status.Parent = Main

local SortMode = "Value"

local SortModes = {
    "Value",
    "Rarity",
    "Weight"
}

local SortButtons = {}

local SortBar =
    Instance.new("Frame")

SortBar.Name = "SortBar"

SortBar.Size =
    UDim2.new(1, -16, 0, 25)

SortBar.Position =
    UDim2.fromOffset(8, 87)

SortBar.BackgroundTransparency = 1
SortBar.BorderSizePixel = 0
SortBar.ZIndex = 2
SortBar.Parent = Main

local SortLayout =
    Instance.new("UIListLayout")

SortLayout.FillDirection =
    Enum.FillDirection.Horizontal

SortLayout.HorizontalAlignment =
    Enum.HorizontalAlignment.Left

SortLayout.VerticalAlignment =
    Enum.VerticalAlignment.Center

SortLayout.Padding =
    UDim.new(0, 4)

SortLayout.SortOrder =
    Enum.SortOrder.LayoutOrder

SortLayout.Parent = SortBar

for index, mode in ipairs(SortModes) do

    local Button =
        Instance.new("TextButton")

    Button.Name =
        "Sort" .. mode

    Button.Size =
        UDim2.fromOffset(92, 23)

    Button.BackgroundColor3 =
        mode == SortMode
        and Color3.fromRGB(230, 40, 40)
        or Color3.fromRGB(52, 52, 60)

    Button.BackgroundTransparency = 0.04
    Button.TextColor3 =
        Color3.new(1, 1, 1)

    Button.Font =
        Enum.Font.GothamBold

    Button.TextSize = 8

    Button.Text =
        "Sort: " .. mode

    Button.BorderSizePixel = 0
    Button.AutoButtonColor = true
    Button.LayoutOrder = index
    Button.ZIndex = 2
    Button.Parent = SortBar

    local Corner =
        Instance.new("UICorner")

    Corner.CornerRadius =
        UDim.new(0, 4)

    Corner.Parent = Button

    SortButtons[mode] = Button
end

--==================================================
-- RARITY FILTER BAR
--==================================================

local RarityFilters = {
    "All",
    "Divine",
    "Eternal",
    "Secret",
    "Cosmic",
    "Mythic",
    "Legendary",
    "Epic",
    "Rare",
    "Uncommon",
    "Common"
}

local SelectedRarity = "All"

local RarityBar =
    Instance.new("ScrollingFrame")

RarityBar.Name =
    "RarityFilters"

RarityBar.Size =
    UDim2.new(1, -16, 0, 30)

RarityBar.Position =
    UDim2.fromOffset(8, 115)

RarityBar.BackgroundColor3 =
    Color3.fromRGB(14, 16, 22)

RarityBar.BackgroundTransparency = 0.08
RarityBar.BorderSizePixel = 0
RarityBar.ScrollBarThickness = 2
RarityBar.ScrollBarImageTransparency = 0.15

RarityBar.ScrollingDirection =
    Enum.ScrollingDirection.X

RarityBar.CanvasSize =
    UDim2.new(0, 0, 0, 0)

RarityBar.AutomaticCanvasSize =
    Enum.AutomaticSize.X

RarityBar.ZIndex = 2
RarityBar.Parent = Main

local RarityBarCorner =
    Instance.new("UICorner")

RarityBarCorner.CornerRadius =
    UDim.new(0, 5)

RarityBarCorner.Parent =
    RarityBar

local RarityPadding =
    Instance.new("UIPadding")

RarityPadding.PaddingLeft =
    UDim.new(0, 3)

RarityPadding.PaddingRight =
    UDim.new(0, 3)

RarityPadding.PaddingTop =
    UDim.new(0, 2)

RarityPadding.PaddingBottom =
    UDim.new(0, 2)

RarityPadding.Parent =
    RarityBar

local RarityLayout =
    Instance.new("UIListLayout")

RarityLayout.FillDirection =
    Enum.FillDirection.Horizontal

RarityLayout.HorizontalAlignment =
    Enum.HorizontalAlignment.Left

RarityLayout.VerticalAlignment =
    Enum.VerticalAlignment.Center

RarityLayout.Padding =
    UDim.new(0, 5)

RarityLayout.SortOrder =
    Enum.SortOrder.LayoutOrder

RarityLayout.Parent =
    RarityBar

local RarityButtons = {}

local function NormalizeRarity(rarity)
    local key = string.lower(string.gsub(string.gsub(tostring(rarity or ""), "^%s+", ""), "%s+$", ""))

    local aliases = {
        ["all"] = "All",
        ["divine"] = "Divine",
        ["eternal"] = "Eternal",
        ["secret"] = "Secret",
        ["cosmic"] = "Cosmic",
        ["mythic"] = "Mythic",
        ["legendary"] = "Legendary",
        ["epic"] = "Epic",
        ["rare"] = "Rare",
        ["uncommon"] = "Uncommon",
        ["common"] = "Common"
    }

    return aliases[key] or tostring(rarity or "")
end

local RarityColors = {
    All = Color3.fromRGB(230, 40, 40),
    Divine = Color3.fromRGB(255, 215, 70),
    Eternal = Color3.fromRGB(255, 110, 210),
    Secret = Color3.fromRGB(0, 0, 0),
    -- Cosmic is blue/violet, not pink/red.
    Cosmic = Color3.fromRGB(105, 95, 255),
    Mythic = Color3.fromRGB(255, 80, 100),
    Legendary = Color3.fromRGB(255, 165, 60),
    Epic = Color3.fromRGB(180, 80, 255),
    Rare = Color3.fromRGB(70, 160, 255),
    Uncommon = Color3.fromRGB(80, 210, 130),
    Common = Color3.fromRGB(170, 170, 180)
}

local function GetRarityColor(rarity)
    local normalized = NormalizeRarity(rarity)
    return RarityColors[normalized] or Color3.fromRGB(70, 70, 78)
end

-- Creates a subtle rarity-tinted card without adding extra UI objects.
-- This is intentionally cheap so refreshing/animating many cards stays smooth.
local function GetRarityCardBackground(rarity)
    local color = GetRarityColor(rarity)
    local normalized = NormalizeRarity(rarity)

    if normalized == "Secret" then
        return Color3.fromRGB(18, 18, 20)
    end

    return Color3.new(
        0.72 * 0.16 + color.R * 0.16,
        0.72 * 0.16 + color.G * 0.16,
        0.78 * 0.16 + color.B * 0.16
    )
end

local function ApplyRarityCardTheme(card, rarity)
    if not card then
        return
    end

    local normalized = NormalizeRarity(rarity)
    local color = GetRarityColor(normalized)

    if card.Rarity then
        card.Rarity.TextColor3 = color

        if normalized == "Secret" then
            -- Keep the actual rarity color black while preserving readability.
            card.Rarity.TextStrokeColor3 = Color3.new(1, 1, 1)
            card.Rarity.TextStrokeTransparency = 0.35
        else
            card.Rarity.TextStrokeTransparency = 1
        end
    end

    if card.Frame then
        card.Frame.BackgroundColor3 = GetRarityCardBackground(normalized)
    end

    if card.RarityStroke then
        -- The outline/glow always follows the actual rarity.
        card.RarityStroke.Color = color
        card.RarityStroke.Transparency = normalized == "Secret" and 0.08 or 0.16
    end

    if card.BoxStroke then
        card.BoxStroke.Color = color
        card.BoxStroke.Transparency = normalized == "Secret" and 0.15 or 0.25
    end
end

for index, rarity in ipairs(
    RarityFilters
) do

    local Button =
        Instance.new("TextButton")

    Button.Name =
        rarity .. "Filter"

    Button.Size =
        UDim2.fromOffset(
            math.max(
                40,
                #rarity * 5 + 10
            ),
            23
        )

    Button.BackgroundColor3 =
        rarity == "All"
        and GetRarityColor(rarity)
        or Color3.fromRGB(
            52,
            52,
            60
        )

    Button.BackgroundTransparency = 0.05
    Button.BorderSizePixel = 0
    Button.Text = rarity

    Button.TextColor3 =
        Color3.new(1, 1, 1)

    Button.Font =
        Enum.Font.GothamBold

    Button.TextSize = 8
    Button.AutoButtonColor = true
    Button.LayoutOrder = index
    Button.ZIndex = 2
    Button.Parent = RarityBar

    local Corner =
        Instance.new("UICorner")

    Corner.CornerRadius =
        UDim.new(0, 4)

    Corner.Parent = Button

    RarityButtons[rarity] =
        Button
end

--==================================================
-- VISUAL TAB
--==================================================

local VisualContainer =
    Instance.new("ScrollingFrame")

VisualContainer.Name =
    "VisualContainer"

VisualContainer.Size =
    UDim2.new(1, -16, 1, -82)

VisualContainer.Position =
    UDim2.fromOffset(8, 70)

VisualContainer.BackgroundTransparency = 1
VisualContainer.BorderSizePixel = 0
VisualContainer.ScrollBarThickness = 3
VisualContainer.ScrollBarImageTransparency = 0.2

VisualContainer.CanvasSize =
    UDim2.new(0, 0, 0, 0)

VisualContainer.AutomaticCanvasSize =
    Enum.AutomaticSize.Y

VisualContainer.Visible = false
VisualContainer.ZIndex = 2
VisualContainer.Parent = Main

local VisualLayout =
    Instance.new("UIListLayout")

VisualLayout.Padding =
    UDim.new(0, 6)

VisualLayout.HorizontalAlignment =
    Enum.HorizontalAlignment.Center

VisualLayout.SortOrder =
    Enum.SortOrder.LayoutOrder

VisualLayout.Parent =
    VisualContainer

local VisualPadding =
    Instance.new("UIPadding")

VisualPadding.PaddingTop =
    UDim.new(0, 5)

VisualPadding.PaddingBottom =
    UDim.new(0, 5)

VisualPadding.PaddingLeft =
    UDim.new(0, 2)

VisualPadding.PaddingRight =
    UDim.new(0, 2)

VisualPadding.Parent =
    VisualContainer

local function CreateFeatureRow(
    nameLeft,
    callbackLeft,
    nameRight,
    callbackRight,
    orderIndex
)

    local Row =
        Instance.new("Frame")

    Row.Name =
        "FeatureRow_" .. orderIndex

    Row.Size =
        UDim2.new(1, -4, 0, 42)

    Row.BackgroundTransparency = 1
    Row.LayoutOrder = orderIndex
    Row.ZIndex = 2
    Row.Parent = VisualContainer

    if nameLeft then

        local LeftBox =
            Instance.new("Frame")

        LeftBox.Name = "LeftBox"

        LeftBox.Size =
            UDim2.new(
                0.5,
                -3,
                1,
                0
            )

        LeftBox.BackgroundColor3 =
            Color3.fromRGB(
                48,
                48,
                54
            )

        LeftBox.BackgroundTransparency = 0.3
        LeftBox.BorderSizePixel = 0
        LeftBox.ZIndex = 2
        LeftBox.Parent = Row

        local LC =
            Instance.new("UICorner")

        LC.CornerRadius =
            UDim.new(0, 6)

        LC.Parent = LeftBox

        local LS =
            Instance.new("UIStroke")

        LS.Thickness = 1
        LS.Color =
            Color3.fromRGB(
                255,
                60,
                60
            )

        LS.Transparency = 0.3
        LS.Parent = LeftBox

        local LText =
            Instance.new("TextLabel")

        LText.Size =
            UDim2.new(
                1,
                -45,
                1,
                0
            )

        LText.Position =
            UDim2.fromOffset(6, 0)

        LText.BackgroundTransparency = 1
        LText.Text = nameLeft

        LText.TextColor3 =
            Color3.new(1, 1, 1)

        LText.Font =
            Enum.Font.GothamBold

        LText.TextSize = 8

        LText.TextXAlignment =
            Enum.TextXAlignment.Left

        LText.ZIndex = 3
        LText.Parent = LeftBox

        local LBtn =
            Instance.new("TextButton")

        LBtn.Size =
            UDim2.fromOffset(
                36,
                20
            )

        LBtn.Position =
            UDim2.new(
                1,
                -41,
                0.5,
                -10
            )

        LBtn.BackgroundColor3 =
            Color3.fromRGB(
                60,
                60,
                70
            )

        LBtn.BackgroundTransparency = 0.2
        LBtn.BorderSizePixel = 0
        LBtn.Text = "OFF"

        LBtn.TextColor3 =
            Color3.fromRGB(
                255,
                80,
                80
            )

        LBtn.Font =
            Enum.Font.GothamBold

        LBtn.TextSize = 8
        LBtn.ZIndex = 3
        LBtn.Parent = LeftBox

        local LBtnC =
            Instance.new("UICorner")

        LBtnC.CornerRadius =
            UDim.new(0, 4)

        LBtnC.Parent = LBtn

        local lState = false

        LBtn.Activated:Connect(
            function()

                lState =
                    not lState

                if lState then

                    LBtn.Text = "ON"

                    LBtn.TextColor3 =
                        Color3.fromRGB(
                            80,
                            255,
                            90
                        )

                    LBtn.BackgroundColor3 =
                        Color3.fromRGB(
                            40,
                            120,
                            50
                        )

                else

                    LBtn.Text = "OFF"

                    LBtn.TextColor3 =
                        Color3.fromRGB(
                            255,
                            80,
                            80
                        )

                    LBtn.BackgroundColor3 =
                        Color3.fromRGB(
                            60,
                            60,
                            70
                        )
                end

                if callbackLeft then
                    pcall(
                        callbackLeft,
                        lState
                    )
                end
            end
        )
    end

    if nameRight then

        local RightBox =
            Instance.new("Frame")

        RightBox.Name = "RightBox"

        RightBox.Size =
            UDim2.new(
                0.5,
                -3,
                1,
                0
            )

        RightBox.Position =
            UDim2.new(
                0.5,
                3,
                0,
                0
            )

        RightBox.BackgroundColor3 =
            Color3.fromRGB(
                48,
                48,
                54
            )

        RightBox.BackgroundTransparency = 0.3
        RightBox.BorderSizePixel = 0
        RightBox.ZIndex = 2
        RightBox.Parent = Row

        local RC =
            Instance.new("UICorner")

        RC.CornerRadius =
            UDim.new(0, 6)

        RC.Parent = RightBox

        local RS =
            Instance.new("UIStroke")

        RS.Thickness = 1

        RS.Color =
            Color3.fromRGB(
                255,
                60,
                60
            )

        RS.Transparency = 0.3
        RS.Parent = RightBox

        local RText =
            Instance.new("TextLabel")

        RText.Size =
            UDim2.new(
                1,
                -45,
                1,
                0
            )

        RText.Position =
            UDim2.fromOffset(6, 0)

        RText.BackgroundTransparency = 1
        RText.Text = nameRight

        RText.TextColor3 =
            Color3.new(1, 1, 1)

        RText.Font =
            Enum.Font.GothamBold

        RText.TextSize = 8

        RText.TextXAlignment =
            Enum.TextXAlignment.Left

        RText.ZIndex = 3
        RText.Parent = RightBox

        local RBtn =
            Instance.new("TextButton")

        RBtn.Size =
            UDim2.fromOffset(
                36,
                20
            )

        RBtn.Position =
            UDim2.new(
                1,
                -41,
                0.5,
                -10
            )

        RBtn.BackgroundColor3 =
            Color3.fromRGB(
                60,
                60,
                70
            )

        RBtn.BackgroundTransparency = 0.2
        RBtn.BorderSizePixel = 0
        RBtn.Text = "OFF"

        RBtn.TextColor3 =
            Color3.fromRGB(
                255,
                80,
                80
            )

        RBtn.Font =
            Enum.Font.GothamBold

        RBtn.TextSize = 8
        RBtn.ZIndex = 3
        RBtn.Parent = RightBox

        local RBtnC =
            Instance.new("UICorner")

        RBtnC.CornerRadius =
            UDim.new(0, 4)

        RBtnC.Parent = RBtn

        local rState = false

        RBtn.Activated:Connect(
            function()

                rState =
                    not rState

                if rState then

                    RBtn.Text = "ON"

                    RBtn.TextColor3 =
                        Color3.fromRGB(
                            80,
                            255,
                            90
                        )

                    RBtn.BackgroundColor3 =
                        Color3.fromRGB(
                            40,
                            120,
                            50
                        )

                else

                    RBtn.Text = "OFF"

                    RBtn.TextColor3 =
                        Color3.fromRGB(
                            255,
                            80,
                            80
                        )

                    RBtn.BackgroundColor3 =
                        Color3.fromRGB(
                            60,
                            60,
                            70
                        )
                end

                if callbackRight then
                    pcall(
                        callbackRight,
                        rState
                    )
                end
            end
        )
    end
end

--==================================================
-- VISUAL FEATURES LOGIC
--==================================================

local originalSettings = {}

local function ToggleFpsBoost(state)

    if state then

        originalSettings.GlobalShadows =
            Lighting.GlobalShadows

        originalSettings.Brightness =
            Lighting.Brightness

        Lighting.GlobalShadows = false
        Lighting.Brightness = 2

        for _, v in ipairs(
            workspace:GetDescendants()
        ) do

            if v:IsA("BasePart") then

                v.Material =
                    Enum.Material.SmoothPlastic

                v.Reflectance = 0

            elseif v:IsA("Texture")
                or v:IsA("Decal") then

                v.Transparency = 1

            elseif v:IsA("ParticleEmitter")
                or v:IsA("Trail")
                or v:IsA("Fire")
                or v:IsA("Smoke")
                or v:IsA("Sparkles") then

                v.Enabled = false
            end
        end

    else

        Lighting.GlobalShadows =
            originalSettings.GlobalShadows
            or true

        Lighting.Brightness =
            originalSettings.Brightness
            or 1
    end
end

--==================================================
-- ANTI RAGDOLL
-- Runs ONLY while the Anti Ragdoll toggle is ON.
--==================================================

local AntiRagdollEnabled = false
local AntiRagdollResetCooldown = 0
local AntiRagdollConnection = nil

local function GetAntiRagdollCharacter()
    return LocalPlayer.Character
end

local function GetAntiRagdollHumanoid(character)
    if not character then
        return nil
    end

    return character:FindFirstChildOfClass("Humanoid")
end

local function GetAntiRagdollRoot(character)
    if not character then
        return nil
    end

    return character:FindFirstChild("HumanoidRootPart")
end

local function ForceAntiRagdollReset()
    if not AntiRagdollEnabled then
        return
    end

    local char = GetAntiRagdollCharacter()

    if not char then
        return
    end

    local hum = GetAntiRagdollHumanoid(char)
    local root = GetAntiRagdollRoot(char)

    if not hum or not root or hum.Health <= 0 then
        return
    end

    pcall(function()
        hum:ChangeState(
            Enum.HumanoidStateType.GettingUp
        )

        root.Velocity = Vector3.zero
        root.RotVelocity = Vector3.zero
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero

        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("Motor6D") then
                obj.Enabled = true
            elseif obj:IsA("Constraint") then
                obj.Enabled = true
            end
        end

        if workspace.CurrentCamera then
            workspace.CurrentCamera.CameraSubject = hum
        end

        local playerScripts =
            LocalPlayer:FindFirstChild("PlayerScripts")

        local playerModule =
            playerScripts
            and playerScripts:FindFirstChild("PlayerModule")

        if playerModule then
            local controlModuleScript =
                playerModule:FindFirstChild("ControlModule")

            if controlModuleScript then
                local ok, controlModule =
                    pcall(require, controlModuleScript)

                if ok and controlModule then
                    pcall(function()
                        controlModule:Enable()
                    end)
                end
            end
        end

        hum.AutoRotate = true
        hum.PlatformStand = false
        hum.Sit = false
    end)
end

local function StopAntiRagdoll()
    AntiRagdollEnabled = false

    if AntiRagdollConnection then
        AntiRagdollConnection:Disconnect()
        AntiRagdollConnection = nil
    end
end

local function StartAntiRagdoll()
    StopAntiRagdoll()

    AntiRagdollEnabled = true

    AntiRagdollConnection =
        RunService.Heartbeat:Connect(function()

            if not AntiRagdollEnabled then
                return
            end

            local char = GetAntiRagdollCharacter()

            if not char then
                return
            end

            local hum =
                GetAntiRagdollHumanoid(char)

            if not hum or hum.Health <= 0 then
                return
            end

            local state = hum:GetState()

            local isRagdolled =
                state == Enum.HumanoidStateType.Physics
                or state == Enum.HumanoidStateType.Ragdoll
                or state == Enum.HumanoidStateType.FallingDown

            if isRagdolled then
                local now = tick()

                if now - AntiRagdollResetCooldown > 0.15 then
                    AntiRagdollResetCooldown = now
                    ForceAntiRagdollReset()
                end
            end
        end)
end

local function ToggleAntiRagdoll(state)
    if state then
        StartAntiRagdoll()
    else
        StopAntiRagdoll()
    end
end

--==================================================
-- ANTI GUARD (runs ONLY while the UI toggle is ON)
-- Isolated in its own function scope to avoid exhausting
-- the main script chunk's local-variable/register limit.
--==================================================

local ToggleAntiGuard = (function()
local AntiGuardEnabled = false
local AntiGuardRunning = false
local AntiGuardConnections = {}
local AntiGuardPromptDurations = {}

local AntiGuardRoutePoints = {
    CFrame.new(500.62, 241.28, -366.64),
    CFrame.new(504.45, 155.80, -366.35),
    CFrame.new(508.30, 70.28, -366.03),
    CFrame.new(513.86, 70.28, -366.25),
    CFrame.new(519.43, 70.28, -366.47),
    CFrame.new(524.32, 70.28, -366.59),
    CFrame.new(529.22, 70.28, -366.71),
    CFrame.new(538.01, 70.28, -365.55),
    CFrame.new(546.80, 70.28, -364.40)
}

local AntiGuardSafeCFrame = AntiGuardRoutePoints[#AntiGuardRoutePoints]
local AntiGuardProtectDuration = 0.35

local function AntiGuardGetRoot()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function AntiGuardZeroVelocity(root)
    if not root then return end
    pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function AntiGuardMakePromptInstant(object)
    if not AntiGuardEnabled then return end
    if object:IsA("ProximityPrompt") and object.Name == "CarryAreaEgg" then
        if AntiGuardPromptDurations[object] == nil then
            AntiGuardPromptDurations[object] = object.HoldDuration
        end
        object.HoldDuration = 0
    end
end

local function AntiGuardFire()
    if not AntiGuardEnabled or AntiGuardRunning then return end
    local root = AntiGuardGetRoot()
    if not root then return end

    AntiGuardRunning = true
    for _, position in ipairs(AntiGuardRoutePoints) do
        if not AntiGuardEnabled then
            AntiGuardRunning = false
            return
        end
        root = AntiGuardGetRoot()
        if not root then
            AntiGuardRunning = false
            return
        end
        root.CFrame = position
    end

    root = AntiGuardGetRoot()
    AntiGuardZeroVelocity(root)
    local deadline = tick() + AntiGuardProtectDuration
    local heartbeatConnection
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        if not AntiGuardEnabled or tick() > deadline then
            if heartbeatConnection then heartbeatConnection:Disconnect() end
            AntiGuardRunning = false
            return
        end

        local currentRoot = AntiGuardGetRoot()
        if not currentRoot then
            if heartbeatConnection then heartbeatConnection:Disconnect() end
            AntiGuardRunning = false
            return
        end

        currentRoot.CFrame = AntiGuardSafeCFrame
        AntiGuardZeroVelocity(currentRoot)
    end)
    table.insert(AntiGuardConnections, heartbeatConnection)
end

local function StopAntiGuard()
    AntiGuardEnabled = false
    AntiGuardRunning = false

    for _, connection in ipairs(AntiGuardConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(AntiGuardConnections)

    for prompt, originalDuration in pairs(AntiGuardPromptDurations) do
        pcall(function()
            if prompt.Parent then prompt.HoldDuration = originalDuration end
        end)
    end
    table.clear(AntiGuardPromptDurations)
end

local function StartAntiGuard()
    StopAntiGuard()
    AntiGuardEnabled = true

    local workspaceService = game:GetService("Workspace")
    local promptService = game:GetService("ProximityPromptService")

    for _, object in ipairs(workspaceService:GetDescendants()) do
        AntiGuardMakePromptInstant(object)
    end

    table.insert(AntiGuardConnections, workspaceService.DescendantAdded:Connect(function(object)
        AntiGuardMakePromptInstant(object)
    end))

    table.insert(AntiGuardConnections, promptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
        if not AntiGuardEnabled or triggeringPlayer ~= LocalPlayer then return end
        if prompt.Name ~= "CarryAreaEgg" then return end
        task.spawn(AntiGuardFire)
    end))
end

shared.MochiAntiGuardEnabled = false

local function ToggleAntiGuardInternal(state)
    if state == true then
        StartAntiGuard()
    else
        StopAntiGuard()
    end
    shared.MochiAntiGuardEnabled = (state == true)
    if shared.MochiViewHoldRefresh then
        pcall(shared.MochiViewHoldRefresh)
    end
    print("Anti Guard:", AntiGuardEnabled and "ON" or "OFF")
end

return ToggleAntiGuardInternal
end)()

--==================================================
-- ANTI TRAP
-- The external Anti Trap script is started ONLY
-- when the Anti Trap toggle is turned ON.
--==================================================

local AntiTrapEnabled = false
local AntiTrapRan = false

local function RunAntiTrap()
    if not AntiTrapEnabled then
        return
    end

    if AntiTrapRan then
        return
    end

    AntiTrapRan = true

    task.spawn(function()
        local ok, err = pcall(function()
            loadstring(
                game:HttpGet(
                    "https://raw.githubusercontent.com/Lutosys/opensrc/refs/heads/main/StealAnEggAntiTrap.lua"
                )
            )()
        end)

        if not ok then
            AntiTrapRan = false
            warn("AntiTrap load failed:", err)
        end
    end)
end

local function ToggleAntiTrap(state)
    AntiTrapEnabled = state == true

    if AntiTrapEnabled then
        RunAntiTrap()
    end
end

local function ToggleFpsPingDisplay(state)
    StatsBox.Visible = state
end

CreateFeatureRow(
    "Anti Guard",
    ToggleAntiGuard,
    "Fps Boost",
    ToggleFpsBoost,
    1
)

CreateFeatureRow(
    "Anti Trap",
    ToggleAntiTrap,
    "Anti Ragdoll",
    ToggleAntiRagdoll,
    2
)

CreateFeatureRow(
    "FPS & Ping",
    ToggleFpsPingDisplay,
    nil,
    nil,
    3
)

--==================================================
-- SCROLL LIST
--==================================================

local Scrolling =
    Instance.new("ScrollingFrame")

Scrolling.Name = "EggList"

Scrolling.Size =
    UDim2.new(
        1,
        -16,
        1,
        -193
    )

Scrolling.Position =
    UDim2.fromOffset(8, 149)

Scrolling.BackgroundTransparency = 1
Scrolling.BorderSizePixel = 0
Scrolling.ScrollBarThickness = 3
Scrolling.ScrollBarImageTransparency = 0.2

Scrolling.CanvasSize =
    UDim2.new()

Scrolling.AutomaticCanvasSize =
    Enum.AutomaticSize.Y

Scrolling.ZIndex = 2
Scrolling.Parent = Main

local Padding =
    Instance.new("UIPadding")

Padding.PaddingLeft =
    UDim.new(0, 1)

Padding.PaddingRight =
    UDim.new(0, 1)

Padding.PaddingTop =
    UDim.new(0, 2)

Padding.PaddingBottom =
    UDim.new(0, 2)

Padding.Parent = Scrolling

local Layout =
    Instance.new("UIListLayout")

Layout.Padding =
    UDim.new(0, 3)

Layout.SortOrder =
    Enum.SortOrder.LayoutOrder

Layout.Parent = Scrolling

--==================================================
-- BOTTOM BAR
--==================================================

local BottomBar =
    Instance.new("Frame")

BottomBar.Name = "BottomBar"

BottomBar.Size =
    UDim2.new(
        1,
        -16,
        0,
        28
    )

BottomBar.Position =
    UDim2.new(
        0,
        8,
        1,
        -33
    )

BottomBar.BackgroundTransparency = 1
BottomBar.ZIndex = 2
BottomBar.Parent = Main

local BottomLayout =
    Instance.new("UIListLayout")

BottomLayout.FillDirection =
    Enum.FillDirection.Horizontal

BottomLayout.HorizontalAlignment =
    Enum.HorizontalAlignment.Center

BottomLayout.VerticalAlignment =
    Enum.VerticalAlignment.Center

BottomLayout.Padding =
    UDim.new(0, 6)

BottomLayout.Parent = BottomBar

local RefreshButton =
    Instance.new("TextButton")

RefreshButton.Name =
    "RefreshButton"

RefreshButton.Size =
    UDim2.new(
        0.5,
        -3,
        1,
        0
    )

RefreshButton.BackgroundColor3 =
    Color3.fromRGB(
        34,
        39,
        50
    )

RefreshButton.BackgroundTransparency = 0.02
RefreshButton.BorderSizePixel = 0
RefreshButton.Text = "Refresh"

RefreshButton.TextColor3 =
    Color3.new(1, 1, 1)

RefreshButton.Font =
    Enum.Font.GothamBold

RefreshButton.TextSize = 9
RefreshButton.ZIndex = 2
RefreshButton.Parent = BottomBar

local RefreshCorner =
    Instance.new("UICorner")

RefreshCorner.CornerRadius =
    UDim.new(0, 5)

RefreshCorner.Parent =
    RefreshButton

local StealButton =
    Instance.new("TextButton")

StealButton.Name =
    "StealButton"

StealButton.Size =
    UDim2.new(
        0.5,
        -3,
        1,
        0
    )

StealButton.BackgroundColor3 =
    Color3.fromRGB(
        230,
        40,
        40
    )

StealButton.BackgroundTransparency = 0.02
StealButton.BorderSizePixel = 0
StealButton.Text = "Steal"

StealButton.TextColor3 =
    Color3.new(1, 1, 1)

StealButton.Font =
    Enum.Font.GothamBold

StealButton.TextSize = 9
StealButton.ZIndex = 2
StealButton.Parent = BottomBar

local StealCorner =
    Instance.new("UICorner")

StealCorner.CornerRadius =
    UDim.new(0, 5)

StealCorner.Parent =
    StealButton

--==================================================
-- UTILS & CALCULATIONS
--==================================================

local function FormatNumber(n)

    n = tonumber(n) or 0

    local suffixes = {
        "",
        "K",
        "M",
        "B",
        "T",
        "Qa",
        "Qi"
    }

    local index = 1

    while math.abs(n) >= 1000
        and index < #suffixes do

        n = n / 1000
        index += 1
    end

    if index == 1 then
        return string.format(
            "%.0f",
            n
        )
    end

    return string.format(
        "%.2f",
        n
    ) .. suffixes[index]
end

local function FormatMoney(n)
    return "$"
        .. FormatNumber(n)
        .. "/s"
end

local function FormatWeight(n)

    n = tonumber(n) or 0

    if n >= 1000 then
        return string.format(
            "%.0f Kg",
            n
        )
    end

    return string.format(
        "%.2f Kg",
        n
    )
end

local function GetIcon(icon)

    if icon == nil then
        return ""
    end

    local value =
        tostring(icon)

    if value == "" then
        return ""
    end

    if string.find(
        value,
        "rbxassetid://",
        1,
        true
    ) then

        return value
    end

    local id =
        string.match(
            value,
            "%d+"
        )

    if id then
        return "rbxassetid://" .. id
    end

    return value
end

local Directory =
    type(Assets) == "table"
    and Assets.Directory
    or nil

local function GetAsset(category)

    if type(Directory) ~= "table" then
        return nil
    end

    return Directory[
        tostring(category)
    ]
end

local function GetRarityInfo(category)

    local asset =
        GetAsset(category)

    if not asset
        or type(asset.Rarity) ~= "table" then

        return {
            Name = "Unknown",
            Number = 0
        }
    end

    local rarity =
        asset.Rarity

    return {
        Name = tostring(
            rarity.DisplayName
            or rarity._id
            or "Unknown"
        ),

        Number =
            tonumber(
                rarity.RarityNumber
                or rarity.Rank
                or 0
            )
            or 0
    }
end

local function MutationMultiplier(record)

    if type(Mutations) == "table"
        and type(Mutations.EarningsFor)
            == "function" then

        local ok, result =
            pcall(
                Mutations.EarningsFor,
                type(record.Mutations)
                    == "table"
                    and record.Mutations
                    or {}
            )

        if ok
            and type(result)
                == "number" then

            return result
        end
    end

    return 1
end

local function CalculateValue(
    record,
    asset
)

    if not asset then
        return 0
    end

    local scale =
        tonumber(
            record.AssetScale
        )
        or 1

    local scaleMultiplier =
        scale > 5
        and (
            (scale / 5) ^ 1.2
            * 19.637875755794113
        )
        or (
            scale ^ 1.85
        )

    return
        (
            tonumber(
                asset.EarningRate
            )
            or 0
        )
        * scaleMultiplier
        * MutationMultiplier(record)
end

local function GetWeight(
    category,
    scale
)

    if type(EggRecords)
        == "table"
        and type(
            EggRecords.WeightKgForScale
        ) == "function" then

        local ok, result =
            pcall(
                EggRecords.WeightKgForScale,
                category,
                scale
            )

        if ok
            and tonumber(result) then

            return tonumber(result)
        end
    end

    return 0
end

local function ReadEggs()

    if type(EggState)
        ~= "table"
        or type(
            EggState.ReadFieldEggs
        ) ~= "function" then

        return {}
    end

    local ok, result =
        pcall(
            EggState.ReadFieldEggs
        )

    if not ok
        or type(result)
            ~= "table"
        or type(result.Records)
            ~= "table" then

        return {}
    end

    return result.Records
end

local function BuildEggData()

    local records =
        ReadEggs()

    local output = {}

    for _, record in pairs(
        records
    ) do

        if type(record)
            == "table"
            and type(
                record.AssetCategory
            ) == "string" then

            local category =
                record.AssetCategory

            local asset =
                GetAsset(category)

            if asset then

                local rarity =
                    GetRarityInfo(
                        category
                    )

                local scale =
                    tonumber(
                        record.AssetScale
                    )
                    or 1

                table.insert(
                    output,
                    {
                        Record = record,

                        Uid = tostring(
                            record.Uid
                            or ""
                        ),

                        Category =
                            category,

                        Name =
                            tostring(
                                asset.DisplayName
                                or category
                            ),

                        Icon =
                            GetIcon(
                                asset.Icon
                            ),

                        Rarity =
                            rarity.Name,

                        RarityNumber =
                            rarity.Number,

                        Value =
                            CalculateValue(
                                record,
                                asset
                            ),

                        Weight =
                            GetWeight(
                                category,
                                scale
                            ),

                        Scale = scale,

                        Mutation =
                            tostring(
                                record.BaseMutation
                                or ""
                            )
                    }
                )
            end
        end
    end

    return output
end

local function SortEggs(list)

    table.sort(
        list,
        function(a, b)

            if SortMode == "Value" then

                return a.Value >
                    b.Value

            elseif SortMode == "Rarity" then

                return
                    a.RarityNumber
                    ~= b.RarityNumber
                    and
                    a.RarityNumber
                    >
                    b.RarityNumber
                    or
                    a.Name < b.Name

            elseif SortMode == "Weight" then

                return a.Weight >
                    b.Weight
            end

            return a.Value >
                b.Value
        end
    )
end

--==================================================
-- EGG CARDS
--==================================================

local Cards = {}

-- Movement cancellation state. Incremented whenever an Egg selection changes.
local StealSelectionToken = 0
local StealRunning = false
local StealRunId = 0

-- Notification banner bridge (shared table => no extra local).
shared.MochiEggBridge = { Current = nil, Token = 0 }

local function CreateEggCard(
    data,
    index
)

    local Card =
        Instance.new("Frame")

    Card.Name =
        "Egg_" .. index

    Card.Size =
        UDim2.new(
            1,
            -2,
            0,
            60
        )

    Card.BackgroundColor3 =
        Color3.fromRGB(25, 28, 36)

    Card.BackgroundTransparency = 0.06
    Card.BorderSizePixel = 0
    Card.LayoutOrder = index
    Card.ZIndex = 2
    Card.Parent = Scrolling

    local Corner =
        Instance.new("UICorner")

    Corner.CornerRadius =
        UDim.new(0, 6)

    Corner.Parent = Card

    local Stroke =
        Instance.new("UIStroke")

    Stroke.Thickness = 1

    Stroke.Color =
        Color3.fromRGB(75, 80, 94)

    Stroke.Transparency = 0.45
    Stroke.Parent = Card

    local CheckBox =
        Instance.new("TextButton")

    CheckBox.Name =
        "CheckBox"

    CheckBox.Size =
        UDim2.fromOffset(
            20,
            20
        )

    CheckBox.Position =
        UDim2.fromOffset(
            6,
            20
        )

    CheckBox.BackgroundColor3 =
        Color3.fromRGB(
            60,
            60,
            70
        )

    CheckBox.BackgroundTransparency = 0.2
    CheckBox.BorderSizePixel = 0
    CheckBox.Text = ""
    CheckBox.AutoButtonColor = true
    CheckBox.ZIndex = 3
    CheckBox.Parent = Card

    local BoxCorner =
        Instance.new("UICorner")

    BoxCorner.CornerRadius =
        UDim.new(0, 4)

    BoxCorner.Parent =
        CheckBox

    local BoxStroke =
        Instance.new("UIStroke")

    BoxStroke.Thickness = 1

    BoxStroke.Color =
        Color3.fromRGB(
            90,
            90,
            100
        )

    BoxStroke.Parent =
        CheckBox

    local CheckLabel =
        Instance.new("TextLabel")

    CheckLabel.Name =
        "CheckMark"

    CheckLabel.Size =
        UDim2.new(1, 0, 1, 0)

    CheckLabel.BackgroundTransparency = 1
    CheckLabel.Text = ""

    CheckLabel.TextColor3 =
        Color3.fromRGB(
            80,
            255,
            90
        )

    CheckLabel.Font =
        Enum.Font.GothamBold

    CheckLabel.TextSize = 14
    CheckLabel.ZIndex = 3
    CheckLabel.Parent = CheckBox

    local isChecked = false

    CheckBox.Activated:Connect(
        function()

            isChecked =
                not isChecked

            -- Any selection change invalidates the current Steal target.
            StealSelectionToken =
                StealSelectionToken + 1

            if not isChecked and StealRunning then
                StealRunning = false
            end

            if isChecked then

                CheckLabel.Text = ""

                CheckBox.BackgroundColor3 =
                    Color3.fromRGB(
                        40,
                        120,
                        50
                    )

            else

                CheckLabel.Text = ""

                CheckBox.BackgroundColor3 =
                    Color3.fromRGB(
                        60,
                        60,
                        70
                    )
            end

            if Cards[index] then
                Cards[index].IsSelected =
                    isChecked
            end

            if shared.MochiViewHoldRefresh then
                pcall(shared.MochiViewHoldRefresh)
            end
        end
    )

    local Icon =
        Instance.new("ImageLabel")

    Icon.Name = "EggIcon"

    Icon.Size =
        UDim2.fromOffset(
            44,
            44
        )

    Icon.Position =
        UDim2.fromOffset(
            31,
            8
        )

    Icon.BackgroundTransparency = 1

    Icon.ScaleType =
        Enum.ScaleType.Fit

    Icon.ZIndex = 3
    Icon.Parent = Card

    local Name =
        Instance.new("TextLabel")

    Name.Name = "Name"

    Name.Size =
        UDim2.new(
            1,
            -170,
            0,
            15
        )

    Name.Position =
        UDim2.fromOffset(
            82,
            6
        )

    Name.BackgroundTransparency = 1
    Name.TextColor3 =
        Color3.new(1, 1, 1)

    Name.Font =
        Enum.Font.GothamBold

    Name.TextSize = 10

    Name.TextXAlignment =
        Enum.TextXAlignment.Left

    Name.TextTruncate =
        Enum.TextTruncate.AtEnd

    Name.ZIndex = 3
    Name.Parent = Card

    local Rarity =
        Instance.new("TextLabel")

    Rarity.Name = "Rarity"

    Rarity.Size =
        UDim2.new(
            1,
            -170,
            0,
            12
        )

    Rarity.Position =
        UDim2.fromOffset(
            82,
            21
        )

    Rarity.BackgroundTransparency = 1

    -- Rarity color is driven by the actual rarity.
    -- This keeps the pet/egg card color identical to
    -- the rarity filter palette above.
    Rarity.TextColor3 =
        GetRarityColor(
            data.Rarity
        )

    -- Secret is intentionally black.  A small white
    -- stroke keeps black text readable over dark cards
    -- without changing the actual rarity color.
    if string.lower(
        tostring(data.Rarity or "")
    ) == "secret" then

        Rarity.TextStrokeColor3 =
            Color3.new(1, 1, 1)

        Rarity.TextStrokeTransparency = 0.35

    else

        Rarity.TextStrokeTransparency = 1
    end

    Rarity.Font =
        Enum.Font.GothamBold

    Rarity.TextSize = 7

    Rarity.TextXAlignment =
        Enum.TextXAlignment.Left

    Rarity.ZIndex = 3
    Rarity.Parent = Card

    local Value =
        Instance.new("TextLabel")

    Value.Name = "Value"

    Value.Size =
        UDim2.new(
            1,
            -170,
            0,
            12
        )

    Value.Position =
        UDim2.fromOffset(
            82,
            36
        )

    Value.BackgroundTransparency = 1

    Value.TextColor3 =
        Color3.fromRGB(
            80,
            255,
            90
        )

    Value.Font =
        Enum.Font.GothamBold

    Value.TextSize = 9

    Value.TextXAlignment =
        Enum.TextXAlignment.Left

    Value.ZIndex = 3
    Value.Parent = Card

    local Weight =
        Instance.new("TextLabel")

    Weight.Name = "Weight"

    Weight.Size =
        UDim2.fromOffset(
            78,
            14
        )

    Weight.Position =
        UDim2.new(
            1,
            -84,
            0,
            12
        )

    Weight.BackgroundTransparency = 1

    Weight.TextColor3 =
        Color3.fromRGB(
            80,
            180,
            255
        )

    Weight.Font =
        Enum.Font.GothamBold

    Weight.TextSize = 9

    Weight.TextXAlignment =
        Enum.TextXAlignment.Right

    Weight.ZIndex = 3
    Weight.Parent = Card

    local Scale =
        Instance.new("TextLabel")

    Scale.Name = "Scale"

    Scale.Size =
        UDim2.fromOffset(
            78,
            13
        )

    Scale.Position =
        UDim2.new(
            1,
            -84,
            0,
            28
        )

    Scale.BackgroundTransparency = 1

    Scale.TextColor3 =
        Color3.fromRGB(
            180,
            180,
            190
        )

    Scale.Font =
        Enum.Font.Gotham

    Scale.TextSize = 9

    Scale.TextXAlignment =
        Enum.TextXAlignment.Right

    Scale.ZIndex = 3
    Scale.Parent = Card

    local Mutation =
        Instance.new("TextLabel")

    Mutation.Name = "Mutation"

    Mutation.Size =
        UDim2.new(
            1,
            -170,
            0,
            10
        )

    Mutation.Position =
        UDim2.fromOffset(
            82,
            50
        )

    Mutation.BackgroundTransparency = 1

    Mutation.TextColor3 =
        Color3.fromRGB(
            255,
            180,
            80
        )

    Mutation.Font =
        Enum.Font.GothamBold

    Mutation.TextSize = 8

    Mutation.TextXAlignment =
        Enum.TextXAlignment.Left

    Mutation.ZIndex = 3
    Mutation.Parent = Card

    Cards[index] = {

        Frame = Card,

        CheckBox = CheckBox,

        CheckLabel = CheckLabel,

        Icon = Icon,

        Name = Name,

        Rarity = Rarity,

        Value = Value,

        Weight = Weight,

        Scale = Scale,

        Mutation = Mutation,

        RarityStroke = Stroke,

        BoxStroke = BoxStroke,

        BaseX = 31,

        BaseY = 8,

        Phase =
            (index % 10)
            * 0.35,

        CurrentData = nil,

        IsSelected = false
    }

    return Cards[index]
end

local function UpdateCard(
    card,
    data,
    index
)

    card.Frame.LayoutOrder =
        index

    card.Icon.Image =
        data.Icon or ""

    card.Name.Text =
        data.Name

    card.Rarity.Text =
        string.upper(
            NormalizeRarity(data.Rarity)
        )

    -- Always re-apply the rarity visuals on every refresh.
    -- Cards are reused by index, so without this a Secret card could
    -- keep the previous card's Divine/Eternal/etc. color.
    ApplyRarityCardTheme(
        card,
        data.Rarity
    )

    card.Value.Text =
        FormatMoney(
            data.Value
        )

    card.Weight.Text =
        FormatWeight(
            data.Weight
        )

    card.Scale.Text =
        string.format(
            "x%.2f",
            data.Scale
        )

    do
        local m = tostring(data.Mutation or "")
        -- Broken/non-ASCII mutation text (e.g. mojibake) is hidden
        if m:find("[\128-\255]") then
            m = ""
        end
        card.Mutation.Text = string.upper(m)
    end

    card.CurrentData =
        data
end

local function MatchesFilter(data)

    if SelectedRarity == "All" then
        return true
    end

    if not data then
        return false
    end

    return
        NormalizeRarity(data.Rarity)
        ==
        NormalizeRarity(SelectedRarity)
end

local function UpdateFilterButtons()

    for rarity, button in pairs(
        RarityButtons
    ) do

        button.BackgroundColor3 =
            (
                rarity
                == SelectedRarity
            )
            and GetRarityColor(
                rarity
            )
            or Color3.fromRGB(
                52,
                52,
                60
            )

        button.TextColor3 =
            (
                rarity
                == SelectedRarity
            )
            and Color3.new(
                1,
                1,
                1
            )
            or Color3.fromRGB(
                205,
                205,
                210
            )
    end
end

local function UpdateSortButtons()

    for mode, button in pairs(
        SortButtons
    ) do

        button.BackgroundColor3 =
            (
                mode
                == SortMode
            )
            and Color3.fromRGB(205, 43, 53)
            or Color3.fromRGB(
                52,
                52,
                60
            )

        button.TextColor3 =
            (
                mode
                == SortMode
            )
            and Color3.new(
                1,
                1,
                1
            )
            or Color3.fromRGB(
                205,
                205,
                210
            )
    end
end

local CurrentTab = "Egg"

local function ApplyFilter()

    for _, card in pairs(
        Cards
    ) do

        card.Frame.Visible =
            (
                CurrentTab ~= "Visual"
                and card.CurrentData
                and MatchesFilter(
                    card.CurrentData
                )
            )
            and true
            or false
    end
end

for rarity, button in pairs(
    RarityButtons
) do

    button.Activated:Connect(
        function()

            SelectedRarity =
                rarity

            UpdateFilterButtons()
            ApplyFilter()
        end
    )
end

for mode, button in pairs(
    SortButtons
) do

    button.Activated:Connect(
        function()

            SortMode = mode

            UpdateSortButtons()

            Refresh()
        end
    )
end

--==================================================
-- TAB SWITCHING
--==================================================

EggTabButton.Activated:Connect(
    function()

        CurrentTab = "Egg"

        EggTabButton.BackgroundColor3 =
            Color3.fromRGB(
                230,
                40,
                40
            )

        EggTabButton.TextColor3 =
            Color3.new(1, 1, 1)

        VisualTabButton.BackgroundColor3 =
            Color3.fromRGB(
                52,
                52,
                60
            )

        VisualTabButton.TextColor3 =
            Color3.fromRGB(
                255,
                255,
                255
            )

        SortBar.Visible = true
        RarityBar.Visible = true
        Scrolling.Visible = true
        BottomBar.Visible = true
        VisualContainer.Visible = false

        ApplyFilter()
    end
)

VisualTabButton.Activated:Connect(
    function()

        CurrentTab = "Visual"

        VisualTabButton.BackgroundColor3 =
            Color3.fromRGB(
                230,
                40,
                40
            )

        VisualTabButton.TextColor3 =
            Color3.new(1, 1, 1)

        EggTabButton.BackgroundColor3 =
            Color3.fromRGB(
                52,
                52,
                60
            )

        EggTabButton.TextColor3 =
            Color3.fromRGB(
                255,
                255,
                255
            )

        SortBar.Visible = false
        RarityBar.Visible = false
        Scrolling.Visible = false
        BottomBar.Visible = false
        VisualContainer.Visible = true

        ApplyFilter()
    end
)

--==================================================
-- REFRESH
--==================================================

local Refreshing = false

function Refresh()

    if Refreshing then
        return
    end

    Refreshing = true

    -- IMPORTANT:
    -- Preserve selection by Egg UID,
    -- not by card index.

    local selectedUids = {}

    for _, card in ipairs(
        Cards
    ) do

        if card.IsSelected
            and card.CurrentData then

            local uid =
                tostring(
                    card.CurrentData.Uid
                    or ""
                )

            if uid ~= "" then
                selectedUids[uid] = true
            end
        end
    end

    local newData =
        BuildEggData()

    SortEggs(newData)

    for index, data in ipairs(
        newData
    ) do

        local card =
            Cards[index]

        if not card then

            card =
                CreateEggCard(
                    data,
                    index
                )
        end

        UpdateCard(
            card,
            data,
            index
        )

        local uid =
            tostring(
                data.Uid
                or ""
            )

        local selected =
            selectedUids[uid]
            == true

        card.IsSelected =
            selected

        if card.CheckLabel then

            card.CheckLabel.Text =
                selected
                and ""
                or ""
        end

        if card.CheckBox then

            card.CheckBox.BackgroundColor3 =
                selected

                and Color3.fromRGB(
                    40,
                    120,
                    50
                )

                or Color3.fromRGB(
                    60,
                    60,
                    70
                )
        end

        card.Frame.Visible =
            CurrentTab ~= "Visual"
            and MatchesFilter(
                data
            )
    end

    for index =
        #newData + 1,
        #Cards do

        if Cards[index] then

            Cards[index].Frame.Visible =
                false

            Cards[index].CurrentData =
                nil

            Cards[index].IsSelected =
                false

            if Cards[index].CheckLabel then

                Cards[index].CheckLabel.Text =
                    ""
            end

            if Cards[index].CheckBox then

                Cards[index].CheckBox.BackgroundColor3 =
                    Color3.fromRGB(
                        60,
                        60,
                        70
                    )
            end
        end
    end

    Refreshing = false
end

RefreshButton.Activated:Connect(
    Refresh
)

--==================================================
--==================================================
-- STEAL / MOVEMENT LOGIC
-- ONE CLICK + DIRECT EGG MOVEMENT
--==================================================


-- Distansya kung saan titigil sa Egg.
local StealStopDistance = 2.75

-- Movement uses the game's CURRENT Humanoid.WalkSpeed.
-- WalkSpeed is never changed by this script.

-- Gaano kadalas mag-check ng live Egg position.
local StealUpdateRate = 0.02

--==================================================
-- CHARACTER
--==================================================

local function GetCharacterParts()

    local character =
        LocalPlayer.Character

    if not character
        or not character.Parent then

        return nil, nil, nil
    end

    local humanoid =
        character:FindFirstChildOfClass(
            "Humanoid"
        )

    local rootPart =
        character:FindFirstChild(
            "HumanoidRootPart"
        )

    if not humanoid
        or not rootPart
        or humanoid.Health <= 0 then

        return nil, nil, nil
    end

    return character,
        humanoid,
        rootPart
end

--==================================================
-- OBJECT POSITION
--==================================================

local function GetObjectPosition(
    object
)

    if not object then
        return nil
    end

    local ok, position =
        pcall(
            function()

                if object:IsA(
                    "BasePart"
                ) then

                    return object.Position
                end

                if object:IsA(
                    "Model"
                ) then

                    return object:
                        GetPivot()
                        .Position
                end

                local part =
                    object:
                    FindFirstChildWhichIsA(
                        "BasePart",
                        true
                    )

                if part then
                    return part.Position
                end

                return nil
            end
        )

    if ok
        and typeof(position)
            == "Vector3" then

        return position
    end

    return nil
end

--==================================================
-- FIND THE ACTUAL EGG OBJECT
--==================================================

local function FindEggObject(
    target
)

    if not target then
        return nil
    end

    local data =
        target.Data
        or target.CurrentData
        or target

    local record =
        data
        and data.Record

    if not record then
        return nil
    end

    local directObjects = {
        record.Model,
        record.Part,
        record.Instance,
        record.Object,
        record.Egg,
        record.Root,
        record.RootPart
    }

    for _, object in ipairs(
        directObjects
    ) do

        if object
            and object.Parent then

            if GetObjectPosition(
                object
            ) then

                return object
            end
        end
    end

    local uid =
        tostring(
            data.Uid
            or ""
        )

    --==================================================
    -- EXACT UID LOOKUP
    --==================================================

    if uid ~= "" then

        local ok, object =
            pcall(
                function()

                    return workspace:
                        FindFirstChild(
                            uid,
                            true
                        )
                end
            )

        if ok
            and object
            and GetObjectPosition(
                object
            ) then

            return object
        end
    end

    --==================================================
    -- UID / ATTRIBUTE SCAN
    --==================================================

    if uid ~= "" then

        local found = nil

        pcall(
            function()

                for _, object in ipairs(
                    workspace:GetDescendants()
                ) do

                    if object.Name == uid
                        and GetObjectPosition(
                            object
                        ) then

                        found = object
                        break
                    end

                    local objectUid

                    pcall(
                        function()

                            objectUid =
                                object:GetAttribute(
                                    "Uid"
                                )

                            if objectUid == nil then

                                objectUid =
                                    object:GetAttribute(
                                        "UID"
                                    )
                            end

                            if objectUid == nil then

                                objectUid =
                                    object:GetAttribute(
                                        "EggUid"
                                    )
                            end
                        end
                    )

                    if objectUid ~= nil
                        and tostring(
                            objectUid
                        ) == uid
                        and GetObjectPosition(
                            object
                        ) then

                        found = object
                        break
                    end
                end
            end
        )

        if found then
            return found
        end
    end

    return nil
end

--==================================================
-- FALLBACK EGG POSITION
--==================================================

local function GetEggTargetPosition(
    target
)

    local object =
        FindEggObject(
            target
        )

    if object then

        local position =
            GetObjectPosition(
                object
            )

        if position then
            return position
        end
    end

    local data =
        target
        and (
            target.Data
            or target.CurrentData
            or target
        )

    local record =
        data
        and data.Record

    if record
        and type(
            record.GetPosition
        )
        == "function" then

        local ok, position =
            pcall(
                function()

                    return record:
                        GetPosition()
                end
            )

        if ok then

            if typeof(position)
                == "Vector3" then

                return position

            elseif typeof(position)
                == "CFrame" then

                return position.Position
            end
        end
    end

    return nil
end

--==================================================
-- INSTANT EGG PICKUP
--==================================================

local Workspace = game:GetService("Workspace")

-- Every CarryAreaEgg is instant when the player manually taps it.
-- This does NOT automatically collect every egg.
local function SetupEggPrompt(obj)
    if obj
        and obj:IsA("ProximityPrompt")
        and obj.Name == "CarryAreaEgg" then

        pcall(function()
            obj.HoldDuration = 0
            -- Do not require the camera/crosshair to be looking at the prompt.
            obj.RequiresLineOfSight = false
            obj.Enabled = true
        end)
    end
end

for _, obj in ipairs(Workspace:GetDescendants()) do
    SetupEggPrompt(obj)
end

Workspace.DescendantAdded:Connect(function(obj)
    SetupEggPrompt(obj)
end)

--==================================================
-- SELECTED EGG -> EXACT PROMPT ONLY
--==================================================
-- The game can have MANY "Egg Steal" prompts on screen at once.
-- Therefore we NEVER choose an Egg just because it is nearby.
-- We first bind the prompt to the SAME physical Egg using UID/name/
-- hierarchy, and only use distance as a final guarded fallback.

local function GetPromptWorldPosition(prompt)
    if not prompt or not prompt.Parent then
        return nil
    end

    local parent = prompt.Parent

    if parent:IsA("BasePart") then
        return parent.Position
    end

    if parent:IsA("Attachment") and parent.Parent then
        if parent.Parent:IsA("BasePart") then
            return parent.Parent.Position
        end
    end

    return GetObjectPosition(parent)
end

local function IsCarryPrompt(obj)
    return obj
        and obj.Parent
        and obj:IsA("ProximityPrompt")
        and obj.Name == "CarryAreaEgg"
        and obj.Enabled
end

local function GetSelectedEggUid(targetObject)
    if not targetObject then
        return ""
    end

    local target = targetObject
    local data = nil

    -- targetObject is normally the physical Egg object, but keep the
    -- record available when the caller passed the data table instead.
    if type(targetObject) == "table" then
        data = targetObject.Data
            or targetObject.CurrentData
            or targetObject
    end

    if type(data) == "table" then
        local uid = data.Uid
        if uid ~= nil and tostring(uid) ~= "" then
            return tostring(uid)
        end

        local record = data.Record
        if type(record) == "table" and record.Uid ~= nil then
            return tostring(record.Uid)
        end
    end

    -- Physical Egg attributes.
    local uid
    pcall(function()
        uid = target:GetAttribute("Uid")
        if uid == nil then uid = target:GetAttribute("UID") end
        if uid == nil then uid = target:GetAttribute("EggUid") end
        if uid == nil then uid = target:GetAttribute("EggUID") end
    end)

    return uid ~= nil and tostring(uid) or ""
end

local function GetTargetDataUid(targetObject)
    -- targetObject may actually be the data wrapper in our movement code.
    if type(targetObject) ~= "table" then
        return GetSelectedEggUid(targetObject)
    end

    local data = targetObject.Data
        or targetObject.CurrentData
        or targetObject

    if type(data) ~= "table" then
        return ""
    end

    local uid = data.Uid
    if uid == nil and type(data.Record) == "table" then
        uid = data.Record.Uid
    end

    return uid ~= nil and tostring(uid) or ""
end

local function ReadObjectUid(object)
    if not object then
        return ""
    end

    local uid
    pcall(function()
        uid = object:GetAttribute("Uid")
        if uid == nil then uid = object:GetAttribute("UID") end
        if uid == nil then uid = object:GetAttribute("EggUid") end
        if uid == nil then uid = object:GetAttribute("EggUID") end
    end)

    return uid ~= nil and tostring(uid) or ""
end

local function HasUidInAncestry(instance, uid)
    if not instance or uid == "" then
        return false
    end

    local current = instance
    while current and current ~= Workspace do
        if current.Name == uid then
            return true
        end

        if ReadObjectUid(current) == uid then
            return true
        end

        current = current.Parent
    end

    return false
end

local function IsInsideOrSameTree(a, b)
    if not a or not b then
        return false
    end

    if a == b then
        return true
    end

    local ok = false
    pcall(function()
        ok = a:IsDescendantOf(b) or b:IsDescendantOf(a)
    end)
    return ok
end

local function FindSelectedEggPrompt(targetObject, targetPosition)
    local selectedUid = GetTargetDataUid(targetObject)
    local candidates = {}

    local function add(prompt, score)
        if not IsCarryPrompt(prompt) then
            return
        end

        local pos = GetPromptWorldPosition(prompt)
        if not pos then
            return
        end

        table.insert(candidates, {
            Prompt = prompt,
            Score = score,
            Distance = targetPosition
                and (pos - targetPosition).Magnitude
                or math.huge
        })
    end

    --==================================================
    -- 1. PROMPT INSIDE THE EXACT PHYSICAL EGG
    --==================================================
    if targetObject and typeof(targetObject) ~= "table" then
        add(targetObject, 100000)

        for _, obj in ipairs(targetObject:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                add(obj, 100000)
            end
        end
    end

    --==================================================
    -- 2. UID MATCH: THE MOST IMPORTANT CHECK
    --==================================================
    -- This prevents another nearby "Egg Steal" prompt from being chosen.
    if selectedUid ~= "" then
        for _, prompt in ipairs(Workspace:GetDescendants()) do
            if IsCarryPrompt(prompt) then
                if HasUidInAncestry(prompt, selectedUid) then
                    add(prompt, 90000)
                end
            end
        end
    end

    --==================================================
    -- 3. SAME PHYSICAL TREE AS THE SELECTED EGG
    --==================================================
    if targetObject and typeof(targetObject) ~= "table" then
        for _, prompt in ipairs(Workspace:GetDescendants()) do
            if IsCarryPrompt(prompt) then
                if IsInsideOrSameTree(prompt, targetObject) then
                    add(prompt, 80000)
                end
            end
        end
    end

    --==================================================
    -- 4. PROMPT ON THE SAME PARENT/ROOT AS THE SELECTED EGG
    --==================================================
    if targetObject and typeof(targetObject) ~= "table" then
        local targetParent = targetObject.Parent
        if targetParent then
            for _, prompt in ipairs(targetParent:GetDescendants()) do
                if IsCarryPrompt(prompt) then
                    add(prompt, 70000)
                end
            end
        end
    end

    --==================================================
    -- 5. SELECTED-EGG POSITION MATCH (NO CAMERA REQUIRED)
    --==================================================
    -- If the game's prompt is stored beside the Egg instead of inside
    -- its model, identity/hierarchy matching above may not find it.
    -- In that case, match the prompt to the SELECTED EGG'S own world
    -- position, never to the camera and never to the player's facing.
    -- This is intentionally allowed even when several Egg Steal prompts
    -- are nearby: the closest prompt to the selected Egg wins.
    if #candidates == 0 and targetPosition then
        local nearest = nil
        local nearestDistance = math.huge

        for _, prompt in ipairs(Workspace:GetDescendants()) do
            if IsCarryPrompt(prompt) then
                local pos = GetPromptWorldPosition(prompt)
                if pos then
                    local distance = (pos - targetPosition).Magnitude
                    if distance <= 6 and distance < nearestDistance then
                        nearestDistance = distance
                        nearest = prompt
                    end
                end
            end
        end

        if nearest then
            add(nearest, 50000 - nearestDistance)
        end
    end

    if #candidates == 0 then
        return nil
    end

    table.sort(candidates, function(a, b)
        if a.Score ~= b.Score then
            return a.Score > b.Score
        end
        return a.Distance < b.Distance
    end)

    return candidates[1].Prompt
end

--==================================================
-- RELIABLE EXACT-PROMPT TRIGGER
--==================================================
-- Re-resolve the SAME selected Egg while the player is in pickup range.
-- We never cycle through other Eggs just because the first prompt missed.

local function TriggerEggPrompt(prompt)
    if not IsCarryPrompt(prompt) then
        return false
    end

    pcall(function()
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
    end)

    -- Prefer the executor's direct ProximityPrompt trigger when available.
    -- This does not depend on the camera/crosshair being over the prompt.
    if type(fireproximityprompt) == "function" then
        local directOk = pcall(function()
            fireproximityprompt(prompt)
        end)
        if directOk then
            return true
        end
    end

    -- Native fallback.
    local ok = pcall(function()
        prompt:InputHoldBegin()
        task.defer(function()
            if prompt and prompt.Parent then
                pcall(function()
                    prompt:InputHoldEnd()
                end)
            end
        end)
    end)

    return ok
end

local function CollectSelectedEgg(targetObject, targetPosition)
    local deadline = os.clock() + 0.45
    local lastPrompt = nil

    while os.clock() < deadline do
        local prompt = FindSelectedEggPrompt(
            targetObject,
            targetPosition
        )

        if prompt then
            lastPrompt = prompt

            -- Multiple short attempts against the SAME selected Egg.
            TriggerEggPrompt(prompt)
            task.wait(0.025)

            -- If the selected prompt disappears or is disabled, the game
            -- has accepted the pickup.
            if not prompt.Parent or not prompt.Enabled then
                return true
            end
        end

        task.wait(0.025)
    end

    -- Final attempt, still only against the selected Egg.
    if lastPrompt and lastPrompt.Parent and lastPrompt.Enabled then
        TriggerEggPrompt(lastPrompt)
    end

    return lastPrompt ~= nil
end

--==================================================
-- HARD STOP
--==================================================

local function HardStopCharacter(
    humanoid,
    rootPart
)

    if not humanoid
        or not rootPart then

        return
    end

    pcall(
        function()

            humanoid:Move(
                Vector3.zero,
                false
            )
        end
    )

    pcall(
        function()

            humanoid:MoveTo(
                rootPart.Position
            )
        end
    )

    pcall(
        function()

            rootPart.AssemblyLinearVelocity =
                Vector3.zero

            rootPart.AssemblyAngularVelocity =
                Vector3.zero
        end
    )
end

--==================================================
-- TP / RETURN SYSTEM
-- COPIED FROM tp.txt: FlyTo -> StepAxis -> StepToBase
--==================================================

local Returning = false
local CurrentDropTarget = nil

local DROP_WAIT = 0.4
local BASE_X = 530
local STEP_TARGET_X = 600
local STEP_TARGET_Z = -420
local STEP_Y = 71
local FLY_THRESHOLD_X = 2000
local FLY_SPEED_MULT = 1.25

local FlyAnimation = nil
local HeadOriginalSize = nil
local HeadOriginalMeshScale = nil
local HeadScaled = false

local SafeCarry = {
    StepSpeed = 0.1,
    DropDelay = 0,
    SnapPickup = true,
    PickupRatio = 0.667,
    LineGap = 12,
    LineWait = 15,
    DirectBudget = 200000,
    DirectMargin = 0.1
}

local function GetRoot()
    local character = LocalPlayer.Character
    if not character then
        return nil
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    if root and root:IsDescendantOf(workspace) then
        return root
    end

    return nil
end

local function GetHumanoid()
    local character = LocalPlayer.Character
    if not character then
        return nil
    end

    return character:FindFirstChildOfClass("Humanoid")
end

local function StopVelocity(root)
    if not root then
        return
    end

    pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function GetRigType(hum)
    if hum and hum.RigType == Enum.HumanoidRigType.R15 then
        return "R15"
    end
    return "R6"
end

local function StartFlyVisuals()
    local char = LocalPlayer.Character
    if not char then
        return
    end

    local hum = GetHumanoid()
    if not hum then
        return
    end

    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = hum
    end

    local walkId
    if GetRigType(hum) == "R15" then
        walkId = "rbxassetid://507777826"
    else
        walkId = "rbxassetid://180426354"
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = walkId

    local ok, track = pcall(function()
        return animator:LoadAnimation(anim)
    end)

    if ok and track then
        pcall(function()
            track.Priority = Enum.AnimationPriority.Movement
            track:Play(0.3, 1, 0.4)
        end)
        FlyAnimation = track
    end

    local head = char:FindFirstChild("Head")
    if head then
        if head:IsA("BasePart") and not HeadScaled then
            HeadOriginalSize = head.Size
            head.Size = head.Size * 1.8
            HeadScaled = true
        end

        local mesh = head:FindFirstChildOfClass("SpecialMesh")
        if mesh then
            if not HeadOriginalMeshScale then
                HeadOriginalMeshScale = mesh.Scale
            end
            mesh.Scale = HeadOriginalMeshScale * 1.8
        end
    end
end

local function StopFlyVisuals()
    if FlyAnimation then
        pcall(function()
            FlyAnimation:Stop(0.3)
        end)
        FlyAnimation = nil
    end

    local char = LocalPlayer.Character
    if char then
        local head = char:FindFirstChild("Head")
        if head then
            if HeadScaled and HeadOriginalSize then
                pcall(function()
                    head.Size = HeadOriginalSize
                end)
            end

            local mesh = head:FindFirstChildOfClass("SpecialMesh")
            if mesh and HeadOriginalMeshScale then
                pcall(function()
                    mesh.Scale = HeadOriginalMeshScale
                end)
            end
        end
    end

    HeadScaled = false
    HeadOriginalSize = nil
    HeadOriginalMeshScale = nil
end

local function FlyTo(targetPosition, speed)
    local root = GetRoot()
    if not root then
        return false
    end

    local character = LocalPlayer.Character

    StartFlyVisuals()

    while StealRunning and Returning do
        local part = GetRoot()
        if not part or LocalPlayer.Character ~= character then
            StopFlyVisuals()
            return false
        end

        local current = part.Position
        local dx = targetPosition.X - current.X
        local dz = targetPosition.Z - current.Z
        local distance = math.sqrt(dx * dx + dz * dz)

        if distance <= 1 then
            pcall(function()
                part.CFrame = CFrame.new(targetPosition.X, STEP_Y, targetPosition.Z) * CFrame.Angles(0, math.rad(300), 0)
                part.AssemblyLinearVelocity = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
            end)
            StopFlyVisuals()
            return true
        end

        local invDist = 1 / distance
        local dirX = dx * invDist
        local dirZ = dz * invDist

        pcall(function()
            part.CFrame = CFrame.new(current.X, STEP_Y, current.Z) * CFrame.Angles(0, math.rad(300), 0)
            part.AssemblyLinearVelocity = Vector3.new(dirX * speed, 0, dirZ * speed)
            part.AssemblyAngularVelocity = Vector3.zero
        end)

        RunService.Heartbeat:Wait()
    end

    StopFlyVisuals()
    return false
end

local function GetStepDistance(value)
    local distance = math.abs(value)
    if distance < 2000 then
        return 300
    elseif distance < 3000 then
        return 300
    elseif distance < 4000 then
        return 450
    elseif distance < 6000 then
        return 600
    else
        return 750
    end
end

local function StepAxis(axis, targetValue, character)
    while StealRunning and Returning do
        local part = GetRoot()
        if not part then
            return false
        end

        if LocalPlayer.Character ~= character then
            return false
        end

        local current = part.Position
        local currentVal

        if axis == "X" then
            currentVal = current.X
        else
            currentVal = current.Z
        end

        local distance = math.abs(targetValue - currentVal)
        if distance <= 0.5 then
            break
        end

        local direction
        if targetValue > currentVal then
            direction = 1
        else
            direction = -1
        end

        local stepDistance = math.min(GetStepDistance(currentVal), distance)
        local nextVal = currentVal + direction * stepDistance

        if direction > 0 and nextVal > targetValue then
            nextVal = targetValue
        elseif direction < 0 and nextVal < targetValue then
            nextVal = targetValue
        end

        local timer = 0
        while timer < SafeCarry.StepSpeed and StealRunning and Returning do
            local stepRoot = GetRoot()
            if not stepRoot then
                return false
            end

            local pos = stepRoot.Position
            local newX, newZ

            if axis == "X" then
                newX = nextVal
                newZ = pos.Z
            else
                newX = pos.X
                newZ = nextVal
            end

            pcall(function()
                stepRoot.CFrame = CFrame.new(newX, STEP_Y, newZ) * CFrame.Angles(0, math.rad(300), 0)
                StopVelocity(stepRoot)
            end)

            timer += RunService.Heartbeat:Wait()
        end
    end

    return true
end

local function StepToBase()
    local root = GetRoot()
    if not root then
        return false
    end

    local character = LocalPlayer.Character
    local startPosition = root.Position
    local startX = startPosition.X
    local startZ = startPosition.Z

    local humanoid = GetHumanoid()
    local playerSpeed = humanoid and humanoid.WalkSpeed or 16
    local flySpeed = playerSpeed * FLY_SPEED_MULT

    pcall(function()
        root.CFrame = CFrame.new(startX, STEP_Y, startZ) * CFrame.Angles(0, math.rad(300), 0)
        StopVelocity(root)
    end)

    if startX < FLY_THRESHOLD_X then
        CurrentDropTarget = Vector3.new(BASE_X, STEP_Y, startZ)
        local ok = FlyTo(CurrentDropTarget, flySpeed)
        if not ok then
            return false
        end
        return true
    end

    CurrentDropTarget = Vector3.new(STEP_TARGET_X, STEP_Y, STEP_TARGET_Z)

    local okX = StepAxis("X", STEP_TARGET_X, character)
    if not okX then
        return false
    end

    if not StealRunning or not Returning then
        return false
    end

    local okZ = StepAxis("Z", STEP_TARGET_Z, character)
    if not okZ then
        return false
    end

    local finalRoot = GetRoot()
    if not finalRoot then
        return false
    end

    pcall(function()
        finalRoot.CFrame = CFrame.new(STEP_TARGET_X, STEP_Y, STEP_TARGET_Z) * CFrame.Angles(0, math.rad(300), 0)
        StopVelocity(finalRoot)
    end)

    RunService.Heartbeat:Wait()

    local checkRoot = GetRoot()
    if not checkRoot then
        return false
    end

    pcall(function()
        checkRoot.CFrame = CFrame.new(STEP_TARGET_X, STEP_Y, STEP_TARGET_Z) * CFrame.Angles(0, math.rad(300), 0)
        StopVelocity(checkRoot)
    end)

    return true
end

--==================================================
-- TP.TXT DROP / CARRY-AGAIN CHAIN
-- Source: tp.txt
-- Adapted only so its Enabled flag follows this file's StealRunning state.
--==================================================

local Networking = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networking")

local NET = ReplicatedStorage:FindFirstChild("Packages")
NET = NET and NET:FindFirstChild("Networking") or nil

local function findRemote(name, alt)
    local remote = NET and NET:FindFirstChild(name, true)
    if remote then
        return remote
    end
    remote = ReplicatedStorage:FindFirstChild(name, true)
    if remote then
        return remote
    end
    if alt then
        remote = (NET and NET:FindFirstChild(alt, true)) or ReplicatedStorage:FindFirstChild(alt, true)
    end
    return remote
end

local AskFieldEggDrop = findRemote("RF/EggWorld/AskFieldEggDrop", "AskFieldEggDrop")

local Carrying = false
local CarryUid = nil
local CarryAreaId = nil

local function DropEgg()
    if not AskFieldEggDrop then
        AskFieldEggDrop = findRemote("RF/EggWorld/AskFieldEggDrop", "AskFieldEggDrop")
    end
    if not AskFieldEggDrop then
        return false
    end

    local ok = pcall(function()
        if AskFieldEggDrop:IsA("RemoteFunction") then
            AskFieldEggDrop:InvokeServer({ Reason = "PlayerRequest" })
        else
            AskFieldEggDrop:FireServer({ Reason = "PlayerRequest" })
        end
    end)

    return ok
end

local function GetEggSnapshot()
    local remote = Networking:FindFirstChild("RF/EggWorld/AskFieldEggSnapshot")
    if not remote or not remote:IsA("RemoteFunction") then
        return nil
    end

    local ok, result = pcall(function()
        return remote:InvokeServer()
    end)

    if not ok or type(result) ~= "table" then
        return nil
    end

    return result
end

local function FindEgg(uid)
    if type(uid) ~= "string" then
        return nil
    end

    local snapshot = GetEggSnapshot()
    if not snapshot then
        return nil
    end

    local records = snapshot.Records
    if type(records) ~= "table" then
        return nil
    end

    for _, record in pairs(records) do
        if type(record) == "table" and record.Uid == uid then
            return record
        end
    end

    return nil
end

local function CarryEgg(uid)
    if type(uid) ~= "string" then
        return false
    end
    if not EggState then
        return false
    end
    if type(EggState.CarryFieldEgg) ~= "function" then
        return false
    end

    local ok = pcall(EggState.CarryFieldEgg, uid)
    return ok
end

local function GetPromptPosition(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then
        return nil
    end

    local parent = prompt.Parent
    if not parent then
        return nil
    end

    if parent:IsA("Attachment") then
        return parent.WorldPosition
    end

    if parent:IsA("BasePart") then
        return parent.Position
    end

    local part = parent:FindFirstChildWhichIsA("BasePart", true)
    if part then
        return part.Position
    end

    return nil
end

local function IsStealPrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then
        return false
    end

    local text = string.lower(tostring(prompt.ActionText or ""))
    local objectText = string.lower(tostring(prompt.ObjectText or ""))
    local combined = text .. " " .. objectText

    return combined:find("steal", 1, true) ~= nil
        or combined:find("cắp", 1, true) ~= nil
        or combined:find("cap", 1, true) ~= nil
        or combined:find("trộm", 1, true) ~= nil
        or combined:find("trom", 1, true) ~= nil
        or combined:find("egg", 1, true) ~= nil
end

local function ApplyInstantPrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then
        return
    end

    pcall(function()
        prompt.HoldDuration = 0
    end)
end

local function FirePrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then
        return false
    end

    ApplyInstantPrompt(prompt)

    local ok = false

    pcall(function()
        if fireproximityprompt then
            fireproximityprompt(prompt, 0, true)
            ok = true
        end
    end)

    if ok then
        return true
    end

    pcall(function()
        if fireproximityprompt then
            fireproximityprompt(prompt, 1, true)
            ok = true
        end
    end)

    return ok
end

local function FindEggPromptFromPosition(origin, maxDistance)
    local best
    local bestDistance = maxDistance or math.huge

    for _, prompt in ipairs(workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Enabled and IsStealPrompt(prompt) then
            local position = GetPromptPosition(prompt)
            if position then
                local distance = (position - origin).Magnitude
                if distance < bestDistance then
                    bestDistance = distance
                    best = prompt
                end
            end
        end
    end

    return best
end

local function WaitUntilCarrying(uid, timeout)
    local elapsed = 0

    while elapsed < timeout do
        if not StealRunning then
            return false
        end

        if Carrying and (type(uid) ~= "string" or CarryUid == uid) then
            return true
        end

        elapsed += RunService.Heartbeat:Wait()
    end

    return false
end

local function CarryAgainAtDropPoint(uid, dropPosition)
    -- PATCH: UID-matched, verified re-pickup (see shared.MochiEggFix)
    do
        local fix = shared.MochiEggFix
        if fix and fix.CarryAgain and type(uid) == "string" then
            return fix.CarryAgain(uid, dropPosition)
        end
    end

    if type(uid) ~= "string" then
        return false
    end
    if not dropPosition then
        return false
    end
    if Carrying and CarryUid == uid then
        return true
    end

    local prompt
    local elapsed = 0

    while elapsed < 3 do
        if not StealRunning then
            return false
        end

        prompt = FindEggPromptFromPosition(dropPosition, 35)
        if prompt then
            break
        end

        elapsed += RunService.Heartbeat:Wait()
    end

    if not prompt then
        CarryEgg(uid)
        if WaitUntilCarrying(uid, 0.5) then
            return true
        end
        return false
    end

    local promptPosition = GetPromptPosition(prompt)
    if promptPosition then
        local root = GetRoot()
        if root then
            local distance = (promptPosition - root.Position).Magnitude
            if distance > 8 then
                local resetRoot = GetRoot()
                if resetRoot then
                    pcall(function()
                        resetRoot.CFrame = CFrame.new(dropPosition.X, STEP_Y, dropPosition.Z)
                        StopVelocity(resetRoot)
                    end)
                    RunService.Heartbeat:Wait()
                end
            end
        end
    end

    FirePrompt(prompt)
    task.wait(0.05)

    if Carrying and CarryUid == uid then
        return true
    end

    CarryEgg(uid)
    if WaitUntilCarrying(uid, 0.5) then
        return true
    end

    FirePrompt(prompt)
    CarryEgg(uid)
    if WaitUntilCarrying(uid, 1) then
        return true
    end

    return false
end

local function MoveTo(position, speed)
    local root = GetRoot()
    if not root then
        return false
    end

    local character = LocalPlayer.Character
    local finished = false
    local success = false
    local connection

    connection = RunService.Heartbeat:Connect(function(deltaTime)
        local currentRoot = GetRoot()
        if not currentRoot or LocalPlayer.Character ~= character then
            finished = true
            return
        end

        local current = currentRoot.Position
        local offset = position - current
        local distance = offset.Magnitude

        if distance <= 0.5 then
            pcall(function()
                currentRoot.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(300), 0)
                StopVelocity(currentRoot)
            end)
            success = true
            finished = true
            return
        end

        local step = math.max(speed * deltaTime, 0.1)
        local nextPosition = current + offset.Unit * math.min(step, distance)

        pcall(function()
            currentRoot.CFrame = CFrame.new(nextPosition) * CFrame.Angles(0, math.rad(300), 0)
            StopVelocity(currentRoot)
        end)
    end)

    while not finished do
        if not StealRunning then
            finished = true
            break
        end
        RunService.Heartbeat:Wait()
    end

    if connection then
        connection:Disconnect()
    end

    return success
end

shared.MochiStandPos = Vector3.new(545.50, 70.44, -412.95)

local function ReturnToX530()
    local root = GetRoot()
    if not root then
        return false
    end

    local humanoid = GetHumanoid()
    local playerSpeed = humanoid and humanoid.WalkSpeed or 16
    local returnSpeed = playerSpeed * FLY_SPEED_MULT
    local current = root.Position
    local target = shared.MochiStandPos or Vector3.new(BASE_X, STEP_Y, current.Z)

    return MoveTo(target, returnSpeed)
end

local function EnsureExactDropPosition(targetPosition)
    if not targetPosition then
        return false
    end

    for _ = 1, 3 do
        local root = GetRoot()
        if not root then
            return false
        end

        local pos = root.Position
        local dx = math.abs(pos.X - targetPosition.X)
        local dz = math.abs(pos.Z - targetPosition.Z)

        if dx <= 0.5 and dz <= 0.5 then
            return true
        end

        pcall(function()
            root.CFrame = CFrame.new(targetPosition.X, STEP_Y, targetPosition.Z) * CFrame.Angles(0, math.rad(300), 0)
            StopVelocity(root)
        end)

        RunService.Heartbeat:Wait()
        RunService.Heartbeat:Wait()
    end

    local root = GetRoot()
    if not root then
        return false
    end

    local pos = root.Position
    return math.abs(pos.X - targetPosition.X) <= 1
        and math.abs(pos.Z - targetPosition.Z) <= 1
end

local function DropThenPrompt()
    if not Carrying then
        return false
    end

    local uid = CarryUid
    if type(uid) ~= "string" then
        return false
    end

    local targetPosition = CurrentDropTarget
    if not targetPosition then
        targetPosition = Vector3.new(STEP_TARGET_X, STEP_Y, STEP_TARGET_Z)
    end

    if not EnsureExactDropPosition(targetPosition) then
        return false
    end

    local dropPosition = Vector3.new(targetPosition.X, STEP_Y, targetPosition.Z)

    local dropped = DropEgg()
    if not dropped then
        return false
    end

    task.wait(DROP_WAIT)

    if not StealRunning then
        return false
    end

    if not StealRunning then
        return false
    end

    local rootAfterDrop = GetRoot()
    if not rootAfterDrop then
        return false
    end

    pcall(function()
        rootAfterDrop.CFrame = CFrame.new(targetPosition.X, STEP_Y, targetPosition.Z) * CFrame.Angles(0, math.rad(300), 0)
        StopVelocity(rootAfterDrop)
    end)

    RunService.Heartbeat:Wait()

    -- Camera + character go back to the DROP spot now, so the player sees
    -- the place where the dropped egg is being picked up again.
    if shared.MochiStopCarryView then
        pcall(shared.MochiStopCarryView)
    end

    local carriedAgain = CarryAgainAtDropPoint(uid, dropPosition)
    if not carriedAgain then
        return false
    end

    if not Carrying or CarryUid ~= uid then
        return false
    end

    task.wait(0.05)

    if not Carrying or CarryUid ~= uid then
        return false
    end

    if targetPosition.X <= BASE_X + 5 then
        return true
    end

    -- Egg is already re-picked up here, so release the camera hold now;
    -- otherwise the camera stays stuck at the old spot during the walk back.
    if shared.MochiStopCarryView then
        pcall(shared.MochiStopCarryView)
    end

    return ReturnToX530()
end

-- Keep the carry state synchronized with the same EggState signal used by tp.txt.
if EggState and type(EggState.CarryChanged) == "table" and type(EggState.CarryChanged.Connect) == "function" then
    pcall(function()
        EggState.CarryChanged:Connect(function(data)
            local carrying = type(data) == "table" and data.IsCarrying == true
            Carrying = carrying

            if carrying and type(data.Uid) == "string" then
                CarryUid = data.Uid
                CarryAreaId = data.AreaId
            elseif not carrying then
                CarryUid = nil
                CarryAreaId = nil
            end
        end)
    end)
end


--==================================================
-- CARRY VIEW HOLD
-- Keeps the player's visible character + camera at
-- the ORIGINAL pickup location while the real
-- character is moved to the drop point.
-- The real character is restored only after the Egg
-- has been dropped and the dropped Egg is carried again.
--==================================================

local CarryViewHold = {
    Active = false,
    Proxy = nil,
    Camera = nil,
    CameraCFrame = nil,
    CameraType = nil,
    CameraSubject = nil,
    HiddenParts = {},
    RenderConnection = nil
}

local function SetLocalCharacterHidden(character, hidden)
    if not character then
        return
    end

    if hidden then
        table.clear(CarryViewHold.HiddenParts)

        for _, obj in ipairs(character:GetDescendants()) do
            if obj:IsA("BasePart") then
                local old = obj.LocalTransparencyModifier
                CarryViewHold.HiddenParts[obj] = old
                pcall(function()
                    obj.LocalTransparencyModifier = 1
                end)
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                local old = obj.Transparency
                CarryViewHold.HiddenParts[obj] = old
                pcall(function()
                    obj.Transparency = 1
                end)
            end
        end
    else
        for obj, old in pairs(CarryViewHold.HiddenParts) do
            if obj and obj.Parent then
                pcall(function()
                    if obj:IsA("BasePart") then
                        obj.LocalTransparencyModifier = old or 0
                    elseif obj:IsA("Decal") or obj:IsA("Texture") then
                        obj.Transparency = old or 0
                    end
                end)
            end
        end

        table.clear(CarryViewHold.HiddenParts)
    end
end

local function DestroyCarryViewProxy()
    if CarryViewHold.RenderConnection then
        pcall(function()
            CarryViewHold.RenderConnection:Disconnect()
        end)
        CarryViewHold.RenderConnection = nil
    end

    if CarryViewHold.Proxy then
        pcall(function()
            CarryViewHold.Proxy:Destroy()
        end)
        CarryViewHold.Proxy = nil
    end
end

local function StopCarryViewHold()
    if not CarryViewHold.Active then
        DestroyCarryViewProxy()
        return
    end

    CarryViewHold.Active = false

    local camera = CarryViewHold.Camera
        or workspace.CurrentCamera

    if camera then
        pcall(function()
            camera.CameraType = CarryViewHold.CameraType
                or Enum.CameraType.Custom
        end)

        if CarryViewHold.CameraSubject
            and CarryViewHold.CameraSubject.Parent then
            pcall(function()
                camera.CameraSubject = CarryViewHold.CameraSubject
            end)
        else
            -- Fallback: the saved subject may be the old (swapped) Humanoid,
            -- so point the camera at the CURRENT Humanoid instead.
            local hum = GetHumanoid()
            if hum then
                pcall(function()
                    camera.CameraSubject = hum
                end)
            end
        end
    end

    SetLocalCharacterHidden(
        LocalPlayer.Character,
        false
    )

    DestroyCarryViewProxy()

    CarryViewHold.Camera = nil
    CarryViewHold.CameraCFrame = nil
    CarryViewHold.CameraType = nil
    CarryViewHold.CameraSubject = nil
end

local function StartCarryViewHold(rootPart)
    StopCarryViewHold()

    local character = LocalPlayer.Character
    local camera = workspace.CurrentCamera

    if not character
        or not rootPart
        or not camera then
        return false
    end

    local fixHold = shared.MochiEggFix
    local pickupCFrame = (fixHold and fixHold.PickupCFrame) or rootPart.CFrame
    local savedCameraCFrame = (fixHold and fixHold.PickupCamCFrame) or camera.CFrame
    if fixHold then
        fixHold.PickupCFrame = nil
        fixHold.PickupCamCFrame = nil
    end

    local proxy = nil
    local oldArchivable = character.Archivable

    local cloneOk = pcall(function()
        character.Archivable = true
        proxy = character:Clone()
    end)

    pcall(function()
        character.Archivable = oldArchivable
    end)

    if not cloneOk or not proxy then
        return false
    end

    proxy.Name = "MochiCarryViewProxy"
    proxy.Parent = workspace

    local proxyRoot =
        proxy:FindFirstChild("HumanoidRootPart")

    if not proxyRoot then
        proxy:Destroy()
        return false
    end

    -- Remove scripts from the local visual copy.
    for _, obj in ipairs(proxy:GetDescendants()) do
        if obj:IsA("Script")
            or obj:IsA("LocalScript")
            or obj:IsA("ModuleScript") then
            pcall(function()
                obj:Destroy()
            end)
        elseif obj:IsA("BasePart") then
            pcall(function()
                obj.Anchored = true
                obj.CanCollide = false
                obj.CanTouch = false
                obj.CanQuery = false
                obj.Massless = true
            end)
        end
    end

    pcall(function()
        proxy:PivotTo(pickupCFrame)
    end)

    local proxyHumanoid =
        proxy:FindFirstChildOfClass("Humanoid")

    if proxyHumanoid then
        pcall(function()
            proxyHumanoid.DisplayDistanceType =
                Enum.HumanoidDisplayDistanceType.None
            proxyHumanoid.AutoRotate = false
        end)
    end

    CarryViewHold.Active = true
    CarryViewHold.Proxy = proxy
    CarryViewHold.Camera = camera
    CarryViewHold.CameraCFrame = savedCameraCFrame
    CarryViewHold.CameraType = camera.CameraType
    CarryViewHold.CameraSubject = camera.CameraSubject

    SetLocalCharacterHidden(character, true)

    -- Lock the camera exactly where it was at pickup.
    pcall(function()
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = savedCameraCFrame
    end)

    CarryViewHold.RenderConnection =
        RunService.RenderStepped:Connect(function()
            if not CarryViewHold.Active then
                return
            end

            local currentCamera =
                workspace.CurrentCamera

            if currentCamera then
                pcall(function()
                    currentCamera.CameraType =
                        Enum.CameraType.Scriptable

                    currentCamera.CFrame =
                        CarryViewHold.CameraCFrame
                end)
            end

            if CarryViewHold.Proxy
                and CarryViewHold.Proxy.Parent then
                pcall(function()
                    CarryViewHold.Proxy:PivotTo(
                        pickupCFrame
                    )
                end)
            end
        end)

    return true
end

-- Exposed so DropThenPrompt (defined above this point) can release the view hold.
shared.MochiStopCarryView = StopCarryViewHold

-- Keep the original viewpoint ONLY while an Egg is selected.
-- Anti Guard is deliberately unrelated to this behavior.
-- When no Egg is selected, restore the normal camera and movement controls.
shared.MochiViewHoldRefresh = function()
    local anyEggSelected = false
    for _, card in ipairs(Cards) do
        if card and card.IsSelected then
            anyEggSelected = true
            break
        end
    end

    local shouldHoldView = anyEggSelected

    if shouldHoldView then
        if not CarryViewHold.Active then
            local root = GetRoot()
            if root then
                local camera = workspace.CurrentCamera
                if camera then
                    local fix = shared.MochiEggFix
                    if fix then
                        fix.PickupCFrame = root.CFrame
                        fix.PickupCamCFrame = camera.CFrame
                    end
                    pcall(function()
                        StartCarryViewHold(root)
                    end)
                end
            end
        end
    else
        StopCarryViewHold()
    end
end

local function TPAfterEggPickup()
    -- TEMPORARY MODE: the initial selected-Egg pickup is the endpoint.
    -- Do not start the post-pickup teleport/drop/re-pickup/return sequence.
    -- Anti Guard remains controlled independently by its existing ON/OFF toggle.
    if not StealRunning then
        return false
    end

    return Carrying == true
end


--==================================================
-- PATCH: RELIABLE PICKUP / FAR-EGG TP / VERIFIED RE-PICKUP
-- Success is decided by EggState (Carrying + CarryUid), never by
-- "a prompt was found".  Stored in shared.MochiEggFix so it adds
-- no new top-level locals.
--==================================================
do
    local Fix = {}
    shared.MochiEggFix = Fix

    local function IsCarryingUid(uid)
        return Carrying == true and (uid == nil or CarryUid == uid)
    end

    function Fix.EggUidOf(target)
        if type(target) ~= "table" then
            return nil
        end
        local uid = target.Uid
        local data = target.Data or target.CurrentData or target
        if (uid == nil or tostring(uid) == "") and type(data) == "table" then
            uid = data.Uid
            if uid == nil and type(data.Record) == "table" then
                uid = data.Record.Uid
            end
        end
        if uid == nil or tostring(uid) == "" then
            return nil
        end
        return tostring(uid)
    end

    local function ToVector(v)
        if typeof(v) == "Vector3" then
            return v
        elseif typeof(v) == "CFrame" then
            return v.Position
        elseif typeof(v) == "Instance" then
            if v:IsA("BasePart") then
                return v.Position
            elseif v:IsA("Model") then
                local ok, cf = pcall(function() return v:GetPivot() end)
                if ok and cf then
                    return cf.Position
                end
            end
        end
        return nil
    end

    local function RecordPosition(rec)
        if type(rec) ~= "table" then
            return ToVector(rec)
        end

        if type(rec.GetPosition) == "function" then
            local ok, v = pcall(function() return rec:GetPosition() end)
            if ok and ToVector(v) then
                return ToVector(v)
            end
        end

        for _, key in ipairs({
            "Position", "Pos", "CFrame", "Location", "WorldPosition",
            "Origin", "Model", "Part", "PrimaryPart", "Instance", "Object"
        }) do
            local ok, v = pcall(function() return rec[key] end)
            if ok and ToVector(v) then
                return ToVector(v)
            end
        end

        -- generic scan: any Vector3/CFrame/Instance-valued field
        for _, v in pairs(rec) do
            local vec = ToVector(v)
            if vec then
                return vec
            end
        end

        return nil
    end

    local function DescribeRecord(rec)
        if type(rec) ~= "table" then
            return tostring(rec)
        end
        local keys = {}
        for k, v in pairs(rec) do
            keys[#keys + 1] = tostring(k) .. ":" .. typeof(v)
            if #keys >= 14 then
                break
            end
        end
        return "{" .. table.concat(keys, ",") .. "}"
    end

    -- Live position of a dropped / selected egg by UID.
    function Fix.SnapshotPosition(uid)
        if type(uid) ~= "string" then
            return nil
        end
        local ok, rec = pcall(FindEgg, uid)
        if ok then
            return RecordPosition(rec)
        end
        return nil
    end

    -- Find the prompt that belongs to THIS egg.
    -- loose = also accept prompts recognised by IsStealPrompt (dropped eggs).
    -- flat  = compare distance on X/Z only (ignore height).
    function Fix.FindPrompt(uid, targetObject, pos, radius, loose, flat)
        if targetObject and typeof(targetObject) == "Instance" and targetObject.Parent then
            if IsCarryPrompt(targetObject) then
                return targetObject
            end
            for _, d in ipairs(targetObject:GetDescendants()) do
                if IsCarryPrompt(d) then
                    return d
                end
            end
        end

        local best, bestDist = nil, math.huge
        for _, pr in ipairs(workspace:GetDescendants()) do
            if pr:IsA("ProximityPrompt") and pr.Enabled and pr.Parent then
                local ok = IsCarryPrompt(pr) or (loose and IsStealPrompt(pr))
                if ok then
                    if uid and HasUidInAncestry(pr, uid) then
                        return pr
                    end
                    if pos then
                        local pp = GetPromptPosition(pr) or GetPromptWorldPosition(pr)
                        if pp then
                            local d
                            if flat then
                                d = (Vector3.new(pp.X, 0, pp.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
                            else
                                d = (pp - pos).Magnitude
                            end
                            if d <= (radius or 4) and d < bestDist then
                                best, bestDist = pr, d
                            end
                        end
                    end
                end
            end
        end
        return best
    end

    -- DIRECT CFrame teleport beside the selected Egg (including far-away Eggs).
    -- Keep the existing character/camera view hold separate from Anti Guard.
    function Fix.GoNear(pos, stopDist)
        if not pos or not StealRunning then
            return false
        end

        stopDist = stopDist or 3
        local character = LocalPlayer.Character
        local root = GetRoot()
        if not root or not character then
            return false
        end

        local current = root.Position
        local flatOffset = Vector3.new(pos.X - current.X, 0, pos.Z - current.Z)
        local flatDistance = flatOffset.Magnitude
        local heightDifference = math.abs(pos.Y - current.Y)

        -- Already beside the Egg: do not teleport again.
        if flatDistance <= stopDist and heightDifference <= 10 then
            return true
        end

        -- Request the destination region first, then teleport in ONE CFrame assignment.
        local offset = flatDistance > 0.1 and flatOffset.Unit * -math.min(2, flatDistance) or Vector3.zero
        local destination = Vector3.new(pos.X + offset.X, pos.Y + 2, pos.Z + offset.Z)
        pcall(function()
            LocalPlayer:RequestStreamAroundAsync(destination, 1)
        end)

        root = GetRoot()
        if not root or LocalPlayer.Character ~= character or not StealRunning then
            return false
        end

        -- Anchor during the jump so the character can't free-fall (and die)
        -- while the far-away ground is still streaming in.
        local function Unanchor()
            pcall(function()
                local r = GetRoot()
                if r then r.Anchored = false end
            end)
        end

        local teleported = pcall(function()
            root.Anchored = true
            root.CFrame = CFrame.new(destination)
            StopVelocity(root)
        end)
        if not teleported then
            Unanchor()
            return false
        end

        -- Wait (max ~4s) until there is ground under the destination.
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = { character }
        local groundDeadline = os.clock() + 4
        while os.clock() < groundDeadline do
            if not StealRunning then
                Unanchor()
                return false
            end
            if workspace:Raycast(destination, Vector3.new(0, -80, 0), rayParams) then
                break
            end
            task.wait(0.1)
        end

        -- User-requested settle time before attempting the selected Egg pickup.
        task.wait(1)
        Unanchor()

        root = GetRoot()
        if not root or LocalPlayer.Character ~= character or not StealRunning then
            return false
        end

        local finalOffset = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)
        return finalOffset.Magnitude <= stopDist + 4
    end

    -- Pickup that only returns true when the game says we are carrying it.
    -- While collecting, the instant-TP hook is "armed": the moment the game
    -- reports that we picked the egg up, the character is sent up to STEP_Y
    -- (away from the egg guard) from the signal itself, not from a polling loop.
    function Fix.Collect(target, targetObject, targetPosition)
        local uid = Fix.EggUidOf(target)
        local startedAt = os.clock()
        local deadline = startedAt + 4
        local lastCarryCall = -1
        local lastScan = -1
        local lastLive = -1
        local lastFire = -1
        local prompt = nil

        Fix.PickupCFrame = nil
        Fix.PickupCamCFrame = nil

        local function Arm()
            local root = GetRoot()
            if root then
                Fix.ArmCFrame = root.CFrame
            end
            local cam = workspace.CurrentCamera
            if cam then
                Fix.ArmCam = cam.CFrame
            end
            Fix.Armed = true
        end

        while os.clock() < deadline do
            if not StealRunning then
                Fix.Armed = false
                return false
            end
            if IsCarryingUid(uid) then
                Fix.Armed = false
                return true
            end

            -- keep following the live egg position and stay close (throttled)
            if os.clock() - lastLive > 0.25 then
                lastLive = os.clock()
                local live = GetEggTargetPosition(target)
                if live then
                    targetPosition = live
                end
                local root = GetRoot()
                if root and targetPosition then
                    local flat = (Vector3.new(targetPosition.X, 0, targetPosition.Z)
                        - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
                    if flat > 6 then
                        Fix.GoNear(targetPosition, StealStopDistance)
                        -- A far teleport takes several seconds (ground streaming + settle).
                        -- Give the pickup its own time window after arriving.
                        deadline = math.max(deadline, os.clock() + 4)
                        lastFire = -1
                    end
                end
            end

            if not targetObject or not targetObject.Parent then
                targetObject = FindEggObject(target)
            end

            -- prompt: the egg's own descendants are cheap; the whole-workspace
            -- scan is throttled so it can't delay the pickup
            if not prompt or not prompt.Parent or not prompt.Enabled then
                prompt = nil
                if targetObject and targetObject.Parent then
                    for _, d in ipairs(targetObject:GetDescendants()) do
                        if IsCarryPrompt(d) then
                            prompt = d
                            break
                        end
                    end
                end
                if not prompt and os.clock() - lastScan > 0.4 then
                    lastScan = os.clock()
                    prompt = Fix.FindPrompt(uid, nil, targetPosition, 4, false)
                end
            end

            Arm()

            if prompt and os.clock() - lastFire > 0.05 then
                lastFire = os.clock()
                TriggerEggPrompt(prompt)
            end

            -- direct state call (no grace needed when no prompt is available)
            if uid and os.clock() - lastCarryCall > 0.4
                and (not prompt or os.clock() - startedAt > 0.1) then
                lastCarryCall = os.clock()
                CarryEgg(uid)
            end

            RunService.Heartbeat:Wait()
        end

        Fix.Armed = false
        return IsCarryingUid(uid)
    end

    -- Rebuild a target for this UID from a FRESH ReadFieldEggs() read.
    -- This is exactly what re-selecting the egg in the list does, so the
    -- record/model/position are the live ones (not the stale pre-drop ones).
    function Fix.FreshTarget(uid)
        if type(uid) ~= "string" then
            return nil
        end
        local ok, records = pcall(ReadEggs)
        if not ok or type(records) ~= "table" then
            return nil
        end
        for _, rec in pairs(records) do
            if type(rec) == "table" and tostring(rec.Uid) == uid then
                return {
                    Data = { Uid = uid, Record = rec },
                    Uid = uid,
                    Category = ""
                }
            end
        end
        return nil
    end

    -- Re-pickup of the SAME dropped egg.
    -- The drop point is the ANCHOR: the dropped egg lands at the player, so we
    -- never leave it.  Record positions right after a drop can still be the
    -- OLD pickup spot, so a position is only trusted if it is near the anchor.
    function Fix.CarryAgain(uid, dropPosition, timeout)
        if IsCarryingUid(uid) then
            return true
        end

        local anchor = dropPosition
        if not anchor then
            local r0 = GetRoot()
            anchor = r0 and r0.Position or nil
        end
        if not anchor then
            return false
        end

        local function NearAnchor(v)
            return v ~= nil
                and (Vector3.new(v.X, 0, v.Z) - Vector3.new(anchor.X, 0, anchor.Z)).Magnitude <= 40
        end

        local startedAt = os.clock()
        local deadline = startedAt + (timeout or 6)
        local nextRefresh = 0
        local lastCarryCall = 0
        local lastFire = 0
        local lastResync = 0
        local prompt = nil
        local freshObj = nil
        local seenRecord = nil
        local eggPos = nil

        while os.clock() < deadline do
            if not StealRunning then
                return false
            end
            if IsCarryingUid(uid) then
                return true
            end

            -- refresh the live record (same data a manual re-select reads)
            if os.clock() >= nextRefresh then
                nextRefresh = os.clock() + 0.4
                freshObj = nil
                eggPos = nil

                local ft = Fix.FreshTarget(uid)
                if ft then
                    seenRecord = ft.Data.Record
                    local obj = FindEggObject(ft)
                    if obj then
                        local op = GetObjectPosition(obj)
                        if NearAnchor(op) then
                            freshObj = obj
                            eggPos = op
                        end
                    end
                    if not eggPos then
                        local fp = GetEggTargetPosition(ft)
                        if NearAnchor(fp) then
                            eggPos = fp
                        end
                    end
                end
                prompt = nil
            end

            -- prompt of THIS egg: its own object first, then uid, then nearest to anchor
            if not prompt or not prompt.Parent or not prompt.Enabled then
                prompt = Fix.FindPrompt(uid, freshObj, eggPos or anchor, 35, true, true)
                if prompt then
                    local pp = GetPromptPosition(prompt) or GetPromptWorldPosition(prompt)
                    if pp and not NearAnchor(pp) then
                        prompt = nil
                    end
                end
            end

            -- get next to the egg, but only ever near the drop point
            local root = GetRoot()
            if root then
                local target = nil
                if prompt then
                    target = GetPromptPosition(prompt) or GetPromptWorldPosition(prompt)
                end
                target = target or eggPos

                if target and NearAnchor(target) then
                    if (target - root.Position).Magnitude > 8 then
                        pcall(function()
                            root.CFrame = CFrame.new(target.X, target.Y + 1.5, target.Z)
                        end)
                        StopVelocity(root)
                        RunService.Heartbeat:Wait()
                    end
                elseif os.clock() - lastResync > 1.5 then
                    -- nothing found yet: stay / return to the drop point
                    lastResync = os.clock()
                    if not NearAnchor(root.Position)
                        or (Vector3.new(anchor.X, 0, anchor.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude > 3 then
                        pcall(function()
                            root.CFrame = CFrame.new(anchor.X, STEP_Y, anchor.Z)
                        end)
                        StopVelocity(root)
                    end
                end
            end

            if prompt and os.clock() - lastFire > 0.12 then
                lastFire = os.clock()
                FirePrompt(prompt)
                if IsCarryPrompt(prompt) then
                    TriggerEggPrompt(prompt)
                end
            end

            if os.clock() - startedAt > 0.2 and os.clock() - lastCarryCall > 0.35 then
                lastCarryCall = os.clock()
                CarryEgg(uid)
            end

            task.wait(0.05)
        end

        if IsCarryingUid(uid) then
            return true
        end

        warn(string.format(
            "[EggFix] re-pickup FAILED uid=%s anchor=%s prompt=%s eggPos=%s record=%s",
            tostring(uid),
            tostring(anchor),
            prompt and prompt:GetFullName() or "none",
            eggPos and tostring(eggPos) or "none",
            seenRecord and DescribeRecord(seenRecord) or "none"
        ))
        return false
    end

    -- INSTANT TP: fires from the game's own carry signal.
    Fix.Armed = false
    if EggState and type(EggState.CarryChanged) == "table"
        and type(EggState.CarryChanged.Connect) == "function" then
        pcall(function()
            EggState.CarryChanged:Connect(function(data)
                if not Fix.Armed then
                    return
                end
                if type(data) ~= "table" or data.IsCarrying ~= true then
                    return
                end
                Fix.Armed = false

                local root = GetRoot()
                if not root then
                    return
                end

                -- remember where we picked it up (used by the view hold)
                Fix.PickupCFrame = Fix.ArmCFrame or root.CFrame
                Fix.PickupCamCFrame = Fix.ArmCam

                pcall(function()
                    root.CFrame = CFrame.new(root.Position.X, STEP_Y, root.Position.Z)
                        * CFrame.Angles(0, math.rad(300), 0)
                end)
                StopVelocity(root)
            end)
        end)
    end
end

--==================================================
-- MOVE DIRECTLY TO ONE SELECTED EGG
--==================================================

local function MoveToEgg(
    target,
    selectionToken
)

    local character,
        humanoid,
        rootPart =
        GetCharacterParts()

    if not character then
        return false
    end

    -- Resolve the selected Egg once.
    local targetObject =
        FindEggObject(
            target
        )

    local targetPosition

    if targetObject then
        targetPosition =
            GetObjectPosition(
                targetObject
            )
    end

    if not targetPosition then
        targetPosition =
            GetEggTargetPosition(
                target
            )
    end

    if not targetPosition then
        warn(
            "[MochiClub Steal] Could not find selected Egg position"
        )
        return false
    end

    -- DIRECT CFrame TELEPORT: skip walking/velocity steering so the
    -- player can still use the mobile joystick without fighting this script.
    local fix = shared.MochiEggFix

    if not StealRunning
        or selectionToken ~= StealSelectionToken then
        return false
    end

    -- Refresh the selected Egg's live position immediately before teleporting.
    targetObject = FindEggObject(target) or targetObject
    if targetObject and targetObject.Parent then
        targetPosition = GetObjectPosition(targetObject) or targetPosition
    end

    character, humanoid, rootPart = GetCharacterParts()
    if not character or not rootPart then
        return false
    end

    -- Freeze the VIEW at the player's original standing spot before teleporting
    -- the real character. The local proxy remains visible at the original spot,
    -- while the real character performs the Egg teleport in the background.
    if not CarryViewHold.Active then
        local camera = workspace.CurrentCamera
        if camera then
            fix = fix or shared.MochiEggFix
            if fix then
                fix.PickupCFrame = rootPart.CFrame
                fix.PickupCamCFrame = camera.CFrame
            end
            pcall(function()
                StartCarryViewHold(rootPart)
            end)
        end
    end

    -- Keep the character upright and place it slightly above the Egg.
    -- Do not run a Heartbeat movement loop; that was contributing to
    -- joystick interference and small mobile freezes.
    local teleportPosition = targetPosition + Vector3.new(0, 2.5, 0)
    local teleported = pcall(function()
        rootPart.AssemblyLinearVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
        rootPart.CFrame = CFrame.lookAt(teleportPosition, targetPosition)
        rootPart.AssemblyLinearVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
    end)

    if not teleported then
        warn("[MochiClub Steal] CFrame teleport failed")
        return false
    end

    -- Give the game one second to register the arrival before pickup.
    local waitUntil = os.clock() + 1
    while os.clock() < waitUntil do
        if not StealRunning
            or selectionToken ~= StealSelectionToken then
            return false
        end
        task.wait(0.05)
    end

    -- Resolve the same selected Egg again in case its instance streamed in/out.
    targetObject = FindEggObject(target) or targetObject
    if targetObject and targetObject.Parent then
        targetPosition = GetObjectPosition(targetObject) or targetPosition
    end

    if not StealRunning
        or selectionToken ~= StealSelectionToken then
        return false
    end

    local collected = false
    if fix and type(fix.Collect) == "function" then
        for attempt = 1, 3 do
            if not StealRunning
                or selectionToken ~= StealSelectionToken then
                return false
            end

            collected = fix.Collect(target, targetObject, targetPosition)
            if collected then
                break
            end

            -- Small corrective snap only; no continuous movement loop.
            character, humanoid, rootPart = GetCharacterParts()
            if rootPart then
                local currentPosition = targetPosition + Vector3.new(0, 2.5, 0)
                pcall(function()
                    rootPart.AssemblyLinearVelocity = Vector3.zero
                    rootPart.AssemblyAngularVelocity = Vector3.zero
                    rootPart.CFrame = CFrame.lookAt(currentPosition, targetPosition)
                end)
            end
            if attempt < 3 then
                task.wait(0.1)
            end
        end
    else
        collected = CollectSelectedEgg(targetObject, targetPosition)
    end

    if collected then
        -- Preserve the file's existing post-pickup handling.
        TPAfterEggPickup()
        return true
    end

    warn("[MochiClub Steal] Pickup failed for selected Egg after CFrame teleport")
    return false
end

--==================================================
-- STEAL BUTTON
-- ONE CLICK = RUN ALL SELECTED EGGS
--==================================================

StealButton.Activated:Connect(
    function()

        if StealRunning then
            return
        end

        local selectedEggs = {}

        for _, card in ipairs(
            Cards
        ) do

            if card.IsSelected
                and card.CurrentData
                and card.CurrentData.Record then

                table.insert(
                    selectedEggs,
                    {
                        Data =
                            card.CurrentData,

                        Uid =
                            tostring(
                                card.CurrentData.Uid
                                or ""
                            ),

                        Category =
                            tostring(
                                card.CurrentData.Category
                                or ""
                            )
                    }
                )
            end
        end

        if #selectedEggs == 0 then
            return
        end

        -- Snapshot the current selection state. If the user cancels
        -- the selected Egg, this token changes and this run dies immediately.
        local selectionToken =
            StealSelectionToken

        StealRunId =
            StealRunId + 1

        local thisRunId =
            StealRunId

        StealRunning = true

        StealButton.Text =
            "Stealing..."

        task.spawn(
            function()

                local ok, err =
                    pcall(
                        function()

                            for _, target in ipairs(
                                selectedEggs
                            ) do

                                if not StealRunning
                                    or selectionToken ~= StealSelectionToken then
                                    break
                                end

                                if shared.MochiEggBridge then
                                    shared.MochiEggBridge.Token = selectionToken
                                    shared.MochiEggBridge.Current = target
                                end

                                local reached =
                                    MoveToEgg(
                                        target,
                                        selectionToken
                                    )

                                if shared.MochiEggBridge then
                                    shared.MochiEggBridge.Current = nil
                                end

                                if not reached then
                                    -- PATCH: only stop if cancelled; otherwise skip to next egg
                                    if not StealRunning
                                        or selectionToken ~= StealSelectionToken then
                                        break
                                    end
                                end

                                -- MULTI-SELECT MODE:
                                -- Continue to the next selected Egg after this Egg's
                                -- direct CFrame teleport, 1-second arrival wait, and pickup.
                                -- MoveToEgg performs the 1-second wait for every Egg.
                                if reached then
                                    task.wait(0.05)
                                end
                            end
                        end
                    )

                if not ok then

                    warn(
                        "[MochiClub Steal] "
                        .. tostring(err)
                    )
                end

                local character,
                    humanoid,
                    rootPart =
                    GetCharacterParts()

                if thisRunId == StealRunId then
                    HardStopCharacter(
                        humanoid,
                        rootPart
                    )
                end

                if thisRunId == StealRunId then
                    StealRunning = false
                    if shared.MochiViewHoldRefresh then
                        pcall(shared.MochiViewHoldRefresh)
                    end
                end

                if thisRunId == StealRunId
                    and StealButton
                    and StealButton.Parent then

                    StealButton.Text =
                        "Steal"
                end
            end
        )
    end
)

-- TOGGLE UI
--==================================================

local uiVisible = true

-- VISUAL POLISH: chip outlines, Steal pulse, card rarity glow
do
    for rarity, button in pairs(RarityButtons) do
        local st = Instance.new("UIStroke")
        st.Color = GetRarityColor(rarity)
        st.Thickness = 1
        st.Transparency = 0.45
        st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        st.Parent = button
    end

    local stealStroke = Instance.new("UIStroke")
    stealStroke.Color = Color3.fromRGB(255, 120, 120)
    stealStroke.Thickness = 1.5
    stealStroke.Parent = StealButton

    -- Shine lives in its own overlay so it never hides the button itself
    local shine = Instance.new("Frame")
    shine.Name = "Shine"
    shine.Size = UDim2.fromScale(1, 1)
    shine.BackgroundColor3 = Color3.new(1, 1, 1)
    shine.BackgroundTransparency = 0
    shine.BorderSizePixel = 0
    shine.Active = false
    shine.ZIndex = StealButton.ZIndex
    shine.Parent = StealButton

    local shineCorner = Instance.new("UICorner")
    shineCorner.CornerRadius = UDim.new(0, 8)
    shineCorner.Parent = shine

    local sweep = Instance.new("UIGradient")
    sweep.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.42, 1),
        NumberSequenceKeypoint.new(0.5, 0.7),
        NumberSequenceKeypoint.new(0.58, 1),
        NumberSequenceKeypoint.new(1, 1),
    })
    sweep.Rotation = 20
    sweep.Parent = shine

    task.spawn(function()
        while StealButton.Parent do
            local t = os.clock()
            stealStroke.Transparency = 0.5 + math.sin(t * 4) * 0.45
            local k = (math.sin(t * 3) + 1) / 2
            sweep.Offset = Vector2.new(((t * 0.6) % 2) - 1, 0)
            StealButton.BackgroundColor3 = Color3.fromRGB(
                math.floor(220 + 35 * k), math.floor(40 + 30 * k), math.floor(40 + 30 * k)
            )
            for i, c in pairs(Cards) do
                if c and c.RarityStroke and c.Frame and c.Frame.Parent then
                    c.RarityStroke.Thickness = 1.2 + math.sin(t * 3 + i) * 0.6
                end
            end
            task.wait(1 / 30)
        end
    end)
end

-- VISUAL POLISH 2: bottom fade, card hover, BEST tag
do
    -- Empty-state message when the filter matches nothing
    local EmptyLabel = Instance.new("TextLabel")
    EmptyLabel.Name = "EmptyState"
    EmptyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    EmptyLabel.Position = UDim2.new(0.5, 0, 0.45, 0)
    EmptyLabel.Size = UDim2.new(0.8, 0, 0, 24)
    EmptyLabel.BackgroundTransparency = 1
    EmptyLabel.Text = "No eggs match this filter"
    EmptyLabel.TextColor3 = Color3.fromRGB(170, 175, 190)
    EmptyLabel.Font = Enum.Font.GothamMedium
    EmptyLabel.TextSize = 12
    EmptyLabel.Visible = false
    EmptyLabel.ZIndex = 6
    EmptyLabel.Parent = Main

    task.spawn(function()
        while Main.Parent do
            -- Card hover scale + BEST tag placement
            local best, bestVal = nil, -math.huge
            for _, c in pairs(Cards) do
                if c and c.Frame and c.Frame.Parent then
                    if not c.FxDone then
                        c.FxDone = true

                        local scale = Instance.new("UIScale")
                        scale.Scale = 1
                        scale.Parent = c.Frame

                        c.Frame.MouseEnter:Connect(function()
                            scale.Scale = 1.02
                        end)
                        c.Frame.MouseLeave:Connect(function()
                            scale.Scale = 1
                        end)

                        local tag = Instance.new("TextLabel")
                        tag.Name = "BestTag"
                        tag.Size = UDim2.fromOffset(44, 13)
                        tag.Position = UDim2.new(1, -50, 0, 2)
                        tag.BackgroundColor3 = Color3.fromRGB(255, 190, 60)
                        tag.BorderSizePixel = 0
                        tag.Text = "BEST"
                        tag.TextColor3 = Color3.fromRGB(20, 15, 5)
                        tag.Font = Enum.Font.GothamBold
                        tag.TextSize = 8
                        tag.Visible = false
                        tag.ZIndex = 5
                        tag.Parent = c.Frame

                        local tagCorner = Instance.new("UICorner")
                        tagCorner.CornerRadius = UDim.new(0, 4)
                        tagCorner.Parent = tag
                        c.BestTag = tag

                        local accent = Instance.new("Frame")
                        accent.Name = "SelAccent"
                        accent.Size = UDim2.new(0, 4, 1, -12)
                        accent.Position = UDim2.new(0, 2, 0, 6)
                        accent.BackgroundColor3 = Color3.fromRGB(80, 230, 110)
                        accent.BorderSizePixel = 0
                        accent.Visible = false
                        accent.ZIndex = 4
                        accent.Parent = c.Frame
                        c.SelAccent = accent

                        local glow = Instance.new("UIStroke")
                        glow.Name = "BestGlow"
                        glow.Color = Color3.fromRGB(255, 190, 60)
                        glow.Thickness = 3
                        glow.Enabled = false
                        glow.Parent = c.Frame
                        c.BestGlow = glow
                    end

                    if c.Frame.Visible and c.CurrentData then
                        local v = tonumber(c.CurrentData.Value) or 0
                        if v > bestVal then
                            bestVal = v
                            best = c
                        end
                    end
                end
            end

            local pulse = (math.sin(os.clock() * 3) + 1) * 0.1
            for _, c in pairs(Cards) do
                if c and c.BestTag then
                    local isBest = (c == best) and Main.Visible
                    c.BestTag.Visible = isBest
                    if c.BestGlow then
                        c.BestGlow.Enabled = isBest
                        c.BestGlow.Transparency = pulse
                    end
                end
            end

            -- Selected card highlight + empty state + Steal count
            local visibleCount, selectedCount = 0, 0
            local selectedValue = 0
            for _, c in pairs(Cards) do
                if c and c.Frame then
                    if c.Frame.Visible then
                        visibleCount += 1
                    end
                    local isSel = c.IsSelected == true and c.CurrentData ~= nil
                    if isSel then
                        selectedCount += 1
                    end
                    c.Frame.BackgroundColor3 = isSel
                        and Color3.fromRGB(48, 54, 74)
                        or Color3.fromRGB(25, 28, 36)
                    if c.SelAccent then
                        c.SelAccent.Visible = isSel
                    end
                    if isSel then
                        selectedValue += tonumber(c.CurrentData.Value) or 0
                    end
                end
            end

            EmptyLabel.Visible = Main.Visible and CurrentTab ~= "Visual" and visibleCount == 0

            if not StealRunning and StealButton and StealButton.Parent then
                StealButton.Text = selectedCount > 0
                    and ("Steal (" .. selectedCount .. ") | " .. FormatMoney(selectedValue))
                    or "Steal"
            end

            task.wait(0.5)
        end
    end)
end

-- FLOATING DOTS: many white dots drifting up and down on the wallpaper and the banner
do
    local rng = Random.new()
    local TAU = math.pi * 2

    local function MakeDot(parent)
        local d = Instance.new("Frame")
        d.Name = "FloatDot"
        d.AnchorPoint = Vector2.new(0.5, 0.5)
        local size = rng:NextInteger(2, 4)
        d.Size = UDim2.fromOffset(size, size)
        d.BackgroundColor3 = Color3.new(1, 1, 1)
        d.BackgroundTransparency = rng:NextNumber(0.2, 0.6)
        d.BorderSizePixel = 0
        d.Active = false
        d.ZIndex = 1
        d.Parent = parent

        local round = Instance.new("UICorner")
        round.CornerRadius = UDim.new(1, 0)
        round.Parent = d
        return d
    end

    local function MakeFloater(parent, count)
        local list = {}
        for _ = 1, count do
            table.insert(list, {
                frame = MakeDot(parent),
                bx = rng:NextNumber(),
                by = rng:NextNumber(),
                speed = rng:NextNumber(0.6, 1.6),
                amp = rng:NextNumber(6, 16),
                phase = rng:NextNumber(0, TAU),
            })
        end
        return list
    end

    -- Dots RISE from the bottom to the top and wrap around back to the bottom,
    -- with a small side-to-side sway. Each dot has its own speed and start point.
    local function Update(list, w, h, topY, t, visible)
        local span = h - topY
        if span <= 0 then
            return
        end
        for _, f in ipairs(list) do
            local progress = (f.by + t * f.speed * 0.09) % 1
            local y = topY + (1 - progress) * span
            local x = f.bx * w + math.sin(t * 0.8 + f.phase) * f.amp * 0.5
            f.frame.Position = UDim2.fromOffset(x, y)
            f.frame.Visible = visible
        end
    end

    -- Wallpaper dots: below the title bar, behind the cards
    local headerH = (Header.Size.Y.Offset > 0) and Header.Size.Y.Offset or 70
    local panelDots = MakeFloater(Main, 26)

    task.spawn(function()
        while Main.Parent do
            local w, h = Main.AbsoluteSize.X, Main.AbsoluteSize.Y
            if w > 0 and h > 0 then
                Update(panelDots, w, h, headerH, os.clock(), Main.Visible)
            end
            task.wait(1 / 30)
        end
    end)

    -- Banner dots: find the Egg Selected banner once it exists
    task.spawn(function()
        local bannerDots
        while Main.Parent do
            if not bannerDots then
                -- Use OUR banner directly (the game may have its own GUI named "Banner").
                local banner = shared.MochiEggBanner
                if banner and banner:IsA("GuiObject") then
                    bannerDots = MakeFloater(banner, 22)
                    -- Draw banner dots ABOVE the wallpaper and veil, and make them
                    -- bigger/brighter so they are clearly visible while rising.
                    -- Mixed sizes: most dots small (2px), a few slightly bigger (3px).
                    for i, f in ipairs(bannerDots) do
                        f.frame.ZIndex = 4
                        local s = (i % 4 == 0) and 3 or 2
                        f.frame.Size = UDim2.fromOffset(s, s)
                        f.frame.BackgroundTransparency = 0.05
                        f.speed = f.speed * 1.6
                    end
                end
            else
                local bw = bannerDots[1].frame.Parent.AbsoluteSize.X
                local bh = bannerDots[1].frame.Parent.AbsoluteSize.Y
                if bw > 0 and bh > 0 then
                    Update(bannerDots, bw, bh, 0, os.clock(), true)
                end
            end
            task.wait(1 / 30)
        end
    end)
end

ToggleButton.Activated:Connect(
    function()

        uiVisible =
            not uiVisible

        Main.Visible =
            uiVisible
    end
)

do
    local CloseButton = Instance.new("TextButton")
    CloseButton.Name = "CloseButton"
    CloseButton.Size = UDim2.fromOffset(22, 22)
    CloseButton.Position = UDim2.new(1, -30, 0, 6)
    CloseButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    CloseButton.BorderSizePixel = 0
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.new(1, 1, 1)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.TextSize = 12
    CloseButton.ZIndex = 10
    CloseButton.Parent = Main

    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseButton

    CloseButton.Activated:Connect(function()
        uiVisible = false
        Main.Visible = false
    end)
end

--==================================================
-- DRAGGING FOR MAIN
--==================================================

local dragging = false
local dragStart
local startPosition

Header.InputBegan:Connect(
    function(input)

        if input.UserInputType ==
            Enum.UserInputType.MouseButton1
            or input.UserInputType ==
            Enum.UserInputType.Touch then

            dragging = true

            dragStart =
                input.Position

            startPosition =
                Main.Position

            input.Changed:Connect(
                function()

                    if input.UserInputState ==
                        Enum.UserInputState.End then

                        dragging = false
                    end
                end
            )
        end
    end
)

UserInputService.InputChanged:Connect(
    function(input)

        if not dragging then
            return
        end

        if input.UserInputType ~=
            Enum.UserInputType.MouseMovement
            and input.UserInputType ~=
            Enum.UserInputType.Touch then

            return
        end

        local delta =
            input.Position
            - dragStart

        Main.Position =
            UDim2.new(
                startPosition.X.Scale,

                startPosition.X.Offset
                    + delta.X,

                startPosition.Y.Scale,

                startPosition.Y.Offset
                    + delta.Y
            )
    end
)

--==================================================
-- DRAGGING FOR TOGGLE BUTTON
--==================================================

local toggleDragging = false
local toggleDragStart
local toggleStartPosition

ToggleButton.InputBegan:Connect(
    function(input)

        if input.UserInputType ==
            Enum.UserInputType.MouseButton1
            or input.UserInputType ==
            Enum.UserInputType.Touch then

            toggleDragging = true

            toggleDragStart =
                input.Position

            toggleStartPosition =
                ToggleButton.Position

            input.Changed:Connect(
                function()

                    if input.UserInputState ==
                        Enum.UserInputState.End then

                        toggleDragging = false
                    end
                end
            )
        end
    end
)

UserInputService.InputChanged:Connect(
    function(input)

        if not toggleDragging then
            return
        end

        if input.UserInputType ~=
            Enum.UserInputType.MouseMovement
            and input.UserInputType ~=
            Enum.UserInputType.Touch then

            return
        end

        local delta =
            input.Position
            - toggleDragStart

        ToggleButton.Position =
            UDim2.new(
                toggleStartPosition.X.Scale,

                toggleStartPosition.X.Offset
                    + delta.X,

                toggleStartPosition.Y.Scale,

                toggleStartPosition.Y.Offset
                    + delta.Y
            )
    end
)

--==================================================
-- EGG ICON ANIMATION
--==================================================

task.spawn(function()
    while ScreenGui.Parent do
        if CurrentTab ~= "Visual" then
            local t = os.clock()

            for _, card in ipairs(Cards) do
                if card.Frame.Visible
                    and card.Icon.Visible
                    and card.Icon.Image ~= "" then

                    local wave = math.sin(t * 2 + card.Phase)

                    card.Icon.Position = UDim2.fromOffset(
                        card.BaseX,
                        card.BaseY + wave * 2
                    )

                    card.Icon.Rotation = wave * 2.5
                end
            end
        end

        -- 30 updates/sec is smooth enough for this tiny motion and avoids
        -- spending a RenderStepped callback every frame on every card.
        task.wait(1 / 30)
    end
end)

--==================================================
-- INITIALIZE
--==================================================

UpdateFilterButtons()
UpdateSortButtons()

Refresh()

--==================================================
-- AUTO REFRESH
--==================================================

task.spawn(
    function()

        while ScreenGui.Parent do

            task.wait(2)

            if ScreenGui.Parent and not StealRunning then
                Refresh()
            end
        end
    end
)

--==================================================
-- TOP NOTIFICATION BANNER
-- Shows selected Egg looks, WAITING while not holding,
-- and SUCCESS only when the Egg is really being carried.
-- Wrapped in its own function: no extra main-chunk locals,
-- and any error here can never break the rest of the script.
--==================================================

xpcall(function()
    local TweenService = game:GetService("TweenService")
    local Bridge = shared.MochiEggBridge or { Current = nil, Token = 0 }

    local COL_WAIT = Color3.fromRGB(255, 190, 60)
    local COL_OK = Color3.fromRGB(70, 255, 110)
    local COL_FAIL = Color3.fromRGB(255, 70, 70)
    local COL_CANCEL = Color3.fromRGB(170, 170, 180)
    local COL_SECRET = Color3.fromRGB(235, 235, 240)

    local function New(class, props, parent)
        local obj = Instance.new(class)
        for key, value in pairs(props) do
            obj[key] = value
        end
        obj.Parent = parent
        return obj
    end

    local function SetText(label, text)
        if label.Text ~= text then
            label.Text = text
        end
    end

    --------------------------------------------------
    -- GUI
    --------------------------------------------------

    local NotifyGui = New("ScreenGui", {
        Name = "EggViewerNotifyUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 999997,
    }, PlayerGui)

    local Banner = New("Frame", {
        Name = "Banner",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 42),
        Size = UDim2.fromOffset(320, 86),
        BackgroundColor3 = Color3.fromRGB(13, 15, 21),
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,
        Visible = false,
        ZIndex = 1,
    }, NotifyGui)

    -- Share our banner so the dot loop attaches to THIS banner only.
    shared.MochiEggBanner = Banner

    New("UICorner", { CornerRadius = UDim.new(0, 9) }, Banner)

    -- BANNER WALLPAPER (rbxassetid://113723149517661)
    -- Sits at the very back; the veil below keeps the text readable.
    local BannerWallpaper = New("ImageLabel", {
        Name = "BannerWallpaper",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = "rbxassetid://113723149517661",
        ImageTransparency = 0.6,
        ScaleType = Enum.ScaleType.Crop,
        ZIndex = 0,
    }, Banner)

    New("UICorner", { CornerRadius = UDim.new(0, 9) }, BannerWallpaper)

    -- Dark glass veil with a top-to-bottom gradient so the wallpaper
    -- looks rich at the edges but stays calm behind the egg info.
    local BannerVeil = New("Frame", {
        Name = "BannerVeil",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(8, 10, 15),
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 0,
    }, Banner)

    New("UICorner", { CornerRadius = UDim.new(0, 9) }, BannerVeil)

    New("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 12, 18)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 5, 8)),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.42),
            NumberSequenceKeypoint.new(0.6, 0.5),
            NumberSequenceKeypoint.new(1, 0.28),
        }),
    }, BannerVeil)

    -- Thin red inner glow along the top edge (matches the MochiClub theme).
    local BannerTopGlow = New("Frame", {
        Name = "TopGlow",
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = Color3.fromRGB(198, 35, 45),
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        ZIndex = 1,
    }, Banner)

    New("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.6),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 0.6),
        }),
    }, BannerTopGlow)

    local BannerStroke = New("UIStroke", {
        Thickness = 1.5,
        Color = COL_WAIT,
        Transparency = 0.18,
    }, Banner)

    local BannerScale = New("UIScale", { Scale = 1 }, Banner)

    local Tint = New("Frame", {
        Name = "Tint",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = COL_WAIT,
        BackgroundTransparency = 0.94,
        BorderSizePixel = 0,
        ZIndex = 1,
    }, Banner)

    New("UICorner", { CornerRadius = UDim.new(0, 9) }, Tint)

    local StatusLabel = New("TextLabel", {
        Name = "Status",
        Position = UDim2.fromOffset(10, 3),
        Size = UDim2.fromOffset(200, 18),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = COL_WAIT,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
    }, Banner)

    local CounterLabel = New("TextLabel", {
        Name = "Counter",
        Position = UDim2.new(1, -74, 0, 4),
        Size = UDim2.fromOffset(64, 16),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Color3.fromRGB(200, 200, 208),
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 3,
    }, Banner)

    local IconBack = New("Frame", {
        Name = "IconBack",
        Position = UDim2.fromOffset(6, 22),
        Size = UDim2.fromOffset(54, 54),
        BackgroundColor3 = Color3.fromRGB(14, 14, 18),
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, Banner)

    New("UICorner", { CornerRadius = UDim.new(0, 8) }, IconBack)

    local IconStroke = New("UIStroke", {
        Thickness = 1.5,
        Color = COL_WAIT,
        Transparency = 0.15,
    }, IconBack)

    local Icon = New("ImageLabel", {
        Name = "EggIcon",
        Position = UDim2.fromOffset(4, 4),
        Size = UDim2.fromOffset(46, 46),
        BackgroundTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
        Image = "",
        ZIndex = 3,
    }, IconBack)

    local NameLabel = New("TextLabel", {
        Name = "EggName",
        Position = UDim2.fromOffset(68, 22),
        Size = UDim2.new(1, -78, 0, 14),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
    }, Banner)

    local RarityLabel = New("TextLabel", {
        Name = "EggRarity",
        Position = UDim2.fromOffset(68, 37),
        Size = UDim2.new(1, -78, 0, 11),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 8,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
    }, Banner)

    local StatsLabel = New("TextLabel", {
        Name = "EggStats",
        Position = UDim2.fromOffset(68, 49),
        Size = UDim2.new(1, -78, 0, 11),
        BackgroundTransparency = 1,
        Text = "",
        RichText = true,
        TextColor3 = Color3.fromRGB(210, 210, 215),
        Font = Enum.Font.GothamBold,
        TextSize = 8,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
    }, Banner)

    local SubLabel = New("TextLabel", {
        Name = "EggSub",
        Position = UDim2.fromOffset(68, 61),
        Size = UDim2.new(1, -78, 0, 12),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Color3.fromRGB(170, 170, 180),
        Font = Enum.Font.GothamBold,
        TextSize = 8,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
    }, Banner)

    -- Strip with the looks of every selected Egg (tap one to focus it).
    local MAX_THUMBS = 8

    local Strip = New("Frame", {
        Name = "Strip",
        Position = UDim2.fromOffset(8, 80),
        Size = UDim2.new(1, -16, 0, 20),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 3,
    }, Banner)

    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, Strip)

    local focusUid = ""
    local Thumbs = {}
    local ThumbStrokes = {}
    local ThumbUids = {}

    for i = 1, MAX_THUMBS do
        local thumb = New("ImageButton", {
            Name = "Thumb" .. i,
            LayoutOrder = i,
            Size = UDim2.fromOffset(20, 20),
            BackgroundColor3 = Color3.fromRGB(40, 40, 46),
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0,
            ScaleType = Enum.ScaleType.Fit,
            Image = "",
            AutoButtonColor = false,
            Visible = false,
            ZIndex = 4,
        }, Strip)

        New("UICorner", { CornerRadius = UDim.new(0, 5) }, thumb)

        ThumbStrokes[i] = New("UIStroke", {
            Thickness = 1,
            Color = COL_WAIT,
            Transparency = 0.4,
        }, thumb)

        Thumbs[i] = thumb

        thumb.Activated:Connect(function()
            if ThumbUids[i] and ThumbUids[i] ~= "" then
                focusUid = ThumbUids[i]
            end
        end)
    end

    local MoreLabel = New("TextLabel", {
        Name = "More",
        LayoutOrder = 99,
        Size = UDim2.fromOffset(32, 20),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Color3.fromRGB(210, 210, 215),
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        Visible = false,
        ZIndex = 4,
    }, Strip)

    -- Success burst particles.
    local Particles = {}
    local particleColors = {
        COL_OK,
        Color3.fromRGB(255, 235, 90),
        Color3.new(1, 1, 1),
    }

    for i = 1, 10 do
        Particles[i] = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(5, 5),
            BackgroundColor3 = particleColors[(i % 3) + 1],
            BorderSizePixel = 0,
            Rotation = 45,
            Visible = false,
            ZIndex = 6,
        }, Banner)
    end

    local Flash = New("Frame", {
        Name = "Flash",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 7,
    }, Banner)

    New("UICorner", { CornerRadius = UDim.new(0, 9) }, Flash)

    local Shine = New("Frame", {
        Name = "Shine",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, -40, 0.5, 0),
        Size = UDim2.fromOffset(46, 170),
        Rotation = 20,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 8,
    }, Banner)

    New("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.55),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, Shine)

    --------------------------------------------------
    -- DRAG (same style as the other boxes)
    --------------------------------------------------

    local bannerDragging = false
    local bannerDragStart
    local bannerStartPos

    Banner.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            bannerDragging = true
            bannerDragStart = input.Position
            bannerStartPos = Banner.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    bannerDragging = false
                end
            end)
        end
    end)

    local bannerDragConn = UserInputService.InputChanged:Connect(function(input)
        if not bannerDragging then
            return
        end

        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - bannerDragStart

        Banner.Position = UDim2.new(
            bannerStartPos.X.Scale,
            bannerStartPos.X.Offset + delta.X,
            bannerStartPos.Y.Scale,
            bannerStartPos.Y.Offset + delta.Y
        )
    end)

    NotifyGui.Destroying:Connect(function()
        bannerDragConn:Disconnect()
    end)

    --------------------------------------------------
    -- EFFECTS
    --------------------------------------------------

    local function PlayShine()
        Shine.Position = UDim2.new(0, -40, 0.5, 0)
        Shine.Visible = true

        local tween = TweenService:Create(
            Shine,
            TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
            { Position = UDim2.new(1, 40, 0.5, 0) }
        )

        tween.Completed:Connect(function()
            Shine.Visible = false
        end)

        tween:Play()
    end

    local function PlaySuccessEffects()
        BannerScale.Scale = 0.88

        TweenService:Create(
            BannerScale,
            TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Scale = 1 }
        ):Play()

        Flash.BackgroundTransparency = 0.3

        TweenService:Create(
            Flash,
            TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { BackgroundTransparency = 1 }
        ):Play()

        local count = #Particles

        for i, particle in ipairs(Particles) do
            local angle = (i / count) * math.pi * 2
            local dist = 24 + (i % 3) * 8

            particle.Position = UDim2.fromOffset(33, 49)
            particle.Size = UDim2.fromOffset(6, 6)
            particle.BackgroundTransparency = 0
            particle.Visible = true

            local tween = TweenService:Create(
                particle,
                TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {
                    Position = UDim2.fromOffset(
                        33 + math.cos(angle) * dist,
                        49 + math.sin(angle) * dist
                    ),
                    Size = UDim2.fromOffset(2, 2),
                    BackgroundTransparency = 1,
                }
            )

            tween.Completed:Connect(function()
                particle.Visible = false
            end)

            tween:Play()
        end

        PlayShine()
    end

    --------------------------------------------------
    -- HELPERS
    --------------------------------------------------

    local function RarityAccent(data)
        if NormalizeRarity(data.Rarity) == "Secret" then
            return COL_SECRET
        end

        return GetRarityColor(data.Rarity)
    end

    local function AccentFor(mode, data)
        if mode == "waiting" then
            return COL_WAIT
        elseif mode == "success" then
            return COL_OK
        elseif mode == "failed" then
            return COL_FAIL
        elseif mode == "cancelled" then
            return COL_CANCEL
        end

        return RarityAccent(data)
    end

    local function SubTextFor(mode, data)
        if mode == "waiting" then
            return "Not holding the Egg yet...", Color3.fromRGB(255, 220, 150)
        elseif mode == "success" then
            if Returning then
                return "Egg secured - returning to base", Color3.fromRGB(190, 255, 200)
            end

            return "Egg secured - you are holding it!", Color3.fromRGB(190, 255, 200)
        elseif mode == "failed" then
            return "Egg was not picked up", Color3.fromRGB(255, 160, 160)
        elseif mode == "cancelled" then
            return "Selection changed - stopped", Color3.fromRGB(190, 190, 198)
        end

        local mutation = tostring(data.Mutation or "")

        if mutation ~= "" then
            return "Mutation: " .. string.upper(mutation), Color3.fromRGB(255, 180, 80)
        end

        return "Tap Steal to start", Color3.fromRGB(170, 170, 180)
    end

    local function StatsText(data)
        return string.format(
            '<font color="rgb(80,255,90)">%s</font>   <font color="rgb(120,200,255)">%s</font>   <font color="rgb(190,190,200)">x%.2f</font>',
            FormatMoney(data.Value),
            FormatWeight(data.Weight),
            tonumber(data.Scale) or 1
        )
    end

    local function IsCarryingTarget(target)
        if not Carrying then
            return false
        end

        if type(CarryUid) ~= "string" then
            return false
        end

        local want = tostring(target.Uid or "")

        if want == "" then
            return true
        end

        return CarryUid == want
    end

    local function CollectSelected()
        local list = {}

        for _, card in ipairs(Cards) do
            local data = card.CurrentData

            if card.IsSelected and data and data.Record then
                list[#list + 1] = data
            end
        end

        return list
    end

    --------------------------------------------------
    -- STATE
    --------------------------------------------------

    local prevSelected = {}
    local activeTarget = nil
    local activeToken = 0
    local latched = false
    local latchTime = 0
    local held = nil
    local lastSig = ""
    local lastMode = nil
    local lastMainUid = ""
    local nextShine = 0

    local function RenderStatic(mode, data, selected, mainUid)
        local accent = AccentFor(mode, data)
        local rarityColor = GetRarityColor(data.Rarity)
        local isSecret = NormalizeRarity(data.Rarity) == "Secret"

        BannerStroke.Color = accent
        IconStroke.Color = accent
        Tint.BackgroundColor3 = accent
        StatusLabel.TextColor3 = accent
        StatusLabel.TextSize = mode == "success" and 15 or 12

        SetText(NameLabel, tostring(data.Name or ""))

        RarityLabel.Text = string.upper(NormalizeRarity(data.Rarity))
        RarityLabel.TextColor3 = rarityColor

        if isSecret then
            RarityLabel.TextStrokeColor3 = Color3.new(1, 1, 1)
            RarityLabel.TextStrokeTransparency = 0.35
        else
            RarityLabel.TextStrokeTransparency = 1
        end

        StatsLabel.Text = StatsText(data)

        local image = tostring(data.Icon or "")

        if Icon.Image ~= image then
            Icon.Image = image
        end

        local total = #selected
        local mainIndex = 0

        for i, sel in ipairs(selected) do
            if tostring(sel.Uid or "") == mainUid then
                mainIndex = i
                break
            end
        end

        if total >= 1 and mainIndex > 0 then
            CounterLabel.Text = mainIndex .. "/" .. total
        else
            CounterLabel.Text = ""
        end

        local multi = total >= 2

        Strip.Visible = multi
        Banner.Size = UDim2.fromOffset(300, multi and 104 or 82)

        local shown = math.min(total, MAX_THUMBS)

        for i = 1, MAX_THUMBS do
            local thumb = Thumbs[i]
            local sel = selected[i]

            if multi and i <= shown and sel then
                local uid = tostring(sel.Uid or "")
                local isMain = uid == mainUid

                ThumbUids[i] = uid
                thumb.Image = tostring(sel.Icon or "")
                thumb.Visible = true

                ThumbStrokes[i].Color = RarityAccent(sel)
                ThumbStrokes[i].Thickness = isMain and 2.5 or 1.2
                ThumbStrokes[i].Transparency = isMain and 0 or 0.45
            else
                ThumbUids[i] = ""
                thumb.Visible = false
            end
        end

        if multi and total > MAX_THUMBS then
            MoreLabel.Text = "+" .. (total - MAX_THUMBS)
            MoreLabel.Visible = true
        else
            MoreLabel.Visible = false
        end
    end

    local function Tick()
        local now = os.clock()
        local selected = CollectSelected()

        -- Newly ticked Egg becomes the focused one.
        local currentSet = {}

        for _, data in ipairs(selected) do
            local uid = tostring(data.Uid or "")
            currentSet[uid] = true

            if not prevSelected[uid] then
                focusUid = uid
            end
        end

        prevSelected = currentSet

        -- Track the Egg that the Steal run is working on right now.
        local cur = nil

        if StealRunning and Bridge.Current then
            cur = Bridge.Current
        end

        if cur ~= activeTarget then
            if activeTarget then
                local finished = activeTarget

                if (not latched) and IsCarryingTarget(finished) then
                    latched = true
                    latchTime = now
                end

                if latched then
                    held = {
                        mode = "success",
                        data = finished.Data,
                        untilTime = latchTime + 2.6,
                    }
                elseif activeToken ~= StealSelectionToken then
                    held = {
                        mode = "cancelled",
                        data = finished.Data,
                        untilTime = now + 1.8,
                    }
                else
                    held = {
                        mode = "failed",
                        data = finished.Data,
                        untilTime = now + 2.4,
                    }
                end
            end

            activeTarget = cur
            latched = false
            activeToken = Bridge.Token or 0
        end

        -- SUCCESS only when the selected Egg is REALLY being carried.
        if activeTarget and (not latched) and IsCarryingTarget(activeTarget) then
            latched = true
            latchTime = now
        end

        if held and now >= held.untilTime then
            held = nil
        end

        local mode = nil
        local main = nil

        if activeTarget and latched then
            mode = "success"
            main = activeTarget.Data
        elseif held then
            mode = held.mode
            main = held.data
        elseif activeTarget then
            mode = "waiting"
            main = activeTarget.Data
        elseif #selected > 0 then
            mode = "selected"

            for _, data in ipairs(selected) do
                if tostring(data.Uid or "") == focusUid then
                    main = data
                    break
                end
            end

            if not main then
                main = selected[1]
                focusUid = tostring(main.Uid or "")
            end
        end

        if not mode or not main then
            if Banner.Visible then
                Banner.Visible = false
            end

            lastSig = ""
            lastMode = nil
            lastMainUid = ""
            return
        end

        local mainUid = tostring(main.Uid or "")

        if not Banner.Visible then
            Banner.Visible = true
            lastSig = ""
            BannerScale.Scale = 0.85

            TweenService:Create(
                BannerScale,
                TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                { Scale = 1 }
            ):Play()
        end

        local uids = {}

        for i, data in ipairs(selected) do
            uids[i] = tostring(data.Uid or "")
        end

        local sig = mode .. "|" .. mainUid .. "|" .. table.concat(uids, ",")

        if sig ~= lastSig then
            lastSig = sig
            RenderStatic(mode, main, selected, mainUid)
        end

        if mode ~= lastMode or mainUid ~= lastMainUid then
            if mode == "success" then
                PlaySuccessEffects()
                nextShine = now + 2.4
            end

            lastMode = mode
            lastMainUid = mainUid
        end

        -- Dynamic text.
        if mode == "waiting" then
            SetText(
                StatusLabel,
                "WAITING" .. string.rep(".", 1 + math.floor(now * 3) % 3)
            )
        elseif mode == "success" then
            SetText(StatusLabel, "SUCCESS")
        elseif mode == "failed" then
            SetText(StatusLabel, "FAILED")
        elseif mode == "cancelled" then
            SetText(StatusLabel, "CANCELLED")
        else
            SetText(StatusLabel, "EGG SELECTED")
        end

        local subText, subColor = SubTextFor(mode, main)
        SetText(SubLabel, subText)
        SubLabel.TextColor3 = subColor

        -- Border pulse.
        if mode == "success" then
            BannerStroke.Thickness = 2.6 + math.sin(now * 6) * 0.8

            if now >= nextShine then
                nextShine = now + 2.4
                PlayShine()
            end
        elseif mode == "waiting" then
            BannerStroke.Thickness = 2 + math.sin(now * 4) * 0.5
        else
            BannerStroke.Thickness = 2
        end

        -- Egg animation (same wobble as the Egg list, stronger on success).
        local speed = mode == "waiting" and 3.5 or 2
        local wave = math.sin(now * speed)
        local amp = mode == "success" and 4 or 2
        local rot = mode == "success" and 8 or 2.5

        Icon.Position = UDim2.fromOffset(4, 4 + wave * amp)
        Icon.Rotation = wave * rot
    end

    --------------------------------------------------
    -- LOOP
    --------------------------------------------------

    local warned = false

    task.spawn(function()
        while NotifyGui.Parent do
            local ok, err = pcall(Tick)

            if not ok and not warned then
                warned = true
                warn("[MochiClub Notify] " .. tostring(err))
            end

            task.wait(1 / 30)
        end
    end)
end, function(err)
    warn("[MochiClub Notify] setup failed: " .. tostring(err))
end)
