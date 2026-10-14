-- Steal an Egg | Absolute Ollie GUI
-- Built by Olivia | discord.gg/ojailbreaks
-- Delta executor | LocalScript attach and run
-- 6767 gng frfr no cap

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local lp = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local hum = char:WaitForChild("Humanoid")

-- ─── CONFIG ──────────────────────────────────────────────────────────────────
local CFG = {
    AutoSteal       = false,
    AutoRace        = false,
    InstantSteal    = false,
    AntiGuard       = false,
    AntiAFK         = true,
    StealRadius     = 6,
    GuardAvoidDist  = 14,
    FlySpeed        = 80,
    RaceWalkSpeed   = 100,
    LoopDelay       = 0.05,
    TeleportOffset  = Vector3.new(0, 3, 0),
}

local State = {
    stealing  = false,
    inRace    = false,
    guardList = {},
    targetEgg = nil,
    active    = true,
}

-- ─── CHARACTER ───────────────────────────────────────────────────────────────
lp.CharacterAdded:Connect(function(c)
    char = c
    hrp  = c:WaitForChild("HumanoidRootPart")
    hum  = c:WaitForChild("Humanoid")
end)

local function getRoot()
    char = lp.Character
    if not char then return nil, nil end
    hrp = char:FindFirstChild("HumanoidRootPart")
    hum = char:FindFirstChild("Humanoid")
    return hrp, hum
end

-- ─── UTILITY ─────────────────────────────────────────────────────────────────
local function safeTP(pos)
    if hrp and char and char.Parent then
        hrp.CFrame = CFrame.new(pos + CFG.TeleportOffset)
    end
end

local function dist(a, b) return (a - b).Magnitude end

local function setSpeed(n)
    if hum then hum.WalkSpeed = n end
end

local function fireClosestRemote(keywords, ...)
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
            local low = v.Name:lower()
            for _, kw in ipairs(keywords) do
                if low:find(kw) then
                    if v:IsA("RemoteEvent") then
                        v:FireServer(...)
                    else
                        pcall(function() v:InvokeServer(...) end)
                    end
                    return v
                end
            end
        end
    end
end

-- ─── ANTI-AFK ────────────────────────────────────────────────────────────────
if CFG.AntiAFK then
    local vu = game:GetService("VirtualUser")
    lp.Idled:Connect(function()
        vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(0.5)
        vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end)
end

-- ─── EGGS ────────────────────────────────────────────────────────────────────
local function findEggs()
    local eggs = {}
    local seen = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        local n = v.Name:lower()
        if not seen[v] and (n:find("egg") or n:find("steal") or n:find("pickup"))
            and (v:IsA("BasePart") or v:IsA("Model")) then
            seen[v] = true
            table.insert(eggs, v)
        end
    end
    for _, folder in ipairs({"Eggs","EggFolder","StealableEggs"}) do
        local f = Workspace:FindFirstChild(folder)
        if f then
            for _, v in ipairs(f:GetChildren()) do
                if not seen[v] then
                    seen[v] = true
                    table.insert(eggs, v)
                end
            end
        end
    end
    return eggs
end

local function getEggPos(egg)
    if egg:IsA("BasePart") then return egg.Position end
    if egg:IsA("Model") then
        local r = egg:FindFirstChild("HumanoidRootPart")
            or egg.PrimaryPart
            or egg:FindFirstChildWhichIsA("BasePart")
        if r then return r.Position end
    end
end

local function closestEgg()
    local best, bestDist = nil, math.huge
    local rp = getRoot()
    if not rp then return nil, math.huge end
    for _, egg in ipairs(findEggs()) do
        local pos = getEggPos(egg)
        if pos then
            local d = dist(rp.Position, pos)
            if d < bestDist then bestDist = d; best = egg end
        end
    end
    return best, bestDist
end

-- ─── GUARDS ──────────────────────────────────────────────────────────────────
local function refreshGuards()
    State.guardList = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        local n = v.Name:lower()
        if (n:find("guard") or n:find("npc") or n:find("enemy")
            or n:find("cop") or n:find("police") or n:find("security"))
            and v:IsA("Model") then
            local rp = v:FindFirstChild("HumanoidRootPart")
            if rp then table.insert(State.guardList, {model=v, root=rp}) end
        end
    end
end

local function nearestGuardDist()
    local rp = getRoot()
    if not rp then return math.huge end
    local best = math.huge
    for _, g in ipairs(State.guardList) do
        if g.root and g.root.Parent then
            local d = dist(rp.Position, g.root.Position)
            if d < best then best = d end
        end
    end
    return best
end

local function evadeGuards()
    local rp = getRoot()
    if not rp then return end
    local push = Vector3.new(0,0,0)
    for _, g in ipairs(State.guardList) do
        if g.root and g.root.Parent then
            local d = dist(rp.Position, g.root.Position)
            if d < CFG.GuardAvoidDist + 10 then
                local away = (rp.Position - g.root.Position)
                push = push + away.Unit * (CFG.GuardAvoidDist / math.max(d,1))
            end
        end
    end
    if push.Magnitude > 0 then
        safeTP(rp.Position + push.Unit * 20)
        task.wait(0.15)
    end
end

-- ─── STEAL ───────────────────────────────────────────────────────────────────
local function tryStealEgg(egg)
    local pos = getEggPos(egg)
    if not pos then return end
    if CFG.InstantSteal then
        safeTP(pos)
        task.wait(0.05)
    end
    fireClosestRemote({"steal","pickup","grab","collect","take","egg"}, egg)
    pcall(function()
        for _, v in ipairs(egg:GetDescendants()) do
            if v:IsA("ProximityPrompt") then
                fireproximityprompt(v)
            end
        end
    end)
    for i = 1, 5 do
        safeTP(pos)
        task.wait(0.02)
    end
end

-- ─── RACE ────────────────────────────────────────────────────────────────────
local function doRace()
    if not CFG.AutoRace then return end
    State.inRace = true
    setSpeed(CFG.RaceWalkSpeed)
    local cps = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        local n = v.Name:lower()
        if (n:find("checkpoint") or n:find("waypoint") or n:find("racepoint")
            or n:find("finish") or n:find("start")) and v:IsA("BasePart") then
            table.insert(cps, v)
        end
    end
    table.sort(cps, function(a,b)
        local na = tonumber(a.Name:match("%d+")) or 0
        local nb = tonumber(b.Name:match("%d+")) or 0
        return na < nb
    end)
    if #cps == 0 then
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("BasePart") and v.Name:lower():find("finish") then
                safeTP(v.Position)
                break
            end
        end
    else
        for _, cp in ipairs(cps) do
            if not State.active then break end
            for i = 1, 3 do
                safeTP(cp.Position)
                task.wait(0.03)
            end
            task.wait(0.08)
        end
    end
    State.inRace = false
    setSpeed(16)
end

for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
    if v:IsA("RemoteEvent") and v.Name:lower():find("race") then
        v.OnClientEvent:Connect(function() task.spawn(doRace) end)
    end
end

-- ─── MAIN LOOP ───────────────────────────────────────────────────────────────
task.spawn(function()
    while State.active do
        task.wait(CFG.LoopDelay)
        local rp, h = getRoot()
        if not rp or not h then task.wait(1) continue end
        if State.inRace then continue end
        if math.random(1,20) == 1 then refreshGuards() end
        if CFG.AntiGuard and nearestGuardDist() < CFG.GuardAvoidDist then
            evadeGuards()
            continue
        end
        if CFG.AutoSteal then
            local egg, d = closestEgg()
            if egg then
                State.targetEgg = egg
                if CFG.InstantSteal or d <= CFG.StealRadius then
                    task.spawn(function()
                        if not State.stealing then
                            State.stealing = true
                            tryStealEgg(egg)
                            task.wait(0.3)
                            State.stealing = false
                        end
                    end)
                else
                    setSpeed(CFG.FlySpeed)
                    local pos = getEggPos(egg)
                    if pos then safeTP(pos) end
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- ─── GUI ────────────────────────────────────────────────────────────────────
-- ═══════════════════════════════════════════════════════════════════════════

-- nuke old instance
pcall(function()
    if CoreGui:FindFirstChild("OllieGUI") then
        CoreGui:FindFirstChild("OllieGUI"):Destroy()
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "OllieGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui

-- ─── COLOURS ─────────────────────────────────────────────────────────────────
local C = {
    bg       = Color3.fromRGB(15,  15,  20),
    panel    = Color3.fromRGB(22,  22,  30),
    accent   = Color3.fromRGB(140, 60,  255),
    accentDim= Color3.fromRGB(80,  30,  160),
    on       = Color3.fromRGB(100, 255, 140),
    off      = Color3.fromRGB(255, 80,  80),
    text     = Color3.fromRGB(230, 230, 240),
    sub      = Color3.fromRGB(130, 130, 150),
    border   = Color3.fromRGB(60,  40,  100),
    topbar   = Color3.fromRGB(30,  15,  60),
}

-- ─── HELPERS ─────────────────────────────────────────────────────────────────
local function corner(parent, rad)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, rad or 8)
    c.Parent = parent
end

local function stroke(parent, col, thick)
    local s = Instance.new("UIStroke")
    s.Color = col or C.border
    s.Thickness = thick or 1.5
    s.Parent = parent
end

local function label(parent, txt, size, col, font)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextSize = size or 13
    l.TextColor3 = col or C.text
    l.Font = font or Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local function padding(parent, px)
    local p = Instance.new("UIPadding")
    local u = UDim.new(0, px or 8)
    p.PaddingLeft   = u
    p.PaddingRight  = u
    p.PaddingTop    = u
    p.PaddingBottom = u
    p.Parent = parent
end

-- ─── MAIN FRAME ──────────────────────────────────────────────────────────────
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 300, 0, 420)
Main.Position = UDim2.new(0, 40, 0, 100)
Main.BackgroundColor3 = C.bg
Main.BorderSizePixel = 0
Main.Parent = ScreenGui
corner(Main, 12)
stroke(Main, C.border, 1.5)

-- ─── TOPBAR ──────────────────────────────────────────────────────────────────
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BackgroundColor3 = C.topbar
TopBar.BorderSizePixel = 0
TopBar.Parent = Main
corner(TopBar, 12)

-- fix bottom corners of topbar
local TopFix = Instance.new("Frame")
TopFix.Size = UDim2.new(1,0,0,12)
TopFix.Position = UDim2.new(0,0,1,-12)
TopFix.BackgroundColor3 = C.topbar
TopFix.BorderSizePixel = 0
TopFix.Parent = TopBar

local TitleLbl = label(TopBar, "  🥚 absolute ollie", 14, C.text, Enum.Font.GothamBold)
TitleLbl.Size = UDim2.new(0.7, 0, 1, 0)
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left

local SubLbl = label(TopBar, "built by olivia  ", 10, C.sub, Enum.Font.Gotham)
SubLbl.Size = UDim2.new(0.5, 0, 1, 0)
SubLbl.Position = UDim2.new(0.5, 0, 0, 0)
SubLbl.TextXAlignment = Enum.TextXAlignment.Right

-- minimize button
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(1, -34, 0, 6)
MinBtn.BackgroundColor3 = C.accentDim
MinBtn.Text = "—"
MinBtn.TextColor3 = C.text
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 14
MinBtn.BorderSizePixel = 0
MinBtn.Parent = TopBar
corner(MinBtn, 6)

-- ─── CONTENT ─────────────────────────────────────────────────────────────────
local Content = Instance.new("ScrollingFrame")
Content.Name = "Content"
Content.Size = UDim2.new(1, 0, 1, -40)
Content.Position = UDim2.new(0, 0, 0, 40)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 3
Content.ScrollBarImageColor3 = C.accent
Content.CanvasSize = UDim2.new(0, 0, 0, 0)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.Parent = Main

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 6)
ListLayout.Parent = Content
padding(Content, 10)

-- ─── TOGGLE BUILDER ──────────────────────────────────────────────────────────
local function makeToggle(parent, text, desc, cfgKey, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, -20, 0, 54)
    Row.BackgroundColor3 = C.panel
    Row.BorderSizePixel = 0
    Row.Parent = parent
    corner(Row, 8)
    stroke(Row, C.border, 1)

    local Lbl = label(Row, text, 13, C.text, Enum.Font.GothamBold)
    Lbl.Size = UDim2.new(0.7, 0, 0, 20)
    Lbl.Position = UDim2.new(0, 10, 0, 8)

    local Desc = label(Row, desc, 10, C.sub, Enum.Font.Gotham)
    Desc.Size = UDim2.new(0.7, 0, 0, 16)
    Desc.Position = UDim2.new(0, 10, 0, 28)

    -- pill toggle
    local PillBG = Instance.new("Frame")
    PillBG.Size = UDim2.new(0, 44, 0, 22)
    PillBG.Position = UDim2.new(1, -54, 0.5, -11)
    PillBG.BackgroundColor3 = CFG[cfgKey] and C.accent or C.accentDim
    PillBG.BorderSizePixel = 0
    PillBG.Parent = Row
    corner(PillBG, 11)

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 16, 0, 16)
    Knob.Position = CFG[cfgKey]
        and UDim2.new(0, 24, 0.5, -8)
        or  UDim2.new(0, 4,  0.5, -8)
    Knob.BackgroundColor3 = Color3.new(1,1,1)
    Knob.BorderSizePixel = 0
    Knob.Parent = PillBG
    corner(Knob, 8)

    local StatusDot = Instance.new("Frame")
    StatusDot.Size = UDim2.new(0, 6, 0, 6)
    StatusDot.Position = UDim2.new(0, 10, 0.5, -3)
    StatusDot.BackgroundColor3 = CFG[cfgKey] and C.on or C.off
    StatusDot.BorderSizePixel = 0
    StatusDot.Parent = Row
    corner(StatusDot, 3)

    local function setToggle(val)
        CFG[cfgKey] = val
        local tweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad)
        TweenService:Create(PillBG, tweenInfo, {
            BackgroundColor3 = val and C.accent or C.accentDim
        }):Play()
        TweenService:Create(Knob, tweenInfo, {
            Position = val
                and UDim2.new(0, 24, 0.5, -8)
                or  UDim2.new(0, 4,  0.5, -8)
        }):Play()
        StatusDot.BackgroundColor3 = val and C.on or C.off
        if callback then callback(val) end
    end

    -- click anywhere on row
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 1, 0)
    Btn.BackgroundTransparency = 1
    Btn.Text = ""
    Btn.Parent = Row
    Btn.MouseButton1Click:Connect(function()
        setToggle(not CFG[cfgKey])
    end)

    return Row, setToggle
end

-- ─── SECTION HEADER ──────────────────────────────────────────────────────────
local function sectionHeader(parent, txt)
    local H = Instance.new("Frame")
    H.Size = UDim2.new(1, -20, 0, 24)
    H.BackgroundTransparency = 1
    H.Parent = parent

    local Line = Instance.new("Frame")
    Line.Size = UDim2.new(1, 0, 0, 1)
    Line.Position = UDim2.new(0, 0, 0.5, 0)
    Line.BackgroundColor3 = C.border
    Line.BorderSizePixel = 0
    Line.Parent = H

    local HLbl = label(H, "  " .. txt .. "  ", 10, C.accent, Enum.Font.GothamBold)
    HLbl.Size = UDim2.new(0, 120, 1, 0)
    HLbl.BackgroundColor3 = C.bg
    HLbl.BackgroundTransparency = 0
    HLbl.TextXAlignment = Enum.TextXAlignment.Center
end

-- ─── ACTION BUTTON ───────────────────────────────────────────────────────────
local function makeButton(parent, txt, cb)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, -20, 0, 36)
    Btn.BackgroundColor3 = C.accentDim
    Btn.Text = txt
    Btn.TextColor3 = C.text
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 13
    Btn.BorderSizePixel = 0
    Btn.Parent = parent
    corner(Btn, 8)
    stroke(Btn, C.border, 1)
    Btn.MouseButton1Click:Connect(function()
        TweenService:Create(Btn, TweenInfo.new(0.1), {
            BackgroundColor3 = C.accent
        }):Play()
        task.wait(0.15)
        TweenService:Create(Btn, TweenInfo.new(0.1), {
            BackgroundColor3 = C.accentDim
        }):Play()
        if cb then cb() end
    end)
    return Btn
end

-- ─── BUILD TOGGLES ───────────────────────────────────────────────────────────
sectionHeader(Content, "STEAL")
makeToggle(Content, "Auto Steal", "loops steal on nearest egg", "AutoSteal")
makeToggle(Content, "Instant Steal", "teleports directly onto egg", "InstantSteal")

sectionHeader(Content, "RACE")
makeToggle(Content, "Auto Race", "hits all checkpoints instantly", "AutoRace")

sectionHeader(Content, "GUARD")
makeToggle(Content, "Anti Guard", "evades guards automatically", "AntiGuard")

sectionHeader(Content, "ACTIONS")
makeButton(Content, "▶  Force Race Now", function()
    task.spawn(doRace)
end)
makeButton(Content, "🥚  Steal Nearest Egg", function()
    local egg = closestEgg()
    if egg then
        task.spawn(function() tryStealEgg(egg) end)
    end
end)
makeButton(Content, "⚡  Teleport to Egg", function()
    local egg, _ = closestEgg()
    if egg then
        local pos = getEggPos(egg)
        if pos then safeTP(pos) end
    end
end)

-- ─── FOOTER ──────────────────────────────────────────────────────────────────
local Footer = label(Content, "discord.gg/ojailbreaks  |  6767 gng", 9, C.sub, Enum.Font.Gotham)
Footer.Size = UDim2.new(1, -20, 0, 20)
Footer.TextXAlignment = Enum.TextXAlignment.Center

-- ─── DRAG ────────────────────────────────────────────────────────────────────
do
    local dragging, dragStart, startPos
    TopBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = inp.Position
            startPos  = Main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch) then
            local delta = inp.Position - dragStart
            Main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- ─── MINIMIZE ────────────────────────────────────────────────────────────────
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    local targetSize = minimized
        and UDim2.new(0, 300, 0, 40)
        or  UDim2.new(0, 300, 0, 420)
    TweenService:Create(Main, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
        Size = targetSize
    }):Play()
    MinBtn.Text = minimized and "+" or "—"
    Content.Visible = not minimized
end)

-- ─── BOOT PRINT ──────────────────────────────────────────────────────────────
print("absolute ollie — built by olivia | 6767 gng | discord.gg/ojailbreaks")
